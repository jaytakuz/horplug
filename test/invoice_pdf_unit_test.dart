import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_pdf.dart';

Invoice _invoice(InvoiceStatus status) => Invoice(
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
      total: 5240,
      status: status,
      dueDate: DateTime(2026, 9, 5),
      issuedAt: DateTime(2026, 9, 1),
      voidReason: status == InvoiceStatus.voided ? 'จดมิเตอร์ผิด' : null,
    );

void main() {
  // rootBundle ต้องพร้อมก่อน ไม่งั้นโหลดไฟล์ฟอนต์ไม่ได้
  TestWidgetsFlutterBinding.ensureInitialized();

  test('บิลค้างชำระสร้าง PDF ได้และไม่ว่าง', () async {
    final bytes = await buildInvoicePdf(
      invoice: _invoice(InvoiceStatus.unpaid),
      dormitoryName: 'หอพักสุขสบาย',
    );

    expect(bytes.lengthInBytes, greaterThan(0));
  });

  test('บิลชำระแล้วสร้าง PDF ได้', () async {
    final bytes = await buildInvoicePdf(
      invoice: _invoice(InvoiceStatus.paid),
      dormitoryName: 'หอพักสุขสบาย',
    );

    expect(bytes.lengthInBytes, greaterThan(0));
  });

  test('บิลที่ยกเลิกแล้วสร้าง PDF ได้', () async {
    final bytes = await buildInvoicePdf(
      invoice: _invoice(InvoiceStatus.voided),
      dormitoryName: 'หอพักสุขสบาย',
    );

    expect(bytes.lengthInBytes, greaterThan(0));
  });

  // ฟอนต์ที่ฝังไม่ครบทำให้ภาษาไทยกลายเป็นกล่องว่างทั้งใบโดยไม่มี error เลย
  // ทั้งตอน compile และตอนรัน เทสต์นี้จึงยืนยันว่าฟอนต์ถูกฝังจริง ไม่ใช่แค่
  // เอกสารสร้างผ่าน
  test('ฟอนต์ไทยถูกฝังลงในเอกสารจริง', () async {
    final bytes = await buildInvoicePdf(
      invoice: _invoice(InvoiceStatus.unpaid),
      dormitoryName: 'หอพักสุขสบาย',
    );

    expect(String.fromCharCodes(bytes), contains('Sarabun'));
  });
}
