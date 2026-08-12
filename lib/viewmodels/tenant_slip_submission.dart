import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/picked_image.dart';
import '../services/tenant_billing_source.dart';
import 'action_result.dart';
import 'error_message.dart';

/// การส่งสลิปและการอ่านช่องทางชำระเงินฝั่งผู้เช่า
///
/// สามหน้าจอของผู้เช่าเปิดแผ่นชำระเงินได้ — แท็บบิล แดชบอร์ด และแชท — และทั้งสาม
/// ViewModel เคยถือสำเนาของตรรกะเดียวกันนี้คนละชุด สำเนาเหล่านั้นเริ่มเพี้ยนจาก
/// กันไปแล้วด้วย: ของแดชบอร์ดไม่เคยตั้ง `isSubmittingSlip` เลย และไม่ได้ประกาศ
/// ฟิลด์นั้นด้วยซ้ำ ทั้งที่อีกสองตัวมี
///
/// ใช้รูปแบบเดียวกับ [SafeNotifier] — `mixin ... on ChangeNotifier` ที่
/// ViewModel ฝั่งผู้เช่าทุกตัวผสมอยู่แล้ว
mixin TenantSlipSubmission on ChangeNotifier {
  /// แหล่งข้อมูลบิลของ ViewModel ที่ผสม mixin นี้
  TenantBillingSource get billingSource;

  /// เรียกหลังส่งสลิปสำเร็จ เพื่อให้หน้าจอเห็นสถานะใหม่ทันที
  Future<void> reloadAfterSlip();

  bool isSubmittingSlip = false;

  PaymentChannel? paymentChannel;

  Future<ActionResult> submitSlip({
    required Invoice bill,
    required PickedImage slip,
  }) =>
      _runPaymentAction(
        () => billingSource.submitPaymentSlip(bill: bill, slip: slip),
        onFailure: 'ส่งสลิปไม่สำเร็จ',
      );

  /// แจ้งว่าจ่ายเงินสดแล้ว · ใช้ busy flag ตัวเดียวกับการส่งสลิป เพราะเป็นการ
  /// "แจ้งชำระ" เหมือนกัน และหน้าจอไม่ควรให้กดทั้งสองทางพร้อมกันอยู่แล้ว
  Future<ActionResult> submitCash({required Invoice bill}) =>
      _runPaymentAction(
        () => billingSource.submitCashPayment(bill: bill),
        onFailure: 'แจ้งชำระเงินสดไม่สำเร็จ',
      );

  Future<ActionResult> cancelCash({required Invoice bill}) =>
      _runPaymentAction(
        () => billingSource.cancelCashPayment(bill: bill),
        onFailure: 'ยกเลิกไม่สำเร็จ',
      );

  Future<ActionResult> _runPaymentAction(
    Future<ActionResult> Function() action, {
    required String onFailure,
  }) async {
    isSubmittingSlip = true;
    notifyListeners();

    try {
      final result = await action();
      if (result.success) await reloadAfterSlip();
      return result;
    } catch (error) {
      return ActionResult(
        success: false,
        message: '$onFailure: ${formatErrorMessage(error)}',
      );
    } finally {
      isSubmittingSlip = false;
      notifyListeners();
    }
  }

  /// โหลดช่องทางชำระเงินของหอ
  ///
  /// ไม่ critical — ล้มก็แค่ไม่มีเลขบัญชีให้ดู ผู้เช่ายังแนบสลิปได้ถ้าจ่ายทางอื่น
  /// ไปแล้ว จึงกลืน error ไว้ตรงนี้แทนที่จะพาทั้งหน้าจอล้มไปด้วย
  Future<void> loadPaymentChannel(int? dormitoryId) async {
    if (dormitoryId == null) return;
    try {
      paymentChannel =
          await billingSource.fetchPaymentChannel(dormitoryId: dormitoryId);
    } catch (_) {
      paymentChannel = null;
    }
  }
}
