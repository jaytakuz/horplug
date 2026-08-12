import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/supabase_service.dart';
import 'package:horplug/viewmodels/meter_view_model.dart';

// ---------------------------------------------------------------------------
// Pure helper functions (extracted from MeterScreen logic)
// ---------------------------------------------------------------------------

String? validateElecReading(double? reading) {
  if (reading == null) return null;
  if (reading > 9999) return 'ค่าต้องอยู่ในช่วง 0-9999';
  return null;
}

bool matchesFilters({
  required String roomNumber,
  required String? tenantName,
  required String? floor,
  required RoomStatus? roomStatus,
  required String query,
  required String selectedFloor,
  required String selectedRoomStatus,
}) {
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty) {
    final matchRoom = roomNumber.toLowerCase().contains(q);
    final matchName = (tenantName ?? '').toLowerCase().contains(q);
    if (!matchRoom && !matchName) { return false; }
  }
  if (selectedFloor != 'ทั้งหมด' && (floor ?? '') != selectedFloor) { return false; }
  if (selectedRoomStatus != 'ทั้งหมด' &&
      roomStatusLabel(roomStatus) != selectedRoomStatus) { return false; }
  return true;
}

String roomStatusLabel(RoomStatus? status) {
  switch (status) {
    case RoomStatus.occupied:
      return 'มีคนอยู่';
    case RoomStatus.vacant:
      return 'ว่าง';
    case RoomStatus.maintenance:
      return 'ซ่อมบำรุง';
    default:
      return '-';
  }
}

int electricityProgress(List<ElectricityRecord> records) {
  return records.where((r) => r.currentReading != null).length;
}

List<WaterRecord> waterRecordsToSave(
  List<WaterRecord> records,
  Set<int> modifiedRoomIds,
) {
  return records
      .where((r) => r.id == null || modifiedRoomIds.contains(r.roomDbId))
      .toList();
}

int waterProgress(List<WaterRecord> records) {
  return records.where((r) => r.id != null).length;
}

// ---------------------------------------------------------------------------
// Fake repository — no real Supabase calls
// ---------------------------------------------------------------------------

class FakeMeterRepository {
  FakeMeterRepository({
    List<ElectricityRecord>? electricityRecords,
    List<WaterRecord>? waterRecords,
    this.shouldThrowOnFetchElec = false,
    this.shouldThrowOnSaveElec = false,
    this.shouldThrowOnFetchWater = false,
    this.shouldThrowOnSaveWater = false,
  })  : _electricityRecords = List.from(electricityRecords ?? []),
        _waterRecords = List.from(waterRecords ?? []);

  final List<ElectricityRecord> _electricityRecords;
  final List<WaterRecord> _waterRecords;
  final bool shouldThrowOnFetchElec;
  final bool shouldThrowOnSaveElec;
  final bool shouldThrowOnFetchWater;
  final bool shouldThrowOnSaveWater;

