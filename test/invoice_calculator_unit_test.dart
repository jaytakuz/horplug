import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_calculator.dart';

Room _room({
  int dbId = 1,
  String number = '301',
  String? tenantId = 'tenant-uuid',
  double price = 3500,
}) {
  return Room(
    dbId: dbId,
    id: number,
    floor: '3',
    status: RoomStatus.occupied,
    currentTenantId: tenantId,
    tenantName: 'สมชาย ใจดี',
    price: price,
  );
}

void main() {
  group('buildDraft — เหตุผลที่ข้ามห้อง', () {
    test('ห้องไม่มีผู้เช่า ถูกข้ามด้วย noTenant', () {
      final draft = buildDraft(
        room: _room(tenantId: null),
        billingMonth: 8,
        billingYear: 2026,
        electricity: const MeterCharge(units: 142, amount: 1136),
        waterAmount: 404,
      );

      expect(draft.skipReason, SkipReason.noTenant);
      expect(draft.canIssue, isFalse);
    });

    test('ไม่มีมิเตอร์และไม่มีค่าทำความสะอาด ถูกข้ามด้วย noMeterReading', () {
      final draft = buildDraft(
        room: _room(),
        billingMonth: 8,
        billingYear: 2026,
      );

      expect(draft.skipReason, SkipReason.noMeterReading);
    });

    test('มีแต่ค่าทำความสะอาด ออกบิลได้ ไม่ถือว่าไม่มีมิเตอร์', () {
      final draft = buildDraft(
        room: _room(),
        billingMonth: 8,
        billingYear: 2026,
        cleaningFee: 200,
      );

      expect(draft.canIssue, isTrue);
      expect(draft.total, 3700);
    });

    test('ออกบิลงวดนี้ไปแล้ว ถูกข้ามด้วย alreadyIssued', () {
      final draft = buildDraft(
        room: _room(),
        billingMonth: 8,
        billingYear: 2026,
        electricity: const MeterCharge(units: 142, amount: 1136),
        alreadyIssued: true,
      );

      expect(draft.skipReason, SkipReason.alreadyIssued);
    });

    test('ออกบิลไปแล้ว แม้ไม่มีข้อมูลคิดเงินเลย ก็ยังรายงาน alreadyIssued ไม่ใช่ noMeterReading', () {
      // ก่อนหน้านี้ทุกเทสต์ของ alreadyIssued แนบ electricity มาด้วย จึงไม่เคย
      // พิสูจน์ว่า alreadyIssued ถูกตัดสินก่อน noMeterReading จริง — ถ้าลำดับ
      // สลับกัน เทสต์เดิมก็ยังผ่านอยู่ดี เทสต์นี้ตัดข้อมูลคิดเงินออกทั้งหมด
      // เพื่อบังคับให้มีทางเดียวที่ผ่านได้
      final draft = buildDraft(
        room: _room(),
        billingMonth: 8,
        billingYear: 2026,
        alreadyIssued: true,
      );

      expect(draft.skipReason, SkipReason.alreadyIssued);
    });

    test('ห้องว่างที่ออกบิลไปแล้ว รายงาน noTenant ก่อน', () {
      final draft = buildDraft(
        room: _room(tenantId: null),
        billingMonth: 8,
        billingYear: 2026,
        alreadyIssued: true,
      );

      expect(draft.skipReason, SkipReason.noTenant);
    });
  });

  group('buildDraft — ตัวเลข', () {
    test('รวมค่าห้อง ค่าไฟ ค่าน้ำ ค่าทำความสะอาด', () {
      final draft = buildDraft(
        room: _room(price: 3500),
        billingMonth: 8,
        billingYear: 2026,
        electricity: const MeterCharge(units: 142, amount: 1136),
        waterAmount: 404,
        cleaningFee: 200,
      );

      expect(draft.roomPrice, 3500);
      expect(draft.electricityUnits, 142);
      expect(draft.electricityCost, 1136);
      expect(draft.waterCost, 404);
      expect(draft.cleaningFee, 200);
      expect(draft.total, 5240);
    });

    test('ไม่มีค่าน้ำในงวดนั้น คิดเป็นศูนย์ ไม่ใช่ทำให้ทั้งบิลตก', () {
      final draft = buildDraft(
        room: _room(),
        billingMonth: 8,
        billingYear: 2026,
        electricity: const MeterCharge(units: 142, amount: 1136),
      );

      expect(draft.canIssue, isTrue);
      expect(draft.waterCost, 0);
    });
  });

  group('dueDateFor', () {
    test('ครบกำหนดวันที่ 5 ของเดือนถัดไป', () {
      expect(dueDateFor(2026, 8), DateTime(2026, 9, 5));
    });

    test('งวดธันวาคมครบกำหนด 5 มกราคมปีถัดไป', () {
      expect(dueDateFor(2026, 12), DateTime(2027, 1, 5));
    });
  });

  group('invoiceNoFor', () {
    test('เติมศูนย์หน้าเดือนหลักเดียว', () {
      expect(
        invoiceNoFor(year: 2026, month: 8, roomNumber: '301'),
        'INV-202608-301',
      );
    });

    test('เดือนสองหลักไม่ถูกเติมศูนย์ซ้ำ', () {
      expect(
        invoiceNoFor(year: 2026, month: 12, roomNumber: '301'),
        'INV-202612-301',
      );
    });

    test('ใบที่ออกใหม่ต่อท้ายด้วย -R ตามรอบแก้ไข', () {
      expect(
        invoiceNoFor(year: 2026, month: 8, roomNumber: '301', revision: 2),
        'INV-202608-301-R2',
      );
    });

    test('รอบแก้ไขที่ 1 ไม่มีคำต่อท้าย', () {
      expect(
        invoiceNoFor(year: 2026, month: 8, roomNumber: '301', revision: 1),
        'INV-202608-301',
      );
    });
  });

  group('skipReasonLabel', () {
    test('ทุกเหตุผลมีข้อความภาษาไทยที่ไม่ว่าง', () {
      for (final reason in SkipReason.values) {
        expect(skipReasonLabel(reason).trim(), isNotEmpty);
      }
    });
  });

  // ตรรกะนี้อยู่ใน models.dart มาตลอดแต่ไม่เคยถูกทดสอบผ่านเส้นทางบิลเลย
  // ทั้งที่มิเตอร์วนรอบทำให้ผู้เช่าถูกเรียกเก็บเกินได้เป็นหลักหมื่นหน่วย
  group('ElectricityRecord.unitsUsed — มิเตอร์สี่หลักวนรอบ', () {
    ElectricityRecord record({required double previous, required double current}) {
      return ElectricityRecord(
        roomDbId: 1,
        roomNumber: '301',
        billingMonth: 8,
        billingYear: 2026,
        previousReading: previous,
        currentReading: current,
        unitRate: 8,
      );
    }

    test('เดือนปกติ หักลบตรงๆ', () {
      expect(record(previous: 1200, current: 1342).unitsUsed, 142);
    });

    test('วนจาก 9950 ไป 0092 ได้ 142 หน่วย ไม่ใช่ติดลบ', () {
      final wrapped = record(previous: 9950, current: 92);

      expect(wrapped.isOverflow, isTrue);
      expect(wrapped.unitsUsed, 142);
      expect(wrapped.amount, 1136);
    });

    test('ยังไม่จดเลขปัจจุบัน คิดเป็นศูนย์หน่วย', () {
      final record = ElectricityRecord(
        roomDbId: 1,
        roomNumber: '301',
        billingMonth: 8,
        billingYear: 2026,
        previousReading: 1200,
        unitRate: 8,
      );

      expect(record.unitsUsed, 0);
      expect(record.amount, 0);
    });
  });
}
