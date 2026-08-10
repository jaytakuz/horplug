import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_lifecycle.dart';

void main() {
  group('canTransition — เส้นทางที่อนุญาต', () {
    test('อัปสลิป: unpaid → pending', () {
      expect(canTransition(InvoiceStatus.unpaid, InvoiceStatus.pending), isTrue);
    });

    test('อนุมัติ: pending → paid', () {
      expect(canTransition(InvoiceStatus.pending, InvoiceStatus.paid), isTrue);
    });

    test('ปฏิเสธสลิปพากลับไป unpaid ไม่ใช่สถานะที่ห้า', () {
      expect(canTransition(InvoiceStatus.pending, InvoiceStatus.unpaid), isTrue);
    });

    test('ยกเลิกได้จากทุกสถานะที่ยังไม่ถูกยกเลิก รวมทั้ง paid', () {
      expect(canTransition(InvoiceStatus.unpaid, InvoiceStatus.voided), isTrue);
      expect(canTransition(InvoiceStatus.pending, InvoiceStatus.voided), isTrue);
      expect(canTransition(InvoiceStatus.paid, InvoiceStatus.voided), isTrue);
    });
  });

  group('canTransition — เส้นทางที่ต้องปฏิเสธ', () {
    test('ถอยจาก paid กลับไป pending ไม่ได้', () {
      expect(canTransition(InvoiceStatus.paid, InvoiceStatus.pending), isFalse);
    });

    test('ข้ามขั้นจาก unpaid ไป paid ไม่ได้ ต้องผ่านการตรวจสลิป', () {
      expect(canTransition(InvoiceStatus.unpaid, InvoiceStatus.paid), isFalse);
    });

    test('voided เป็นสถานะสุดท้าย ออกไปไหนไม่ได้เลย', () {
      for (final to in InvoiceStatus.values) {
        expect(canTransition(InvoiceStatus.voided, to), isFalse,
            reason: 'voided → ${to.name} ต้องถูกปฏิเสธ');
      }
    });

    test('เปลี่ยนเป็นสถานะเดิมไม่นับเป็นการเปลี่ยน', () {
      for (final status in InvoiceStatus.values) {
        expect(canTransition(status, status), isFalse,
            reason: '${status.name} → ${status.name} ต้องถูกปฏิเสธ');
      }
    });
  });
}
