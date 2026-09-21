import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/theme/app_theme.dart';
import 'package:horplug/widgets/skeleton.dart';
import 'package:horplug/widgets/tenant_bill_card.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(body: child),
    );

Color _boneColor(WidgetTester tester) {
  final box = tester.widget<Container>(find
      .descendant(of: find.byType(SkeletonBox), matching: find.byType(Container))
      .first);
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('bones pulse while animations are enabled', (tester) async {
    await tester.pumpWidget(
        _host(const SkeletonScope(child: SkeletonBox(width: 100, height: 12))));
    final first = _boneColor(tester);

    await tester.pump(const Duration(milliseconds: 450));

    expect(_boneColor(tester), isNot(first));
  });

  testWidgets('bones stay still when the OS asks for reduced motion',
      (tester) async {
    await tester.pumpWidget(_host(
      const SkeletonScope(child: SkeletonBox(width: 100, height: 12)),
      reduceMotion: true,
    ));
    await tester.pump(const Duration(milliseconds: 450));

    expect(_boneColor(tester), AppColors.muted);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a bone outside any scope renders as a still muted block',
      (tester) async {
    await tester.pumpWidget(_host(const SkeletonBox(width: 100, height: 12)));

    expect(_boneColor(tester), AppColors.muted);
  });

  testWidgets('screen readers hear one loading label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(const SkeletonScope(
      semanticsLabel: 'กำลังโหลดบิล',
      child: Column(children: [
        SkeletonBox(height: 12),
        SkeletonBox(height: 12),
      ]),
    )));

    expect(find.bySemanticsLabel('กำลังโหลดบิล'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('LoadingSwap never builds content while loading', (tester) async {
    var built = 0;
    await tester.pumpWidget(_host(LoadingSwap(
      isLoading: true,
      skeleton: const SkeletonBox(height: 12),
      builder: (_) {
        built++;
        return const Text('เนื้อหา');
      },
    )));

    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(find.text('เนื้อหา'), findsNothing);
    expect(built, 0);
  });

  testWidgets('LoadingSwap crossfades to content, then drops the skeleton',
      (tester) async {
    Widget swap(bool loading) => _host(LoadingSwap(
          isLoading: loading,
          skeleton: const SkeletonBox(height: 12),
          builder: (_) => const Text('เนื้อหา'),
        ));

    await tester.pumpWidget(swap(true));
    await tester.pumpWidget(swap(false));
    await tester.pump(const Duration(milliseconds: 100));
    // mid-fade: both are on screen
    expect(find.text('เนื้อหา'), findsOneWidget);
    expect(find.byType(SkeletonBox), findsOneWidget);

    await tester.pump(LoadingSwap.duration);
    expect(find.byType(SkeletonBox), findsNothing);
  });

  for (final scale in const [1.0, 1.3]) {
    testWidgets('StatCardSkeleton fits a 140×132 grid cell at text ×$scale',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: app!,
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              height: 132,
              child: SkeletonScope(child: StatCardSkeleton()),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TenantBillCardSkeleton lays out at the narrowest phone width',
      (tester) async {
    await tester.pumpWidget(_host(const SizedBox(
      width: 288, // 320 − 16 × 2 gutter
      child: SkeletonScope(child: TenantBillCardSkeleton()),
    )));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  for (final scale in const [1.0, 1.3]) {
    testWidgets(
        'TenantBillCardSkeleton is as tall as a real paid bill at text ×$scale',
        (tester) async {
      // กว้างพอที่ข้อความจริงไม่ตัดบรรทัด — วัดเฉพาะความสูงต่อบรรทัด ไม่ใช่การตัดคำ
      // ซึ่งขึ้นกับฟอนต์และต่างกันระหว่างฟอนต์ทดสอบกับฟอนต์จริง
      final bill = Invoice(
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
        status: InvoiceStatus.paid,
        dueDate: DateTime(2026, 10, 5),
        issuedAt: DateTime(2026, 9, 28),
      );
      tester.view
        ..physicalSize = const Size(1440, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: app!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              const SizedBox(
                width: 1080,
                child: SkeletonScope(child: TenantBillCardSkeleton()),
              ),
              SizedBox(
                width: 1080,
                child: TenantBillCard(bill: bill, onSavePdf: () {}),
              ),
            ]),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final skeleton = tester.getSize(find.byType(TenantBillCardSkeleton)).height;
      final real = tester.getSize(find.byType(TenantBillCard)).height;
      expect(skeleton, closeTo(real, 6));
    });
  }
}
