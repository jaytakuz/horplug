import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/maintenance_overview.dart';
import 'package:horplug/services/supabase_service.dart';
import 'package:horplug/viewmodels/maintenance_overview_view_model.dart';

MaintenanceRequest _request({
  int id = 1,
  int roomId = 1,
  String roomNumber = '301',
  String tenantName = 'สมชาย ใจดี',
  MaintenanceRequestType type = MaintenanceRequestType.repair,
  String description = 'ก๊อกน้ำรั่ว',
  MaintenanceStatus status = MaintenanceStatus.pending,
  DateTime? requestedAt,
}) =>
    MaintenanceRequest(
      id: id,
      roomId: roomId,
      roomNumber: roomNumber,
      tenantId: 'tenant-uuid',
      tenantName: tenantName,
      requestType: type,
      description: description,
      status: status,
      requestedAt: requestedAt ?? DateTime(2026, 8, 1),
    );

class _FakeSupabaseService extends SupabaseService {
  _FakeSupabaseService({this.summaries = const [], this.error});

  final List<RoomMaintenanceSummary> summaries;
  final Object? error;

  @override
  Future<List<RoomMaintenanceSummary>> fetchMaintenanceSummaries({
    required int dormitoryId,
  }) async {
    if (error != null) throw error!;
    return summaries;
  }
}

RoomMaintenanceSummary _summary({
  int roomDbId = 1,
  String roomNumber = '301',
  String floor = '3',
  String tenantName = 'สมชาย ใจดี',
  int openCount = 1,
  String description = 'ก๊อกน้ำรั่ว',
}) =>
    RoomMaintenanceSummary(
      roomDbId: roomDbId,
      roomNumber: roomNumber,
      floor: floor,
      tenantName: tenantName,
      latest: _request(
        roomId: roomDbId,
        roomNumber: roomNumber,
        tenantName: tenantName,
        description: description,
      ),
      openCount: openCount,
      totalCount: 1,
    );

void main() {
  group('summarizeMaintenanceByRoom', () {
    test('ยุบหลายคำขอของห้องเดียวเหลือแถวเดียว', () {
      final summaries = summarizeMaintenanceByRoom(
        requests: [
          _request(id: 1, requestedAt: DateTime(2026, 8, 1)),
          _request(id: 2, requestedAt: DateTime(2026, 8, 5)),
        ],
        floorByRoom: {1: '3'},
      );

      expect(summaries, hasLength(1));
      expect(summaries.single.totalCount, 2);
    });

    // เชื่อลำดับที่ผู้เรียกส่งมาไม่ได้ — วันที่ query เปลี่ยน order รายการจะขึ้น
    // "คำขอล่าสุด" ที่เป็นใบเก่าสุดโดยไม่มีอะไรพัง
    test('เลือกใบล่าสุดเป็นตัวแทน แม้ข้อมูลจะเรียงจากเก่าไปใหม่', () {
      final summaries = summarizeMaintenanceByRoom(
        requests: [
          _request(
              id: 1, description: 'เก่า', requestedAt: DateTime(2026, 7, 1)),
          _request(
              id: 2, description: 'ใหม่', requestedAt: DateTime(2026, 8, 9)),
        ],
        floorByRoom: {1: '3'},
      );

      expect(summaries.single.latest.description, 'ใหม่');
    });

    test('นับเฉพาะงานที่ยังไม่จบเป็น openCount', () {
      final summaries = summarizeMaintenanceByRoom(
        requests: [
          _request(id: 1, status: MaintenanceStatus.pending),
          _request(id: 2, status: MaintenanceStatus.inProgress),
          _request(id: 3, status: MaintenanceStatus.completed),
          _request(id: 4, status: MaintenanceStatus.cancelled),
        ],
        floorByRoom: {1: '3'},
      );

      expect(summaries.single.openCount, 2);
      expect(summaries.single.totalCount, 4);
    });

    test('เรียงห้องที่แจ้งล่าสุดไว้บนสุด', () {
      final summaries = summarizeMaintenanceByRoom(
        requests: [
          _request(
              id: 1,
              roomId: 1,
              roomNumber: '301',
              requestedAt: DateTime(2026, 8, 1)),
          _request(
              id: 2,
              roomId: 2,
              roomNumber: '302',
              requestedAt: DateTime(2026, 8, 9)),
          _request(
              id: 3,
              roomId: 3,
              roomNumber: '303',
              requestedAt: DateTime(2026, 8, 5)),
        ],
        floorByRoom: {1: '3', 2: '3', 3: '3'},
      );

      expect(
        summaries.map((s) => s.roomNumber),
        ['302', '303', '301'],
      );
    });

    test('ห้องที่ไม่มีข้อมูลชั้น ได้สตริงว่าง ไม่ทำให้ล้ม', () {
      final summaries = summarizeMaintenanceByRoom(
        requests: [_request()],
        floorByRoom: const {},
      );

      expect(summaries.single.floor, '');
    });

    test('ไม่มีคำขอเลย ได้รายการว่าง', () {
      expect(
        summarizeMaintenanceByRoom(requests: const [], floorByRoom: const {}),
        isEmpty,
      );
    });
  });

  group('MaintenanceOverviewViewModel', () {
    test('ค้นหาได้ทั้งเลขห้อง ชื่อผู้เช่า และข้อความคำขอ', () async {
      final viewModel = MaintenanceOverviewViewModel(
        dormitoryId: 1,
        service: _FakeSupabaseService(summaries: [
          _summary(roomDbId: 1, roomNumber: '301', tenantName: 'สมชาย ใจดี'),
          _summary(
            roomDbId: 2,
            roomNumber: '302',
            tenantName: 'มานี รักดี',
            description: 'แอร์ไม่เย็น',
          ),
        ]),
      );
      await viewModel.load();

      viewModel.setSearchQuery('302');
      expect(viewModel.filteredSummaries.single.roomNumber, '302');

      viewModel.setSearchQuery('มานี');
      expect(viewModel.filteredSummaries.single.roomNumber, '302');

      viewModel.setSearchQuery('แอร์');
      expect(viewModel.filteredSummaries.single.roomNumber, '302');
    });

    test('กรองตามชั้นได้ และ availableFloors ไม่มีค่าว่างปน', () async {
      final viewModel = MaintenanceOverviewViewModel(
        dormitoryId: 1,
        service: _FakeSupabaseService(summaries: [
          _summary(roomDbId: 1, roomNumber: '301', floor: '3'),
          _summary(roomDbId: 2, roomNumber: '401', floor: '4'),
          _summary(roomDbId: 3, roomNumber: '999', floor: ''),
        ]),
      );
      await viewModel.load();

      expect(viewModel.availableFloors, {'3', '4'});

      viewModel.setFloorFilter('4');
      expect(viewModel.filteredSummaries.single.roomNumber, '401');
    });

    test('นับห้องที่ยังมีงานค้าง', () async {
      final viewModel = MaintenanceOverviewViewModel(
        dormitoryId: 1,
        service: _FakeSupabaseService(summaries: [
          _summary(roomDbId: 1, openCount: 2),
          _summary(roomDbId: 2, openCount: 0),
        ]),
      );
      await viewModel.load();

      expect(viewModel.roomsWithOpenWork, 1);
    });

    test('โหลดไม่สำเร็จ รายงาน errorMessage และไม่ค้าง isLoading', () async {
      final viewModel = MaintenanceOverviewViewModel(
        dormitoryId: 1,
        service: _FakeSupabaseService(error: Exception('เน็ตหลุด')),
      );

      await viewModel.load();

      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.summaries, isEmpty);
    });
  });
}
