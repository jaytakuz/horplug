import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../viewmodels/tenant_dashboard_view_model.dart' show thaiMonthName;
import 'invoice_calculator.dart';
import 'invoice_lifecycle.dart';
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
  ///
  /// ใบที่ยกเลิกถูกกรองออกโดยค่าเริ่มต้น ไม่ใช่แค่เพื่อความสะอาดของรายการ แต่
  /// เพราะ [monthCount] ถูกใช้เป็น `limit` ซึ่งนับ **แถว** งวดที่มีทั้งใบที่
  /// ยกเลิกและใบแทนจึงกินโควตาสองแถว ทำให้ "ประวัติ 6 เดือน" เหลือ 5 เดือนโดย
  /// เงียบสนิท เมื่อกรอง voided ออกแล้ว partial unique index
  /// (`invoices_one_active_per_period`) รับประกันว่าหนึ่งงวดเหลือได้อย่างมาก
  /// หนึ่งแถว หนึ่งแถวจึงเท่ากับหนึ่งเดือนจริงๆ
  ///
  /// [includeVoided] มีไว้ให้ [invoicesByIdForRoom] ซึ่งต้อง resolve บิลทุกใบที่
  /// การ์ดในแชทอ้างถึง รวมใบที่ยกเลิกไปแล้ว — ที่นั่น [monthCount] กลับไปเป็น
  /// จำนวนแถวตามตรง
  Future<List<Invoice>> fetchForRoom({
    required int roomDbId,
    int monthCount = 6,
    bool includeVoided = false,
  }) async {
    var query = _client.from('invoices').select(_columns).eq('room_id', roomDbId);
    if (!includeVoided) {
      query = query.neq('status', InvoiceStatus.voided.name);
    }

    final data = await query
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
        // หน่วยต้องผ่าน meterUnitsUsed เหมือนกับที่ ElectricityRecord.amount
        // ผ่านตอนบันทึกมิเตอร์ ไม่งั้นงวดที่มิเตอร์หมุนกลับ 9999 → 0000 จะถูก
        // ตรึงลงบิลเป็นหน่วยติดลบข้างค่าไฟที่ถูกต้อง แล้วพิมพ์ออก PDF แบบนั้น
        electricity: e.isEmpty
            ? null
            : MeterCharge(
                units: meterUnitsUsed(
                  previousReading: _toDouble(e['previous_reading']),
                  currentReading: _toDouble(e['current_reading']),
                ),
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

  /// ออกบิลทั้งชุดใน insert เดียว
  ///
  /// Postgres รับประกัน all-or-nothing ให้เอง จึงไม่มีสภาพ "ออกไป 7 จาก 12
  /// ห้องแล้วค้าง" และการกดซ้อนกันจะชนที่ partial unique index เป็น 23505
  /// แทนที่จะสร้างบิลซ้ำเงียบๆ
  Future<List<Invoice>> issueInvoices({
    required int dormitoryId,
    required List<InvoiceDraft> drafts,
  }) async {
    if (drafts.isEmpty) return [];

    final issuedBy = _client.auth.currentUser?.id;
    if (issuedBy == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final superseded = await _supersededByRoom(drafts);

    final rows = drafts.map((draft) {
      final due = dueDateFor(draft.billingYear, draft.billingMonth);
      final previous = superseded[draft.roomDbId];
      final revision = (previous?.revision ?? 0) + 1;

      return {
        'invoice_no': invoiceNoFor(
          year: draft.billingYear,
          month: draft.billingMonth,
          roomNumber: draft.roomNumber,
          revision: revision,
        ),
        'dorm_id': dormitoryId,
        'room_id': draft.roomDbId,
        'tenant_id': draft.tenantId,
        'billing_month': draft.billingMonth,
        'billing_year': draft.billingYear,
        'room_price': draft.roomPrice,
        'electricity_units': draft.electricityUnits,
        'electricity_cost': draft.electricityCost,
        'water_cost': draft.waterCost,
        'cleaning_fee': draft.cleaningFee,
        'due_date':
            '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
        'issued_by': issuedBy,
        'revision': revision,
        if (previous != null) 'replaces_invoice_id': previous.id,
      };
    }).toList();

    final inserted = await _client.from('invoices').insert(rows).select(_columns);
    return (inserted as List)
        .cast<Map<String, dynamic>>()
        .map(_invoiceFromRow)
        .toList();
  }

  /// บิลใบล่าสุดของแต่ละห้องในงวดที่กำลังจะออก — รวมใบที่ยกเลิกแล้ว
  ///
  /// มีอยู่เพราะเลขที่บิลไม่ซ้ำทั้งหอ (`invoices_no_per_dorm`) และใบที่ยกเลิก
  /// **ยังถือครองเลขของมันอยู่** ถ้าออกบิลงวดเดิมซ้ำโดยไม่ขยับ revision เลขจะชน
  /// เป็น 23505 และเพราะเป็น batch insert เดียว ทั้งหอจะไม่ได้บิลสักห้อง โดยที่
  /// ข้อความบอกให้ "โหลดใหม่" ซึ่งไม่ได้แก้อะไรเลย
  Future<Map<int, ({int id, int revision})>> _supersededByRoom(
    List<InvoiceDraft> drafts,
  ) async {
    final roomIds = drafts.map((draft) => draft.roomDbId).toList();
    final first = drafts.first;

    final rows = await _client
        .from('invoices')
        .select('id, room_id, revision')
        .inFilter('room_id', roomIds)
        .eq('billing_month', first.billingMonth)
        .eq('billing_year', first.billingYear);

    final latest = <int, ({int id, int revision})>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final roomId = row['room_id'] as int;
      final revision = (row['revision'] as int?) ?? 1;
      // เก็บ revision สูงสุดไว้ ห้องหนึ่งอาจถูกยกเลิกมาแล้วหลายรอบ
      if (revision > (latest[roomId]?.revision ?? 0)) {
        latest[roomId] = (id: row['id'] as int, revision: revision);
      }
    }
    return latest;
  }

  /// โพสต์การ์ดบิลเข้าห้องแชทของแต่ละบิล
  ///
  /// เป็น batch insert เดียวเช่นกัน ถ้าล้มก็ล้มทั้งชุด — บิลยังอยู่ ผู้เรียก
  /// รายงานว่าแจ้งเตือนไม่สำเร็จแล้วให้กดส่งซ้ำ ไม่ rollback บิล เพราะบิลคือ
  /// ของจริง ข้อความคือการแจ้งเตือนเกี่ยวกับมัน
  Future<int> postIssueNotices({required List<Invoice> invoices}) async {
    if (invoices.isEmpty) return 0;

    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    // ข้ามใบที่เคยแจ้งไปแล้ว เพื่อให้ปุ่มส่งซ้ำไม่สร้างข้อความซ้อน
    final existing = await _client
        .from('messages')
        .select('invoice_id')
        .inFilter('invoice_id', invoices.map((i) => i.dbId).toList())
        .eq('message_type', MessageType.invoice.name);
    final notified = (existing as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['invoice_id'] as int)
        .toSet();

    final rows = invoices
        .where((invoice) => !notified.contains(invoice.dbId))
        .map((invoice) => {
              'room_id': invoice.roomDbId,
              'sender_id': senderId,
              'is_from_owner': true,
              'body': 'ออกบิลค่าเช่างวด'
                  '${thaiMonthName(invoice.billingMonth)} '
                  '${invoice.billingYear} แล้ว',
              'message_type': MessageType.invoice.name,
              'invoice_id': invoice.dbId,
            })
        .toList();

    if (rows.isEmpty) return 0;
    await _client.from('messages').insert(rows);
    return rows.length;
  }

  /// บิลของห้องหนึ่ง map ด้วย id — ให้การ์ดในแชทแสดงสถานะสด ไม่ใช่สถานะตอนส่ง
  Future<Map<int, Invoice>> invoicesByIdForRoom({
    required int roomDbId,
    int rowCount = 24,
  }) async {
    // includeVoided: การ์ดในแชทที่ชี้ไปยังบิลที่ถูกยกเลิกต้องขึ้นป้าย
    // "ยกเลิกแล้ว" ไม่ใช่ตกกลับไปเป็นข้อความเปล่าเพราะ resolve ไม่เจอ
    final invoices = await fetchForRoom(
      roomDbId: roomDbId,
      monthCount: rowCount,
      includeVoided: true,
    );
    return {for (final invoice in invoices) invoice.dbId: invoice};
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

  // ── เจ้าของหอตรวจสลิป ──────────────────────────────────────────────────

  Future<void> approveSlip({required Invoice invoice}) async {
    _assertTransition(invoice.status, InvoiceStatus.paid);

    final approvedBy = _client.auth.currentUser?.id;
    await _client.from('invoices').update({
      'status': InvoiceStatus.paid.name,
      // .toUtc() ก่อนแปลงเป็นสตริงเสมอ — DateTime.now() ไม่มี UTC เป็นค่า
      // เครื่องท้องถิ่น (ICT = UTC+7) ไม่มี offset ต่อท้าย Postgres จึงตีความ
      // ตาม session timezone ซึ่งบน Supabase คือ UTC แล้วเวลาที่บันทึกจะ
      // เพี้ยนไปเจ็ดชั่วโมงจากที่กดจริง ต่างจาก issued_at/slip_submitted_at
      // ที่มาจาก NOW() ฝั่งเซิร์ฟเวอร์อยู่แล้ว
      'paid_at': DateTime.now().toUtc().toIso8601String(),
      'approved_by': approvedBy,
    }).eq('id', invoice.dbId);

    await _postInvoiceNotice(
      invoice: invoice,
      body: 'รับชำระบิล ${invoice.invoiceNo} เรียบร้อยแล้ว ขอบคุณครับ',
    );
  }

  /// ปฏิเสธพากลับไป unpaid ไม่ใช่สถานะที่ห้า เพราะสิ่งที่ผู้เช่าต้องทำ
  /// เหมือนเดิมคือจ่ายใหม่ ต่างแค่มีเหตุผลให้อ่าน
  Future<void> rejectSlip({
    required Invoice invoice,
    required String reason,
  }) async {
    _assertTransition(invoice.status, InvoiceStatus.unpaid);

    // เก็บ path เดิมไว้ก่อน column จะถูกเซ็ตเป็น null — ไม่งั้นไฟล์ในบัคเก็ต
    // payment-slip จะกำพร้าอยู่ถาวรเพราะไม่มีบิลไหนอ้างอิงมันอีกแล้ว
    final oldSlipPath = invoice.slipUrl;

    // อัปเดตแถวก่อน แล้วค่อยลบไฟล์ ลำดับกลับกันทำให้บิลที่ยังเป็น pending ชี้ไป
    // ที่ไฟล์ที่ถูกลบไปแล้วเมื่อ update ล้ม ซึ่งกู้ไม่ได้จากทั้งสองฝั่ง —
    // เจ้าของหอเปิดสลิปแล้วเจอ 404 ส่วนผู้เช่าแนบใหม่ไม่ได้เพราะบิลไม่ได้อยู่ที่
    // unpaid ไฟล์กำพร้าหนึ่งไฟล์ราคาถูกกว่าบิลที่ค้างอยู่ในสภาพนั้นมาก
    await _client.from('invoices').update({
      'status': InvoiceStatus.unpaid.name,
      'rejection_reason': reason,
      'slip_url': null,
      'slip_submitted_at': null,
    }).eq('id', invoice.dbId);

    if (oldSlipPath != null) {
      await discardSlip(oldSlipPath);
    }

    await _postInvoiceNotice(
      invoice: invoice,
      body: 'สลิปของบิล ${invoice.invoiceNo} ไม่ผ่านการตรวจสอบ: $reason',
    );
  }

  // ── ยกเลิกและออกใบแทน ──────────────────────────────────────────────────

  Future<void> voidInvoice({
    required Invoice invoice,
    required String reason,
  }) async {
    _assertTransition(invoice.status, InvoiceStatus.voided);

    await _client.from('invoices').update({
      'status': InvoiceStatus.voided.name,
      // .toUtc() — เหตุผลเดียวกับ paid_at ใน approveSlip ด้านบน
      'voided_at': DateTime.now().toUtc().toIso8601String(),
      'void_reason': reason,
    }).eq('id', invoice.dbId);

    await _postInvoiceNotice(
      invoice: invoice,
      body: 'บิล ${invoice.invoiceNo} ถูกยกเลิก: $reason',
    );
  }

  /// ออกใบแทนจากมิเตอร์ปัจจุบัน — เรียกหลัง voidInvoice เท่านั้น
  ///
  /// partial unique index ปล่อยให้ใบใหม่เกิดได้เพราะใบเดิมไม่นับเป็น active
  /// แล้ว revision + 1 ทำให้เลขที่บิลไม่ชนกัน และ replaces_invoice_id ทำให้
  /// สลิปที่จ่ายใบเดิมไปแล้วยังตามรอยได้
  Future<Invoice?> reissueInvoice({
    required Invoice voided,
    required int dormitoryId,
  }) async {
    final preview = await previewDrafts(
      dormitoryId: dormitoryId,
      month: voided.billingMonth,
      year: voided.billingYear,
    );

    InvoiceDraft? draft;
    for (final candidate in preview.drafts) {
      if (candidate.roomDbId == voided.roomDbId) {
        draft = candidate;
        break;
      }
    }
    if (draft == null) return null;

    final issuedBy = _client.auth.currentUser?.id;
    if (issuedBy == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final revision = voided.revision + 1;
    final due = dueDateFor(draft.billingYear, draft.billingMonth);

    final inserted = await _client.from('invoices').insert({
      'invoice_no': invoiceNoFor(
        year: draft.billingYear,
        month: draft.billingMonth,
        roomNumber: draft.roomNumber,
        revision: revision,
      ),
      'dorm_id': dormitoryId,
      'room_id': draft.roomDbId,
      'tenant_id': draft.tenantId,
      'billing_month': draft.billingMonth,
      'billing_year': draft.billingYear,
      'room_price': draft.roomPrice,
      'electricity_units': draft.electricityUnits,
      'electricity_cost': draft.electricityCost,
      'water_cost': draft.waterCost,
      'cleaning_fee': draft.cleaningFee,
      'due_date':
          '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
      'issued_by': issuedBy,
      'revision': revision,
      'replaces_invoice_id': voided.dbId,
    }).select(_columns).single();

    final invoice = _invoiceFromRow(inserted);

    // ใบแทนเกิดแล้ว ณ จุดนี้ การแจ้งเตือนที่ล้มต้องไม่ถูกรายงานว่า "ออกใบแทน
    // ไม่สำเร็จ" — ถ้าปล่อยให้ throw ขึ้นไป ผู้ใช้จะกดใหม่ แล้วรอบสองห้องนั้นมี
    // บิลอยู่แล้วจึงไม่อยู่ในร่าง ทำให้ได้ข้อความว่า "ยังไม่ได้จดมิเตอร์ หรือ
    // ห้องไม่มีผู้เช่า" ซึ่งไม่จริงสักข้อ
    try {
      await postIssueNotices(invoices: [invoice]);
    } catch (_) {
      // การ์ดในแชทเป็นการประกาศเกี่ยวกับบิล ไม่ใช่ตัวบิล
    }

    return invoice;
  }

  void _assertTransition(InvoiceStatus from, InvoiceStatus to) {
    if (!canTransition(from, to)) {
      throw Exception('บิลใบนี้เปลี่ยนสถานะแบบนั้นไม่ได้');
    }
  }

  /// ข้อความธรรมดาที่ผูกกับบิล — ต่างจากการ์ดตอนออกบิลตรงที่ไม่ต้องเปิดดูอะไร
  Future<void> _postInvoiceNotice({
    required Invoice invoice,
    required String body,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) return;

    await _client.from('messages').insert({
      'room_id': invoice.roomDbId,
      'sender_id': senderId,
      'is_from_owner': true,
      'body': body,
      'message_type': MessageType.text.name,
      'invoice_id': invoice.dbId,
    });
  }
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
