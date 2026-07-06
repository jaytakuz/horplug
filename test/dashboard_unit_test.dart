import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';

// ---------------------------------------------------------------------------
// Pure helper functions (extracted from DashboardScreen logic)
// ---------------------------------------------------------------------------

double estimatedMonthlyRevenue(List<Room> rooms) {
  return rooms
      .where((room) => room.status == RoomStatus.occupied)
      .fold<double>(0, (sum, room) => sum + room.price);
}

int occupancyRate(List<Room> rooms) {
  final total = rooms.length;
  if (total == 0) return 0;
  final occupied = rooms.where((r) => r.status == RoomStatus.occupied).length;
  return ((occupied / total) * 100).round();
}

int occupiedCount(List<Room> rooms) =>
    rooms.where((r) => r.status == RoomStatus.occupied).length;

int vacantCount(List<Room> rooms) =>
    rooms.where((r) => r.status == RoomStatus.vacant).length;

List<String> sortedFloorNumbers(List<Room> rooms) {
  final floors = rooms.map((room) => room.floor).toSet().toList()
    ..sort((a, b) {
      final ai = int.tryParse(a);
      final bi = int.tryParse(b);
      if (ai != null && bi != null) return ai.compareTo(bi);
      return a.compareTo(b);
    });
  return floors;
}

String shortTenantName(String? fullName) {
  if (fullName == null || fullName.trim().isEmpty) return '';
  return fullName.trim().split(RegExp(r'\s+')).first;
}

