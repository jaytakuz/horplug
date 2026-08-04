/// แปลง error จาก service ให้เป็นข้อความภาษาไทยที่ผู้ใช้อ่านเข้าใจ
///
/// เดิมฟังก์ชันนี้ถูกคัดลอกซ้ำอยู่ใน ViewModel หลายตัว (dashboard, rooms,
/// tenant_home) — ย้ายมารวมไว้ที่เดียวเพื่อให้ข้อความสอดคล้องกันทั้งแอป
String formatErrorMessage(Object error) {
  final message = error.toString().trim();
  final normalized = message.startsWith('Exception: ')
      ? message.substring('Exception: '.length).trim()
      : message;
  final lowerCaseMessage = normalized.toLowerCase();

  if (lowerCaseMessage.contains('failed host lookup') ||
      lowerCaseMessage.contains('socketexception') ||
      lowerCaseMessage.contains('clientexception') ||
      lowerCaseMessage.contains('connection refused') ||
      lowerCaseMessage.contains('network is unreachable') ||
      lowerCaseMessage.contains('connection timed out') ||
      lowerCaseMessage.contains('timed out')) {
    return 'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
  }

  return normalized;
}
