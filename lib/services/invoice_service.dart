import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../models/picked_image.dart';
import '../utils/formatters.dart' show formatBaht;
import '../viewmodels/tenant_dashboard_view_model.dart' show thaiMonthName;
import 'invoice_calculator.dart';
import 'invoice_lifecycle.dart';
import 'supabase_service.dart';

const _slipBucket = 'payment-slip';

/// ข้อมูลของงวดหนึ่ง map ตามห้อง — ผลของ [InvoiceService._fetchPeriodInputs]
///
/// การไม่มีคีย์กับการมีคีย์ที่เป็น 0 คนละความหมาย: ห้องที่ไม่มีใน [water] คือ
/// ยังไม่มีใครกรอกค่าน้ำงวดนี้ ส่วนห้องที่มีค่า 0 คือกรอกไว้แล้วว่าไม่เก็บ ·
/// [electricity] ก็เช่นกัน ห้องที่ยังไม่จดเลขมิเตอร์จะไม่มีคีย์เลย
class _PeriodInputs {
  const _PeriodInputs({
    required this.electricity,
    required this.water,
    required this.carriedExtraFees,
  });

  final Map<int, MeterCharge> electricity;
  final Map<int, double> water;
  final Map<int, List<ExtraFee>> carriedExtraFees;

  MeterCharge? electricityFor(int roomDbId) => electricity[roomDbId];
  double? waterFor(int roomDbId) => water[roomDbId];

  /// ไม่มีบิลก่อนหน้า หรือบิลก่อนหน้าไม่มีรายการ "ทุกเดือน" = ไม่มีอะไรให้พก
  List<ExtraFee> carriedExtraFeesFor(int roomDbId) =>
      carriedExtraFees[roomDbId] ?? const [];
}

/// ผลของการตรวจก่อนออกบิล — แยกห้องที่ออกได้ออกจากห้องที่ข้าม
class InvoicePreview {
  final List<InvoiceDraft> drafts;
  final List<InvoiceDraft> skipped;

  const InvoicePreview({required this.drafts, required this.skipped});

  double get total => drafts.fold<double>(0, (sum, draft) => sum + draft.total);
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

