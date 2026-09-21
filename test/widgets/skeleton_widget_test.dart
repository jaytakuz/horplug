import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/theme/app_theme.dart';
import 'package:horplug/widgets/skeleton.dart';

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
}
