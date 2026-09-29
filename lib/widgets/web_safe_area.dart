/// ระยะขอบล่างที่ต้องเว้นให้ home indicator เมื่อรันบนเบราว์เซอร์
///
/// Flutter บนเว็บไม่ส่ง env(safe-area-inset-bottom) เข้า MediaQuery ·
/// ค่านี้จึงอ่านจากฟังก์ชันใน web/index.html โดยตรง · บนแพลตฟอร์มอื่นคืน 0
/// เพราะ MediaQuery.viewPadding มีค่าที่ถูกต้องอยู่แล้ว
library;

export 'web_safe_area_stub.dart'
    if (dart.library.js_interop) 'web_safe_area_web.dart';
