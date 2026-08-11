import 'dart:io';

import '../models/models.dart';
import '../viewmodels/action_result.dart';
import 'invoice_service.dart';
import 'payment_channel_service.dart';
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

  /// null เมื่อหอนี้ยังไม่ได้ตั้งค่าช่องทางชำระเงิน
  Future<PaymentChannel?> fetchPaymentChannel({required int dormitoryId});

  Future<ActionResult> submitPaymentSlip({
    required Invoice bill,
    required File slip,
  });

  /// ผู้เช่าแจ้งว่าจ่ายเงินสดให้เจ้าของหอแล้ว — ไม่มีสลิป เจ้าของหอต้องยืนยันเอง
  Future<ActionResult> submitCashPayment({required Invoice bill});

  /// ถอนการแจ้งจ่ายเงินสดที่ยังไม่ถูกยืนยัน — กดผิดได้ ไม่ควรต้องรอให้อีกฝ่าย
  /// ปฏิเสธให้
  Future<ActionResult> cancelCashPayment({required Invoice bill});
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
  PaymentChannelService? _resolvedChannels;

  /// สร้างแบบ lazy: constructor ของทั้งสองตัวอ่าน Supabase.instance ทันที
  /// ซึ่ง assert ใน unit test การหน่วงไว้ทำให้ทดสอบส่วนที่ไม่แตะเครือข่ายได้
  InvoiceService get _invoices =>
      _resolvedInvoices ??= (_injectedInvoices ?? InvoiceService());
  SupabaseService get _service =>
      _resolvedService ??= (_injectedService ?? SupabaseService());
  PaymentChannelService get _channels =>
      _resolvedChannels ??= PaymentChannelService(service: _service);

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
  /// อ่านช่องทางที่เจ้าของหอตั้งไว้ · null เมื่อยังไม่ได้ตั้ง
  ///
  /// เคย hardcode เลขบัญชีเดียวให้ทุกหอ โดยหยิบชื่อเจ้าของหอจริงมาแสดงคู่กัน
  /// ผู้เช่าของหออื่นจึงเห็นชื่อที่ถูกต้องข้างเลขบัญชีของคนอื่น ซึ่งอ่านแล้ว
  /// เหมือนข้อมูลที่ผ่านการยืนยันมาแล้ว
  @override
  Future<PaymentChannel?> fetchPaymentChannel({
    required int dormitoryId,
  }) =>
      _channels.fetch(dormitoryId: dormitoryId);

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

  @override
  Future<ActionResult> submitCashPayment({required Invoice bill}) async {
    await _invoices.submitCashPayment(invoiceId: bill.dbId);
    return const ActionResult(
      success: true,
      message: 'แจ้งชำระเงินสดแล้ว รอเจ้าของหอยืนยันการรับเงิน',
    );
  }

  @override
  Future<ActionResult> cancelCashPayment({required Invoice bill}) async {
    await _invoices.cancelCashPayment(invoiceId: bill.dbId);
    return const ActionResult(
      success: true,
      message: 'ยกเลิกการแจ้งชำระเงินสดแล้ว',
    );
  }
}