String formatDashboardErrorMessage(Object error) {
  final message = error.toString().trim();
  final normalized = message.startsWith('Exception: ')
      ? message.substring('Exception: '.length).trim()
      : message;
  final lower = normalized.toLowerCase();

  if (lower.contains('failed host lookup') ||
      lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection timed out') ||
      lower.contains('timed out')) {
    return 'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
  }

  return normalized;
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

Room buildRoom({
  required int dbId,
  required String roomNumber,
  required String floor,
  required RoomStatus status,
  double price = 3000,
  String? tenantName,
}) {
  return Room(
    dbId: dbId,
    id: roomNumber,
    floor: floor,
    status: status,
    tenantName: tenantName,
    price: price,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Feature 6: Dashboard for Landlord', () {
    group('UTC-01 estimatedMonthlyRevenue', () {
      test('UTC-01-TC-01 sums prices of occupied rooms only', () {
        final rooms = [
          buildRoom(
            dbId: 1,
            roomNumber: '101',
            floor: '1',
            status: RoomStatus.occupied,
            price: 3000,
          ),
          buildRoom(
            dbId: 2,
            roomNumber: '102',
            floor: '1',
            status: RoomStatus.occupied,
            price: 2500,
          ),
        ];

        expect(estimatedMonthlyRevenue(rooms), 5500.0);
      });

      test(
          'UTC-01-TC-02 excludes vacant and maintenance rooms from revenue',
          () {
        final rooms = [
          buildRoom(
            dbId: 1,
            roomNumber: '101',
            floor: '1',
            status: RoomStatus.occupied,
            price: 3000,
          ),
          buildRoom(
            dbId: 2,
            roomNumber: '102',
            floor: '1',
            status: RoomStatus.vacant,
            price: 2500,
          ),
          buildRoom(
            dbId: 3,
            roomNumber: '103',
            floor: '1',
            status: RoomStatus.maintenance,
            price: 2000,
          ),
        ];

        expect(estimatedMonthlyRevenue(rooms), 3000.0);
      });

      test('UTC-01-TC-03 returns 0 when no rooms exist', () {
        expect(estimatedMonthlyRevenue([]), 0.0);
      });
    });

    group('UTC-01 occupancyRate', () {
      test('UTC-01-TC-04 returns 50 when 2 of 4 rooms are occupied', () {
        final rooms = [
          buildRoom(
            dbId: 1,
            roomNumber: '101',
            floor: '1',
            status: RoomStatus.occupied,
          ),
          buildRoom(
            dbId: 2,
            roomNumber: '102',
            floor: '1',
            status: RoomStatus.occupied,
          ),
          buildRoom(
            dbId: 3,
            roomNumber: '103',
            floor: '1',
            status: RoomStatus.vacant,
          ),
          buildRoom(
            dbId: 4,
            roomNumber: '104',
            floor: '1',
            status: RoomStatus.vacant,
          ),
        ];

        expect(occupancyRate(rooms), 50);
      });

      test('UTC-01-TC-05 returns 0 when no rooms exist', () {
        expect(occupancyRate([]), 0);
      });

      test('UTC-01-TC-06 returns 100 when all rooms are occupied', () {
        final rooms = [
          buildRoom(
            dbId: 1,
            roomNumber: '101',
            floor: '1',
            status: RoomStatus.occupied,
          ),
          buildRoom(
            dbId: 2,
            roomNumber: '102',
            floor: '1',
            status: RoomStatus.occupied,
          ),
        ];

        expect(occupancyRate(rooms), 100);
      });
    });

    group('UTC-01 occupiedCount and vacantCount', () {
      test('UTC-01-TC-07 counts correct number of occupied and vacant rooms',
          () {
        final rooms = [
          buildRoom(
            dbId: 1,
            roomNumber: '101',
            floor: '1',
            status: RoomStatus.occupied,
          ),
          buildRoom(
            dbId: 2,
            roomNumber: '102',
            floor: '1',
            status: RoomStatus.vacant,
          ),
          buildRoom(
            dbId: 3,
            roomNumber: '103',
            floor: '1',
            status: RoomStatus.maintenance,
          ),
        ];

        expect(occupiedCount(rooms), 1);
        expect(vacantCount(rooms), 1);
      });

      test('UTC-01-TC-08 all counts are 0 when no rooms exist', () {
        expect(occupiedCount([]), 0);
        expect(vacantCount([]), 0);
      });
    });

    group('UTC-01 sortedFloorNumbers', () {
      test('UTC-01-TC-09 returns unique floors sorted numerically', () {
        final rooms = [
          buildRoom(
            dbId: 1,
            roomNumber: '301',
            floor: '3',
            status: RoomStatus.vacant,
          ),
          buildRoom(
            dbId: 2,
            roomNumber: '101',
            floor: '1',
            status: RoomStatus.vacant,
          ),
          buildRoom(
            dbId: 3,
            roomNumber: '102',
            floor: '1',
            status: RoomStatus.occupied,
          ),
          buildRoom(
            dbId: 4,
            roomNumber: '201',
            floor: '2',
            status: RoomStatus.vacant,
          ),
        ];

        expect(sortedFloorNumbers(rooms), ['1', '2', '3']);
      });

      test('UTC-01-TC-10 returns empty list when no rooms exist', () {
        expect(sortedFloorNumbers([]), isEmpty);
      });
    });

    group('UTC-01 shortTenantName', () {
      test('UTC-01-TC-11 returns first word of full name', () {
        expect(shortTenantName('Kongpiphat Lalaka'), 'Kongpiphat');
        expect(shortTenantName('สมชาย ใจดี'), 'สมชาย');
      });

      test('UTC-01-TC-12 returns empty string for null or empty name', () {
        expect(shortTenantName(null), '');
        expect(shortTenantName(''), '');
        expect(shortTenantName('   '), '');
      });
    });

    group('UTC-01 formatDashboardErrorMessage', () {
      test('UTC-01-TC-13 maps SocketException to Thai network message', () {
        expect(
          formatDashboardErrorMessage(
              const SocketException('Failed host lookup')),
          'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
        );
      });

      test('UTC-01-TC-14 strips Exception prefix for non-network errors', () {
        expect(
          formatDashboardErrorMessage(Exception('some error')),
          'some error',
        );
      });
    });
  });
}
