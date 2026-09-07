/// ข้อความย่อของแชทหนึ่งห้อง สำหรับแสดงบนการ์ดทางลัด
///
/// แยกออกมาเป็นฟังก์ชันบริสุทธิ์เพราะเป็นตรรกะการแสดงผลล้วนๆ ที่ทดสอบได้โดย
/// ไม่ต้องสร้าง widget และมีเงื่อนไขเยอะพอที่จะพลาดได้
library;

import '../models/models.dart';

/// คำนำหน้าบอกว่าใครส่งข้อความล่าสุด
///
/// แพลตฟอร์มแชททั่วไปแสดง "คุณ:" เมื่อเราเป็นคนส่ง เพื่อให้รู้ได้ทันทีว่ากำลัง
/// รอฝ่ายตรงข้ามตอบอยู่หรือเปล่า โดยไม่ต้องเปิดห้องเข้าไปดู
String chatSenderLabel(ChatMessage message, {required bool viewerIsOwner}) =>
    message.isFromOwner == viewerIsOwner ? 'คุณ' : message.senderName;

/// เนื้อความย่อ — ข้อความที่ไม่ใช่ตัวอักษรต้องมีคำอธิบายแทน
///
/// ถ้าปล่อยให้ว่าง การ์ดจะขึ้นแค่ "เจ้าของหอ:" ลอยๆ ซึ่งอ่านแล้วเหมือนระบบพัง
String chatMessagePreview(ChatMessage message) {
  switch (message.type) {
    case MessageType.image:
      return 'รูปภาพ';
    case MessageType.invoice:
      return 'บิลค่าเช่า';
    case MessageType.maintenanceRequest:
      return 'แจ้งซ่อม';
    case MessageType.cleaningRequest:
      return 'แจ้งทำความสะอาด';
    case MessageType.maintenanceUpdate:
      return 'อัปเดตงานซ่อม';
    case MessageType.cleaningUpdate:
      return 'อัปเดตงานทำความสะอาด';
    case MessageType.text:
      final text = message.text.trim();
      // ข้อความว่างเกิดได้จากข้อความที่แนบรูปมาแต่ไม่ได้พิมพ์อะไร
      return text.isEmpty ? 'รูปภาพ' : text;
  }
}

/// บรรทัดพรีวิวเต็ม เช่น `เจ้าของหอ: รูปภาพ` หรือ `คุณ: ค่าน้ำเดือนนี้เท่าไหร่`
String chatPreviewLine(ChatMessage message, {required bool viewerIsOwner}) =>
    '${chatSenderLabel(message, viewerIsOwner: viewerIsOwner)}: '
    '${chatMessagePreview(message)}';

/// เวลาแบบที่แอปแชททั่วไปใช้ — ยิ่งใกล้ยิ่งละเอียด ยิ่งไกลยิ่งหยาบ
///
/// ต่างจากรูปแบบเดิม ("6 วันที่แล้ว") ตรงที่บอกได้ว่าเป็นข้อความของ *เมื่อไหร่*
/// ไม่ใช่แค่ *นานแค่ไหน* — คนอ่านแชทสนใจว่า "เมื่อเช้า" หรือ "เมื่อวาน"
/// มากกว่าจำนวนชั่วโมงที่ผ่านไป
///
/// [now] รับเข้ามาเพื่อให้เทสต์กำหนดเวลาอ้างอิงได้ ไม่ต้องพึ่งนาฬิกาจริง
String chatTimestampLabel(DateTime timestamp, {DateTime? now}) {
  final local = timestamp.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();

  final today = DateTime(reference.year, reference.month, reference.day);
  final messageDay = DateTime(local.year, local.month, local.day);
  final daysApart = today.difference(messageDay).inDays;

  if (daysApart == 0) {
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (daysApart == 1) return 'เมื่อวาน';
  if (daysApart < 7) return _thaiWeekday(local.weekday);

  final year = (local.year % 100).toString().padLeft(2, '0');
  return '${local.day}/${local.month}/$year';
}

String _thaiWeekday(int weekday) {
  const names = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
  return names[weekday - 1];
}
