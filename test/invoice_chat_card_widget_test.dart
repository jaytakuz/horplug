import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/widgets/invoice_chat_card.dart';
import 'package:horplug/widgets/promptpay_qr.dart';

Invoice _invoice({
  InvoiceStatus status = InvoiceStatus.unpaid,
  double total = 5240,
}) =>
    Invoice(
      dbId: 1,
      invoiceNo: 'INV-202608-301',
      roomDbId: 7,
      roomNumber: '301',
      tenantName: 'สมชาย ใจดี',
      billingMonth: 8,
      billingYear: 2026,
      roomPrice: 3500,
      electricityUnits: 142,
      electricityCost: 1136,
      waterCost: 404,
      cleaningFee: 200,
      total: total,
      status: status,
      dueDate: DateTime(2026, 9, 5),
      issuedAt: DateTime(2026, 9, 1),
    );

Future<void> _pump(
  WidgetTester tester, {
  required Invoice invoice,
  String? promptPayId,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InvoiceChatCard(
          invoice: invoice,
          fallbackText: 'ออกบิลค่าเช่างวดสิงหาคม 2026 แล้ว',
          textColor: Colors.black,
          promptPayId: promptPayId,
        ),
      ),
    ),
  );
}

void main() {
  group('QR ในการ์ดบิล', () {
    testWidgets('บิลค้างชำระของผู้เช่า มี QR ให้สแกนจ่ายได้เลย', (tester) async {
      await _pump(
        tester,
        invoice: _invoice(),
        promptPayId: '0812345678',
      );

      expect(find.byType(PromptPayQr), findsOneWidget);
      expect(find.textContaining('สแกนเพื่อจ่าย'), findsOneWidget);
    });

    testWidgets('ฝั่งเจ้าของหอไม่ได้ส่งเลขพร้อมเพย์มา จึงไม่มี QR',
        (tester) async {
      await _pump(tester, invoice: _invoice());

      expect(find.byType(PromptPayQr), findsNothing);
    });

    testWidgets('หอที่ยังไม่ได้ตั้งเลขพร้อมเพย์ การ์ดยังแสดงได้ ไม่ล้ม',
        (tester) async {
      await _pump(tester, invoice: _invoice(), promptPayId: '   ');

      expect(find.byType(PromptPayQr), findsNothing);
      expect(find.textContaining('ยอดรวม'), findsOneWidget);
    });

    testWidgets('เลขพร้อมเพย์ผิดรูปแบบ ไม่วาดกล่อง QR เปล่า', (tester) async {
      // promptPayPayload คืน null เมื่อเลขไม่ใช่ 10 หรือ 13 หลัก · ถ้าการ์ดไม่
      // เช็ค null ผู้เช่าจะเห็นกรอบขาวว่างๆ ที่ดูเหมือน QR โหลดไม่ขึ้น
      await _pump(tester, invoice: _invoice(), promptPayId: '12345');

      expect(find.byType(PromptPayQr), findsNothing);
    });

    // บิลที่จ่ายไปแล้วยังโชว์ QR = เชิญให้จ่ายซ้ำ · บิลที่ยกเลิกแล้วยังโชว์ QR =
    // เชิญให้โอนเงินตามใบที่ไม่มีผลแล้ว ซึ่งไม่มีบิลใบไหนรองรับยอดที่โอนไป
    for (final status in [
      InvoiceStatus.pending,
      InvoiceStatus.paid,
      InvoiceStatus.voided,
    ]) {
      testWidgets('บิลสถานะ ${status.name} ไม่มี QR', (tester) async {
        await _pump(
          tester,
          invoice: _invoice(status: status),
          promptPayId: '0812345678',
        );

        expect(find.byType(PromptPayQr), findsNothing);
      });
    }

    testWidgets('ยอดศูนย์ไม่มี QR เพราะธนาคารไม่รับ QR ยอด ฿0', (tester) async {
      await _pump(
        tester,
        invoice: _invoice(total: 0),
        promptPayId: '0812345678',
      );

      expect(find.byType(PromptPayQr), findsNothing);
    });
  });

  testWidgets('resolve บิลไม่ได้ ตกกลับไปเป็นข้อความเดิม ไม่ทำให้แชทพัง',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InvoiceChatCard(
            invoice: null,
            fallbackText: 'ออกบิลค่าเช่างวดสิงหาคม 2026 แล้ว',
            textColor: Colors.black,
            promptPayId: '0812345678',
          ),
        ),
      ),
    );

    expect(find.text('ออกบิลค่าเช่างวดสิงหาคม 2026 แล้ว'), findsOneWidget);
    expect(find.byType(PromptPayQr), findsNothing);
  });
}
