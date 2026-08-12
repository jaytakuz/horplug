import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/theme/app_theme.dart';

Widget _appWithPushablePage() {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('หน้าที่ซ้อนขึ้นมา')),
            ),
          ),
          child: const Text('เปิดหน้ารายละเอียด'),
        ),
      ),
    ),
  );
}

void main() {
  test('แต่ละแพลตฟอร์มได้อนิเมชันเปลี่ยนหน้าที่ตั้งใจไว้', () {
    final builders = buildAppTheme().pageTransitionsTheme.builders;

    // เครื่อง Android จริงใช้ PredictiveBack ซึ่งให้พรีวิวหน้าถัดไประหว่างปัด
    // (เทสต์รันบน VM ไม่ใช่เว็บ kIsWeb จึงเป็น false เหมือนตอนรันเป็นแอป)
    expect(builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>());

    // ที่เหลือใช้ Cupertino ซึ่งพก CupertinoBackGestureDetector มาในตัว
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(builders[platform], isA<CupertinoPageTransitionsBuilder>(),
          reason: '$platform ต้องปัดขอบจอย้อนกลับได้');
    }
  });

  // TargetPlatformVariant จัดการตั้งและคืนค่า debugDefaultTargetPlatformOverride
  // ให้เอง · การตั้งเองใน setUp/tearDown ไม่ผ่าน เพราะ flutter_test ตรวจว่าตัวแปร
  // debug ถูกคืนค่าแล้วตั้งแต่จบ body ของเทสต์ ก่อนที่ tearDown จะได้ทำงาน
  group('ปัดจากขอบซ้ายเพื่อย้อนกลับ', () {
    testWidgets('ลากจนสุดแล้วหน้าที่ซ้อนอยู่ถูกปิด', (tester) async {
      await tester.pumpWidget(_appWithPushablePage());
      await tester.tap(find.text('เปิดหน้ารายละเอียด'));
      await tester.pumpAndSettle();
      expect(find.text('หน้าที่ซ้อนขึ้นมา'), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(2, 300));
      await gesture.moveBy(const Offset(400, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('หน้าที่ซ้อนขึ้นมา'), findsNothing);
      expect(find.text('เปิดหน้ารายละเอียด'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('ลากไม่ถึงครึ่งแล้วปล่อย หน้าเดิมเด้งกลับ ไม่ถูกปิด',
        (tester) async {
      await tester.pumpWidget(_appWithPushablePage());
      await tester.tap(find.text('เปิดหน้ารายละเอียด'));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(const Offset(2, 300));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('หน้าที่ซ้อนขึ้นมา'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
