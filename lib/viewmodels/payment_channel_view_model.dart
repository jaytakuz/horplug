import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/thai_bank.dart';
import '../services/payment_channel_service.dart';
import '../services/promptpay.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'safe_notifier.dart';

/// ตรวจว่ามีอย่างน้อยหนึ่งช่องทางให้โอน · null แปลว่าผ่าน
///
/// สะท้อน CHECK `dpc_has_a_channel` ในฐานข้อมูล ถ้าไม่ตรวจที่นี่ด้วย เจ้าของหอ
/// จะเจอข้อความดิบจาก Postgres แทนคำอธิบายว่าต้องกรอกอะไรเพิ่ม
String? validateHasAnyChannel({
  required String promptPayId,
  required String bankName,
  required String accountNo,
}) {
  final hasPromptPay = promptPayId.trim().isNotEmpty;
  final hasBank = bankName.trim().isNotEmpty && accountNo.trim().isNotEmpty;
  if (hasPromptPay || hasBank) return null;
  return 'ต้องมีอย่างน้อยหนึ่งช่องทาง — เบอร์พร้อมเพย์ หรือ ธนาคารพร้อมเลขบัญชี';
}

/// ตรวจคู่ธนาคาร/เลขบัญชีว่ากรอกครบทั้งคู่หรือเว้นว่างทั้งคู่ · null แปลว่าผ่าน
///
/// กรอกมาอย่างเดียวจะได้แถวที่มีชื่อธนาคารแต่ไม่มีเลขให้โอน ซึ่ง CHECK
/// ในฐานข้อมูลก็ไม่นับว่าเป็นช่องทางที่ใช้ได้
String? validateBankPair({
  required String bankName,
  required String accountNo,
}) {
  final hasBankName = bankName.trim().isNotEmpty;
  final hasAccountNo = accountNo.trim().isNotEmpty;
  if (hasBankName == hasAccountNo) return null;
  return hasBankName
      ? 'กรอกเลขบัญชีด้วย หรือลบชื่อธนาคารออก'
      : 'กรอกชื่อธนาคารด้วย หรือลบเลขบัญชีออก';
}

class PaymentChannelViewModel extends ChangeNotifier with SafeNotifier {
  PaymentChannelViewModel({
    required this.dormitoryId,
    PaymentChannelService? service,
  }) : _service = service ?? PaymentChannelService();

  final int dormitoryId;
  final PaymentChannelService _service;

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  String promptPayId = '';
  String bankName = '';
  String accountNo = '';
  String accountName = '';

  /// ยอดเริ่มต้นของคิวอาร์ตัวอย่าง
  static const defaultPreviewAmount = 1234.56;

  /// ยอดที่ใช้สร้างคิวอาร์ตัวอย่าง · ปรับได้
  ///
  /// จุดประสงค์คือให้เจ้าของหอสแกนตรวจเองว่าเข้าบัญชีถูกใบก่อนบันทึก — เป็นทาง
  /// เดียวที่จะจับเบอร์ที่พิมพ์ผิดแต่ยังครบ 10 หลักได้ ซึ่ง validation ไม่มีทางรู้
  ///
  /// ปรับได้เพราะการตรวจที่แน่นอนที่สุดคือ**โอนจริง**ด้วยยอดเล็กๆ แล้วดูว่าเงิน
  /// เข้าบัญชีไหม ยอดตายตัว ฿1,234.56 บังคับให้ต้องโอนเงินจำนวนนั้นจริงเพื่อ
  /// ทดสอบ ซึ่งไม่มีใครทำ
  double previewAmount = defaultPreviewAmount;

  String? get previewPayload => promptPayId.trim().isEmpty
      ? null
      : promptPayPayload(
          promptPayId: promptPayId.trim(),
          amount: previewAmount,
        );

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final channel = await _service.fetch(dormitoryId: dormitoryId);
      if (channel != null) {
        promptPayId = channel.promptPayId ?? '';
        bankName = channel.bankName ?? '';
        accountNo = channel.accountNo ?? '';
        accountName = channel.accountName;
      }
    } catch (error) {
      errorMessage = formatErrorMessage(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// อัปเดตค่าในฟอร์ม · แยกจาก TextEditingController เพื่อให้ QR ตัวอย่าง
  /// วาดใหม่ตามที่พิมพ์ได้ทันที
  void update({
    String? promptPayId,
    String? bankName,
    String? accountNo,
    String? accountName,
  }) {
    this.promptPayId = promptPayId ?? this.promptPayId;
    this.bankName = bankName ?? this.bankName;
    this.accountNo = accountNo ?? this.accountNo;
    this.accountName = accountName ?? this.accountName;
    notifyListeners();
  }

  /// ตั้งยอดของคิวอาร์ตัวอย่าง · ค่าที่ใช้ไม่ได้จะกลับไปใช้ค่าเริ่มต้น
  ///
  /// ยอด 0 หรือติดลบสร้าง payload ที่ไม่มี tag 54 ซึ่งเป็นคิวอาร์คนละแบบกับที่
  /// ผู้เช่าจะเห็นจริง การทดสอบด้วยของที่ไม่เหมือนของจริงไม่ได้พิสูจน์อะไร
  void setPreviewAmount(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', ''));
    previewAmount =
        (parsed == null || parsed <= 0) ? defaultPreviewAmount : parsed;
    notifyListeners();
  }

  /// ธนาคารที่เลือกไว้ · null เมื่อยังไม่เลือก หรือชื่อที่เก็บไว้ไม่ตรงรายการ
  ThaiBank? get selectedBank => ThaiBank.fromName(bankName);

  /// true เมื่อชื่อธนาคารที่เก็บไว้ไม่ตรงกับรายการที่มีให้เลือก
  ///
  /// เกิดกับหอที่ตั้งค่าไว้ตอนที่ช่องนี้ยังพิมพ์เองได้ · หน้าจอต้องแสดงค่าเดิม
  /// ต่อไปได้ ไม่ใช่ทำเหมือนเจ้าของหอไม่เคยกรอกอะไรไว้
  bool get hasUnlistedBank =>
      bankName.trim().isNotEmpty && selectedBank == null;

  void selectBank(ThaiBank? bank) {
    bankName = bank?.displayName ?? '';
    notifyListeners();
  }

  Future<ActionResult> save() async {
    isSaving = true;
    notifyListeners();

    try {
      await _service.save(
        dormitoryId: dormitoryId,
        channel: PaymentChannel(
          accountName: accountName.trim(),
          promptPayId: promptPayId.trim().isEmpty ? null : promptPayId.trim(),
          bankName: bankName.trim().isEmpty ? null : bankName.trim(),
          accountNo: accountNo.trim().isEmpty ? null : accountNo.trim(),
        ),
      );
      return const ActionResult(
        success: true,
        message: 'บันทึกช่องทางชำระเงินแล้ว',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'บันทึกไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
