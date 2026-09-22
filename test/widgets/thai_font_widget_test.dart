import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/theme/app_theme.dart';
import 'package:horplug/widgets/adaptive_scaffold.dart';
import 'package:horplug/widgets/tenant_bill_card.dart';

final _thai = RegExp(r'[฀-๿]');

/// ข้อความไทยทุกก้อนบนจอที่ **ไม่ได้** ตกไป Google Sans
///
/// widget บางตัวใช้ TextStyle ที่ส่งเข้าไป "แทน" สไตล์ที่สืบทอดมา ไม่ได้ merge
/// (ปุ่มที่ใส่ textStyle, ป้ายของ NavigationRail, หัวกล่องโต้ตอบ) ถ้าสไตล์นั้น
/// ไม่มี fontFamilyFallback ตัวไทยจะไปใช้ฟอนต์ของระบบ ซึ่งมองด้วยตาแยกยาก
/// แต่ต่างกันทุกเครื่อง · ตรวจที่ style ที่มีผลจริงของ RenderParagraph
List<String> _thaiWithoutGoogleSans(WidgetTester tester) {
  final failures = <String>[];
  for (final paragraph
      in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
    void walk(InlineSpan span, TextStyle? parent) {
      final style = parent == null ? span.style : parent.merge(span.style);
      if (span is! TextSpan) return;
      final text = span.text;
      if (text != null && _thai.hasMatch(text)) {
        final fallback = style?.fontFamilyFallback ?? const [];
        if (!fallback.contains('Google Sans') ||
            style?.fontFamily != 'Open Sans') {
          failures.add('"$text" → ${style?.fontFamily} / $fallback');
        }
      }
      span.children?.forEach((child) => walk(child, style));
    }

    walk(paragraph.text, null);
  }
  return failures;
}

const _destinations = [
  NavDestination(
      label: 'หน้าหลัก', icon: Icons.home_outlined, activeIcon: Icons.home),
  NavDestination(
      label: 'บิลของฉัน',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long),
];

Invoice _bill(InvoiceStatus status) => Invoice(
      dbId: 1,
      invoiceNo: 'INV-202609-101',
      roomDbId: 101,
      roomNumber: '101',
      tenantName: 'ผู้เช่า',
      billingMonth: 9,
      billingYear: 2026,
      roomPrice: 3000,
      electricityUnits: 90,
      electricityCost: 720,
      waterCost: 100,
      total: 3820,
      status: status,
      dueDate: DateTime(2026, 10, 5),
      issuedAt: DateTime(2026, 9, 28),
    );

void main() {
  for (final width in [360.0, 800.0, 1440.0]) {
    testWidgets('navigation labels use Google Sans at ${width.toInt()}px',
        (tester) async {
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: AdaptiveNavigationScaffold(
          destinations: _destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('แดชบอร์ด'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(_thaiWithoutGoogleSans(tester), isEmpty);
    });
  }

  testWidgets('tenant bill card buttons use Google Sans', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: TenantBillCard(
          bill: _bill(InvoiceStatus.unpaid),
          onPay: () {},
          onSavePdf: () {},
        ),
      ),
    ));

    expect(find.text('บันทึก PDF'), findsOneWidget);
    expect(_thaiWithoutGoogleSans(tester), isEmpty);
  });

  testWidgets('dialog title and content use Google Sans', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('ยืนยันการชำระ'),
                content: const Text('ต้องการชำระบิลนี้ใช่ไหม'),
                actions: [
                  TextButton(onPressed: () {}, child: const Text('ยกเลิก')),
                ],
              ),
            ),
            child: const Text('เปิด'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('เปิด'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ยืนยันการชำระ'), findsOneWidget);
    expect(_thaiWithoutGoogleSans(tester), isEmpty);
  });
}
