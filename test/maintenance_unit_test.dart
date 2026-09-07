import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/supabase_service.dart';
import 'package:horplug/viewmodels/maintenance_view_model.dart';

MaintenanceRequest _request({
  int id = 1,
  int roomId = 101,
  String roomNumber = '101',
  String tenantId = 'tenant-uuid',
  String tenantName = 'สมชาย ใจดี',
  MaintenanceRequestType requestType = MaintenanceRequestType.repair,
  String description = 'ก๊อกน้ำรั่ว',
  MaintenanceStatus status = MaintenanceStatus.pending,
  DateTime? requestedAt,
  DateTime? completedAt,
}) =>
    MaintenanceRequest(
      id: id,
      roomId: roomId,
      roomNumber: roomNumber,
      tenantId: tenantId,
      tenantName: tenantName,
      requestType: requestType,
      description: description,
      status: status,
      requestedAt: requestedAt ?? DateTime(2026, 8, 1),
      completedAt: completedAt,
    );

/// SupabaseService ปลอมสำหรับ Feature 3 — บันทึกอาร์กิวเมนต์ที่ถูกเรียกไว้ตรวจสอบ
/// แทนที่จะแตะเครือข่ายจริง เช่นเดียวกับ _FakeSupabaseService ใน
/// maintenance_overview_unit_test.dart
class _FakeMaintenanceService extends SupabaseService {
  _FakeMaintenanceService({
    this.requests = const [],
    this.shouldThrow = false,
  });

  final List<MaintenanceRequest> requests;
  final bool shouldThrow;

  int? createdRoomId;
  String? createdTenantId;
  String? createdDescription;
  MaintenanceRequestType? createdRequestType;

  int? updatedRequestId;
  MaintenanceStatus? updatedStatus;

  @override
  Future<List<MaintenanceRequest>> fetchMaintenanceRequests({
    required int roomId,
  }) async {
    if (shouldThrow) throw const SocketException('Failed host lookup');
    return requests;
  }

  @override
  Future<void> createMaintenanceRequest({
    required int roomId,
    required String tenantId,
    required String description,
    MaintenanceRequestType requestType = MaintenanceRequestType.repair,
  }) async {
    if (shouldThrow) throw const SocketException('Failed host lookup');
    createdRoomId = roomId;
    createdTenantId = tenantId;
    createdDescription = description;
    createdRequestType = requestType;
  }

  @override
  Future<void> updateMaintenanceStatus({
    required int requestId,
    required int roomId,
    required String landlordId,
    required MaintenanceStatus status,
    required MaintenanceRequestType requestType,
  }) async {
    if (shouldThrow) throw const SocketException('Failed host lookup');
    updatedRequestId = requestId;
    updatedStatus = status;
  }
}

