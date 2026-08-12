import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/widgets/refreshable.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

/// ลากลงจากกลางจอให้ไกลพอจะข้ามระยะที่ RefreshIndicator ถือว่าเป็นการรีเฟรช
Future<void> _dragDown(WidgetTester tester) async {
  await tester.fling(find.byType(Scrollable), const Offset(0, 300), 1000);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ลากรายการยาวแล้วเรียก onRefresh', (tester) async {
    var refreshed = 0;

    await _pump(
      tester,
      PullToRefresh(
        onRefresh: () async => refreshed++,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: 30,
          itemBuilder: (_, index) => ListTile(title: Text('แถวที่ $index')),
        ),
      ),
    );

    await _dragDown(tester);

    expect(refreshed, 1);
  });

  // สถานะว่างกับสถานะผิดพลาดเคยเป็น Center เฉยๆ ซึ่งไม่มี scrollable ให้
  // RefreshIndicator เกาะ — ท่าทางประจำของแอปจึงใช้ไม่ได้ในหน้าที่ต้องการมันที่สุด
  testWidgets('ลากสถานะว่างที่เนื้อหาสั้นกว่าจอก็ยังเรียก onRefresh',
      (tester) async {
    var refreshed = 0;

    await _pump(
      tester,
      PullToRefresh(
        onRefresh: () async => refreshed++,
        child: const CenteredScrollable(child: Text('ยังไม่มีบิล')),
      ),
    );

    await _dragDown(tester);

    expect(refreshed, 1);
  });

  testWidgets('เนื้อหาเดิมยังอยู่ครบระหว่างรีเฟรช', (tester) async {
    await _pump(
      tester,
      PullToRefresh(
        onRefresh: () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [ListTile(title: Text('บิลเดือนสิงหาคม'))],
        ),
      ),
    );

    await tester.fling(find.byType(Scrollable), const Offset(0, 300), 1000);
    await tester.pump();

    expect(find.text('บิลเดือนสิงหาคม'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
