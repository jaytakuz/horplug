import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/invoice_pdf.dart';
import '../services/invoice_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'safe_notifier.dart';

/// การกระทำทั้งหมดที่เจ้าของหอทำกับบิลใบเดียว — อนุมัติ ปฏิเสธ ยกเลิก ออกใบแทน
///
/// มีอยู่เพราะแผ่นตรวจสลิปกับแผ่นรายละเอียดบิลเคยสร้าง [InvoiceService] เอง
/// แล้วจัดการ error กับสถานะ busy ในตัว widget ทำให้เทสต์อะไรไม่ได้เลย และทำให้
/// `BillingViewModel.approve/reject/voidBill` กลายเป็นโค้ดตายที่ไม่มีใครเรียก
///
/// ผูกกับบิล **ใบเดียว** ตามอายุของแผ่นที่เปิดอยู่ (สร้างใน `showSlipReviewSheet`
/// และ `showInvoiceDetailSheet` ผ่าน `ChangeNotifierProvider` แบบเดียวกับที่
/// [InvoiceIssueViewModel] ทำใน `showIssueInvoicesDialog`) จงใจไม่ใช้
/// `BillingViewModel` เพราะแผ่นทั้งสองเปิดจากหน้าแชทได้ด้วย ซึ่งที่นั่นไม่มี
/// `BillingViewModel` อยู่ใน tree เลย
class InvoiceActionsViewModel extends ChangeNotifier with SafeNotifier {
  InvoiceActionsViewModel({
    required this.invoice,
    required this.dormitoryId,
    InvoiceService? service,
  }) : _service = service ?? InvoiceService();

  final Invoice invoice;

  /// ต้องรู้ว่าบิลอยู่หอไหน เพราะ [reissue] ประกอบร่างบิลใหม่จากทั้งหอ
  final int dormitoryId;

  final InvoiceService _service;

  bool isBusy = false;

  /// URL สลิปที่เซ็นแล้ว — สร้างใหม่ทุกครั้งที่เรียก ไม่ cache ข้าม session
  Future<String> slipUrl() => _service.signedSlipUrl(invoice.slipUrl!);

  Future<ActionResult> approve() => _run(
        () => _service.approveSlip(invoice: invoice),
        onSuccess: 'อนุมัติการชำระเงินของบิล ${invoice.invoiceNo} แล้ว',
        onFailure: 'อนุมัติไม่สำเร็จ',
      );

  /// ยืนยันว่าได้รับเงินสดจากผู้เช่าแล้ว — ปลายทางเดียวกับ [approve]
  /// ต่างที่ข้อความในแชท เพราะผู้เช่าควรเห็นว่าเจ้าของหอรับรองการจ่ายสด
  /// ไม่ใช่รับรองสลิปที่ไม่มีอยู่
  Future<ActionResult> confirmCash() => _run(
        () => _service.confirmCashPayment(invoice: invoice),
        onSuccess: 'ยืนยันรับเงินสดของบิล ${invoice.invoiceNo} แล้ว',
        onFailure: 'ยืนยันไม่สำเร็จ',
      );

  Future<ActionResult> reject(String reason) => _run(
        () => _service.rejectSlip(invoice: invoice, reason: reason.trim()),
        onSuccess: 'ปฏิเสธสลิปของบิล ${invoice.invoiceNo} แล้ว',
        onFailure: 'ปฏิเสธไม่สำเร็จ',
      );

  Future<ActionResult> voidBill(String reason) => _run(
        () => _service.voidInvoice(invoice: invoice, reason: reason.trim()),
        onSuccess: 'ยกเลิกบิล ${invoice.invoiceNo} แล้ว',
        onFailure: 'ยกเลิกไม่สำเร็จ',
      );

  /// ออกใบแทน — เรียกได้เฉพาะหลัง [voidBill] สำเร็จแล้วเท่านั้น
  ///
  /// ข้อความที่คืนกลับเล่าทั้งสองขั้น (ยกเลิก + ออกใบแทน) เพราะผู้เรียกแสดง
  /// SnackBar เดียวท้ายสุด ไม่ใช่ยิงซ้อนกันทีละขั้น
  ///
  /// `reissueInvoice` คืน null (ไม่ throw) เมื่อห้องไม่มีอยู่ในร่างบิลงวดนี้ —
  /// ยังไม่จดมิเตอร์ หรือห้องไม่มีผู้เช่าแล้ว ถ้าไม่แยกเคสนี้ออกมา แผ่นจะปิดไป
  /// เงียบๆ โดยไม่มีอะไรอธิบายว่าทำไมใบใหม่ไม่โผล่
  Future<ActionResult> reissue() async {
    isBusy = true;
    notifyListeners();

    try {
      final reissued = await _service.reissueInvoice(
        voided: invoice,
        dormitoryId: dormitoryId,
      );

      return reissued != null
          ? ActionResult(
              success: true,
              message: 'ยกเลิกบิล ${invoice.invoiceNo} แล้ว '
                  'ออกใบแทน ${reissued.invoiceNo} เรียบร้อย',
            )
          : ActionResult(
              success: false,
              message: 'ยกเลิกบิล ${invoice.invoiceNo} แล้ว แต่ออกใบแทนไม่ได้ '
                  '— งวดนี้ยังไม่ได้จดมิเตอร์ หรือห้องไม่มีผู้เช่า',
            );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ยกเลิกบิล ${invoice.invoiceNo} แล้ว '
            'แต่ออกใบแทนไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// เปิดแผ่นแชร์ของระบบพร้อมไฟล์ PDF ของบิลใบนี้
  ///
  /// ไม่แตะสถานะบิลเลย จึงทำได้กับทุกสถานะ รวมทั้งใบที่ยกเลิกไปแล้ว
  Future<ActionResult> sharePdf({required String dormitoryName}) => _run(
        () => shareInvoicePdf(invoice: invoice, dormitoryName: dormitoryName),
        onSuccess: 'สร้างไฟล์บิล ${invoice.invoiceNo} แล้ว',
        onFailure: 'สร้างไฟล์ PDF ไม่สำเร็จ',
      );

  /// โครงร่วมของทุกการกระทำ: ตั้ง busy → เรียก service → แปลง error เป็นข้อความ
  Future<ActionResult> _run(
    Future<void> Function() action, {
    required String onSuccess,
    required String onFailure,
  }) async {
    isBusy = true;
    notifyListeners();

    try {
      await action();
      return ActionResult(success: true, message: onSuccess);
    } catch (error) {
      return ActionResult(
        success: false,
        message: '$onFailure: ${formatErrorMessage(error)}',
      );
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