  /// `*` ไม่ใช่รายชื่อคอลัมน์ — จงใจ
  ///
  /// เดิมไล่ชื่อคอลัมน์ทีละตัว ซึ่งทำให้**การเพิ่มคอลัมน์ใหม่กลายเป็น breaking
  /// change ทันที**: แอปที่รู้จัก payment_method แต่เจอฐานข้อมูลที่ยังไม่ได้รัน
  /// migration จะได้ 42703 กลับมาจากทุก query ที่แตะบิล ทั้งหน้าบิล แดชบอร์ด
  /// และการ์ดในแชทล่มพร้อมกันเพราะคอลัมน์เดียวที่ยังไม่มี ทั้งที่ฟีเจอร์ที่ใช้
  /// คอลัมน์นั้นเป็นแค่ส่วนเล็กๆ ส่วนหนึ่ง
  ///
  /// ด้วย `*` คอลัมน์ที่ยังไม่มีจะหายไปจาก row เฉยๆ แล้ว `_invoiceFromRow`
  /// อ่านได้เป็น null ซึ่งทุกฟิลด์ที่เพิ่มมาทีหลังรองรับอยู่แล้ว — ระบบจึงทำงาน
  /// ต่อได้ระหว่างที่ migration ยังไม่ถูกรัน แค่ฟีเจอร์ใหม่ยังไม่ทำงาน
  ///
  /// ต้นทุนคือคอลัมน์ที่ไม่ได้ใช้ (created_at, issued_by, approved_by ฯลฯ)
  /// ถูกส่งมาด้วย ซึ่งเป็นไม่กี่ไบต์ต่อแถวบนตารางที่นับแถวได้ด้วยหลักสิบ
  static const _columns = '''
    *, rooms(room_number), tenant_profiles(first_name, last_name)
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
        .order('invoice_no', ascending: true);

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
    var query =
        _client.from('invoices').select(_columns).eq('room_id', roomDbId);
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

  /// จำนวนบิลของหอที่ผู้เช่าแจ้งชำระมาแล้วและรอเจ้าของหอตรวจ
  ///
  /// นับทุกงวด ไม่ใช่เฉพาะงวดปัจจุบัน — สลิปของบิลเดือนที่แล้วที่ยังไม่มีใครกด
  /// ตรวจคืองานที่ค้างอยู่จริงๆ และเป็นงานที่ลืมง่ายที่สุดเพราะไม่มีอะไรทวง
  ///
  /// error ถูกปล่อยขึ้นไป ผู้เรียกบนแดชบอร์ดเลือกเองว่าจะซ่อน badge เงียบๆ
  /// ดีกว่าคืน 0 ที่นี่ ซึ่งอ่านไม่ออกว่าไม่มีงานค้างหรือนับไม่สำเร็จ
  Future<int> countAwaitingReview({required int dormitoryId}) async {
    final rows = await _client
        .from('invoices')
        .select('id')
        .eq('dorm_id', dormitoryId)
        .eq('status', InvoiceStatus.pending.name);

    return (rows as List).length;
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

    final issued = await _client
        .from('invoices')
        .select('room_id')
        .inFilter('room_id', roomIds)
        .eq('billing_month', month)
        .eq('billing_year', year)
        .neq('status', InvoiceStatus.voided.name);

    final issuedRoomIds = (issued as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['room_id'] as int)
        .toSet();

    final inputs = await _fetchPeriodInputs(
      roomIds: roomIds,
      month: month,
      year: year,
    );

    final drafts = <InvoiceDraft>[];
    final skipped = <InvoiceDraft>[];

    for (final room in rooms) {
      final draft = buildDraft(
        room: room,
        billingMonth: month,
        billingYear: year,
        electricity: inputs.electricityFor(room.dbId),
        waterAmount: inputs.waterFor(room.dbId),
        carriedExtraFees: inputs.carriedExtraFeesFor(room.dbId),
        alreadyIssued: issuedRoomIds.contains(room.dbId),
      );

      (draft.canIssue ? drafts : skipped).add(draft);
    }

    return InvoicePreview(drafts: drafts, skipped: skipped);
  }

  /// ข้อมูลดิบของงวดที่ใช้ตัดสินยอดบิล — ใช้ร่วมกันระหว่างการออกบิลกับการ
  /// คำนวณยอดใหม่ เพื่อไม่ให้สองเส้นทางตีความข้อมูลชุดเดียวกันคนละแบบ
  Future<_PeriodInputs> _fetchPeriodInputs({
    required List<int> roomIds,
    required int month,
    required int year,
  }) async {
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
    final carriedExtraFeesByRoom = await _fetchCarriedExtraFeesByRoom(
      roomIds: roomIds,
      month: month,
      year: year,
    );

    final electricity = <int, MeterCharge>{};
    for (final row in (elecs as List).cast<Map<String, dynamic>>()) {
      // current_reading เป็น NULL ได้เมื่อมีแถวมิเตอร์รอไว้แต่ยังไม่ได้จดเลข
      // งวดนี้ · ต้องไม่ใส่ลงแมปเลย ไม่ใช่ใส่เป็น 0 เพราะ 0 น้อยกว่าเลขครั้งก่อน
      // เสมอ มันจึงเข้าเงื่อนไขมิเตอร์วนรอบแล้วคืน (10000 − เลขครั้งก่อน) —
      // ห้องที่ยังไม่จดมิเตอร์จะได้บิลที่ตรึงหน่วยไฟหลักพันไว้ทั้งที่ไม่มีใคร
      // อ่านมิเตอร์เลย
      if (row['current_reading'] == null) continue;

      // หน่วยต้องผ่าน meterUnitsUsed เหมือนกับที่ ElectricityRecord.amount ผ่าน
      // ตอนบันทึกมิเตอร์ ไม่งั้นงวดที่มิเตอร์หมุนกลับ 9999 → 0000 จะถูกตรึงลงบิล
      // เป็นหน่วยติดลบข้างค่าไฟที่ถูกต้อง แล้วพิมพ์ออก PDF แบบนั้น
      electricity[row['room_id'] as int] = MeterCharge(
        units: meterUnitsUsed(
          previousReading: _toDouble(row['previous_reading']),
          currentReading: _toDouble(row['current_reading']),
        ),
        amount: _toDouble(row['amount']),
      );
    }

    final water = <int, double>{
      for (final row in (waters as List).cast<Map<String, dynamic>>())
        row['room_id'] as int: _toDouble(row['amount']),
    };

    return _PeriodInputs(
      electricity: electricity,
      water: water,
      carriedExtraFees: carriedExtraFeesByRoom,
    );
  }

  /// ปรับยอดบิลค้างชำระของงวดให้ตรงกับข้อมูลล่าสุด · คืนใบที่ปรับสำเร็จแยกจาก
  /// ใบที่ปรับไม่สำเร็จ
  ///
  /// เขียนตอนที่เจ้าของหอทำอะไรบางอย่าง ไม่ใช่ตอนที่ใครสักคนเปิดหน้าดู —
  /// ผู้เช่าไม่มีสิทธิ์ UPDATE ตารางนี้ (RLS) และถ้าคำนวณสดตอนแสดงผล QR
  /// พร้อมเพย์กับแถวในฐานข้อมูลจะพูดคนละยอด
  ///
  /// ต้องรัน `database/invoices_recalculation.sql` ก่อน ไม่งั้น UPDATE จะตกด้วย
  /// 42703 (ไม่มีคอลัมน์ recalculated_at)
  ///
  /// แต่ละใบ UPDATE แยกคำสั่งกัน (ไม่ใช่ batch เดียวเหมือน [issueInvoices])
  /// ก่อนแก้ ใบที่ 3 จาก 5 ล้มทำให้ทั้งฟังก์ชัน throw — ใบที่ 1-2 ที่ถูกเขียน
  /// ไปแล้วในฐานข้อมูลจริงๆ ก็หายไปจากผลลัพธ์ที่คืน ผู้เรียกจึงไม่มีทางรู้ว่าต้อง
  /// ส่ง postAdjustmentNotices ให้สองใบนั้น และรอบถัดไปก็จะไม่เห็นว่ามันยังต้อง
  /// ปรับอีก (revalueInvoice เทียบกับแถวที่ถูกต้องแล้ว) ใบที่ถูกปรับไปแล้วแต่ยัง
  /// ไม่เคยแจ้งผู้เช่าจึงติดอยู่แบบนั้นถาวร ตอนนี้แต่ละใบจึงล้มแยกจากกันได้ ไม่
  /// ทำให้ใบอื่นที่ update สำเร็จหายไปจากผลลัพธ์ด้วย
  Future<({List<InvoiceAdjustment> applied, List<InvoiceAdjustment> failed})>
      syncUnpaidInvoices({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    final rooms = await _service.fetchRooms(dormitoryId: dormitoryId);
    if (rooms.isEmpty) return (applied: <InvoiceAdjustment>[], failed: <InvoiceAdjustment>[]);

    final invoices = await fetchInvoices(
      dormitoryId: dormitoryId,
      month: month,
      year: year,
    );
    final unpaid = invoices
        .where((invoice) => invoice.status == InvoiceStatus.unpaid)
        .toList();
    // ไม่มีใบที่แก้ได้ = ไม่ต้องยิงคิวรีข้อมูลงวดเลย · ท่าทางลากรีเฟรชเรียก
    // เมธอดนี้ทุกครั้ง งวดที่เก็บเงินครบแล้วจึงไม่ควรจ่ายค่าคิวรีสามชุด
    if (unpaid.isEmpty) return (applied: <InvoiceAdjustment>[], failed: <InvoiceAdjustment>[]);

    final inputs = await _fetchPeriodInputs(
      roomIds: rooms.map((room) => room.dbId).toList(),
      month: month,
      year: year,
    );
    final roomsById = {for (final room in rooms) room.dbId: room};

    final adjustments = <InvoiceAdjustment>[];
    for (final invoice in unpaid) {
      final room = roomsById[invoice.roomDbId];
      if (room == null) continue;

      final adjustment = revalueInvoice(
        invoice: invoice,
        room: room,
        electricity: inputs.electricityFor(invoice.roomDbId),
        waterAmount: inputs.waterFor(invoice.roomDbId),
      );
      if (adjustment != null) adjustments.add(adjustment);
    }

    final applied = <InvoiceAdjustment>[];
    final failed = <InvoiceAdjustment>[];
    for (final adjustment in adjustments) {
      try {
        await _client
            .from('invoices')
            .update({
              'room_price': adjustment.roomPrice,
              'electricity_units': adjustment.electricityUnits,
              'electricity_cost': adjustment.electricityCost,
              'water_cost': adjustment.waterCost,
              // cleaning_fee/extra_fees_total ไม่อยู่ในชุดนี้อีกต่อไป — ไม่มีการ
              // ดึงค่าใช้จ่ายเพิ่มเติมมาจากที่ไหนแล้วเขียนทับแบบเดิม รายการพวกนี้
              // เป็นของบิลใบนี้เอง (เพิ่ม/ลบทีละแถวผ่าน invoice_extra_fees)
              // trigger ฝั่งฐานข้อมูลรักษายอดรวมให้อยู่แล้ว
              'previous_total': adjustment.previousTotal,
              'recalculated_at': DateTime.now().toUtc().toIso8601String(),
              // total ไม่อยู่ในชุดนี้ เพราะเป็น GENERATED ALWAYS AS — ฐานข้อมูล
              // คำนวณเอง จึงเป็นไปไม่ได้ที่ยอดรวมจะไม่ตรงกับผลบวกของรายการ
            })
            .eq('id', adjustment.invoice.dbId)
            // ไม่ใช่ของประดับ — ถ้าผู้เช่ากดส่งสลิปในวินาทีเดียวกัน แถวจะเป็น
            // pending ไปแล้วและคำสั่งนี้จะไม่ match อะไรเลย บิลที่มีสลิปแนบอยู่
            // จึงไม่มีทางถูกขยับยอดแม้ในภาวะแข่งกัน
            .eq('status', InvoiceStatus.unpaid.name);
        applied.add(adjustment);
      } catch (_) {
        failed.add(adjustment);
      }
    }

    return (applied: applied, failed: failed);
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
        'due_date':
            '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
        'issued_by': issuedBy,
        'revision': revision,
        if (previous != null) 'replaces_invoice_id': previous.id,
      };
    }).toList();

    final inserted =
        await _client.from('invoices').insert(rows).select(_columns);
    return (inserted as List)
        .cast<Map<String, dynamic>>()
        .map(_invoiceFromRow)
        .toList();
  }

  /// คัดลอกรายการค่าใช้จ่ายเพิ่มเติมแบบทุกเดือนที่ร่างบิลพกมา ลงบิลที่เพิ่ง
  /// ออกจริง — แยกเป็นขั้นที่สอง ไม่ได้อยู่ใน [issueInvoices] เอง เพราะเป็นการ
  /// insert อีกครั้งหนึ่งที่ไม่ได้อยู่ใน transaction เดียวกับการออกบิล (เหมือน
  /// [postIssueNotices]) ถ้าล้ม บิลยังอยู่ครบ แค่ยังไม่มีรายการต่อเนื่องติดมา —
  /// ผู้เรียกต้องรายงานแยกให้เจ้าของหอกดลองใหม่ ไม่ใช่กลืนทิ้งเงียบๆ
  Future<void> carryForwardExtraFeesForIssued({
    required List<Invoice> invoices,
    required List<InvoiceDraft> drafts,
  }) async {
    final draftsByRoom = {for (final draft in drafts) draft.roomDbId: draft};

    final rows = <Map<String, dynamic>>[];
    for (final invoice in invoices) {
      final draft = draftsByRoom[invoice.roomDbId];
      if (draft == null) continue;
      for (final fee in draft.carriedExtraFees) {
        rows.add({
          'invoice_id': invoice.dbId,
          'name': fee.name,
          'amount': fee.amount,
          // ไม่ใช่ true เสมอไป — เดิมใช่ เพราะ carriedExtraFees เคยมีแต่รายการ
          // ที่คัดลอกมาจากบิลก่อนหน้า (เป็นทุกเดือนโดยนิยาม) แต่ตอนนี้เจ้าของหอ
          // เพิ่มรายการครั้งนี้เท่านั้นเข้ามาในลิสต์เดียวกันได้ก่อนกดออกบิลด้วย
          // (ดู InvoiceIssueViewModel.addExtraFeeToDraft) ต้องใช้ค่าจริงของ
          // แต่ละแถว ไม่ใช่ตั้งเป็น true ทั้งหมด
          'is_recurring': fee.isRecurring,
        });
      }
    }
    if (rows.isEmpty) return;

    await _client.from('invoice_extra_fees').insert(rows);
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
        .map((invoice) => _invoiceCardRow(invoice: invoice, senderId: senderId))
        .toList();

    if (rows.isEmpty) return 0;
    await _client.from('messages').insert(rows);
    return rows.length;
  }

  /// แจ้งผู้เช่าว่ายอดบิลเปลี่ยน · คืนจำนวนข้อความที่โพสต์
  ///
  /// เป็นข้อความ `text` ไม่ใช่การ์ดบิล — การ์ดใบเดิมที่อยู่ในแชทแล้ว resolve
  /// ข้อมูลสดผ่าน [invoicesByIdForRoom] จึงแสดงยอดใหม่เองอยู่แล้ว การส่งการ์ด
  /// ซ้ำจะได้การ์ดสองใบที่ยอดเท่ากันในห้องแชทเดียว ซึ่งอ่านเหมือนมีบิลสองใบ
  ///
  /// ไม่ตั้ง `invoice_id` ด้วยเหตุผลเดียวกัน — คอลัมน์นั้นเป็นเครื่องหมายว่า
  /// ข้อความนี้ *คือ* การ์ดบิล
  ///
  /// ระบุทั้งยอดเก่าและยอดใหม่ เพราะผู้เช่าที่แคปหน้าจอ QR ระบุยอดเก็บไว้ต้องรู้
  /// ว่าใบที่ถืออยู่ใช้ไม่ได้แล้ว ไม่ใช่แค่ว่า "มีอะไรบางอย่างเปลี่ยน"
  Future<int> postAdjustmentNotices(List<InvoiceAdjustment> adjustments) async {
    if (adjustments.isEmpty) return 0;

    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final rows = adjustments.map((adjustment) {
      final invoice = adjustment.invoice;
      return {
        'room_id': invoice.roomDbId,
        'sender_id': senderId,
        'is_from_owner': true,
        'body': 'ยอดบิล ${invoice.invoiceNo} '
            'งวด${thaiMonthName(invoice.billingMonth)} ${invoice.billingYear} '
            'เปลี่ยนจาก ${formatBaht(adjustment.previousTotal)} '
            'เป็น ${formatBaht(adjustment.newTotal)} หลังปรับตามเลขมิเตอร์ล่าสุด',
        'message_type': MessageType.text.name,
      };
    }).toList();

    await _client.from('messages').insert(rows);
    return rows.length;
  }

  /// ส่งการ์ดบิลใบเดียวเข้าแชทอีกครั้ง แม้เคยส่งไปแล้ว
  ///
  /// จงใจไม่ใช้ [postIssueNotices] ซึ่งข้ามใบที่เคยแจ้งแล้ว — ที่นั่นต้องกันซ้ำ
  /// เพราะเป็นการแจ้งรอบแรกของบิลทั้งชุดและปุ่ม "ส่งอีกครั้ง" ตอนแจ้งเตือนล้ม
  /// ต้องไม่สร้างข้อความซ้อนให้ห้องที่ผ่านไปแล้ว
  ///
  /// ที่นี่คนละเจตนา: เจ้าของหอกดเพื่อทวง การกันซ้ำจึงเท่ากับปุ่มที่กดแล้วไม่มี
  /// อะไรเกิดขึ้นเลย ซึ่งอ่านไม่ออกว่าส่งไม่สำเร็จหรือส่งไปแล้ว
  Future<void> sendInvoiceCard({required Invoice invoice}) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    await _client
        .from('messages')
        .insert(_invoiceCardRow(invoice: invoice, senderId: senderId));
  }

  /// แถวข้อความของการ์ดบิล — ตัวเดียวที่ทั้งการแจ้งตอนออกบิลและการส่งซ้ำใช้
  ///
  /// `body` เป็นข้อความสำรองที่แสดงเมื่อฝั่งผู้รับ resolve บิลไม่ได้ จึงเขียนให้
  /// จริงกับทั้งสองเส้นทาง ไม่ใช่คำทวงซึ่งจะกลายเป็นคำโกหกเมื่อบิลเพิ่งออก
  Map<String, dynamic> _invoiceCardRow({
    required Invoice invoice,
    required String senderId,
  }) =>
      {
        'room_id': invoice.roomDbId,
        'sender_id': senderId,
        'is_from_owner': true,
        'body': 'ออกบิลค่าเช่างวด'
            '${thaiMonthName(invoice.billingMonth)} '
            '${invoice.billingYear} แล้ว',
        'message_type': MessageType.invoice.name,
        'invoice_id': invoice.dbId,
      };

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

  /// สำหรับแต่ละห้อง หาบิลล่าสุดที่ไม่ใช่ของงวดนี้และไม่ถูกยกเลิก แล้วดึง
  /// รายการค่าใช้จ่ายเพิ่มเติมแบบ "ทุกเดือน" ของบิลใบนั้นมาเป็นตัวตั้งต้น
  /// ของร่างบิลใหม่ — แทนที่กลไกเดิมที่ดึงค่าทำความสะอาดจากคำขอที่เสร็จสิ้น
  Future<Map<int, List<ExtraFee>>> _fetchCarriedExtraFeesByRoom({
    required List<int> roomIds,
    required int month,
    required int year,
  }) async {
    // งวดก่อนงวดนี้ (ปีน้อยกว่า หรือปีเท่ากันแต่เดือนน้อยกว่า) ไม่นับใบที่
    // ยกเลิก เพราะใบยกเลิกไม่ใช่ตัวแทนของ "สิ่งที่เรียกเก็บจริงเดือนก่อน"
    final priorInvoices = await _client
        .from('invoices')
        .select('id, room_id, billing_year, billing_month')
        .inFilter('room_id', roomIds)
        .neq('status', InvoiceStatus.voided.name)
        .or('billing_year.lt.$year,'
            'and(billing_year.eq.$year,billing_month.lt.$month)')
        .order('billing_year', ascending: false)
        .order('billing_month', ascending: false);

    // เก็บเฉพาะบิลล่าสุดต่อห้อง — putIfAbsent เพราะแถวเรียงใหม่สุดมาก่อนแล้ว
    final latestInvoiceIdByRoom = <int, int>{};
    for (final row in (priorInvoices as List).cast<Map<String, dynamic>>()) {
      final roomId = row['room_id'] as int;
      latestInvoiceIdByRoom.putIfAbsent(roomId, () => row['id'] as int);
    }
    if (latestInvoiceIdByRoom.isEmpty) return {};

    final feeRows = await _client
        .from('invoice_extra_fees')
        .select()
        .inFilter('invoice_id', latestInvoiceIdByRoom.values.toList())
        .eq('is_recurring', true);

    final feesByInvoiceId = <int, List<ExtraFee>>{};
    for (final row in (feeRows as List).cast<Map<String, dynamic>>()) {
      feesByInvoiceId
          .putIfAbsent(row['invoice_id'] as int, () => [])
          .add(_extraFeeFromRow(row));
    }

    return {
      for (final entry in latestInvoiceIdByRoom.entries)
        entry.key: feesByInvoiceId[entry.value] ?? const [],
    };
  }

  // ── สลิป ────────────────────────────────────────────────────────────────

  /// อัปโหลดสลิปแล้วคืน storage path
  Future<String> uploadSlip({
    required Invoice invoice,
    required PickedImage file,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        '${invoice.roomDbId}/${invoice.invoiceNo}-$stamp.${file.extension}';
    // uploadBinary ไม่ใช่ upload ด้วยเหตุผลเดียวกับ uploadChatImage — upload
    // อ่านไฟล์จากดิสก์ ซึ่งบนเว็บไม่มีให้อ่าน · นามสกุลก็ต้องมาจากรูปจริง
    // ไม่ใช่ .jpg ตายตัว ไม่งั้น PNG จะถูกเก็บด้วยชื่อที่โกหกชนิดของมัน
    await _client.storage.from(_slipBucket).uploadBinary(
          path,
          file.bytes,
          fileOptions: FileOptions(contentType: file.contentType),
        );
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

  /// ผู้เช่าแจ้งว่าจ่ายเงินสดให้เจ้าของหอแล้ว
  ///
  /// ผ่าน RPC ด้วยเหตุผลเดียวกับ submitSlip — RLS จำกัดไม่ได้ว่า UPDATE แตะ
  /// คอลัมน์ไหน ถ้าให้ผู้เช่าเขียนตรงจะกดตัวเองเป็น paid ได้
  Future<void> submitCashPayment({required int invoiceId}) async {
    await _client.rpc('submit_cash_payment', params: {
      'p_invoice_id': invoiceId,
    });
  }

  /// ผู้เช่าถอนการแจ้งจ่ายเงินสดที่ยังไม่ถูกยืนยัน
  Future<void> cancelCashPayment({required int invoiceId}) async {
    await _client.rpc('cancel_cash_payment', params: {
      'p_invoice_id': invoiceId,
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

  /// เจ้าของหออนุมัติสลิปที่ผู้เช่าแนบมา
  Future<void> approveSlip({required Invoice invoice}) => _markPaid(
        invoice: invoice,
        notice: 'รับชำระบิล ${invoice.invoiceNo} เรียบร้อยแล้ว ขอบคุณครับ',
      );

  /// เจ้าของหอยืนยันว่าได้รับเงินสดจากผู้เช่าแล้ว
  ///
  /// ปลายทางเหมือน [approveSlip] ทุกประการ — บิลเป็น paid, บันทึกเวลาและผู้
  /// อนุมัติ ต่างแค่ข้อความที่โพสต์เข้าแชท เพราะสิ่งที่เกิดขึ้นจริงคนละอย่าง
  /// และผู้เช่าควรเห็นในแชทว่าเจ้าของหอรับรองการจ่ายสด ไม่ใช่รับรองสลิปที่
  /// ไม่มีอยู่
  Future<void> confirmCashPayment({required Invoice invoice}) => _markPaid(
        invoice: invoice,
        notice: 'ยืนยันรับเงินสดค่าบิล ${invoice.invoiceNo} เรียบร้อยแล้ว '
            'ขอบคุณครับ',
      );

  /// เจ้าของหอบันทึกเองว่าได้รับเงินแล้ว โดยผู้เช่าไม่ได้กดแจ้งมาก่อน
  ///
  /// มีไว้สำหรับเงินที่จ่ายกันนอกแอป — ยื่นเงินสดหน้าห้อง หรือโอนแล้วทักบอกทาง
  /// ช่องทางอื่น · ถ้าไม่มีทางนี้ เจ้าของหอที่เก็บเงินครบแล้วมีทางเลือกแค่ปล่อย
  /// บิลค้างไว้ทั้งที่ไม่มีใครค้างจริง
  ///
  /// [method] ถูกบันทึกลงบิลด้วย เพราะผู้เช่าที่ไม่ได้กดอะไรเลยควรอ่านออกจาก
  /// ประวัติได้ว่าเจ้าของหอรับรองการจ่ายแบบไหน — ป้าย "ชำระแล้ว" เฉยๆ ไม่พอให้
  /// สองฝ่ายตรวจสอบย้อนหลังว่าตรงกับที่จ่ายจริงหรือไม่
  Future<void> markPaidByLandlord({
    required Invoice invoice,
    required PaymentMethod method,
  }) =>
      _markPaid(
        invoice: invoice,
        method: method,
        notice: 'เจ้าของหอบันทึกว่าได้รับ'
            '${method == PaymentMethod.cash ? 'เงินสด' : 'เงินโอน'}'
            'ค่าบิล ${invoice.invoiceNo} แล้ว ขอบคุณครับ',
      );

  Future<void> _markPaid({
    required Invoice invoice,
    required String notice,
    PaymentMethod? method,
  }) async {
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
      // ใส่เฉพาะตอนที่เจ้าของหอเป็นคนระบุเอง — เส้นทางที่ผู้เช่าแจ้งมาก่อน
      // (สลิป/เงินสด) บันทึกค่านี้ไว้ตั้งแต่ตอนแจ้งแล้ว การเขียนทับตรงนี้จะลบ
      // สิ่งที่ผู้เช่าเลือกไว้ทิ้ง และฐานข้อมูลที่ยังไม่ได้รัน
      // invoices_cash_payment.sql ก็ไม่มีคอลัมน์นี้ให้เขียน
      if (method != null) 'payment_method': method.name,
    }).eq('id', invoice.dbId);

    await _postInvoiceNotice(invoice: invoice, body: notice);
  }

  /// ปฏิเสธพากลับไป unpaid ไม่ใช่สถานะที่ห้า เพราะสิ่งที่ผู้เช่าต้องทำ
  /// เหมือนเดิมคือจ่ายใหม่ ต่างแค่มีเหตุผลให้อ่าน
  Future<void> rejectSlip({
    required Invoice invoice,
    required String reason,
  }) =>
      _markUnpaid(
        invoice: invoice,
        reason: reason,
        notice: 'สลิปของบิล ${invoice.invoiceNo} ไม่ผ่านการตรวจสอบ: $reason',
      );

  /// เจ้าของหอปฏิเสธการแจ้งจ่ายเงินสดที่ยังไม่ได้รับเงินจริง
  ///
  /// ปลายทางเหมือน [rejectSlip] — บิลกลับไป unpaid พร้อมเหตุผลให้ผู้เช่าอ่าน
  /// ต่างแค่ข้อความ ถ้าไม่มีปุ่มนี้ เจ้าของหอที่เจอผู้เช่ากดแจ้งทั้งที่ยังไม่จ่าย
  /// จะมีทางเลือกเดียวคือยกเลิกบิลทิ้งทั้งใบแล้วออกใหม่ ซึ่งกินเลขที่บิลเพิ่ม
  /// และทำให้ประวัติอ่านเหมือนออกบิลผิด
  Future<void> rejectCashPayment({
    required Invoice invoice,
    required String reason,
  }) =>
      _markUnpaid(
        invoice: invoice,
        reason: reason,
        notice: 'ยังไม่ได้รับเงินสดค่าบิล ${invoice.invoiceNo}: $reason',
      );

  Future<void> _markUnpaid({
    required Invoice invoice,
    required String reason,
    required String notice,
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
      // ล้างวิธีจ่ายด้วย ไม่งั้นบิลที่แจ้งเงินสดแล้วถูกปฏิเสธจะยังค้างเป็น cash
      // อยู่ พอผู้เช่ากลับมาแนบสลิปแทน บิลจะเข้า pending พร้อม payment_method
      // เดิม เจ้าของหอจึงเห็นปุ่ม "ยืนยันรับเงินสด" ทับสลิปที่เพิ่งอัปมา
      //
      // ใส่เฉพาะเมื่อบิลมีค่าอยู่จริง — ฐานข้อมูลที่ยังไม่ได้รัน
      // invoices_cash_payment.sql ไม่มีคอลัมน์นี้ การส่งไปด้วยจะทำให้ทั้ง
      // UPDATE ตกด้วย 42703 แล้วการปฏิเสธสลิปซึ่งเคยใช้ได้มาตลอดก็พังตาม
      if (invoice.paymentMethod != null) 'payment_method': null,
    }).eq('id', invoice.dbId);

    if (oldSlipPath != null) {
      await discardSlip(oldSlipPath);
    }

    await _postInvoiceNotice(invoice: invoice, body: notice);
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
  ///
  /// **ไม่โพสต์การ์ดเข้าแชทเอง** ผู้เรียกต้องเรียก [sendInvoiceCard] ต่อ — เดิม
  /// ทำให้ตรงนี้แล้วกลืน error ทิ้งด้วยเหตุผลว่าใบแทนเกิดแล้ว การแจ้งเตือนที่ล้ม
  /// ไม่ควรรายงานว่า "ออกใบแทนไม่สำเร็จ" ซึ่งถูกครึ่งเดียว: ผลที่ได้จริงคือ
  /// เจ้าของหอออกใบแทนสำเร็จ ผู้เช่าไม่ได้รับการ์ด และไม่มีใครในสองฝั่งรู้เลย
  /// ว่าเกิดอะไรขึ้น · การแยกสองขั้นออกจากกันทำให้ผู้เรียกเล่าได้ครบทั้งสองผล
  ///
  /// `extraFeesCopyFailed` แยกไว้ด้วยเหตุผลเดียวกัน: การคัดลอกรายการค่าใช้จ่าย
  /// เพิ่มเติมของใบเดิมเป็น insert อีกก้อนที่ไม่ได้อยู่ใน transaction เดียวกับ
  /// การสร้างใบใหม่ ถ้าล้ม ใบแทนก็ยังถูกสร้างสำเร็จอยู่ดี — เดิมปล่อยให้ throw
  /// หลุดออกไปทั้งฟังก์ชัน ผู้เรียกจึงรายงานว่า "ออกใบแทนไม่สำเร็จ" ทั้งที่มีใบ
  /// ใหม่เกิดขึ้นจริงแล้วในฐานข้อมูล แค่ยังไม่มีรายการค่าใช้จ่ายเพิ่มเติมติดมา
  Future<({Invoice? invoice, bool extraFeesCopyFailed})> reissueInvoice({
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
    if (draft == null) return (invoice: null, extraFeesCopyFailed: false);

    final issuedBy = _client.auth.currentUser?.id;
    if (issuedBy == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final revision = voided.revision + 1;
    final due = dueDateFor(draft.billingYear, draft.billingMonth);

    final inserted = await _client
        .from('invoices')
        .insert({
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
          'due_date':
              '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
          'issued_by': issuedBy,
          'revision': revision,
          'replaces_invoice_id': voided.dbId,
        })
        .select(_columns)
        .single();

    final reissued = _invoiceFromRow(inserted);

    // reissue คือใบแทนของ "งวดเดียวกัน" ไม่ใช่งวดถัดไป — previewDrafts ข้างบน
    // จึงไม่มีทางเห็นรายการของ [voided] เอง (carry-forward มองย้อนไปแค่งวด
    // ก่อนหน้า) คัดลอกรายการทั้งหมดของใบที่ถูกยกเลิก ทั้งครั้งนี้เท่านั้นและ
    // ทุกเดือน มาลงใบใหม่ตรงๆ ไม่งั้นค่าใช้จ่ายที่เพิ่งเพิ่มเข้าไปจะหายไปเงียบๆ
    // ตอนยกเลิก+ออกใบแทน
    //
    // insert อีกก้อนที่ไม่ได้อยู่ใน transaction เดียวกับใบแทนที่เพิ่งสร้างเสร็จ
    // ข้างบน — ล้มได้เองโดยที่ใบแทนยังอยู่ครบ จึงจับ error ไว้ที่นี่ ไม่ปล่อยให้
    // ทั้งฟังก์ชัน throw ซึ่งจะทำให้ผู้เรียกไม่มีทางรู้เลยว่าใบแทนถูกสร้างไปแล้ว
    var extraFeesCopyFailed = false;
    try {
      final voidedFees = await fetchExtraFees(invoiceId: voided.dbId);
      if (voidedFees.isNotEmpty) {
        await _client.from('invoice_extra_fees').insert([
          for (final fee in voidedFees)
            {
              'invoice_id': reissued.dbId,
              'name': fee.name,
              'amount': fee.amount,
              'is_recurring': fee.isRecurring,
            },
        ]);
      }
    } catch (_) {
      extraFeesCopyFailed = true;
    }

    return (invoice: reissued, extraFeesCopyFailed: extraFeesCopyFailed);
  }

  // ── ค่าใช้จ่ายเพิ่มเติม ────────────────────────────────────────────────────

  /// รายการค่าใช้จ่ายเพิ่มเติมทั้งหมดของบิลใบหนึ่ง เรียงตามลำดับที่เพิ่ม
  Future<List<ExtraFee>> fetchExtraFees({required int invoiceId}) async {
    final rows = await _client
        .from('invoice_extra_fees')
        .select()
        .eq('invoice_id', invoiceId)
        .order('created_at');

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_extraFeeFromRow)
        .toList();
  }

  /// เพิ่มรายการค่าใช้จ่ายเพิ่มเติมหนึ่งแถวให้บิลใบนี้ — trigger ฝั่งฐานข้อมูล
  /// (sync_invoice_extra_fees_total) จะรวมยอดกลับไปที่ invoices.extra_fees_total
  /// เอง ไม่ต้องคำนวณซ้ำที่นี่
  Future<void> addExtraFee({
    required int invoiceId,
    required String name,
    required double amount,
    required bool isRecurring,
  }) async {
    await _client.from('invoice_extra_fees').insert({
      'invoice_id': invoiceId,
      'name': name,
      'amount': amount,
      'is_recurring': isRecurring,
    });
  }

  /// ลบรายการค่าใช้จ่ายเพิ่มเติมหนึ่งแถว — ดีไซน์นี้ไม่มีการแก้ในที่ (edit)
  /// การแก้คือลบแล้วเพิ่มใหม่
  Future<void> removeExtraFee({required int extraFeeId}) async {
    await _client.from('invoice_extra_fees').delete().eq('id', extraFeeId);
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

/// null เมื่อผู้เช่ายังไม่ได้แจ้งวิธีชำระ — บิลเก่าก่อนคอลัมน์นี้จะมีจะเป็น null
/// ทั้งหมด ซึ่ง [Invoice.awaitsSlipReview] ตีความว่ารอตรวจสลิปตามพฤติกรรมเดิม
PaymentMethod? _paymentMethodFrom(Object? value) {
  if (value == null) return null;
  for (final method in PaymentMethod.values) {
    if (method.name == value) return method;
  }
  return null;
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

ExtraFee _extraFeeFromRow(Map<String, dynamic> row) => ExtraFee(
      id: row['id'] as int,
      invoiceId: row['invoice_id'] as int,
      name: row['name'] as String,
      amount: _toDouble(row['amount']),
      isRecurring: row['is_recurring'] as bool? ?? false,
    );

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
    extraFeesTotal: _toDouble(row['extra_fees_total']),
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
    paymentMethod: _paymentMethodFrom(row['payment_method']),
    // สองคอลัมน์นี้มาจาก invoices_recalculation.sql · ฐานข้อมูลที่ยังไม่ได้รัน
    // ไฟล์นั้นจะไม่มีคีย์เหล่านี้ใน row เลย ซึ่งอ่านได้เป็น null ตามปกติ
    recalculatedAt: row['recalculated_at'] == null
        ? null
        : DateTime.parse(row['recalculated_at'] as String).toLocal(),
    previousTotal: row['previous_total'] == null
        ? null
        : _toDouble(row['previous_total']),
  );
}
