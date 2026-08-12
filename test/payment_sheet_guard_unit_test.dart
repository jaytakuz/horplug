import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/models/picked_image.dart';
import 'package:horplug/viewmodels/action_result.dart';
import 'package:horplug/widgets/payment_sheet.dart';

Invoice _bill(InvoiceStatus status) => Invoice(
      dbId: 1,
      invoiceNo: 'INV-202608-301',
      roomDbId: 7,
      roomNumber: '301',
      tenantName: 'สมชาย ใจดี',
      billingMonth: 8,
      billingYear: 2026,
      roomPrice: 3500,
      electricityCost: 1136,
      waterCost: 404,
      cleaningFee: 200,
      total: 5240,
      status: status,
      dueDate: DateTime(2026, 9, 5),
      issuedAt: DateTime(2026, 9, 1),
    );

void main() {
  // กฎ "เปิดได้เฉพาะบิลค้างชำระ" เคยกระจายอยู่ที่ผู้เรียกทั้งสามที่ (การ์ดบิล
  // แสดงปุ่มเฉพาะ unpaid · การ์ดในแชทเช็คก่อนเปิด · แดชบอร์ดเหมือนกัน) ผู้เรียก
  // รายที่สี่ที่ลืมเช็คจะพาผู้เช่าไปแนบสลิปทับบิลที่จ่ายไปแล้ว หรือเห็นคิวอาร์
  // ที่สแกนจ่ายซ้ำได้ · ตอนนี้กฎอยู่ในตัวแผ่นเองแล้ว
  group('canOpenPaymentSheet', () {
    test('บิลค้างชำระเปิดได้', () {
      expect(canOpenPaymentSheet(_bill(InvoiceStatus.unpaid)), isTrue);
    });

    test('บิลที่ส่งสลิปแล้วรอตรวจ เปิดไม่ได้ — จ่ายไปแล้วรอผล', () {
      expect(canOpenPaymentSheet(_bill(InvoiceStatus.pending)), isFalse);
    });

    test('บิลที่ชำระแล้วเปิดไม่ได้ — กันจ่ายซ้ำ', () {
      expect(canOpenPaymentSheet(_bill(InvoiceStatus.paid)), isFalse);
    });

    test('บิลที่ยกเลิกแล้วเปิดไม่ได้ — ไม่มีอะไรให้จ่าย', () {
      expect(canOpenPaymentSheet(_bill(InvoiceStatus.voided)), isFalse);
    });
  });

  group('showPaymentSheet บังคับกฎเดียวกันนี้จริง', () {
    Future<bool> tapToOpen(WidgetTester tester, Invoice bill) async {
      var opened = true;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              opened = await showPaymentSheet(
                context,
                bill: bill,
                channel: const PaymentChannel(
                  promptPayId: '0812345678',
                  accountName: 'สมหญิง เจ้าของหอ',
                ),
                onSubmit: (PickedImage slip) async =>
                    const ActionResult(success: true, message: 'ส่งแล้ว'),
                onSubmitCash: () async =>
                    const ActionResult(success: true, message: 'แจ้งแล้ว'),
              );
            },
            child: const Text('เปิด'),
          ),
        ),
      ));

      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('บิลค้างชำระเปิดแผ่นได้', (tester) async {
      await tapToOpen(tester, _bill(InvoiceStatus.unpaid));
      expect(find.text('แนบสลิปโอนเงิน'), findsOneWidget);
    });

    for (final status in [
      InvoiceStatus.pending,
      InvoiceStatus.paid,
      InvoiceStatus.voided,
    ]) {
      testWidgets('บิลสถานะ ${status.name} ไม่เปิดแผ่นและคืน false',
          (tester) async {
        final opened = await tapToOpen(tester, _bill(status));

        expect(opened, isFalse);
        expect(find.text('แนบสลิปโอนเงิน'), findsNothing);
      });
    }
  });
}
