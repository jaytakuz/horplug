import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/theme/breakpoints.dart';

/// วาง widget ใต้ MediaQuery ที่กำหนดความกว้างเอง แล้วคืน BuildContext ข้างใน
Future<BuildContext> _contextAtWidth(WidgetTester tester, double width) async {
  late BuildContext captured;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return captured;
}

void main() {
  group('layoutSize', () {
    testWidgets('มือถือแนวตั้งเป็น compact', (tester) async {
      final context = await _contextAtWidth(tester, 390);

      expect(context.layoutSize, LayoutSize.compact);
      expect(context.isCompact, isTrue);
      expect(context.isWide, isFalse);
    });

    testWidgets('ตรงจุดตัดพอดีนับเป็นขนาดที่ใหญ่กว่า', (tester) async {
      // ขอบเขตแบบ "ตั้งแต่นี้ขึ้นไป" · ถ้าใช้ > แทน >= จอกว้าง 600 พอดีจะได้
      // เลย์เอาต์มือถือทั้งที่มีที่พอสำหรับแถบข้างแล้ว
      expect((await _contextAtWidth(tester, 600)).layoutSize,
          LayoutSize.medium);
      expect((await _contextAtWidth(tester, 599)).layoutSize,
          LayoutSize.compact);
      expect((await _contextAtWidth(tester, 1024)).layoutSize,
          LayoutSize.expanded);
      expect((await _contextAtWidth(tester, 1023)).layoutSize,
          LayoutSize.medium);
    });

    testWidgets('ระยะขอบกว้างขึ้นตามขนาดจอ', (tester) async {
      expect((await _contextAtWidth(tester, 390)).pageGutter, 16);
      expect((await _contextAtWidth(tester, 800)).pageGutter, 24);
      expect((await _contextAtWidth(tester, 1440)).pageGutter, 32);
    });
  });

  group('contentInsets', () {
    testWidgets('จอแคบได้แค่ระยะขอบ ไม่มีส่วนเผื่อ', (tester) async {
      final insets = contentInsets(await _contextAtWidth(tester, 390),
          availableWidth: 390);

      expect(insets.left, 16);
      expect(insets.right, 16);
      expect(insets.top, 16);
    });

    testWidgets('จอกว้างเผื่อสองข้างเท่ากันจนเนื้อหาไม่เกินเพดาน',
        (tester) async {
      const width = 1920.0;
      final insets = contentInsets(await _contextAtWidth(tester, width),
          availableWidth: width);

      expect(insets.left, insets.right, reason: 'ต้องอยู่กลาง');
      expect(
        width - insets.left - insets.right,
        closeTo(Breakpoints.contentMaxWidth, 0.01),
        reason: 'ความกว้างที่เหลือให้เนื้อหาต้องเท่ากับเพดานพอดี',
      );
    });

    testWidgets('คิดจากความกว้างที่ได้จริง ไม่ใช่ขนาดหน้าต่าง', (tester) async {
      // บนจอกว้างแถบนำทางกินความกว้างไปก่อน · ถ้าคิดจากขนาดหน้าต่างทั้งบาน
      // ระยะขอบจะเผื่อเกินไปข้างละครึ่งของส่วนที่แถบกินไป แล้วเนื้อหาก็เยื้อง
      // ไปทางขวาและแคบกว่าที่ตั้งใจ
      const window = 1920.0;
      const rail = 250.0;
      const pane = window - rail;

      final insets = contentInsets(await _contextAtWidth(tester, window),
          availableWidth: pane);

      expect(
        pane - insets.left - insets.right,
        closeTo(Breakpoints.contentMaxWidth, 0.01),
      );
    });

    testWidgets('กว้างพอดีเพดานยังได้ระยะขอบครบ', (tester) async {
      // เคสขอบ: กว้างเท่าเพดาน + ระยะขอบสองข้างเป๊ะ · ส่วนเผื่อต้องเป็นศูนย์
      // ไม่ใช่ติดลบ ซึ่งจะทำให้ระยะขอบหดจนเนื้อหาชนขอบจอ
      const gutter = 32.0;
      const width = Breakpoints.contentMaxWidth + gutter * 2;
      final insets = contentInsets(await _contextAtWidth(tester, width),
          availableWidth: width);

      expect(insets.left, gutter);
      expect(insets.right, gutter);
    });

    testWidgets('เพดานที่กำหนดเองมีผลจริง', (tester) async {
      final insets = contentInsets(await _contextAtWidth(tester, 1920),
          availableWidth: 1920, maxWidth: 600);

      expect(1920 - insets.left - insets.right, closeTo(600, 0.01));
    });
  });

  group('gridColumnsFor', () {
    test('คอลัมน์เพิ่มตามที่ว่าง แต่ไม่เกินเพดาน', () {
      expect(gridColumnsFor(availableWidth: 360, minItemWidth: 240), 1);
      expect(gridColumnsFor(availableWidth: 500, minItemWidth: 240), 2);
      expect(gridColumnsFor(availableWidth: 1000, minItemWidth: 240), 4);
      expect(gridColumnsFor(availableWidth: 4000, minItemWidth: 240), 4);
    });

    test('อย่างน้อยหนึ่งคอลัมน์เสมอ แม้ที่ว่างไม่พอสักช่อง', () {
      // GridView ที่ crossAxisCount เป็น 0 จะ assert ตาย · หน้าจอที่แคบกว่า
      // ความกว้างขั้นต่ำของช่องเป็นเรื่องที่เกิดได้จริงตอนผู้ใช้ย่อหน้าต่างเว็บ
      expect(gridColumnsFor(availableWidth: 100, minItemWidth: 240), 1);
      expect(gridColumnsFor(availableWidth: 0, minItemWidth: 240), 1);
      expect(gridColumnsFor(availableWidth: -50, minItemWidth: 240), 1);
      expect(gridColumnsFor(availableWidth: 500, minItemWidth: 0), 1);
    });

    test('เพดานที่กำหนดเองมีผล', () {
      expect(
        gridColumnsFor(
            availableWidth: 1000, minItemWidth: 100, maxColumns: 3),
        3,
      );
    });
  });
}
