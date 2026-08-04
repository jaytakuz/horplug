import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'invoice_calculator.dart';
import 'supabase_service.dart';

const _slipBucket = 'payment-slip';

/// ผลของการตรวจก่อนออกบิล — แยกห้องที่ออกได้ออกจากห้องที่ข้าม
class InvoicePreview {
  final List<InvoiceDraft> drafts;
  final List<InvoiceDraft> skipped;

  const InvoicePreview({required this.drafts, required this.skipped});

  double get total =>
      drafts.fold<double>(0, (sum, draft) => sum + draft.total);
}

/// ทุกอย่างที่คุยกับตาราง invoices และ bucket payment-slip
///
/// แยกจาก SupabaseService เพราะไฟล์นั้นถือหกโดเมนอยู่แล้วและยาว 972 บรรทัด
/// การย้ายโค้ด billing ออกมาทำให้ไฟล์เดิมเล็กลง ไม่ใช่ใหญ่ขึ้น
class InvoiceService {
  InvoiceService({SupabaseService? service})
      : _service = service ?? SupabaseService();

  final SupabaseService _service;

  SupabaseClient get _client => Supabase.instance.client;

  static const _columns = '''
    id, invoice_no, room_id, tenant_id, billing_month, billing_year,
    room_price, electricity_units, electricity_cost, water_cost, cleaning_fee,
    total, status, due_date, issued_at, slip_url, slip_submitted_at,
    rejection_reason, paid_at, revision, void_reason,
    rooms(room_number), tenant_profiles(first_name, last_name)
  ''';

  // ── อ่าน ────────────────────────────────────────────────────────────────

