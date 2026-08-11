import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/theme/breakpoints.dart';

/// วาง widget ใต้ MediaQuery ที่กำหนดความกว้างเอง แล้วคืน BuildContext ข้างใน
Future<BuildContext> _contextAtWidth(
  WidgetTester tester,
  double width, {
  double textScale = 1.0,
}) async {
  late BuildContext captured;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
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

/// gridDelegate ที่ได้จาก [cardGridDelegate] ในรูปแบบที่อ่านค่าออกมาตรวจได้
Future<SliverGridDelegateWithFixedCrossAxisCount> _cardGrid(
  WidgetTester tester, {
  required double windowWidth,
  required double availableWidth,
  double minItemWidth = 140,
  double itemHeight = 132,
  int itemCount = 4,
  double textScale = 1.0,
}) async {
  final context =
      await _contextAtWidth(tester, windowWidth, textScale: textScale);

  return cardGridDelegate(
    context,
    availableWidth: availableWidth,
    minItemWidth: minItemWidth,
    itemHeight: itemHeight,
    itemCount: itemCount,
  ) as SliverGridDelegateWithFixedCrossAxisCount;
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

  group('cardGridDelegate', () {
    testWidgets('ความสูงของช่องไม่ผูกกับความกว้างของจอ', (tester) async {
      // หัวใจของบั๊ก · childAspectRatio ผูกความสูงไว้กับความกว้างต่อช่อง
      // พอจำนวนคอลัมน์เปลี่ยนตามจอ ความกว้างต่อช่องก็เปลี่ยน ความสูงจึงเปลี่ยน
      // ตามไปด้วย — การ์ดที่ออกแบบไว้สูง 132 บนมือถือกลายเป็นสูง 291
      final phone =
          await _cardGrid(tester, windowWidth: 440, availableWidth: 408);
      final tablet =
          await _cardGrid(tester, windowWidth: 834, availableWidth: 730);
      final desktop =
          await _cardGrid(tester, windowWidth: 1920, availableWidth: 1080);

      expect(phone.mainAxisExtent, 132);
      expect(tablet.mainAxisExtent, 132);
      expect(desktop.mainAxisExtent, 132);
    });

    testWidgets('มือถือได้สองคอลัมน์ ไม่ใช่คอลัมน์เดียว', (tester) async {
      // ค่า minItemWidth ต้องคิดจากงบความกว้างต่อคอลัมน์ที่มือถือมีจริง
      // ไม่ใช่จากความกว้างที่การ์ดอยากได้บนเดสก์ท็อป
      for (final width in [320.0, 360.0, 390.0, 440.0]) {
        final grid = await _cardGrid(
          tester,
          windowWidth: width,
          availableWidth: width - 32,
        );

        expect(grid.crossAxisCount, 2, reason: 'จอกว้าง $width');
      }
    });

    testWidgets('แถวสุดท้ายไม่เหลือช่องเดียวห้อยอยู่', (tester) async {
      // ของสี่ชิ้นเรียงสามคอลัมน์ได้ 3+1 · แถวล่างที่มีใบเดียวดูเหมือนหลุดมา
      // มากกว่าเป็นส่วนหนึ่งของชุด จึงถอยลงมาหนึ่งคอลัมน์ให้ลงตัว
      final grid = await _cardGrid(
        tester,
        windowWidth: 700,
        availableWidth: 620,
        minItemWidth: 180,
        itemCount: 4,
      );

      expect(grid.crossAxisCount, 2);
    });

    testWidgets('ขยายตัวอักษรของระบบแล้วช่องสูงขึ้นตาม', (tester) async {
      // ความสูงคงที่ตัดข้อความทิ้งเงียบๆ เมื่อผู้ใช้ตั้งตัวอักษรใหญ่ขึ้น
      final normal =
          await _cardGrid(tester, windowWidth: 440, availableWidth: 408);
      final large = await _cardGrid(tester,
          windowWidth: 440, availableWidth: 408, textScale: 1.5);

      expect(large.mainAxisExtent, greaterThan(normal.mainAxisExtent!));
    });
  });

  group('quickActionWidth', () {
    test('มือถือได้สี่ปุ่มต่อแถวเสมอ', () {
      // ปุ่มทางลัดสี่อันเป็นชุดที่ผู้ใช้จำเป็นภาพรวมทั้งแถว · การตัดเหลือสาม
      // แล้วให้อันที่สี่ตกไปแถวล่างทำให้ชุดเดียวดูเหมือนสองกลุ่ม
      for (final available in [288.0, 328.0, 358.0, 408.0]) {
        final width = quickActionWidth(availableWidth: available);
        final rowWidth = width * 4 + 8 * 3;

        expect(rowWidth, lessThanOrEqualTo(available + 0.01),
            reason: 'ที่ว่าง $available');
        expect(width, greaterThan(56), reason: 'ที่ว่าง $available');
      }
    });

    test('จอกว้างไม่ยืดปุ่มจนไอคอนลอยกลางช่องว่าง', () {
      expect(quickActionWidth(availableWidth: 1080), 120);
    });
  });
}
