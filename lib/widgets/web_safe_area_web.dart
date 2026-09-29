import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// เรียก window.horplugSafeAreaBottom ที่ประกาศไว้ใน web/index.html
///
/// คืน 0 เมื่อไม่มีฟังก์ชันนี้ (เช่น index.html รุ่นเก่าที่ยังค้างใน cache)
/// แทนที่จะโยน error แล้วทำให้แถบเมนูวาดไม่ขึ้นทั้งแถบ
double webSafeAreaBottom() {
  if (!globalContext.has('horplugSafeAreaBottom')) return 0;
  final value =
      globalContext.callMethod<JSNumber?>('horplugSafeAreaBottom'.toJS);
  return value?.toDartDouble ?? 0;
}