  /// บิลทุกใบของหอในงวดที่ระบุ รวมใบที่ยกเลิกแล้ว
  ///
  /// การกรอง "ยกเลิกแล้ว" ออกจากรายการปกติเป็นหน้าที่ของ ViewModel ไม่ใช่ของ
  /// ที่นี่ เพราะหน้าจอมีชิปให้ดูใบที่ยกเลิกด้วย
  Future<List<Invoice>> fetchInvoices({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    final data = await _client
        .from('invoices')
        .select(_columns)
        .eq('dorm_id', dormitoryId)
        .eq('billing_month', month)
        .eq('billing_year', year)
        .order('invoice_no');

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(_invoiceFromRow)
        .toList();
  }

  /// ประวัติบิลของห้องเดียว เรียงจากงวดล่าสุดไปเก่า
  Future<List<Invoice>> fetchForRoom({
    required int roomDbId,
    int monthCount = 6,
  }) async {
    final data = await _client
        .from('invoices')
        .select(_columns)
        .eq('room_id', roomDbId)
        .order('billing_year', ascending: false)
        .order('billing_month', ascending: false)
        .limit(monthCount);

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(_invoiceFromRow)
        .toList();
  }

  /// บิลของห้องในงวดที่ระบุ — null แปลว่ายังไม่ออกบิล ไม่ใช่ error
  Future<Invoice?> fetchCurrentForRoom({
    required int roomDbId,
    required int month,
    required int year,
  }) async {
    final data = await _client
        .from('invoices')
        .select(_columns)
        .eq('room_id', roomDbId)
        .eq('billing_month', month)
        .eq('billing_year', year)
        .neq('status', InvoiceStatus.voided.name)
        .maybeSingle();

    return data == null ? null : _invoiceFromRow(data);
  }

  // ── ตรวจก่อนออกบิล ──────────────────────────────────────────────────────

  /// ประกอบร่างบิลของทุกห้องในหอสำหรับงวดที่ระบุ
  ///
  /// รวมทุกห้อง ไม่กรองทิ้ง เพราะหน้าจอต้องบอกได้ว่าห้องไหนข้ามเพราะอะไร
  Future<InvoicePreview> previewDrafts({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    final rooms = await _service.fetchRooms(dormitoryId: dormitoryId);
    final roomIds = rooms.map((room) => room.dbId).toList();
    if (roomIds.isEmpty) {
      return const InvoicePreview(drafts: [], skipped: []);
    }

    final elecs = await _client
        .from('electricity_record')
        .select()
        .inFilter('room_id', roomIds)
        .eq('billing_month', month)
        .eq('billing_year', year);
    final waters = await _client
        .from('water_meter')
        .select()
        .inFilter('room_id', roomIds)
        .eq('billing_month', month)
        .eq('billing_year', year);
    final issued = await _client
        .from('invoices')
        .select('room_id')
        .inFilter('room_id', roomIds)
        .eq('billing_month', month)
        .eq('billing_year', year)
        .neq('status', InvoiceStatus.voided.name);

    final elecData = (elecs as List).cast<Map<String, dynamic>>();
    final waterData = (waters as List).cast<Map<String, dynamic>>();
    final issuedRoomIds = (issued as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['room_id'] as int)
        .toSet();
    final cleaningByRoom = await _fetchCleaningFeesByRoom(
      roomIds: roomIds,
      month: month,
      year: year,
    );

    final drafts = <InvoiceDraft>[];
    final skipped = <InvoiceDraft>[];

    for (final room in rooms) {
      final e = elecData.firstWhere((r) => r['room_id'] == room.dbId,
          orElse: () => {});
      final w = waterData.firstWhere((r) => r['room_id'] == room.dbId,
          orElse: () => {});

      final draft = buildDraft(
        room: room,
        billingMonth: month,
        billingYear: year,
        electricity: e.isEmpty
            ? null
            : MeterCharge(
                units: _toDouble(e['current_reading']) -
                    _toDouble(e['previous_reading']),
                amount: _toDouble(e['amount']),
              ),
        waterAmount: w.isEmpty ? null : _toDouble(w['amount']),
        cleaningFee: cleaningByRoom[room.dbId] ?? 0,
        alreadyIssued: issuedRoomIds.contains(room.dbId),
      );

      (draft.canIssue ? drafts : skipped).add(draft);
    }

    return InvoicePreview(drafts: drafts, skipped: skipped);
  }

  /// ค่าทำความสะอาดจากคำขอที่เสร็จสิ้นในงวดนั้น แยกตามห้อง
  Future<Map<int, double>> _fetchCleaningFeesByRoom({
    required List<int> roomIds,
    required int month,
    required int year,
  }) async {
    final periodStart = DateTime(year, month, 1);
    final periodEnd = DateTime(month == 12 ? year + 1 : year,
        month == 12 ? 1 : month + 1, 1);

    final data = await _client
        .from('maintenance_requests')
        .select('room_id, cleaning_fee')
        .inFilter('room_id', roomIds)
        .eq('request_type', 'Cleaning')
        .eq('status', 'Completed')
        .gte('completed_at', periodStart.toIso8601String())
        .lt('completed_at', periodEnd.toIso8601String());

    final feeByRoom = <int, double>{};
    for (final row in (data as List).cast<Map<String, dynamic>>()) {
      final roomId = row['room_id'] as int;
      feeByRoom[roomId] =
          (feeByRoom[roomId] ?? 0) + _toDouble(row['cleaning_fee']);
    }
    return feeByRoom;
  }

  // ── สลิป ────────────────────────────────────────────────────────────────

  /// อัปโหลดสลิปแล้วคืน storage path
  Future<String> uploadSlip({
    required Invoice invoice,
    required File file,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${invoice.roomDbId}/${invoice.invoiceNo}-$stamp.jpg';
    await _client.storage.from(_slipBucket).upload(path, file);
    return path;
  }

  /// บันทึกสลิปเข้าบิลผ่าน RPC ที่ตรวจสิทธิ์และสถานะเองในฐานข้อมูล
  ///
  /// ไม่ UPDATE ตรงเพราะ RLS policy จำกัดไม่ได้ว่าคอลัมน์ไหนแก้ได้
  Future<void> submitSlip({
    required int invoiceId,
    required String slipPath,
  }) async {
    await _client.rpc('submit_payment_slip', params: {
      'p_invoice_id': invoiceId,
      'p_slip_url': slipPath,
    });
  }

  /// ลบสลิปที่เพิ่งอัปโหลดเมื่อขั้นตอนถัดไปล้ม — best effort
  Future<void> discardSlip(String path) async {
    try {
      await _client.storage.from(_slipBucket).remove([path]);
    } catch (_) {
      // ปล่อยผ่าน: ไฟล์กำพร้าหนึ่งไฟล์ไม่ควรกลบข้อความ error ตัวจริง
    }
  }

  /// signed URL อายุ 1 ชั่วโมง สร้างใหม่ทุกครั้งที่เปิดดู ไม่ cache ข้าม session
  Future<String> signedSlipUrl(String path) =>
      _client.storage.from(_slipBucket).createSignedUrl(path, 3600);
}

// ── แปลงแถว ───────────────────────────────────────────────────────────────

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

InvoiceStatus _statusFromName(String? name) {
  return InvoiceStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => InvoiceStatus.unpaid,
  );
}

/// PostgREST คืน Map สำหรับ many-to-one และ List สำหรับ one-to-many
/// จึงรองรับทั้งสองแบบเหมือนที่ fetchDormitoryInfo ทำอยู่แล้ว
Map<String, dynamic>? _embedded(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return (value.first as Map).cast<String, dynamic>();
  }
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

Invoice _invoiceFromRow(Map<String, dynamic> row) {
  final room = _embedded(row['rooms']);
  final tenant = _embedded(row['tenant_profiles']);
  final tenantName = [
    tenant?['first_name'] as String?,
    tenant?['last_name'] as String?,
  ].where((part) => part != null && part.trim().isNotEmpty).join(' ').trim();

  return Invoice(
    dbId: row['id'] as int,
    invoiceNo: row['invoice_no'] as String,
    roomDbId: row['room_id'] as int,
    roomNumber: room?['room_number'] as String? ?? '-',
    tenantId: row['tenant_id'] as String?,
    tenantName: tenantName.isEmpty ? '-' : tenantName,
    billingMonth: row['billing_month'] as int,
    billingYear: row['billing_year'] as int,
    roomPrice: _toDouble(row['room_price']),
    electricityUnits: _toDouble(row['electricity_units']),
    electricityCost: _toDouble(row['electricity_cost']),
    waterCost: _toDouble(row['water_cost']),
    cleaningFee: _toDouble(row['cleaning_fee']),
    total: _toDouble(row['total']),
    status: _statusFromName(row['status'] as String?),
    // due_date เป็น DATE ไม่ใช่ TIMESTAMPTZ — ใส่ toLocal() จะเลื่อนไปหนึ่งวัน
    dueDate: DateTime.parse(row['due_date'] as String),
    // ที่เหลือเป็น TIMESTAMPTZ ซึ่ง parse ออกมาเป็น UTC แปลงเป็นเวลาเครื่อง
    // ตั้งแต่ขอบของการ map เพื่อไม่ให้หน้าจอไหนต้องจำว่าต้องแปลงเอง
    issuedAt: DateTime.parse(row['issued_at'] as String).toLocal(),
    slipUrl: row['slip_url'] as String?,
    slipSubmittedAt: row['slip_submitted_at'] == null
        ? null
        : DateTime.parse(row['slip_submitted_at'] as String).toLocal(),
    rejectionReason: row['rejection_reason'] as String?,
    paidAt: row['paid_at'] == null
        ? null
        : DateTime.parse(row['paid_at'] as String).toLocal(),
    revision: row['revision'] as int? ?? 1,
    voidReason: row['void_reason'] as String?,
  );
}
