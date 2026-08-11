import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_lifecycle.dart';

Invoice _bill({
  required InvoiceStatus status,
  PaymentMethod? method,
  String? slipUrl,
}) =>
    Invoice(
      dbId: 1,
      invoiceNo: 'INV-202608-301',
      roomDbId: 7,
      roomNumber: '301',
      tenantName: 'สมชาย ใจดี',
      billingMonth: 8,
      billingYear: 2026,
      total: 5240,
      status: status,
      dueDate: DateTime(2026, 9, 5),
      issuedAt: DateTime(2026, 9, 1),
      slipUrl: slipUrl,
      paymentMethod: method,
    );

void main() {
  // pending มีสองหน้าตาที่เจ้าของหอต้องทำคนละอย่าง — ตรวจสลิป กับ ยืนยันรับ
  // เงินสด · ถ้าแยกไม่ออก ผู้เช่าที่จ่ายสดจะถูกพาไปหน้าจอตรวจสลิปที่ว่างเปล่า
  group('แยกบิลที่รอตรวจสลิป ออกจากบิลที่รอยืนยันเงินสด', () {
    test('จ่ายสดแล้วรอยืนยัน', () {
      final bill = _bill(
        status: InvoiceStatus.pending,
        method: PaymentMethod.cash,
      );

      expect(bill.awaitsCashConfirmation, isTrue);
      expect(bill.awaitsSlipReview, isFalse);
    });

    test('อัปสลิปแล้วรอตรวจ', () {
      final bill = _bill(
        status: InvoiceStatus.pending,
        method: PaymentMethod.transfer,
        slipUrl: 'slips/7/INV-202608-301.jpg',
      );

      expect(bill.awaitsSlipReview, isTrue);
      expect(bill.awaitsCashConfirmation, isFalse);
    });

    // บิลที่ออกก่อนมีคอลัมน์ payment_method จะอ่านค่ามาเป็น null ทั้งหมด
    // ต้องตีความเป็นการโอนตามพฤติกรรมเดิม ไม่ใช่ตกไปอยู่ในสถานะที่ไม่มีปุ่มอะไรเลย
    test('บิลเก่าที่ไม่มี payment_method นับเป็นรอตรวจสลิป', () {
      final bill = _bill(status: InvoiceStatus.pending);

      expect(bill.awaitsSlipReview, isTrue);
      expect(bill.awaitsCashConfirmation, isFalse);
    });

    test('สถานะอื่นไม่เข้าเงื่อนไขไหนเลย', () {
      for (final status in [
        InvoiceStatus.unpaid,
        InvoiceStatus.paid,
        InvoiceStatus.voided,
      ]) {
        final bill = _bill(status: status, method: PaymentMethod.cash);

        expect(bill.awaitsCashConfirmation, isFalse,
            reason: 'สถานะ ${status.name} ไม่ควรรอยืนยัน');
        expect(bill.awaitsSlipReview, isFalse);
      }
    });
  });

  // เงินสดจงใจไม่เพิ่มสถานะที่ห้า — เดินทางเดียวกับการอัปสลิปทุกประการ
  // canTransition จึงไม่ต้องรู้เรื่องวิธีจ่ายเลย
  group('เงินสดใช้เส้นทางสถานะเดียวกับการอัปสลิป', () {
    test('แจ้งชำระ: unpaid → pending', () {
      expect(
        canTransition(InvoiceStatus.unpaid, InvoiceStatus.pending),
        isTrue,
      );
    });

    test('เจ้าของหอยืนยัน: pending → paid', () {
      expect(canTransition(InvoiceStatus.pending, InvoiceStatus.paid), isTrue);
    });

    test('ยกเลิกการแจ้ง/ปฏิเสธ: pending → unpaid', () {
      expect(
        canTransition(InvoiceStatus.pending, InvoiceStatus.unpaid),
        isTrue,
      );
    });

    test('ยืนยันแล้วย้อนกลับไม่ได้ ต้องยกเลิกบิลแล้วออกใหม่แทน', () {
      expect(
        canTransition(InvoiceStatus.paid, InvoiceStatus.pending),
        isFalse,
      );
    });
  });

  group('PaymentMethod', () {
    // ชื่อต้องตรงกับ CHECK constraint invoices_payment_method_check
    // ('transfer', 'cash') เพราะ service เขียนค่าด้วย .name ตรงๆ
    test('ชื่อตรงกับค่าที่ฐานข้อมูลยอมรับ', () {
      expect(PaymentMethod.transfer.name, 'transfer');
      expect(PaymentMethod.cash.name, 'cash');
      expect(PaymentMethod.values, hasLength(2));
    });
  });
}
