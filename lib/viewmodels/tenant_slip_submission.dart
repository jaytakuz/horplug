import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
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
    required File slip,
  }) async {
    isSubmittingSlip = true;
    notifyListeners();

    try {
      final result =
          await billingSource.submitPaymentSlip(bill: bill, slip: slip);
      if (result.success) await reloadAfterSlip();
      return result;
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ส่งสลิปไม่สำเร็จ: ${formatErrorMessage(error)}',
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
