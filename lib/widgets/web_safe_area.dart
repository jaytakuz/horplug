import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'web_safe_area_stub.dart'
    if (dart.library.js_interop) 'web_safe_area_web.dart';

/// เติมระยะขอบปลอดภัยของจอ (รอยบาก แถบ home indicator) ให้ MediaQuery บนเว็บ
///
/// engine ของ Flutter บนเว็บตั้ง viewPadding เป็น 0 เสมอ ไม่ได้อ่าน
/// env(safe-area-inset-*) ของเบราว์เซอร์ · ผลคือ AppBar, SafeArea และ
/// BottomNavigationBar ซึ่งบนแอป native เว้นที่ให้รอยบากกับ home indicator เอง
/// กลับวาดชิดขอบจอบน iPhone · widget นี้อ่านค่าจริงจาก web/index.html แล้วใส่
/// กลับเข้า MediaQuery ที่รากของแอป ทุกหน้าจึงได้พฤติกรรมเดียวกับ native โดยไม่
/// ต้องแก้ทีละหน้า · นอกเบราว์เซอร์ค่าที่อ่านได้เป็น 0 จึงส่ง child ผ่านไปตรงๆ
class WebSafeArea extends StatelessWidget {
  const WebSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // พึ่ง MediaQuery ทั้งก้อนเพื่อให้วัดใหม่ทุกครั้งที่จอหมุน หน้าต่างเปลี่ยน
    // ขนาด หรือแป้นพิมพ์เปิดปิด ซึ่งเป็นจังหวะที่ safe area เปลี่ยนตาม
    final media = MediaQuery.of(context);
    final insets = webSafeAreaInsets();
    if (insets == EdgeInsets.zero) return child;

    final viewPadding = EdgeInsets.fromLTRB(
      math.max(media.viewPadding.left, insets.left),
      math.max(media.viewPadding.top, insets.top),
      math.max(media.viewPadding.right, insets.right),
      math.max(media.viewPadding.bottom, insets.bottom),
    );
    // padding คือส่วนของ viewPadding ที่แป้นพิมพ์ไม่ได้บังอยู่ · ตรงกับที่
    // engine บน native คำนวณให้ เมื่อแป้นพิมพ์ขึ้น ช่องพิมพ์แชทจะได้ไม่ลอยสูง
    // เกินจริงเท่ากับความสูงของ home indicator
    final padding = EdgeInsets.fromLTRB(
      viewPadding.left,
      viewPadding.top,
      viewPadding.right,
      math.max(0, viewPadding.bottom - media.viewInsets.bottom),
    );

    return MediaQuery(
      data: media.copyWith(viewPadding: viewPadding, padding: padding),
      child: child,
    );
  }
}
