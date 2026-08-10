// generateQRCode อยู่ใต้ src/ ของ promptpay_qrcode_generate แต่เป็นฟังก์ชัน
// public ที่คืน payload EMVCo ออกมาเป็นสตริง เรียกตรงนี้เพื่อให้ QR บนหน้าจอกับ
// ใน PDF มาจากตัวสร้างเดียวกัน ทางเลือกอื่นคือเขียน generator ซ้ำอีกชุด แล้วต้อง
// คอยดูแลให้สองชุดตรงกันตลอดไป
//
// ตัว widget QRCodeGenerate ที่ package export มาอย่างเป็นทางการใช้ไม่ได้ที่นี่
// เพราะมันวาด QR จาก payload ที่ยังไม่ได้ซ่อม checksum (ดูเหตุผลใต้
// promptPayPayload) และหน้าตาเป็นกรอบสีน้ำเงินพร้อมข้อความอังกฤษตายตัว
// ignore: implementation_imports
import 'package:promptpay_qrcode_generate/src/generate_qrcode.dart';

/// ความยาวของเลข PromptPay ที่ generateQRCode รองรับ
/// 10 = เบอร์โทรศัพท์ · 13 = เลขบัตรประชาชน/นิติบุคคล
const _supportedIdLengths = {10, 13};

/// payload EMVCo สำหรับ PromptPay พร้อมจำนวนเงิน · null เมื่อเลขผิดรูปแบบ
///
/// ห่อ `generateQRCode` ไว้ด้วยเหตุผลสองข้อ
///
/// **หนึ่ง — ซ่อม checksum ที่ยาวไม่ครบ** package คำนวณ CRC16 แล้วแปลงเป็น hex
/// ตรงๆ โดยไม่เติมศูนย์ข้างหน้า
///
/// ```dart
/// crc16(payload).toRadixString(16).toUpperCase()
/// ```
///
/// CRC16 คืนค่า 0–65535 ค่าที่น้อยกว่า 0x1000 จึงได้ hex เพียง 3 หลักหรือสั้นกว่า
/// ขณะที่ tag `6304` ประกาศไว้แล้วว่าข้อมูลยาว 4 — payload ที่ได้ผิดรูปแบบ EMVCo
/// และธนาคารสแกนไม่ผ่าน เกิดกับ 4096 ใน 65536 ค่า หรือราว 6.25% และเพราะยอดเงิน
/// เปลี่ยนทุกบิล CRC จึงเปลี่ยนทุกบิลตามไปด้วย บิลที่พังจึงกระจายแบบสุ่ม
/// (ยืนยันได้จาก test/promptpay_unit_test.dart — ยอด 0.10 ถึง 0.14 พังทุกใบ)
///
/// **สอง — คืน null แทนสตริงว่าง** package คืน `""` เงียบๆ เมื่อเลขไม่ใช่ 10
/// หรือ 13 หลัก ซึ่งผู้เรียกเผลอเอาไปวาดเป็น QR เปล่าได้โดยไม่มีอะไรเตือน
String? promptPayPayload({
  required String promptPayId,
  required double amount,
}) {
  final id = promptPayId.trim();
  if (!_supportedIdLengths.contains(id.length)) return null;
  if (!RegExp(r'^\d+$').hasMatch(id)) return null;

  final raw = generateQRCode(promptPayID: id, amount: amount);
  if (raw.isEmpty) return null;

  // tag 63 (CRC) เป็นฟิลด์สุดท้ายเสมอตามสเปก EMVCo ทุกอย่างก่อน "6304" คือ
  // ข้อมูลที่ CRC คำนวณมาจาก ส่วนที่ตามหลังคือตัว checksum ที่ต้องยาว 4 พอดี
  final marker = raw.lastIndexOf('6304');
  if (marker < 0) return null;

  final body = raw.substring(0, marker + 4);
  final checksum = raw.substring(marker + 4);
  return '$body${checksum.padLeft(4, '0')}';
}

/// ตรวจเลข PromptPay ให้ตรงกับที่ระบบรองรับ · null แปลว่าผ่าน
///
/// ข้อความคืนกลับใช้แสดงใต้ช่องกรอกในหน้าตั้งค่าได้เลย
///
/// ต้องตรวจก่อนถึงมือ package เสมอ เพราะ package จัดการเลขผิดรูปด้วยการคืน
/// สตริงว่าง ซึ่งกลายเป็นกล่อง QR เปล่าบนหน้าจอโดยไม่มี error ให้ตามรอย
String? validatePromptPayId(String? value, {bool required = false}) {
  final id = value?.trim() ?? '';
  if (id.isEmpty) {
    return required ? 'กรุณากรอกเบอร์พร้อมเพย์' : null;
  }
  if (!RegExp(r'^\d+$').hasMatch(id)) {
    return 'กรอกได้เฉพาะตัวเลข ไม่ต้องมีขีดหรือเว้นวรรค';
  }
  if (!_supportedIdLengths.contains(id.length)) {
    return 'ต้องเป็นเบอร์โทร 10 หลัก หรือเลขบัตรประชาชน 13 หลัก';
  }
  return null;
}
