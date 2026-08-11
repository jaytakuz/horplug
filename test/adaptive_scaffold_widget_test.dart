import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/widgets/adaptive_scaffold.dart';

const _destinations = [
  NavDestination(
      label: 'หน้าหลัก', icon: Icons.home_outlined, activeIcon: Icons.home),
  NavDestination(
      label: 'บิล',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long),
  NavDestination(
      label: 'แจ้งซ่อม', icon: Icons.build_outlined, activeIcon: Icons.build),
  NavDestination(
    label: 'แชท',
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    badgeCount: 3,
  ),
  NavDestination(
      label: 'โปรไฟล์', icon: Icons.person_outline, activeIcon: Icons.person),
];

Future<void> _pumpAt(
  WidgetTester tester,
  Size size, {
  int selectedIndex = 0,
  bool showNavigation = true,
  ValueChanged<int>? onSelected,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: AdaptiveNavigationScaffold(
        destinations: _destinations,
        selectedIndex: selectedIndex,
        showNavigation: showNavigation,
        onDestinationSelected: onSelected ?? (_) {},
        body: const Center(child: Text('เนื้อหา')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AdaptiveNavigationScaffold', () {
    testWidgets('จอแคบใช้แถบล่าง', (tester) async {
      await _pumpAt(tester, const Size(390, 844));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('เนื้อหา'), findsOneWidget);
    });

    testWidgets('แท็บเล็ตใช้แถบข้างแบบไม่กางป้าย', (tester) async {
      await _pumpAt(tester, const Size(800, 1000));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('เดสก์ท็อปกางป้ายในแถบข้าง', (tester) async {
      await _pumpAt(tester, const Size(1440, 900));

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });

    testWidgets('ทุกความกว้างวาดได้โดยไม่ล้นขอบ', (tester) async {
      // ไล่ตั้งแต่มือถือเล็กสุดที่ยังต้องรองรับ ไปจนจอกว้าง · ความสูง 500 จำลอง
      // หน้าต่างเว็บที่ถูกลากให้เตี้ย ซึ่งเป็นกรณีที่แถบข้างมีที่ไม่พอสำหรับ
      // ปลายทางทั้งห้า
      for (final size in const [
        Size(320, 640),
        Size(390, 844),
        Size(600, 900),
        Size(834, 500),
        Size(1024, 768),
        Size(1920, 1080),
      ]) {
        await _pumpAt(tester, size);

        expect(tester.takeException(), isNull,
            reason: 'ขนาด $size ต้องวาดได้โดยไม่มี overflow');
        expect(find.text('เนื้อหา'), findsOneWidget);
      }
    });

    testWidgets('ปิดแถบนำทางแล้วเนื้อหายังอยู่', (tester) async {
      // เจ้าของหอที่ยังไม่ได้ผูกกับหอไหนไม่มีแท็บให้กด แต่ต้องเห็นข้อความอธิบาย
      await _pumpAt(tester, const Size(1440, 900), showNavigation: false);

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.text('เนื้อหา'), findsOneWidget);
    });

    testWidgets('ดัชนีที่เกินขอบเขตไม่ทำให้พัง', (tester) async {
      // /landlord/lease ไม่มีในแถบนำทาง แต่หน้ายังต้องวาดได้ · NavigationRail
      // จะ assert ตายถ้า selectedIndex เกินจำนวนปลายทาง
      await _pumpAt(tester, const Size(1440, 900), selectedIndex: 9);
      expect(tester.takeException(), isNull);

      await _pumpAt(tester, const Size(390, 844), selectedIndex: 9);
      expect(tester.takeException(), isNull);
    });

    testWidgets('แตะแล้วส่งดัชนีกลับทั้งสองแบบ', (tester) async {
      final tapped = <int>[];

      await _pumpAt(tester, const Size(390, 844),
          onSelected: tapped.add);
      await tester.tap(find.text('บิล'));
      expect(tapped, [1]);

      await _pumpAt(tester, const Size(1440, 900),
          onSelected: tapped.add);
      await tester.tap(find.text('แจ้งซ่อม'));
      expect(tapped, [1, 2]);
    });

    testWidgets('จำนวนที่ยังไม่อ่านขึ้นเป็น badge ทั้งสองแบบ', (tester) async {
      await _pumpAt(tester, const Size(390, 844));
      expect(find.text('3'), findsOneWidget);

      await _pumpAt(tester, const Size(1440, 900));
      expect(find.text('3'), findsOneWidget);
    });
  });
}
