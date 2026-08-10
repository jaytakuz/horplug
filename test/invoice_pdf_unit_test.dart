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

  group('คิวอาร์พร้อมเพย์ในเอกสาร', () {
    const channel = PaymentChannel(
      promptPayId: '0812345678',
      bankName: 'ธนาคารกสิกรไทย',
      accountNo: '1438323216',
      accountName: 'สมหญิง เจ้าของหอ',
    );

    test('บิลค้างชำระมีคิวอาร์ที่ฝังยอดของบิลไว้', () {
      final payload = invoiceQrPayload(
        invoice: _invoice(InvoiceStatus.unpaid),
        channel: channel,
      );

      expect(payload, isNotNull);
      expect(payload, contains('5240.00'));
    });

    // เอกสารที่แชร์ออกไปแล้วเรียกคืนไม่ได้ ถ้าบิลที่จ่ายหรือยกเลิกไปแล้วยังมี
    // คิวอาร์ที่สแกนจ่ายได้ ไฟล์ที่ผู้เช่าเก็บไว้จะกลายเป็นช่องทางจ่ายซ้ำ
    // ลายน้ำไม่ช่วย เพราะคนที่ยกมือถือขึ้นมาสแกนมองที่คิวอาร์ ไม่ได้อ่านลายน้ำ
    test('บิลที่ชำระแล้วต้องไม่มีคิวอาร์', () {
      expect(
        invoiceQrPayload(
            invoice: _invoice(InvoiceStatus.paid), channel: channel),
        isNull,
      );
    });

    test('บิลที่ยกเลิกแล้วต้องไม่มีคิวอาร์', () {
      expect(
        invoiceQrPayload(
            invoice: _invoice(InvoiceStatus.voided), channel: channel),
        isNull,
      );
    });

    test('บิลที่รอตรวจสลิปต้องไม่มีคิวอาร์ — จ่ายไปแล้วรอเจ้าของหอตรวจ', () {
      expect(
        invoiceQrPayload(
            invoice: _invoice(InvoiceStatus.pending), channel: channel),
        isNull,
      );
    });

    test('ไม่มี channel ก็ไม่มีคิวอาร์', () {
      expect(
        invoiceQrPayload(invoice: _invoice(InvoiceStatus.unpaid)),
        isNull,
      );
    });

    test('หอที่ตั้งแต่เลขบัญชี ไม่มีพร้อมเพย์ ก็ไม่มีคิวอาร์', () {
      expect(
        invoiceQrPayload(
          invoice: _invoice(InvoiceStatus.unpaid),
          channel: const PaymentChannel(
            bankName: 'ธนาคารกสิกรไทย',
            accountNo: '1438323216',
            accountName: 'สมหญิง เจ้าของหอ',
          ),
        ),
        isNull,
      );
    });

    test('เอกสารของบิลค้างชำระที่มีคิวอาร์ใหญ่กว่าใบที่ไม่มี', () async {
      final withQr = await buildInvoicePdf(
        invoice: _invoice(InvoiceStatus.unpaid),
        dormitoryName: 'หอพักสุขสบาย',
        channel: channel,
      );
      // ใบเดียวกัน ข้อความชุดเดียวกัน ต่างแค่พร้อมเพย์ที่ตั้งไว้หรือไม่
      final without = await buildInvoicePdf(
        invoice: _invoice(InvoiceStatus.unpaid),
        dormitoryName: 'หอพักสุขสบาย',
        channel: const PaymentChannel(
          bankName: 'ธนาคารกสิกรไทย',
          accountNo: '1438323216',
          accountName: 'สมหญิง เจ้าของหอ',
        ),
      );

      expect(withQr.lengthInBytes, greaterThan(without.lengthInBytes),
          reason: 'คิวอาร์ต้องถูกวาดลงเอกสารจริง ไม่ใช่แค่คำนวณ payload');
    });

    test('หอที่ไม่ได้ตั้งพร้อมเพย์ สร้างเอกสารได้ตามปกติ', () async {
      final bytes = await buildInvoicePdf(
        invoice: _invoice(InvoiceStatus.unpaid),
        dormitoryName: 'หอพักสุขสบาย',
        channel: const PaymentChannel(
          bankName: 'ธนาคารกสิกรไทย',
          accountNo: '1438323216',
          accountName: 'สมหญิง เจ้าของหอ',
        ),
      );

      expect(bytes.lengthInBytes, greaterThan(0));
    });
  });
}