  Future<List<ElectricityRecord>> fetchElectricityRecords({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    if (shouldThrowOnFetchElec) throw const SocketException('Failed host lookup');
    return List.from(_electricityRecords);
  }

  Future<void> saveElectricityRecords(List<ElectricityRecord> records) async {
    if (shouldThrowOnSaveElec) throw const SocketException('Failed host lookup');
  }

  Future<List<WaterRecord>> fetchWaterRecords({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    if (shouldThrowOnFetchWater) throw const SocketException('Failed host lookup');
    return List.from(_waterRecords);
  }

  Future<void> saveWaterRecords(List<WaterRecord> records) async {
    if (shouldThrowOnSaveWater) throw const SocketException('Failed host lookup');
  }
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

ElectricityRecord buildElecRecord({
  String? id,
  int roomDbId = 1,
  String roomNumber = '101',
  String? tenantName,
  int billingMonth = 6,
  int billingYear = 2026,
  double previousReading = 0,
  double? currentReading,
  double unitRate = 8.0,
  String? floor,
  RoomStatus? roomStatus,
}) {
  return ElectricityRecord(
    id: id,
    roomDbId: roomDbId,
    roomNumber: roomNumber,
    tenantName: tenantName,
    billingMonth: billingMonth,
    billingYear: billingYear,
    previousReading: previousReading,
    currentReading: currentReading,
    unitRate: unitRate,
    floor: floor,
    roomStatus: roomStatus,
  );
}

WaterRecord buildWaterRecord({
  String? id,
  int roomDbId = 1,
  String roomNumber = '101',
  String? tenantName,
  int billingMonth = 6,
  int billingYear = 2026,
  double amount = 0,
  String? floor,
  RoomStatus? roomStatus,
}) {
  return WaterRecord(
    id: id,
    roomDbId: roomDbId,
    roomNumber: roomNumber,
    tenantName: tenantName,
    billingMonth: billingMonth,
    billingYear: billingYear,
    amount: amount,
    floor: floor,
    roomStatus: roomStatus,
  );
}

// ---------------------------------------------------------------------------
// ViewModel fake — client เป็น getter ใน SupabaseService จึงสืบทอดได้โดยไม่แตะ
// Supabase.instance ซึ่ง assert เมื่อยังไม่ได้ initialize
// ---------------------------------------------------------------------------

class _FakeMeterService extends SupabaseService {
  _FakeMeterService({
    required this.electricityRecords,
    required this.waterRecords,
  });

  final List<ElectricityRecord> electricityRecords;
  final List<WaterRecord> waterRecords;
  int saveElectricityCallCount = 0;
  int saveWaterCallCount = 0;

  @override
  Future<List<ElectricityRecord>> fetchElectricityRecords({
    int? dormitoryId,
    int? roomDbId,
    required int month,
    required int year,
  }) async =>
      List.from(electricityRecords);

  @override
  Future<List<WaterRecord>> fetchWaterRecords({
    int? dormitoryId,
    int? roomDbId,
    required int month,
    required int year,
  }) async =>
      List.from(waterRecords);

  @override
  Future<void> saveElectricityRecords(List<ElectricityRecord> records) async {
    saveElectricityCallCount++;
  }

  @override
  Future<void> saveWaterRecords(List<WaterRecord> records) async {
    saveWaterCallCount++;
  }
}

Future<MeterViewModel> buildLoadedMeterViewModel({
  List<ElectricityRecord>? electricityRecords,
  List<WaterRecord>? waterRecords,
}) async {
  final viewModel = MeterViewModel(
    dormitoryId: 1,
    service: _FakeMeterService(
      electricityRecords: electricityRecords ??
          [
            buildElecRecord(id: '1', roomDbId: 1, currentReading: 100),
            buildElecRecord(id: '2', roomDbId: 2, currentReading: 200),
          ],
      waterRecords: waterRecords ??
          [
            buildWaterRecord(id: '1', roomDbId: 1, amount: 80),
            buildWaterRecord(id: '2', roomDbId: 2, amount: 90),
          ],
    ),
  );
  await viewModel.loadAllRecords();
  return viewModel;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // การลากรีเฟรชล้าง TextEditingController ทั้งชุดผ่าน reloadTick หน้าจอจึงต้อง
  // ถามก่อนทิ้ง ซึ่งถามได้ก็ต่อเมื่อ ViewModel ตอบได้จริงว่ามีอะไรค้างอยู่บ้าง
  group('มีอะไรที่ยังไม่ได้บันทึกไหม', () {
    test('ยังไม่แก้อะไร = ไม่มีอะไรให้บันทึก', () async {
      final viewModel = await buildLoadedMeterViewModel();

      expect(viewModel.hasUnsavedEdits, isFalse);
      expect(viewModel.canSave, isFalse,
          reason: 'ปุ่มบันทึกไม่ควรกดได้ทั้งที่ไม่มีอะไรเปลี่ยน');
    });

    test('พิมพ์เลขมิเตอร์ไฟแล้วถือว่ามีของค้าง', () async {
      final viewModel = await buildLoadedMeterViewModel();
      final record = viewModel.electricityRecords.first;

      viewModel.setElectricityReading(record, 1234);

      expect(viewModel.modifiedElectricityRoomIds, contains(record.roomDbId));
      expect(viewModel.hasUnsavedEdits, isTrue);
      expect(viewModel.canSave, isTrue);
    });

    test('แถวค่าน้ำที่ยังไม่เคยบันทึกนับเป็นของที่กดบันทึกได้', () async {
      final viewModel = await buildLoadedMeterViewModel(
        waterRecords: [buildWaterRecord(id: null, roomDbId: 1, amount: 0)],
      );

      expect(viewModel.hasUnsavedEdits, isTrue);
    });

    // งวดใหม่มีแถวค่าน้ำที่ยังไม่มี id ครบทุกห้องตั้งแต่โหลดเสร็จ ถ้ากล่อง
    // "ถามก่อนทิ้ง" ใช้เกณฑ์เดียวกับปุ่มบันทึก มันจะเด้งทุกครั้งที่ลากรีเฟรช
    // ทั้งที่ยังไม่มีใครพิมพ์อะไร ซึ่งสอนให้ผู้ใช้กด "ทิ้ง" โดยไม่อ่าน
    test('งวดใหม่ที่ยังไม่มีใครพิมพ์ ไม่ถือว่ามีของค้างให้ถามก่อนทิ้ง', () async {
      final viewModel = await buildLoadedMeterViewModel(
        waterRecords: [
          buildWaterRecord(id: null, roomDbId: 1, amount: 0),
          buildWaterRecord(id: null, roomDbId: 2, amount: 0),
        ],
      );

      expect(viewModel.hasUnsavedInput, isFalse);
      expect(viewModel.hasUnsavedEdits, isTrue,
          reason: 'ยังกดบันทึกได้ เพราะมีแถวที่ต้องสร้างจริง');
    });

    test('พิมพ์ค่าน้ำแล้วถือว่ามีของค้างให้ถามก่อนทิ้ง', () async {
      final viewModel = await buildLoadedMeterViewModel();

      viewModel.setWaterAmount(viewModel.waterRecords.first, 150);

      expect(viewModel.hasUnsavedInput, isTrue);
    });

    test('บันทึกสำเร็จแล้วล้างธงทั้งสองฝั่ง', () async {
      final viewModel = await buildLoadedMeterViewModel();
      viewModel.setElectricityReading(viewModel.electricityRecords.first, 1234);
      viewModel.setWaterAmount(viewModel.waterRecords.first, 120);

      final saved = await viewModel.saveAll();

      expect(saved, isTrue);
      expect(viewModel.modifiedElectricityRoomIds, isEmpty);
      expect(viewModel.modifiedWaterRoomIds, isEmpty);
      expect(viewModel.hasUnsavedEdits, isFalse);
    });

    test('โหลดใหม่ล้างของค้างทิ้ง — ค่าที่พิมพ์ไว้หายไปกับ reloadTick อยู่แล้ว',
        () async {
      final viewModel = await buildLoadedMeterViewModel();
      viewModel.setElectricityReading(viewModel.electricityRecords.first, 1234);

      await viewModel.loadAllRecords();

      expect(viewModel.hasUnsavedInput, isFalse);
    });
  });

  group('Feature 4: Utility Meter Recording', () {
    // -----------------------------------------------------------------------
    // 4.1 Record Electricity Meter Readings
    // -----------------------------------------------------------------------

    group('UTC-19 ElectricityRecord.unitsUsed', () {
      test('UTC-19-TC-01 returns current − previous for normal reading', () {
        final record = buildElecRecord(
          previousReading: 1000,
          currentReading: 1100,
        );

        expect(record.unitsUsed, 100);
      });

      test('UTC-19-TC-02 handles 4-digit rollover (10000 − prev) + current', () {
        final record = buildElecRecord(
          previousReading: 9990,
          currentReading: 50,
        );

        expect(record.unitsUsed, 60);
      });

      test('UTC-19-TC-03 returns 0 when currentReading is null', () {
        final record = buildElecRecord(
          previousReading: 1000,
          currentReading: null,
        );

        expect(record.unitsUsed, 0);
      });
    });

    group('UTC-20 ElectricityRecord.isOverflow', () {
      test(
          'UTC-20-TC-01 returns true when current < previous; '
          'false otherwise', () {
        final overflow = buildElecRecord(
          previousReading: 9990,
          currentReading: 50,
        );
        final normal = buildElecRecord(
          previousReading: 1000,
          currentReading: 1100,
        );

        expect(overflow.isOverflow, isTrue);
        expect(normal.isOverflow, isFalse);
      });
    });

    group('UTC-21 ElectricityRecord.amount', () {
      test('UTC-21-TC-01 amount = unitsUsed × unitRate for normal case', () {
        final record = buildElecRecord(
          previousReading: 1000,
          currentReading: 1100,
          unitRate: 8.0,
        );

        expect(record.amount, 800.0);
      });

      test('UTC-21-TC-02 amount = unitsUsed × unitRate for rollover case', () {
        final record = buildElecRecord(
          previousReading: 9990,
          currentReading: 50,
          unitRate: 8.0,
        );

        expect(record.amount, 480.0);
      });
    });

    group('UTC-22 validateElecReading', () {
      test('UTC-22-TC-01 returns range error when reading > 9999', () {
        expect(
          validateElecReading(12000),
          'ค่าต้องอยู่ในช่วง 0-9999',
        );
      });

      test('UTC-22-TC-02 returns null for readings within 0–9999', () {
        expect(validateElecReading(9999), isNull);
        expect(validateElecReading(0), isNull);
      });
    });

    group('UTC-23 ElectricityRecord.toJson', () {
      test(
          'UTC-23-TC-01 contains billing keys and computed amount', () {
        final record = buildElecRecord(
          roomDbId: 1,
          billingMonth: 6,
          billingYear: 2026,
          previousReading: 1000,
          currentReading: 1100,
          unitRate: 8.0,
        );

        final json = record.toJson();

        expect(json['room_id'], 1);
        expect(json['billing_month'], 6);
        expect(json['billing_year'], 2026);
        expect(json['amount'], 800.0);
      });
    });

    group('UTC-24 matchesFilters', () {
      test('UTC-24-TC-01 matches by room number', () {
        expect(
          matchesFilters(
            roomNumber: '101',
            tenantName: null,
            floor: '1',
            roomStatus: RoomStatus.vacant,
            query: '101',
            selectedFloor: 'ทั้งหมด',
            selectedRoomStatus: 'ทั้งหมด',
          ),
          isTrue,
        );
        expect(
          matchesFilters(
            roomNumber: '202',
            tenantName: null,
            floor: '2',
            roomStatus: RoomStatus.vacant,
            query: '101',
            selectedFloor: 'ทั้งหมด',
            selectedRoomStatus: 'ทั้งหมด',
          ),
          isFalse,
        );
      });

      test('UTC-24-TC-02 matches by tenant name (case-insensitive)', () {
        expect(
          matchesFilters(
            roomNumber: '102',
            tenantName: 'Kong Kong',
            floor: '1',
            roomStatus: RoomStatus.occupied,
            query: 'kong',
            selectedFloor: 'ทั้งหมด',
            selectedRoomStatus: 'ทั้งหมด',
          ),
          isTrue,
        );
      });

      test('UTC-24-TC-03 applies floor filter', () {
        expect(
          matchesFilters(
            roomNumber: '201',
            tenantName: null,
            floor: '2',
            roomStatus: RoomStatus.vacant,
            query: '',
            selectedFloor: '2',
            selectedRoomStatus: 'ทั้งหมด',
          ),
          isTrue,
        );
        expect(
          matchesFilters(
            roomNumber: '101',
            tenantName: null,
            floor: '1',
            roomStatus: RoomStatus.vacant,
            query: '',
            selectedFloor: '2',
            selectedRoomStatus: 'ทั้งหมด',
          ),
          isFalse,
        );
      });

      test('UTC-24-TC-04 applies room-status filter', () {
        expect(
          matchesFilters(
            roomNumber: '102',
            tenantName: null,
            floor: '1',
            roomStatus: RoomStatus.occupied,
            query: '',
            selectedFloor: 'ทั้งหมด',
            selectedRoomStatus: 'มีคนอยู่',
          ),
          isTrue,
        );
        expect(
          matchesFilters(
            roomNumber: '101',
            tenantName: null,
            floor: '1',
            roomStatus: RoomStatus.vacant,
            query: '',
            selectedFloor: 'ทั้งหมด',
            selectedRoomStatus: 'มีคนอยู่',
          ),
          isFalse,
        );
      });
    });

    group('UTC-25 roomStatusLabel', () {
      test('UTC-25-TC-01 maps each status to its Thai label', () {
        expect(roomStatusLabel(RoomStatus.occupied), 'มีคนอยู่');
        expect(roomStatusLabel(RoomStatus.vacant), 'ว่าง');
        expect(roomStatusLabel(RoomStatus.maintenance), 'ซ่อมบำรุง');
        expect(roomStatusLabel(null), '-');
      });
    });

    group('UTC-26 electricityProgress', () {
      test(
          'UTC-26-TC-01 counts only rooms with a non-null currentReading', () {
        final records = [
          buildElecRecord(roomDbId: 1, currentReading: 1100),
          buildElecRecord(roomDbId: 2, currentReading: 500),
          buildElecRecord(roomDbId: 3, currentReading: null),
        ];

        expect(electricityProgress(records), 2);
      });
    });

    group('UTC-27 fetchElectricityRecords', () {
      test(
          'UTC-27-TC-01 returns the records list when rooms exist', () async {
        final repository = FakeMeterRepository(
          electricityRecords: [
            buildElecRecord(roomDbId: 1, roomNumber: '101'),
            buildElecRecord(roomDbId: 2, roomNumber: '102'),
          ],
        );

        final result = await repository.fetchElectricityRecords(
          dormitoryId: 1,
          month: 6,
          year: 2026,
        );

        expect(result, hasLength(2));
        expect(result.map((r) => r.roomNumber), containsAll(['101', '102']));
      });

      test(
          'UTC-27-TC-02 returns empty list when no rooms exist', () async {
        final repository = FakeMeterRepository(electricityRecords: []);

        final result = await repository.fetchElectricityRecords(
          dormitoryId: 1,
          month: 6,
          year: 2026,
        );

        expect(result, isEmpty);
      });
    });

    group('UTC-28 saveElectricityRecords', () {
      test('UTC-28-TC-01 completes when save succeeds', () async {
        final repository = FakeMeterRepository();

        await expectLater(
          repository.saveElectricityRecords([
            buildElecRecord(roomDbId: 1, currentReading: 1100),
          ]),
          completes,
        );
      });

      test(
          'UTC-28-TC-02 throws SocketException on network failure', () {
        final repository =
            FakeMeterRepository(shouldThrowOnSaveElec: true);

        expect(
          () => repository.saveElectricityRecords([
            buildElecRecord(roomDbId: 1, currentReading: 1100),
          ]),
          throwsA(isA<SocketException>()),
        );
      });
    });

    // -----------------------------------------------------------------------
    // 4.2 Record Water Charges
    // -----------------------------------------------------------------------

    group('UTC-29 waterRecordsToSave', () {
      test(
          'UTC-29-TC-01 keeps only new (id==null) or modified records', () {
        final existing = buildWaterRecord(id: '1', roomDbId: 1, amount: 80);
        final newRecord = buildWaterRecord(id: null, roomDbId: 2, amount: 100);
        final modified = buildWaterRecord(id: '3', roomDbId: 3, amount: 120);

        final result = waterRecordsToSave(
          [existing, newRecord, modified],
          {3},
        );

        expect(result, hasLength(2));
        expect(result.map((r) => r.roomDbId), containsAll([2, 3]));
        expect(result.map((r) => r.roomDbId), isNot(contains(1)));
      });
    });

    group('UTC-30 waterProgress', () {
      test(
          'UTC-30-TC-01 counts only rooms with an existing record (id != null)',
          () {
        final records = [
          buildWaterRecord(id: '1', roomDbId: 1, amount: 100),
          buildWaterRecord(id: '2', roomDbId: 2, amount: 80),
          buildWaterRecord(id: null, roomDbId: 3, amount: 0),
        ];

        expect(waterProgress(records), 2);
      });
    });

    group('UTC-31 fetchWaterRecords', () {
      test(
          'UTC-31-TC-01 returns the records list with correct amount', () async {
        final repository = FakeMeterRepository(
          waterRecords: [
            buildWaterRecord(id: '1', roomDbId: 1, amount: 100.0),
          ],
        );

        final result = await repository.fetchWaterRecords(
          dormitoryId: 1,
          month: 6,
          year: 2026,
        );

        expect(result, isNotEmpty);
        expect(result.first.amount, 100.0);
      });

      test(
          'UTC-31-TC-02 returns empty list when no rooms exist', () async {
        final repository = FakeMeterRepository(waterRecords: []);

        final result = await repository.fetchWaterRecords(
          dormitoryId: 1,
          month: 6,
          year: 2026,
        );

        expect(result, isEmpty);
      });
    });

    group('UTC-32 saveWaterRecords', () {
      test('UTC-32-TC-01 completes when save succeeds', () async {
        final repository = FakeMeterRepository();

        await expectLater(
          repository.saveWaterRecords([
            buildWaterRecord(roomDbId: 1, amount: 150.0),
          ]),
          completes,
        );
      });

      test(
          'UTC-32-TC-02 throws SocketException on network failure', () {
        final repository =
            FakeMeterRepository(shouldThrowOnSaveWater: true);

        expect(
          () => repository.saveWaterRecords([
            buildWaterRecord(roomDbId: 1, amount: 150.0),
          ]),
          throwsA(isA<SocketException>()),
        );
      });
    });
  });
}
