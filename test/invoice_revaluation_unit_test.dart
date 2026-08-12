import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_calculator.dart';

// ---------------------------------------------------------------------------
// Builders — บิลที่ออกไปแล้วหนึ่งใบ กับห้องที่มันอ้างถึง
// ---------------------------------------------------------------------------

Invoice buildIssuedInvoice({
  InvoiceStatus status = InvoiceStatus.unpaid,
  double roomPrice = 3000,
  double electricityUnits = 50,
  double electricityCost = 300,
  double waterCost = 0,
  double cleaningFee = 0,
}) {
  return Invoice(
    dbId: 1,
    invoiceNo: 'INV-202608-101',
    roomDbId: 1,
    roomNumber: '101',
    tenantName: 'สมชาย ใจดี',
    billingMonth: 8,
    billingYear: 2026,
    roomPrice: roomPrice,
    electricityUnits: electricityUnits,
    electricityCost: electricityCost,
    waterCost: waterCost,
    cleaningFee: cleaningFee,
    // ฐานข้อมูลคำนวณ total เองด้วย GENERATED column — ที่นี่จำลองผลของมัน
    total: roomPrice + electricityCost + waterCost + cleaningFee,
    status: status,
    dueDate: DateTime(2026, 9, 5),
    issuedAt: DateTime(2026, 8, 31),
  );
}

Room buildRoom({double price = 3000}) {
  return Room(
    dbId: 1,
    id: '101',
    floor: '1',
    status: RoomStatus.occupied,
    currentTenantId: 'tenant-1',
    price: price,
  );
}

void main() {
  group('revalueInvoice', () {
    test('บิลที่จ่ายแล้วไม่ถูกแตะ', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(status: InvoiceStatus.paid),
        room: buildRoom(),
        electricity: const MeterCharge(units: 200, amount: 1000),
        waterAmount: 200,
        cleaningFee: 0,
      );

      expect(result, isNull);
    });

    test('บิลที่รอตรวจสลิปไม่ถูกแตะ', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(status: InvoiceStatus.pending),
        room: buildRoom(),
        electricity: const MeterCharge(units: 200, amount: 1000),
        waterAmount: 200,
        cleaningFee: 0,
      );

      expect(result, isNull,
          reason: 'ผู้เช่าจ่ายตามยอดที่เห็นไปแล้ว สลิปกับบิลต้องตรงกัน');
    });

    test('บิลที่ยกเลิกแล้วไม่ถูกแตะ', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(status: InvoiceStatus.voided),
        room: buildRoom(),
        electricity: const MeterCharge(units: 200, amount: 1000),
        waterAmount: 200,
        cleaningFee: 0,
      );

      expect(result, isNull);
    });

    test('งวดที่ไม่มีเลขมิเตอร์ไฟไม่ถูกแตะ แม้ค่าน้ำจะเปลี่ยน', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(waterCost: 100),
        room: buildRoom(),
        electricity: null,
        waterAmount: 250,
        cleaningFee: 0,
      );

      expect(result, isNull,
          reason: 'เลขมิเตอร์ที่หายไปคือข้อมูลถูกลบ ไม่ใช่ผู้เช่าใช้ไฟน้อยลง');
    });

    test('ค่าไฟที่แก้แล้วสะท้อนทั้งหน่วยและจำนวนเงิน', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(),
        room: buildRoom(),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: null,
        cleaningFee: 0,
      );

      expect(result, isNotNull);
      expect(result!.electricityUnits, 90);
      expect(result.electricityCost, 540);
      expect(result.previousTotal, 3300);
      expect(result.newTotal, 3540);
    });

    test('ไม่มีแถวค่าน้ำ = คงค่าเดิมในบิล', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(waterCost: 150),
        room: buildRoom(),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: null,
        cleaningFee: 0,
      );

      expect(result!.waterCost, 150,
          reason: '"ยังไม่กรอก" ไม่ใช่ "กรอกว่าไม่เก็บ"');
    });

    test('ค่าน้ำเป็น 0 ที่กรอกมาจริง = ใช้ 0', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(electricityCost: 540, waterCost: 150),
        room: buildRoom(),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: 0,
        cleaningFee: 0,
      );

      expect(result!.waterCost, 0);
    });

    test('ค่าห้องขยับตามราคาห้องปัจจุบัน', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(electricityCost: 540, electricityUnits: 90),
        room: buildRoom(price: 3300),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: null,
        cleaningFee: 0,
      );

      expect(result!.roomPrice, 3300);
      expect(result.newTotal, 3840);
    });

    test('ค่าทำความสะอาดที่ถูกยกเลิกหายจากบิล', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(
            electricityCost: 540, electricityUnits: 90, cleaningFee: 200),
        room: buildRoom(),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: null,
        cleaningFee: 0,
      );

      expect(result!.cleaningFee, 0);
      expect(result.newTotal, 3540);
    });

    test('ทุกค่าเท่าเดิม = ไม่ต้องแก้', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(
          electricityUnits: 90,
          electricityCost: 540,
          waterCost: 150,
          cleaningFee: 200,
        ),
        room: buildRoom(),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: 150,
        cleaningFee: 200,
      );

      expect(result, isNull,
          reason: 'กันข้อความสแปมในแชททุกครั้งที่เจ้าของหอกดบันทึก');
    });

    test('ต่างกันแค่เศษสตางค์จากการปัดเลข = ไม่ต้องแก้', () {
      final result = revalueInvoice(
        invoice: buildIssuedInvoice(electricityCost: 540),
        room: buildRoom(),
        electricity: const MeterCharge(units: 50, amount: 540.001),
        waterAmount: null,
        cleaningFee: 0,
      );

      expect(result, isNull);
    });

    test('เลขที่บิลกับ revision ของใบเดิมติดไปกับผลลัพธ์', () {
      final invoice = buildIssuedInvoice();

      final result = revalueInvoice(
        invoice: invoice,
        room: buildRoom(),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: null,
        cleaningFee: 0,
      );

      expect(result!.invoice.invoiceNo, invoice.invoiceNo,
          reason: 'นี่คือใบเดิมที่ยอดถูกแก้ ไม่ใช่ใบแทนที่กินเลขใหม่');
      expect(result.invoice.revision, invoice.revision);
    });
  });
}
