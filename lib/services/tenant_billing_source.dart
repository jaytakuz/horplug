import 'dart:io';

import '../models/models.dart';
import '../viewmodels/action_result.dart';
import 'supabase_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MOCK — ระบบชำระเงินยังไม่เชื่อมต่อจริง
//
// รายการค่าใช้จ่ายในบิล (ค่าห้อง/ไฟ/น้ำ/ทำความสะอาด) เป็นข้อมูล "จริง" จาก
// มิเตอร์ — ที่จำลองคือ "สถานะการชำระ" เท่านั้น เพราะยังไม่มีตาราง invoices
//
// จะถูกแทนที่ในฟีเจอร์ถัดไป "Invoice Generation" โดยไม่ต้องแก้ ViewModel/UI:
//   • ลบ MockPaymentLedger + MockTenantBillingSource ทิ้ง
//   • เขียน SupabaseTenantBillingSource ที่อ่าน invoices.status / paid_at /
//     slip_url แทน แล้วเปลี่ยนค่า default ของ ViewModel
//   • signature ของ TenantBillingSource คงเดิมทุกตัว
// ═══════════════════════════════════════════════════════════════════════════

abstract class TenantBillingSource {
  Future<TenantBill?> fetchCurrentBill({
    required int roomDbId,
    required int month,
    required int year,
  });

  Future<List<TenantBill>> fetchBillHistory({
    required int roomDbId,
    int monthCount,
  });

  Future<PaymentChannel> fetchPaymentChannel({required int dormitoryId});

  Future<ActionResult> submitPaymentSlip({
    required String billId,
    required File slip,
  });
}

/// สถานะการชำระเงินจำลอง — เก็บใน memory เท่านั้น (หายเมื่อปิดแอป)
///
/// เป็น pure logic ล้วน ไม่แตะเครือข่าย จึงเขียน unit test ได้ตรงๆ
class MockPaymentLedger {
  final Map<String, InvoiceStatus> _overrides = {};

  /// กฎเริ่มต้น: งวดปัจจุบัน = ค้างชำระ, งวดก่อนหน้า = ชำระแล้ว
  InvoiceStatus statusFor(Invoice invoice, {DateTime? now}) {
    final override = _overrides[invoice.id];
    if (override != null) return override;

    final today = now ?? DateTime.now();
    final isCurrentPeriod =
        invoice.date.year == today.year && invoice.date.month == today.month;

    return isCurrentPeriod ? InvoiceStatus.unpaid : InvoiceStatus.paid;
  }

  /// ครบกำหนดวันที่ 5 ของเดือนถัดไป
  ///
  /// DateTime รองรับ month = 13 โดยขึ้นปีใหม่ให้เอง
  static DateTime dueDateFor(DateTime period) =>
      DateTime(period.year, period.month + 1, 5);

  void markPending(String billId) =>
      _overrides[billId] = InvoiceStatus.pending;

  void reset() => _overrides.clear();
}

/// สถานะจำลองต้องอยู่รอดข้ามการสลับแท็บภายใน session เดียวกัน
/// จึงเก็บเป็น singleton ระดับไฟล์
final MockPaymentLedger _sharedLedger = MockPaymentLedger();

class MockTenantBillingSource implements TenantBillingSource {
  MockTenantBillingSource({
    SupabaseService? service,
    MockPaymentLedger? ledger,
  })  : _injectedService = service,
        _ledger = ledger ?? _sharedLedger;

  final SupabaseService? _injectedService;
  SupabaseService? _resolvedService;
  final MockPaymentLedger _ledger;

  /// สร้าง SupabaseService แบบ lazy: constructor ของมันอ่าน
  /// Supabase.instance ทันที ซึ่ง assert ใน unit test — การหน่วงไว้ทำให้
  /// เทสต์ส่วนที่ไม่แตะเครือข่าย (เช่น submitPaymentSlip) รันได้
  SupabaseService get _service =>
      _resolvedService ??= (_injectedService ?? SupabaseService());

  TenantBill _wrap(Invoice invoice) {
    final status = _ledger.statusFor(invoice);
    return TenantBill(
      invoice: invoice,
      status: status,
      dueDate: MockPaymentLedger.dueDateFor(invoice.date),
      paidAt: status == InvoiceStatus.paid
          ? MockPaymentLedger.dueDateFor(invoice.date)
          : null,
    );
  }

  @override
  Future<TenantBill?> fetchCurrentBill({
    required int roomDbId,
    required int month,
    required int year,
  }) async {
    final invoice = await _service.fetchInvoiceForRoom(
      roomDbId: roomDbId,
      month: month,
      year: year,
    );
    return invoice == null ? null : _wrap(invoice);
  }

  @override
  Future<List<TenantBill>> fetchBillHistory({
    required int roomDbId,
    int monthCount = 6,
  }) async {
    final invoices = await _service.fetchInvoiceHistoryForRoom(
      roomDbId: roomDbId,
      monthCount: monthCount,
    );
    return invoices.map(_wrap).toList();
  }

  @override
  Future<PaymentChannel> fetchPaymentChannel({required int dormitoryId}) async {
    final dorm = await _service.fetchDormitoryInfo(dormitoryId: dormitoryId);
    return PaymentChannel(
      promptPayId: '0XX-XXX-XXXX',
      accountName: dorm?.landlordName ?? dorm?.name ?? 'เจ้าของหอ',
    );
  }

  /// ไม่ได้อัปโหลดไฟล์จริง — แค่หน่วงเวลาให้เห็น loading state แล้วเปลี่ยน
  /// สถานะบิลเป็น "รอตรวจสลิป"
  @override
  Future<ActionResult> submitPaymentSlip({
    required String billId,
    required File slip,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _ledger.markPending(billId);

    return const ActionResult(
      success: true,
      message: 'ส่งสลิปแล้ว รอเจ้าของหอตรวจสอบ',
    );
  }
}