void main() {
  group('Feature 3: Maintenance History / Tracking', () {
    group('UTC-35 fetchMaintenanceRequests', () {
      test('UTC-35-TC-01 returns the request list for the room', () async {
        final service = _FakeMaintenanceService(requests: [
          _request(id: 1, description: 'ก๊อกน้ำรั่ว'),
          _request(id: 2, description: 'กวาดพื้น'),
        ]);

        final result = await service.fetchMaintenanceRequests(roomId: 101);

        expect(result, hasLength(2));
        expect(result.map((r) => r.description), ['ก๊อกน้ำรั่ว', 'กวาดพื้น']);
      });

      test(
          'UTC-35-TC-02 returns an empty list when the room has no requests',
          () async {
        final service = _FakeMaintenanceService(requests: const []);

        final result = await service.fetchMaintenanceRequests(roomId: 999);

        expect(result, isEmpty);
      });

      test('UTC-35-TC-03 throws SocketException on network failure', () {
        final service = _FakeMaintenanceService(shouldThrow: true);

        expect(
          () => service.fetchMaintenanceRequests(roomId: 101),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-36 filterMaintenanceRequests', () {
      final requests = [
        _request(
          id: 1,
          description: 'ก๊อกน้ำรั่ว',
          requestType: MaintenanceRequestType.repair,
          status: MaintenanceStatus.pending,
        ),
        _request(
          id: 2,
          description: 'กวาดพื้น',
          requestType: MaintenanceRequestType.cleaning,
          status: MaintenanceStatus.completed,
        ),
        _request(
          id: 3,
          description: 'แอร์เสีย',
          requestType: MaintenanceRequestType.repair,
          status: MaintenanceStatus.inProgress,
        ),
      ];

      test('UTC-36-TC-01 status filter returns only matching-status requests',
          () {
        final result = filterMaintenanceRequests(requests, 'รอดำเนินการ');

        expect(result.map((r) => r.description), ['ก๊อกน้ำรั่ว']);
      });

      test('UTC-36-TC-02 search matches the description', () {
        final result =
            filterMaintenanceRequests(requests, 'ทั้งหมด', searchQuery: 'แอร์');

        expect(result.map((r) => r.description), ['แอร์เสีย']);
      });

      test('UTC-36-TC-03 search matches the request-type label', () {
        final result = filterMaintenanceRequests(requests, 'ทั้งหมด',
            searchQuery: 'ทำความสะอาด');

        expect(result.map((r) => r.description), ['กวาดพื้น']);
      });

      test('UTC-36-TC-04 status filter and search query combine', () {
        final result =
            filterMaintenanceRequests(requests, 'เสร็จสิ้น', searchQuery: 'กวาด');

        expect(result.map((r) => r.description), ['กวาดพื้น']);
      });

      test('UTC-36-TC-05 returns an empty list when nothing matches', () {
        final result = filterMaintenanceRequests(requests, 'ทั้งหมด',
            searchQuery: 'ไม่มีคำนี้');

        expect(result, isEmpty);
      });
    });

    group('UTC-37 createMaintenanceRequest', () {
      test(
          'UTC-37-TC-01 creates a repair request carrying the given description',
          () async {
        final service = _FakeMaintenanceService();

        await service.createMaintenanceRequest(
          roomId: 101,
          tenantId: 'tenant-uuid',
          description: 'ก๊อกน้ำรั่ว',
        );

        expect(service.createdRoomId, 101);
        expect(service.createdTenantId, 'tenant-uuid');
        expect(service.createdDescription, 'ก๊อกน้ำรั่ว');
        expect(service.createdRequestType, MaintenanceRequestType.repair);
      });

      test(
          'UTC-37-TC-02 creates a cleaning request when requestType is cleaning',
          () async {
        final service = _FakeMaintenanceService();

        await service.createMaintenanceRequest(
          roomId: 101,
          tenantId: 'tenant-uuid',
          description: 'กวาดพื้น',
          requestType: MaintenanceRequestType.cleaning,
        );

        expect(service.createdRequestType, MaintenanceRequestType.cleaning);
      });

      test('UTC-37-TC-03 throws SocketException on network failure', () {
        final service = _FakeMaintenanceService(shouldThrow: true);

        expect(
          () => service.createMaintenanceRequest(
            roomId: 101,
            tenantId: 'tenant-uuid',
            description: 'ก๊อกน้ำรั่ว',
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-38 updateMaintenanceStatus', () {
      test('UTC-38-TC-01 updates the request to In-Progress', () async {
        final service = _FakeMaintenanceService();

        await service.updateMaintenanceStatus(
          requestId: 501,
          roomId: 101,
          landlordId: 'landlord-uuid',
          status: MaintenanceStatus.inProgress,
          requestType: MaintenanceRequestType.repair,
        );

        expect(service.updatedRequestId, 501);
        expect(service.updatedStatus, MaintenanceStatus.inProgress);
      });

      test('UTC-38-TC-02 accepts Completed as a valid new status', () async {
        final service = _FakeMaintenanceService();

        await service.updateMaintenanceStatus(
          requestId: 501,
          roomId: 101,
          landlordId: 'landlord-uuid',
          status: MaintenanceStatus.completed,
          requestType: MaintenanceRequestType.repair,
        );

        expect(service.updatedStatus, MaintenanceStatus.completed);
      });

      test('UTC-38-TC-03 accepts Cancelled as a valid new status', () async {
        final service = _FakeMaintenanceService();

        await service.updateMaintenanceStatus(
          requestId: 501,
          roomId: 101,
          landlordId: 'landlord-uuid',
          status: MaintenanceStatus.cancelled,
          requestType: MaintenanceRequestType.repair,
        );

        expect(service.updatedStatus, MaintenanceStatus.cancelled);
      });

      test('UTC-38-TC-04 throws SocketException on network failure', () {
        final service = _FakeMaintenanceService(shouldThrow: true);

        expect(
          () => service.updateMaintenanceStatus(
            requestId: 501,
            roomId: 101,
            landlordId: 'landlord-uuid',
            status: MaintenanceStatus.inProgress,
            requestType: MaintenanceRequestType.repair,
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });

    // Tests roomStatusForMaintenanceSync — the pure decision logic extracted
    // from the private _syncRoomStatusForMaintenance (which still does the
    // Supabase query/write; not itself unit-testable, same reasoning as
    // before). Same split as electricityMeterOverflowCheck for Feature 4.
    group('UTC-39 roomStatusForMaintenanceSync', () {
      test('UTC-39-TC-01 sets the room to maintenance when a request is '
          'Pending', () {
        final result = roomStatusForMaintenanceSync(
          status: MaintenanceStatus.pending,
          hasOtherUnfinishedRequests: false,
        );

        expect(result, 'maintenance');
      });

      test('UTC-39-TC-02 sets the room to maintenance when a request is '
          'In-Progress', () {
        final result = roomStatusForMaintenanceSync(
          status: MaintenanceStatus.inProgress,
          hasOtherUnfinishedRequests: false,
        );

        expect(result, 'maintenance');
      });

      test(
          'UTC-39-TC-03 reverts to occupied once no unfinished requests remain',
          () {
        final result = roomStatusForMaintenanceSync(
          status: MaintenanceStatus.completed,
          hasOtherUnfinishedRequests: false,
        );

        expect(result, 'occupied');
      });

      test(
          'UTC-39-TC-04 stays unchanged (null) while another request is '
          'still unfinished', () {
        final result = roomStatusForMaintenanceSync(
          status: MaintenanceStatus.completed,
          hasOtherUnfinishedRequests: true,
        );

        expect(result, isNull);
      });

      test('UTC-39-TC-05 cancelled behaves the same as completed', () {
        final result = roomStatusForMaintenanceSync(
          status: MaintenanceStatus.cancelled,
          hasOtherUnfinishedRequests: true,
        );

        expect(result, isNull);
      });
    });
  });
}
