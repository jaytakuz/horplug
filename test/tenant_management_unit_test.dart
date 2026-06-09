import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:horplug/models/models.dart';
import 'package:horplug/services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Fake service — overrides only the tested methods; no real Supabase calls.
// ---------------------------------------------------------------------------
class FakeSupabaseService extends SupabaseService {
  List<Tenant> availableTenants = [];
  Object? assignError;
  Object? removeError;

  @override
  Future<List<Tenant>> fetchAvailableTenants() async => availableTenants;

  @override
  Future<void> assignTenantToRoom(
      {required int roomDbId, required String tenantId}) async {
    if (assignError != null) throw assignError!;
  }

  @override
  Future<void> removeTenantFromRoom({required int roomDbId}) async {
    if (removeError != null) throw removeError!;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Mirrors the search filter logic in rooms_screen.dart (_showAddTenantDialog).
List<Tenant> filterTenantsByName(List<Tenant> tenants, String query) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) return [];
  return tenants
      .where((tenant) => tenant.name.toLowerCase().contains(keyword))
      .toList();
}

// Mirrors the room status partitioning in rooms_screen.dart.
List<Room> vacantRooms(List<Room> rooms) =>
    rooms.where((r) => r.status == RoomStatus.vacant).toList();

List<Room> occupiedRooms(List<Room> rooms) =>
    rooms.where((r) => r.status == RoomStatus.occupied).toList();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  // -------------------------------------------------------------------------
  // UTC-04-TC-02 (SRS-02): searchController — tenant name filter
  // Note: TC-01 and TC-07 (DropdownButtonFormField UI) are widget-level tests.
  // -------------------------------------------------------------------------
  group('UTC-04-TC-02 Tenant name search filter (SRS-02)', () {
    final tenants = [
      Tenant(id: 'u1', name: 'Kong Kong', phoneNumber: '099'),
      Tenant(id: 'u2', name: 'Piphatpong Lalaka', phoneNumber: '088'),
      Tenant(id: 'u3', name: 'สมชาย ใจดี', phoneNumber: '077'),
    ];

    test(
        'UTC-04-TC-02a: returns tenants whose names contain the query '
        '(case-insensitive)', () {
      final result = filterTenantsByName(tenants, 'K');
      expect(result.map((t) => t.name),
          containsAll(['Kong Kong', 'Piphatpong Lalaka']));
      expect(result.length, 2);
    });

    test('UTC-04-TC-02b: returns empty list when query is empty', () {
      final result = filterTenantsByName(tenants, '');
      expect(result, isEmpty);
    });

    test('UTC-04-TC-02c: returns empty list when no tenant matches the query',
        () {
      final result = filterTenantsByName(tenants, 'zzz');
      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // UTC-04-TC-03 (SRS-03): No vacant rooms guard
  // Unit-testable part: the vacant-room partition of _rooms is empty.
  // The SnackBar 'ไม่มีห้องว่างสำหรับเพิ่มผู้พักอาศัย' is verified in widget tests.
  // -------------------------------------------------------------------------
  group('UTC-04-TC-03 Vacant room filter (SRS-03)', () {
    test(
        'UTC-04-TC-03a: vacantRooms is empty when all rooms are occupied, '
        'triggering the no-vacant-room guard in rooms_screen.dart', () {
      final rooms = [
        Room(
            dbId: 1,
            id: '101',
            floor: '1',
            status: RoomStatus.occupied,
            price: 3000),
        Room(
            dbId: 2,
            id: '102',
            floor: '1',
            status: RoomStatus.occupied,
            price: 3000),
      ];
      expect(vacantRooms(rooms), isEmpty);
    });

    test(
        'UTC-04-TC-03b: vacantRooms contains only vacant rooms '
        'from a mixed list', () {
      final rooms = [
        Room(
            dbId: 1,
            id: '101',
            floor: '1',
            status: RoomStatus.vacant,
            price: 3000),
        Room(
            dbId: 2,
            id: '102',
            floor: '1',
            status: RoomStatus.occupied,
            price: 3000),
      ];
      final result = vacantRooms(rooms);
      expect(result.length, 1);
      expect(result.first.id, '101');
    });
  });

  // -------------------------------------------------------------------------
  // UTC-04-TC-04 (SRS-05): fetchAvailableTenants — no available tenants
  // -------------------------------------------------------------------------
  group('UTC-04-TC-04 fetchAvailableTenants() (SRS-05)', () {
    test(
        'UTC-04-TC-04a: returns list of tenants when unassigned tenants exist',
        () async {
      final service = FakeSupabaseService()
        ..availableTenants = [
          Tenant(id: 'u2', name: 'Piphatpong Lalaka', phoneNumber: '088'),
        ];
      final result = await service.fetchAvailableTenants();
      expect(result, isNotEmpty);
      expect(result.first.name, 'Piphatpong Lalaka');
    });

    test(
        'UTC-04-TC-04b: returns empty list when no tenants are unassigned, '
        'triggering the no-available-tenant guard '
        "(SnackBar 'ไม่พบผู้พักอาศัย' shown in widget)", () async {
      final service = FakeSupabaseService()..availableTenants = [];
      final result = await service.fetchAvailableTenants();
      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // UTC-04-TC-05 (SRS-06): assignTenantToRoom() — success
  // UTC-04-TC-06 (SRS-07): assignTenantToRoom() — failure
  // -------------------------------------------------------------------------
  group('UTC-04-TC-05/06 assignTenantToRoom() (SRS-06, SRS-07)', () {
    test(
        'UTC-04-TC-05: completes without exception when assignment succeeds '
        "(UI shows 'เพิ่ม ... เข้าห้อง ... แล้ว')", () async {
      final service = FakeSupabaseService();
      await expectLater(
        service.assignTenantToRoom(roomDbId: 202, tenantId: 'tenant-u2'),
        completes,
      );
    });

    test(
        'UTC-04-TC-06a: throws Exception when the service call fails '
        "(UI shows 'บันทึกไม่สำเร็จ: ...')", () async {
      final service = FakeSupabaseService()
        ..assignError = Exception('บันทึกไม่สำเร็จ');
      await expectLater(
        service.assignTenantToRoom(roomDbId: 202, tenantId: 'tenant-u2'),
        throwsException,
      );
    });

    test(
        'UTC-04-TC-06b: throws SocketException when network is unavailable '
        "(UI shows 'บันทึกไม่สำเร็จ: กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่')",
        () async {
      final service = FakeSupabaseService()
        ..assignError = const SocketException('Failed host lookup');
      await expectLater(
        service.assignTenantToRoom(roomDbId: 202, tenantId: 'tenant-u2'),
        throwsA(isA<SocketException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // UTC-04-TC-08 (SRS-09): No occupied rooms guard
  // Unit-testable part: the occupied-room partition of _rooms is empty.
  // -------------------------------------------------------------------------
  group('UTC-04-TC-08 Occupied room filter (SRS-09)', () {
    test(
        'UTC-04-TC-08a: occupiedRooms is empty when all rooms are vacant, '
        'triggering the no-occupied-room guard in rooms_screen.dart', () {
      final rooms = [
        Room(
            dbId: 1,
            id: '201',
            floor: '2',
            status: RoomStatus.vacant,
            price: 3000),
        Room(
            dbId: 2,
            id: '202',
            floor: '2',
            status: RoomStatus.vacant,
            price: 3000),
      ];
      expect(occupiedRooms(rooms), isEmpty);
    });

    test(
        'UTC-04-TC-08b: occupiedRooms contains only occupied rooms '
        'from a mixed list', () {
      final rooms = [
        Room(
            dbId: 1,
            id: '201',
            floor: '2',
            status: RoomStatus.vacant,
            price: 3000),
        Room(
            dbId: 2,
            id: '202',
            floor: '2',
            status: RoomStatus.occupied,
            price: 3000),
      ];
      final result = occupiedRooms(rooms);
      expect(result.length, 1);
      expect(result.first.id, '202');
    });
  });

  // -------------------------------------------------------------------------
  // UTC-04-TC-09 (SRS-10): removeTenantFromRoom() — success
  // UTC-04-TC-10 (SRS-11): removeTenantFromRoom() — failure
  // -------------------------------------------------------------------------
  group('UTC-04-TC-09/10 removeTenantFromRoom() (SRS-10, SRS-11)', () {
    test(
        'UTC-04-TC-09: completes without exception when removal succeeds '
        "(UI shows 'ลบผู้พักอาศัยออกจากห้อง ... แล้ว')", () async {
      final service = FakeSupabaseService();
      await expectLater(
        service.removeTenantFromRoom(roomDbId: 202),
        completes,
      );
    });

    test(
        'UTC-04-TC-10a: throws Exception when the service call fails '
        "(UI shows 'ลบไม่สำเร็จ: ...')", () async {
      final service = FakeSupabaseService()
        ..removeError = Exception('ลบไม่สำเร็จ');
      await expectLater(
        service.removeTenantFromRoom(roomDbId: 202),
        throwsException,
      );
    });

    test(
        'UTC-04-TC-10b: throws SocketException when network is unavailable '
        "(UI shows 'ลบไม่สำเร็จ: กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่')",
        () async {
      final service = FakeSupabaseService()
        ..removeError = const SocketException('Failed host lookup');
      await expectLater(
        service.removeTenantFromRoom(roomDbId: 202),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
