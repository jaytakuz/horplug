import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/screens/admin/landlord_profile_screen.dart';
import 'package:horplug/theme/app_theme.dart';
import 'package:horplug/viewmodels/landlord_profile_view_model.dart';
import 'package:horplug/widgets/reusable_widgets.dart';
import 'package:provider/provider.dart';

import '../landlord_profile_unit_test.dart';

/// หน้าแรกที่มีปุ่มเปิดหน้าโปรไฟล์ — ต้องมีหน้าข้างใต้ ไม่งั้นทดสอบการปิดไม่ได้
Future<LandlordProfileViewModel> pumpProfile(
  WidgetTester tester, {
  Size size = const Size(360, 780),
  double textScale = 1.0,
  FakeLandlordProfileService? service,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final vm = buildViewModel(service: service);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => ChangeNotifierProvider.value(
                value: vm,
                child: const LandlordProfileScreen(),
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await vm.load();
  // ให้ทั้งการเปลี่ยนหน้าแบบ fullscreenDialog และการจางของ LoadingSwap จบก่อน
  // ไม่งั้นปุ่มปิดยังอยู่ใต้ชั้นของแอนิเมชันและรับการแตะไม่ได้
  await tester.pumpAndSettle();
  return vm;
}

void main() {
  for (final size in const [Size(360, 780), Size(800, 1000), Size(1440, 900)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('lays out without overflow at $size ×$scale', (tester) async {
        await pumpProfile(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('ข้อมูลส่วนตัว'), findsOneWidget);
        expect(find.text('ช่องทางรับเงิน'), findsOneWidget);
        expect(find.text('บันทึกการเปลี่ยนแปลง'), findsOneWidget);
        // แถบบันทึกต้องสูงแค่เนื้อหาของมัน ไม่ใช่ขยายเต็มจอทับฟอร์ม
        final bar = tester.getSize(find.byType(PrimaryButton).last);
        expect(bar.height, lessThan(80));
        final barTop = tester.getTopLeft(find.text('บันทึกการเปลี่ยนแปลง')).dy;
        expect(barTop, greaterThan(size.height - 120));
      });

      testWidgets('skeleton lays out at $size ×$scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: LandlordProfileSkeleton()),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('closing with no changes pops straight away', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่ได้บันทึกการเปลี่ยนแปลง'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('closing with unsaved changes asks, and keep editing stays',
      (tester) async {
    final vm = await pumpProfile(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'ค่าไฟฟ้า'), '9');
    await tester.pump();
    expect(vm.hasChanges, isTrue);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่ได้บันทึกการเปลี่ยนแปลง'), findsOneWidget);

    await tester.tap(find.text('แก้ไขต่อ'));
    await tester.pumpAndSettle();
    expect(find.text('โปรไฟล์'), findsOneWidget);
    expect(vm.electricityRate, '9');
  });

  testWidgets('discard closes the page without saving', (tester) async {
    final service = FakeLandlordProfileService();
    await pumpProfile(tester, service: service);

    await tester.enterText(find.widgetWithText(TextFormField, 'ค่าไฟฟ้า'), '9');
    await tester.pump();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทิ้งการแก้ไข'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(service.dormitorySaves, 0);
  });

  testWidgets('save and close writes then pops', (tester) async {
    final service = FakeLandlordProfileService();
    await pumpProfile(tester, service: service);

    await tester.enterText(find.widgetWithText(TextFormField, 'ค่าไฟฟ้า'), '9');
    await tester.pump();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกแล้วปิด'));
    await tester.pumpAndSettle();

    expect(service.dormitorySaves, 1);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('invalid input blocks saving and keeps the page open',
      (tester) async {
    final service = FakeLandlordProfileService();
    await pumpProfile(tester, service: service);

    await tester.enterText(find.widgetWithText(TextFormField, 'ค่าไฟฟ้า'), '0');
    await tester.pump();
    await tester.tap(find.text('บันทึกการเปลี่ยนแปลง'));
    await tester.pumpAndSettle();

    expect(service.dormitorySaves, 0);
    expect(find.text('ค่าไฟต้องมากกว่า 0'), findsOneWidget);
  });

  testWidgets('untouched unconfigured payment channel does not block saving',
      (tester) async {
    final service = FakeLandlordProfileService();
    await pumpProfile(tester, service: service);

    await tester.enterText(find.widgetWithText(TextFormField, 'ค่าไฟฟ้า'), '9');
    await tester.pump();
    await tester.tap(find.text('บันทึกการเปลี่ยนแปลง'));
    await tester.pumpAndSettle();

    expect(service.dormitorySaves, 1);
    expect(find.text('บันทึกการเปลี่ยนแปลงแล้ว'), findsOneWidget);
  });
}
