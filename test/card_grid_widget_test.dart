import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/theme/app_theme.dart';
import 'package:horplug/theme/breakpoints.dart';
import 'package:horplug/widgets/reusable_widgets.dart';

/// วัดจากของที่วาดจริง ไม่ใช่จากตัวเลขที่ป้อนเข้า gridDelegate
///
/// การ์ดสรุปบนแดชบอร์ดเคยพองจนสูงเกือบ 300 บนมือถือ โดยที่ค่าใน gridDelegate
/// ยัง "ถูกต้อง" ตามที่เขียนไว้ทุกตัว — เพราะความผิดอยู่ที่ความสัมพันธ์ระหว่าง
/// ความกว้างกับความสูง ไม่ใช่ที่ตัวเลขตัวใดตัวหนึ่ง
Future<void> _pumpStatGrid(
  WidgetTester tester, {
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ContentBounds(
            child: LayoutBuilder(
              builder: (context, constraints) => GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: cardGridDelegate(
                  context,
                  availableWidth: constraints.maxWidth,
                  minItemWidth: 140,
                  itemHeight: 132,
                  itemCount: 4,
                ),
                children: const [
                  StatCard(
                    title: 'รายได้คาดการณ์',
                    value: '฿37,500',
                    subtitle: 'จากห้องที่มีผู้พักอาศัย',
                    icon: Icons.account_balance_wallet,
                  ),
                  StatCard(
                    title: 'อัตราเข้าพัก',
                    value: '41%',
                    subtitle: '15/37 ห้อง',
                    icon: Icons.home,
                    variant: BadgeVariant.success,
                  ),
                  StatCard(
                    title: 'ผู้พักอาศัยทั้งหมด',
                    value: '15',
                    icon: Icons.people,
                  ),
                  StatCard(
                    title: 'ห้องว่าง',
                    value: '22',
                    icon: Icons.meeting_room_outlined,
                    variant: BadgeVariant.warning,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('การ์ดสรุปบนมือถือ', () {
    testWidgets('สูงเท่าที่ออกแบบไว้ ไม่พองตามความกว้างของจอ', (tester) async {
      // 440 คือความกว้างของ iPhone รุ่นใหญ่ ซึ่งเป็นจอที่ผู้ใช้เห็นบั๊กนี้
      await _pumpStatGrid(tester, width: 440);

      final card = tester.getSize(find.byType(StatCard).first);

      expect(card.height, 132);
      expect(
        card.height,
        lessThan(200),
        reason: 'เคยได้ 291 เพราะเหลือคอลัมน์เดียวแล้วความสูงคิดเป็นสัดส่วน',
      );
    });

    testWidgets('เรียงสองใบต่อแถว', (tester) async {
      await _pumpStatGrid(tester, width: 440);

      final cards = find.byType(StatCard);
      final first = tester.getTopLeft(cards.at(0));
      final second = tester.getTopLeft(cards.at(1));
      final third = tester.getTopLeft(cards.at(2));

      expect(second.dy, first.dy, reason: 'ใบที่สองต้องอยู่แถวเดียวกับใบแรก');
      expect(second.dx, greaterThan(first.dx));
      expect(third.dy, greaterThan(first.dy), reason: 'ใบที่สามขึ้นแถวใหม่');
      expect(third.dx, first.dx);
    });

    testWidgets('เนื้อหาข้างในไม่ล้นออกนอกการ์ด', (tester) async {
      // ความสูงคงที่ที่เตี้ยเกินไปทำให้ Column ข้างในล้น ซึ่งขึ้นเป็นแถบเหลืองดำ
      await _pumpStatGrid(tester, width: 440);

      expect(tester.takeException(), isNull);
    });

    testWidgets('จอแคบสุดที่ยังต้องรองรับก็ยังสองคอลัมน์', (tester) async {
      // iPhone SE · แคบกว่านี้คือหน้าต่างเว็บที่ผู้ใช้ย่อเอง
      await _pumpStatGrid(tester, width: 320);

      final cards = find.byType(StatCard);

      expect(tester.getTopLeft(cards.at(1)).dy,
          tester.getTopLeft(cards.at(0)).dy);
      expect(tester.getSize(cards.first).height, 132);
      expect(tester.takeException(), isNull);
    });
  });
}
