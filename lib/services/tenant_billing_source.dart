import 'dart:io';

import '../models/models.dart';
import '../viewmodels/action_result.dart';
import 'invoice_service.dart';
import 'supabase_service.dart';

/// ช่องทางที่ฝั่งผู้เช่าใช้เข้าถึงบิลของตัวเอง
///
/// คงไว้เป็น abstract เพื่อให้ ViewModel ทดสอบได้ด้วย fake โดยไม่ต้องมี
/// Supabase client — เหตุผลเดียวกับที่ formatters.dart อธิบายไว้
abstract class TenantBillingSource {
  Future<Invoice?> fetchCurrentBill({
    required int roomDbId,
    required int month,
    required int year,
  });

  Future<List<Invoice>> fetchBillHistory({
    required int roomDbId,
    int monthCount,
  });

  Future<PaymentChannel> fetchPaymentChannel({required int dormitoryId});

  Future<ActionResult> submitPaymentSlip({
    required Invoice bill,
    required File slip,
  });
}

class SupabaseTenantBillingSource implements TenantBillingSource {
  SupabaseTenantBillingSource({
    InvoiceService? invoiceService,
    SupabaseService? service,
  })  : _injectedInvoices = invoiceService,
        _injectedService = service;

  final InvoiceService? _injectedInvoices;
  final SupabaseService? _injectedService;
  InvoiceService? _resolvedInvoices;
  SupabaseService? _resolvedService;

  /// สร้างแบบ lazy: constructor ของทั้งสองตัวอ่าน Supabase.instance ทันที
  /// ซึ่ง assert ใน unit test การหน่วงไว้ทำให้ทดสอบส่วนที่ไม่แตะเครือข่ายได้
  InvoiceService get _invoices =>
      _resolvedInvoices ??= (_injectedInvoices ?? InvoiceService());
  SupabaseService get _service =>
      _resolvedService ??= (_injectedService ?? SupabaseService());

  @override
  Future<Invoice?> fetchCurrentBill({
    required int roomDbId,
    required int month,
    required int year,
  }) =>
      _invoices.fetchCurrentForRoom(
        roomDbId: roomDbId,
        month: month,
        year: year,
      );

  @override
  Future<List<Invoice>> fetchBillHistory({
    required int roomDbId,
    int monthCount = 6,
  }) =>
      _invoices.fetchForRoom(roomDbId: roomDbId, monthCount: monthCount);

  @override
  Future<PaymentChannel> fetchPaymentChannel({required int dormitoryId}) async {
    final dorm = await _service.fetchDormitoryInfo(dormitoryId: dormitoryId);
    return PaymentChannel(
      bankName: 'ธนาคารกสิกรไทย',
      accountNo: '1438323216',
      accountName: dorm?.landlordName ?? dorm?.name ?? 'เจ้าของหอ',
      qrAssetPath: 'lib/assets/sample_paymant_qrcode.jpg',
    );
  }

  /// อัปโหลดก่อนแล้วค่อยบันทึก ถ้าบันทึกล้มให้ลบไฟล์ที่เพิ่งอัปทิ้ง
  /// ไม่งั้นจะเหลือไฟล์ที่ไม่มีแถวไหนอ้างถึงค้างอยู่ใน storage
  @override
  Future<ActionResult> submitPaymentSlip({
    required Invoice bill,
    required File slip,
  }) async {
    final path = await _invoices.uploadSlip(invoice: bill, file: slip);
    try {
      await _invoices.submitSlip(invoiceId: bill.dbId, slipPath: path);
    } catch (error) {
      await _invoices.discardSlip(path);
      rethrow;
    }

    return const ActionResult(
      success: true,
      message: 'ส่งสลิปแล้ว รอเจ้าของหอตรวจสอบ',
    );
  }
}
