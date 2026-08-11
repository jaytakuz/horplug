import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_lifecycle.dart';

void main() {
  group('canTransition — เส้นทางที่อนุญาต', () {
    test('อัปสลิป: unpaid → pending', () {
      expect(
          canTransition(InvoiceStatus.unpaid, InvoiceStatus.pending), isTrue);
    });

    test('อนุมัติ: pending → paid', () {
      expect(canTransition(InvoiceStatus.pending, InvoiceStatus.paid), isTrue);
    });

    test('ปฏิเสธสลิปพากลับไป unpaid ไม่ใช่สถานะที่ห้า', () {
      expect(
          canTransition(InvoiceStatus.pending, InvoiceStatus.unpaid), isTrue);
    });

    // เงินที่จ่ายกันนอกแอปเกิดขึ้นจริงและบ่อย ถ้าบังคับให้ผ่าน pending เสมอ
    // เจ้าของหอที่เก็บเงินครบแล้วจะไม่มีทางทำให้บิลตรงกับความจริงได้เลย
    test('เจ้าของหอบันทึกเองได้: unpaid → paid โดยไม่ต้องผ่าน pending', () {
      expect(canTransition(InvoiceStatus.unpaid, InvoiceStatus.paid), isTrue);
    });

    test('ยกเลิกได้จากทุกสถานะที่ยังไม่ถูกยกเลิก รวมทั้ง paid', () {
      expect(canTransition(InvoiceStatus.unpaid, InvoiceStatus.voided), isTrue);
      expect(
          canTransition(InvoiceStatus.pending, InvoiceStatus.voided), isTrue);
      expect(canTransition(InvoiceStatus.paid, InvoiceStatus.voided), isTrue);
    });
  });

  group('canTransition — เส้นทางที่ต้องปฏิเสธ', () {
    test('ถอยจาก paid กลับไป pending ไม่ได้', () {
      expect(canTransition(InvoiceStatus.paid, InvoiceStatus.pending), isFalse);
    });

    // ทางกลับกันของการบันทึกเองยังปิดอยู่ — บิลที่ชำระแล้วจะย้อนกลับไปรอตรวจ
    // ไม่ได้ ต่อให้กดผิด ทางแก้เดียวคือยกเลิกใบนั้นแล้วออกใหม่ ซึ่งทิ้งร่องรอย
    test('ถอยจาก paid กลับไป unpaid ไม่ได้', () {
      expect(canTransition(InvoiceStatus.paid, InvoiceStatus.unpaid), isFalse);
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
