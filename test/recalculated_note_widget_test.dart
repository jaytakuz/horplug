import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/theme/app_theme.dart';
import 'package:horplug/widgets/reusable_widgets.dart';
import 'package:horplug/widgets/tenant_bill_card.dart';

Invoice buildBill({DateTime? recalculatedAt, double? previousTotal}) {
  return Invoice(
    dbId: 1,
    invoiceNo: 'INV-202608-101',
    roomDbId: 1,
    roomNumber: '101',
    tenantName: 'สมชาย ใจดี',
    billingMonth: 8,
    billingYear: 2026,
    roomPrice: 3000,
    electricityUnits: 90,
    electricityCost: 540,
    total: 3540,
    status: InvoiceStatus.unpaid,
    dueDate: DateTime(2026, 9, 5),
    issuedAt: DateTime(2026, 8, 31),
    recalculatedAt: recalculatedAt,
    previousTotal: previousTotal,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
}

void main() {
  group('RecalculatedNote', () {
    testWidgets('บอกยอดเดิมเมื่อรู้ว่าเปลี่ยนจากเท่าไร', (tester) async {
      await _pump(tester, const RecalculatedNote(previousTotal: 3200));

      expect(find.text('ปรับยอดแล้ว · ยอดเดิม ฿3,200'), findsOneWidget);
    });

    // ฐานข้อมูลที่ยังไม่ได้รัน invoices_recalculation.sql ไม่มี previous_total
    // ยังต้องบอกได้ว่าปรับแล้ว ไม่ใช่โชว์ "ยอดเดิม null"
    testWidgets('ยังบอกได้ว่าปรับแล้วแม้ไม่รู้ยอดเดิม', (tester) async {
      await _pump(tester, const RecalculatedNote());

      expect(find.text('ปรับยอดแล้ว'), findsOneWidget);
    });
  });

  group('การ์ดบิลฝั่งผู้เช่า', () {
    testWidgets('บิลที่ยังไม่เคยถูกปรับ ไม่มีป้ายอะไรเพิ่ม', (tester) async {
      await _pump(tester, TenantBillCard(bill: buildBill()));

      expect(find.byType(RecalculatedNote), findsNothing);
    });

    testWidgets('บิลที่ถูกปรับยอด ขึ้นป้ายพร้อมยอดเดิม', (tester) async {
      await _pump(
        tester,
        TenantBillCard(
          bill: buildBill(
            recalculatedAt: DateTime(2026, 9, 1),
            previousTotal: 3200,
          ),
        ),
      );

      expect(find.byType(RecalculatedNote), findsOneWidget);
      expect(find.text('ปรับยอดแล้ว · ยอดเดิม ฿3,200'), findsOneWidget);
      expect(find.text('฿3,540'), findsOneWidget,
          reason: 'ยอดใหม่ยังต้องเป็นตัวเลขหลักที่ผู้เช่าเห็น');
    });
  });
}
