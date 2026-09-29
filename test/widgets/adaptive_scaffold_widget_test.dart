import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/theme/app_theme.dart';
import 'package:horplug/widgets/adaptive_scaffold.dart';

const _destinations = [
  NavDestination(
      label: 'หน้าหลัก',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard),
  NavDestination(
      label: 'ห้องพัก',
      icon: Icons.door_front_door_outlined,
      activeIcon: Icons.door_front_door),
  NavDestination(
      label: 'มิเตอร์', icon: Icons.speed_outlined, activeIcon: Icons.speed),
  NavDestination(
      label: 'บิล',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long),
  NavDestination(
      label: 'แชท',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      badgeCount: 3),
];

Future<void> _pumpShell(WidgetTester tester,
    {required double textScale}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 780),
        textScaler: TextScaler.linear(textScale),
      ),
      child: AdaptiveNavigationScaffold(
        destinations: _destinations,
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        body: const SizedBox.expand(),
      ),
    ),
  ));
}

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('bottom bar is taller than the 56px default at text ×$scale',
        (tester) async {
      await _pumpShell(tester, textScale: scale);

      expect(tester.takeException(), isNull);
      final bar = find
          .ancestor(
            of: find.byType(BottomNavigationBar),
            matching: find.byType(Container),
          )
          .first;
      // 56 ของแถบ + ระยะเติมบนล่างอย่างละ 6 · บน VM ไม่มี safe area ของเว็บ
      expect(tester.getSize(bar).height,
          greaterThanOrEqualTo(kBottomNavigationBarHeight + 12));
    });
  }
}
