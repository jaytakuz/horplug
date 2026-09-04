import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/invoice_pdf.dart';
import '../services/invoice_service.dart';
import '../services/payment_channel_service.dart';
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
    PaymentChannelService? channels,
  })  : _service = service ?? InvoiceService(),
        _channels = channels ?? PaymentChannelService();

  final Invoice invoice;

  /// ต้องรู้ว่าบิลอยู่หอไหน เพราะ [reissue] ประกอบร่างบิลใหม่จากทั้งหอ
  final int dormitoryId;

  final InvoiceService _service;
  final PaymentChannelService _channels;

  bool isBusy = false;

  /// รายการค่าใช้จ่ายเพิ่มเติมของบิลใบนี้ — โหลดแยกจาก [invoice] เพราะบิล
  /// ส่วนใหญ่ที่ถูกสร้างขึ้น (รายการในหน้าบิลทั้งเดือน, การ์ดในแชท, PDF) ไม่ต้อง
  /// รู้รายการย่อยเลย รู้แค่ยอดรวม การดึงมาด้วยทุกครั้งจะเป็น query ซ้อนที่ไม่จำเป็น
  List<ExtraFee> extraFees = [];
  bool isLoadingExtraFees = false;

  Future<void> loadExtraFees() async {
    isLoadingExtraFees = true;
    notifyListeners();
    try {
      extraFees = await _service.fetchExtraFees(invoiceId: invoice.dbId);
    } catch (_) {
      // เงียบไว้ — แผ่นยังใช้งานได้ต่อ แค่ส่วนค่าใช้จ่ายเพิ่มเติมว่างชั่วคราว
    } finally {
      isLoadingExtraFees = false;
      notifyListeners();
    }
  }

  /// ยอดรวมที่ควรแสดงระหว่างเปิดแผ่นนี้อยู่ — [invoice.total] เป็นค่า ณ ตอนเปิด
  /// แผ่น เก่าไปทันทีที่มีการเพิ่ม/ลบค่าใช้จ่ายเพิ่มเติมในเซสชันนี้ (ViewModel
  /// นี้ไม่รีเฟรช [invoice] เอง — ผู้เรียกโหลดบิลใหม่หลังแผ่นปิดตามแบบเดิม)
  double get liveTotal =>
      invoice.roomPrice +
      invoice.electricityCost +
      invoice.waterCost +
      extraFees.fold(0.0, (sum, fee) => sum + fee.amount);

  Future<ActionResult> addExtraFee({
    required String name,
    required double amount,
    required bool isRecurring,
  }) async {
    final result = await _run(
      () => _service.addExtraFee(
        invoiceId: invoice.dbId,
        name: name,
        amount: amount,
        isRecurring: isRecurring,
      ),
      onSuccess: 'เพิ่มรายการ "$name" แล้ว',
      onFailure: 'เพิ่มรายการไม่สำเร็จ',
    );
    if (result.success) await loadExtraFees();
    return result;
  }

  Future<ActionResult> removeExtraFee(ExtraFee fee) async {
    final result = await _run(
      () => _service.removeExtraFee(extraFeeId: fee.id),
      onSuccess: 'ลบรายการ "${fee.name}" แล้ว',
      onFailure: 'ลบรายการไม่สำเร็จ',
    );
    if (result.success) await loadExtraFees();
    return result;
  }

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

  /// เจ้าของหอบันทึกเองว่าได้รับเงินแล้ว โดยผู้เช่าไม่ได้แจ้งมาก่อน
  ///
  /// ข้อความบอกวิธีที่รับเงินด้วย เพราะสิ่งที่เจ้าของหอเพิ่งยืนยันคือ "ได้รับ
  /// เงินสด" หรือ "ได้รับเงินโอน" ไม่ใช่แค่ "บิลนี้จบแล้ว"
  Future<ActionResult> markPaid(PaymentMethod method) => _run(
        () => _service.markPaidByLandlord(invoice: invoice, method: method),
        onSuccess: 'บันทึกว่าบิล ${invoice.invoiceNo} ชำระแล้ว '
            '(${method == PaymentMethod.cash ? 'เงินสด' : 'เงินโอน'})',
        onFailure: 'บันทึกการชำระไม่สำเร็จ',
      );

  Future<ActionResult> reject(String reason) => _run(
        () => _service.rejectSlip(invoice: invoice, reason: reason.trim()),
        onSuccess: 'ปฏิเสธสลิปของบิล ${invoice.invoiceNo} แล้ว',
        onFailure: 'ปฏิเสธไม่สำเร็จ',
      );

  /// ปฏิเสธการแจ้งจ่ายเงินสดที่ยังไม่ได้รับเงินจริง — ปลายทางเดียวกับ [reject]
  /// คือบิลกลับไปค้างชำระพร้อมเหตุผล ต่างที่ข้อความ เพราะไม่มีสลิปให้พูดถึง
  Future<ActionResult> rejectCash(String reason) => _run(
        () =>
            _service.rejectCashPayment(invoice: invoice, reason: reason.trim()),
        onSuccess: 'แจ้งว่ายังไม่ได้รับเงินสดของบิล ${invoice.invoiceNo} แล้ว',
        onFailure: 'ปฏิเสธไม่สำเร็จ',
      );

  /// ส่งการ์ดบิลใบนี้เข้าแชทห้องอีกครั้ง — ใช้ทวงบิลที่ยังไม่จ่าย
  ///
  /// ไม่แตะสถานะบิลเลย ผู้เรียกจึงไม่ต้องปิดแผ่นหรือรีเฟรชรายการหลังกด
  Future<ActionResult> sendCardToChat() => _run(
        () => _service.sendInvoiceCard(invoice: invoice),
        onSuccess: 'ส่งบิล ${invoice.invoiceNo} เข้าแชทแล้ว',
        onFailure: 'ส่งบิลเข้าแชทไม่สำเร็จ',
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
                  'ออกใบแทน ${reissued.invoiceNo} เรียบร้อย'
                  '${await _sendCardOrDescribeFailure(reissued)}',
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

  /// ส่งการ์ดของใบแทนเข้าแชท · คืนสตริงว่างเมื่อสำเร็จ
  ///
  /// ไม่โยน error ต่อ เพราะใบแทนเกิดขึ้นแล้วจริงและถอยกลับไม่ได้ — รายงานว่า
  /// "ออกใบแทนไม่สำเร็จ" จะทำให้เจ้าของหอกดใหม่ แล้วรอบสองห้องนั้นมีบิลอยู่แล้ว
  /// จึงไม่อยู่ในร่าง ได้ข้อความว่า "ยังไม่ได้จดมิเตอร์ หรือห้องไม่มีผู้เช่า"
  /// ซึ่งไม่จริงสักข้อ · แต่การเงียบไปเฉยๆ ก็ไม่ได้เหมือนกัน เจ้าของหอจะเชื่อว่า
  /// ผู้เช่าได้รับการ์ดแล้วทั้งที่ไม่มีอะไรถูกส่ง จึงต่อท้ายข้อความแทน
  Future<String> _sendCardOrDescribeFailure(Invoice reissued) async {
    try {
      await _service.sendInvoiceCard(invoice: reissued);
      return '';
    } catch (error) {
      return ' แต่ส่งการ์ดเข้าแชทไม่สำเร็จ: ${formatErrorMessage(error)} '
          '— เปิดบิลใบใหม่แล้วกด "ส่งบิลเข้าแชท" อีกครั้ง';
    }
  }

  /// เปิดแผ่นแชร์ของระบบพร้อมไฟล์ PDF ของบิลใบนี้
  ///
  /// ไม่แตะสถานะบิลเลย จึงทำได้กับทุกสถานะ รวมทั้งใบที่ยกเลิกไปแล้ว
  ///
  /// ดึงช่องทางรับเงินมาใส่ด้วย — ไฟล์ที่เจ้าของหอส่งให้ผู้เช่าถูกใช้แทนการทวงบิล
  /// ในแชท ถ้าไม่มีเลขบัญชีกับคิวอาร์อยู่ในนั้น ผู้เช่าก็จ่ายจากไฟล์ไม่ได้และต้อง
  /// ย้อนกลับมาเปิดแอป ทั้งที่ไฟล์ฝั่งผู้เช่าเองมีข้อมูลครบมาตลอด
  ///
  /// ช่องทางที่ดึงไม่ได้ไม่ทำให้ล้มทั้งการแชร์ — ได้ไฟล์ที่ขาดคิวอาร์ ดีกว่า
  /// ไม่ได้ไฟล์เลย
  Future<ActionResult> sharePdf({required String dormitoryName}) => _run(
        () async {
          PaymentChannel? channel;
          try {
            channel = await _channels.fetch(dormitoryId: dormitoryId);
          } catch (error) {
            debugPrint('โหลดช่องทางชำระเงินไม่สำเร็จ ข้ามไป: $error');
          }
          await shareInvoicePdf(
            invoice: invoice,
            dormitoryName: dormitoryName,
            channel: channel,
          );
        },
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
