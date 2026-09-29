import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';

/// เรียก window.horplugSafeAreaInsets ที่ประกาศไว้ใน web/index.html
///
/// คืน [EdgeInsets.zero] เมื่อไม่มีฟังก์ชันนี้ (เช่น index.html รุ่นเก่าที่ยัง
/// ค้างใน cache) แทนที่จะโยน error แล้วทำให้ทั้งแอปวาดไม่ขึ้น
EdgeInsets webSafeAreaInsets() {
  if (!globalContext.has('horplugSafeAreaInsets')) return EdgeInsets.zero;
  final result = globalContext
      .callMethod<JSArray<JSNumber>?>('horplugSafeAreaInsets'.toJS);
  final values = result?.toDart.map((value) => value.toDartDouble).toList();
  if (values == null || values.length != 4) return EdgeInsets.zero;
  return EdgeInsets.fromLTRB(values[3], values[0], values[1], values[2]);
}
