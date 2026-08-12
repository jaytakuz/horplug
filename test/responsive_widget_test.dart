import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/theme/app_theme.dart';
import 'package:horplug/widgets/adaptive_scaffold.dart';
import 'package:horplug/widgets/reusable_widgets.dart';
import 'package:horplug/widgets/tenant_bill_card.dart';

/// สามความกว้างตาม Breakpoints ที่โปรเจกต์นิยามไว้
///
/// 360 คือมือถือแคบสุดที่ต้องรองรับ · 800 คือแท็บเล็ตหรือหน้าต่างครึ่งจอ ·
/// 1440 คือเว็บบนเดสก์ท็อป
const _sizes = <String, Size>{
  'compact 360x740': Size(360, 740),
  'medium 800x1280': Size(800, 1280),
  'expanded 1440x900': Size(1440, 900),
};

/// ข้อมูลที่ยาวที่สุดเท่าที่ระบบรับได้จริง ไม่ใช่ข้อมูลตัวอย่างสั้นๆ ที่ผ่านทุกจอ
const _longDormName = 'หอพักสวนดอกไม้บานสะพรั่งยามเช้าตรู่ ซอยพหลโยธิน 42';
const _longTenantName = 'ประกาศิต วงศ์ไพศาลสิน';

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: child,
  ));
}

Invoice _bill({bool recalculated = false}) {
  return Invoice(
    dbId: 1,
    invoiceNo: 'INV-202608-101',
    roomDbId: 1,
    roomNumber: '101',
    tenantName: _longTenantName,
    billingMonth: 8,
    billingYear: 2026,
    roomPrice: 3500,
    electricityUnits: 1234,
    electricityCost: 9876.54,
    waterCost: 450,
    cleaningFee: 800,
    total: 14626.54,
    status: InvoiceStatus.unpaid,
    dueDate: DateTime(2026, 9, 5),
    issuedAt: DateTime(2026, 8, 31),
    revision: 2,
    recalculatedAt: recalculated ? DateTime(2026, 9, 1) : null,
    previousTotal: recalculated ? 12345.67 : null,
  );
}

List<NavDestination> _destinations() => const [
      NavDestination(
          label: 'หน้าหลัก', icon: Icons.home_outlined, activeIcon: Icons.home),
      NavDestination(
          label: 'บิล',
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long),
      NavDestination(
          label: 'แจ้งซ่อม',
          icon: Icons.build_outlined,
          activeIcon: Icons.build),
      NavDestination(
          label: 'แชท',
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          badgeCount: 99),
      NavDestination(
          label: 'โปรไฟล์',
          icon: Icons.person_outline,
          activeIcon: Icons.person),
    ];

void main() {
  _sizes.forEach((label, size) {
    group(label, () {
      testWidgets('หัวหน้าจอที่ชื่อหอยาว', (tester) async {
        await _pumpAt(
          tester,
          size,
          Scaffold(
            appBar: const MobileHeader(dormitoryName: _longDormName),
            body: const SizedBox.shrink(),
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('การ์ดสรุปสองใบเรียงกันโดยยอดหลักหมื่น', (tester) async {
        await _pumpAt(
          tester,
          size,
          const Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'ค้างชำระ',
                    value: '฿123,456.78',
                    icon: Icons.error_outline,
                    variant: BadgeVariant.warning,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'ชำระแล้วปีนี้',
                    value: '฿987,654.32',
                    icon: Icons.check_circle_outline,
                    variant: BadgeVariant.success,
                  ),
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('การ์ดบิลที่มีทั้งป้ายปรับยอดและเลขที่ออกใหม่',
          (tester) async {
        await _pumpAt(
          tester,
          size,
          Scaffold(
            body: SingleChildScrollView(
              child: TenantBillCard(bill: _bill(recalculated: true)),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });

      // ป้ายปุ่มยาวขึ้นระหว่างทำงาน ("บันทึกทั้งหมด" → "กำลังบันทึก...") ซึ่งเป็น
      // จังหวะที่หัวหน้าจอเดิมล้นได้จริงบนจอแคบ
      testWidgets('หัวหน้าจอตอนปุ่มกำลังทำงาน', (tester) async {
        await _pumpAt(
          tester,
          size,
          Scaffold(
            body: ScreenHeader(
              title: 'บันทึกมิเตอร์',
              subtitle: 'งวด กุมภาพันธ์ 2026',
              action: PrimaryButton(
                label: 'กำลังบันทึก...',
                icon: Icons.save,
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('หัวหน้าจอเมื่อผู้ใช้ตั้งตัวอักษรใหญ่ 1.3 เท่า',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.3,
            maxScaleFactor: 1.3,
            child: child!,
          ),
          home: Scaffold(
            body: ScreenHeader(
              title: 'จัดการบิลรายเดือน',
              subtitle: 'กุมภาพันธ์ 2026',
              action: PrimaryButton(
                label: 'ออกบิลใหม่',
                icon: Icons.add_chart,
                onPressed: () {},
              ),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
      });

      testWidgets('แถบนำทางห้าปลายทางพร้อม badge', (tester) async {
        await _pumpAt(
          tester,
          size,
          AdaptiveNavigationScaffold(
            appBar: const MobileHeader(dormitoryName: _longDormName),
            destinations: _destinations(),
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            body: const SizedBox.shrink(),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });
  });
}
