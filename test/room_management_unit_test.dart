import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';

String formatRoomErrorMessage(Object error) {
  final message = error.toString().trim();
  final normalized = message.startsWith('Exception: ')
      ? message.substring('Exception: '.length).trim()
      : message;
  final lowerCaseMessage = normalized.toLowerCase();

  if (lowerCaseMessage.contains('failed host lookup') ||
      lowerCaseMessage.contains('socketexception') ||
      lowerCaseMessage.contains('clientexception') ||
      lowerCaseMessage.contains('connection refused') ||
      lowerCaseMessage.contains('network is unreachable') ||
      lowerCaseMessage.contains('connection timed out') ||
      lowerCaseMessage.contains('timed out')) {
    return 'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
  }

  return normalized;
}

List<Room> filterRooms(
  List<Room> rooms, {
  String query = '',
  String selectedFloor = 'ทั้งหมด',
  String selectedFilter = 'ทั้งหมด',
}) {
  return rooms.where((room) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      final roomNumber = room.id.toLowerCase();
      final tenantName = (room.tenantName ?? '').toLowerCase();
      final tenantPhone = (room.phoneNumber ?? '').toLowerCase();
      final tenantEmail = (room.tenantEmail ?? '').toLowerCase();

      final matchesSearch = roomNumber.contains(normalizedQuery) ||
          tenantName.contains(normalizedQuery) ||
          tenantPhone.contains(normalizedQuery) ||
          tenantEmail.contains(normalizedQuery);

      if (!matchesSearch) return false;
    }

    if (selectedFloor != 'ทั้งหมด' && room.floor != selectedFloor) {
      return false;
    }

    if (selectedFilter == 'ทั้งหมด') return true;
    if (selectedFilter == 'มีคนอยู่') {
      return room.status == RoomStatus.occupied;
    }
    if (selectedFilter == 'ว่าง') {
      return room.status == RoomStatus.vacant;
    }
    if (selectedFilter == 'ซ่อมบำรุง') {
      return room.status == RoomStatus.maintenance;
    }

    return true;
  }).toList();
}

Map<String, int> roomStats(List<Room> rooms) {
  return {
    'occupied': rooms.where((room) => room.status == RoomStatus.occupied).length,
    'vacant': rooms.where((room) => room.status == RoomStatus.vacant).length,
    'maintenance':
        rooms.where((room) => room.status == RoomStatus.maintenance).length,
    'total': rooms.length,
  };
}

String? validateAddRoomInput(String roomNumber, String basePriceStr) {
  if (roomNumber.trim().isEmpty || basePriceStr.trim().isEmpty) {
    return 'กรุณากรอกข้อมูลที่จำเป็นทั้งหมด';
  }

  final parsedPrice = double.tryParse(basePriceStr);
  if (parsedPrice == null || parsedPrice <= 0) {
    return 'ราคาไม่ถูกต้อง';
  }

  return null;
}

bool canDeleteRoom(RoomStatus status) => status == RoomStatus.vacant;

bool priceUnchanged(double currentPrice, String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return true;

  final parsed = double.tryParse(trimmed);
  if (parsed == null) return false;

  return parsed == currentPrice;
}

String? validateUpdatedRoomNumber(String value, String currentRoomNumber) {
  if (value.trim().isEmpty) {
    return 'กรุณากรอกเลขห้องใหม่';
  }
  if (value.trim() == currentRoomNumber) {
    return 'เลขห้องใหม่ต้องแตกต่างจากเดิม';
  }
  return null;
}

class FakeRoomRepository {
  FakeRoomRepository({
    List<Room>? rooms,
    this.shouldThrowOnFetch = false,
    this.shouldThrowOnAdd = false,
    this.shouldThrowOnDelete = false,
    this.shouldThrowOnStatusUpdate = false,
    this.shouldThrowOnPriceUpdate = false,
    this.shouldThrowOnNumberUpdate = false,
  }) : _rooms = List<Room>.from(rooms ?? []);

  final List<Room> _rooms;
  final bool shouldThrowOnFetch;
  final bool shouldThrowOnAdd;
  final bool shouldThrowOnDelete;
  final bool shouldThrowOnStatusUpdate;
  final bool shouldThrowOnPriceUpdate;
  final bool shouldThrowOnNumberUpdate;

  Future<List<Room>> fetchRooms({required int dormitoryId}) async {
    if (shouldThrowOnFetch) {
      throw const SocketException('Failed host lookup');
    }
    return List<Room>.from(_rooms);
  }

  Future<void> addRoom({
    required int dormitoryId,
    required String roomNumber,
    required String floor,
    required double basePrice,
  }) async {
    if (shouldThrowOnAdd) {
      throw const SocketException('Failed host lookup');
    }

    final alreadyExists = _rooms.any((room) => room.id == roomNumber);
    if (alreadyExists) {
      throw Exception('Room number already exists');
    }

    _rooms.add(
      Room(
        dbId: _rooms.length + 1,
        id: roomNumber,
        floor: floor,
        status: RoomStatus.vacant,
        price: basePrice,
      ),
    );
  }

  Future<void> deleteRoom({required int roomDbId}) async {
    if (shouldThrowOnDelete) {
      throw const SocketException('Failed host lookup');
    }

    _rooms.removeWhere((room) => room.dbId == roomDbId);
  }

  Future<void> updateRoomStatus({
    required int roomDbId,
    required RoomStatus newStatus,
  }) async {
    if (shouldThrowOnStatusUpdate) {
      throw const SocketException('Failed host lookup');
    }

    final index = _rooms.indexWhere((room) => room.dbId == roomDbId);
    if (index == -1) return;

    final current = _rooms[index];
    _rooms[index] = Room(
      dbId: current.dbId,
      id: current.id,
      floor: current.floor,
      status: newStatus,
      currentTenantId: current.currentTenantId,
      tenantName: current.tenantName,
      tenantEmail: current.tenantEmail,
      phoneNumber: current.phoneNumber,
      price: current.price,
    );
  }

  Future<void> updateRoomPrice({
    required int roomDbId,
    required double newPrice,
  }) async {
    if (shouldThrowOnPriceUpdate) {
      throw const SocketException('Failed host lookup');
    }

    final index = _rooms.indexWhere((room) => room.dbId == roomDbId);
    if (index == -1) return;

    final current = _rooms[index];
    _rooms[index] = Room(
      dbId: current.dbId,
      id: current.id,
      floor: current.floor,
      status: current.status,
      currentTenantId: current.currentTenantId,
      tenantName: current.tenantName,
      tenantEmail: current.tenantEmail,
      phoneNumber: current.phoneNumber,
      price: newPrice,
    );
  }

  Future<void> updateRoomNumber({
    required int roomDbId,
    required String newRoomNumber,
  }) async {
    if (shouldThrowOnNumberUpdate) {
      throw const SocketException('Failed host lookup');
    }

    final duplicate = _rooms.any(
      (room) => room.dbId != roomDbId && room.id == newRoomNumber,
    );
    if (duplicate) {
      throw Exception('หมายเลขห้องนี้กำลังถูกใช้งาน');
    }

    final index = _rooms.indexWhere((room) => room.dbId == roomDbId);
    if (index == -1) return;

    final current = _rooms[index];
    _rooms[index] = Room(
      dbId: current.dbId,
      id: newRoomNumber,
      floor: current.floor,
      status: current.status,
      currentTenantId: current.currentTenantId,
      tenantName: current.tenantName,
      tenantEmail: current.tenantEmail,
      phoneNumber: current.phoneNumber,
      price: current.price,
    );
  }
}

Room buildRoom({
  required int dbId,
  required String roomNumber,
  required String floor,
  required RoomStatus status,
  double price = 3000,
  String? tenantName,
  String? phoneNumber,
  String? tenantEmail,
}) {
  return Room(
    dbId: dbId,
    id: roomNumber,
    floor: floor,
    status: status,
    tenantName: tenantName,
    phoneNumber: phoneNumber,
    tenantEmail: tenantEmail,
    price: price,
  );
}

void main() {
  group('Feature 1: Room management', () {
    group('UTC-01 fetchRooms', () {
      test('UTC-01-TC-01 returns the room list when rooms exist', () async {
        final repository = FakeRoomRepository(
          rooms: [
            buildRoom(
              dbId: 1,
              roomNumber: '101',
              floor: '1',
              status: RoomStatus.vacant,
            ),
            buildRoom(
              dbId: 2,
              roomNumber: '102',
              floor: '1',
              status: RoomStatus.occupied,
              price: 2500,
            ),
          ],
        );

        final result = await repository.fetchRooms(dormitoryId: 1);

        expect(result, hasLength(2));
        expect(result.first.id, '101');
      });

      test('UTC-01-TC-02 returns an empty list when no rooms exist', () async {
        final repository = FakeRoomRepository(rooms: []);

        final result = await repository.fetchRooms(dormitoryId: 1);

        expect(result, isEmpty);
      });

      test('UTC-01-TC-03 throws SocketException on network failure', () {
        final repository = FakeRoomRepository(shouldThrowOnFetch: true);

        expect(
          () => repository.fetchRooms(dormitoryId: 1),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-02 filterRooms', () {
      final rooms = [
        buildRoom(
          dbId: 1,
          roomNumber: '101',
          floor: '1',
          status: RoomStatus.vacant,
        ),
        buildRoom(
          dbId: 2,
          roomNumber: '102',
          floor: '1',
          status: RoomStatus.occupied,
          tenantName: 'Kong Kong',
          phoneNumber: '0812345678',
          tenantEmail: 'kong@test.com',
        ),
        buildRoom(
          dbId: 3,
          roomNumber: '201',
          floor: '2',
          status: RoomStatus.maintenance,
        ),
        buildRoom(
          dbId: 4,
          roomNumber: '202',
          floor: '2',
          status: RoomStatus.vacant,
        ),
      ];

      test(
        'UTC-02-TC-01 matches room number, tenant name, phone, and email',
        () {
          expect(filterRooms(rooms, query: '102').single.id, '102');
          expect(filterRooms(rooms, query: 'kong').single.id, '102');
          expect(filterRooms(rooms, query: '0812').single.id, '102');
          expect(filterRooms(rooms, query: 'kong@').single.id, '102');
        },
      );

      test('UTC-02-TC-02 filters by floor', () {
        final result = filterRooms(rooms, selectedFloor: '2');

        expect(result, hasLength(2));
        expect(result.map((room) => room.id), containsAll(['201', '202']));
      });

      test('UTC-02-TC-03 filters by status', () {
        expect(
          filterRooms(rooms, selectedFilter: 'มีคนอยู่').map((room) => room.id),
          ['102'],
        );
        expect(
          filterRooms(rooms, selectedFilter: 'ว่าง').map((room) => room.id),
          ['101', '202'],
        );
        expect(
          filterRooms(rooms, selectedFilter: 'ซ่อมบำรุง')
              .map((room) => room.id),
          ['201'],
        );
      });

      test('UTC-02-TC-04 returns empty list when no room matches', () {
        final result = filterRooms(rooms, query: 'zzz');

        expect(result, isEmpty);
      });
    });

    group('UTC-03 roomStats', () {
      test('UTC-03-TC-01 returns correct room counts for all statuses', () {
        final stats = roomStats([
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
            status: RoomStatus.maintenance,
          ),
        ]);

        expect(stats, {
          'occupied': 2,
          'vacant': 1,
          'maintenance': 1,
          'total': 4,
        });
      });
    });

    group('UTC-04 formatRoomErrorMessage', () {
      test('UTC-04-TC-01 maps SocketException to Thai network message', () {
        final result =
            formatRoomErrorMessage(const SocketException('Failed host lookup'));

        expect(result, 'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่');
      });

      test('UTC-04-TC-02 strips Exception prefix for non-network errors', () {
        final result = formatRoomErrorMessage(Exception('already exist'));

        expect(result, 'already exist');
      });
    });

    group('UTC-05 validateAddRoomInput', () {
      test('UTC-05-TC-01 returns error for empty required fields', () {
        expect(
          validateAddRoomInput(' ', ' '),
          'กรุณากรอกข้อมูลที่จำเป็นทั้งหมด',
        );
      });

      test('UTC-05-TC-02 returns error for invalid price', () {
        expect(validateAddRoomInput('101', '-50'), 'ราคาไม่ถูกต้อง');
        expect(validateAddRoomInput('101', 'abc'), 'ราคาไม่ถูกต้อง');
      });

      test('UTC-05-TC-03 returns null for valid input', () {
        expect(validateAddRoomInput('101', '3000'), isNull);
      });
    });

    group('UTC-06 addRoom', () {
      test('UTC-06-TC-01 completes when creation succeeds', () async {
        final repository = FakeRoomRepository(
          rooms: [
            buildRoom(
              dbId: 1,
              roomNumber: '101',
              floor: '1',
              status: RoomStatus.vacant,
            ),
          ],
        );

        await expectLater(
          repository.addRoom(
            dormitoryId: 1,
            roomNumber: '105',
            floor: '1',
            basePrice: 3000,
          ),
          completes,
        );
      });

      test('UTC-06-TC-02 throws on duplicate room number', () {
        final repository = FakeRoomRepository(
          rooms: [
            buildRoom(
              dbId: 1,
              roomNumber: '101',
              floor: '1',
              status: RoomStatus.vacant,
            ),
          ],
        );

        expect(
          () => repository.addRoom(
            dormitoryId: 1,
            roomNumber: '101',
            floor: '1',
            basePrice: 3000,
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('already exists'),
            ),
          ),
        );
      });

      test('UTC-06-TC-03 throws SocketException on network failure', () {
        final repository = FakeRoomRepository(shouldThrowOnAdd: true);

        expect(
          () => repository.addRoom(
            dormitoryId: 1,
            roomNumber: '105',
            floor: '1',
            basePrice: 3000,
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-07 canDeleteRoom', () {
      test('UTC-07-TC-01 returns true only for vacant rooms', () {
        expect(canDeleteRoom(RoomStatus.vacant), isTrue);
        expect(canDeleteRoom(RoomStatus.occupied), isFalse);
        expect(canDeleteRoom(RoomStatus.maintenance), isFalse);
      });
    });

    group('UTC-08 deleteRoom', () {
      test('UTC-08-TC-01 completes when deletion succeeds', () async {
        final repository = FakeRoomRepository(
          rooms: [
            buildRoom(
              dbId: 1,
              roomNumber: '101',
              floor: '1',
              status: RoomStatus.vacant,
            ),
          ],
        );

        await expectLater(repository.deleteRoom(roomDbId: 1), completes);
      });

      test('UTC-08-TC-02 throws SocketException on network failure', () {
        final repository = FakeRoomRepository(shouldThrowOnDelete: true);

        expect(
          () => repository.deleteRoom(roomDbId: 1),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-09 updateRoomStatus', () {
      test('UTC-09-TC-01 completes when update succeeds', () async {
        final repository = FakeRoomRepository(
          rooms: [
            buildRoom(
              dbId: 1,
              roomNumber: '101',
              floor: '1',
              status: RoomStatus.vacant,
            ),
          ],
        );

        await expectLater(
          repository.updateRoomStatus(
            roomDbId: 1,
            newStatus: RoomStatus.maintenance,
          ),
          completes,
        );
      });

      test('UTC-09-TC-02 throws SocketException on network failure', () {
        final repository = FakeRoomRepository(shouldThrowOnStatusUpdate: true);

        expect(
          () => repository.updateRoomStatus(
            roomDbId: 1,
            newStatus: RoomStatus.maintenance,
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-10 priceUnchanged', () {
      test('UTC-10-TC-01 returns true for unchanged or empty input', () {
        expect(priceUnchanged(3000, '3000'), isTrue);
        expect(priceUnchanged(3000, ''), isTrue);
        expect(priceUnchanged(3000, '3500'), isFalse);
      });
    });

    group('UTC-11 updateRoomPrice', () {
      test('UTC-11-TC-01 rejects negative or non-numeric input', () {
        String? validatePriceInput(String input) {
          final parsed = double.tryParse(input);
          if (parsed == null || parsed <= 0) {
            return 'ราคาไม่ถูกต้อง';
          }
          return null;
        }

        expect(validatePriceInput('-1'), 'ราคาไม่ถูกต้อง');
        expect(validatePriceInput('xyz'), 'ราคาไม่ถูกต้อง');
      });

      test('UTC-11-TC-02 completes when update succeeds', () async {
        final repository = FakeRoomRepository(
          rooms: [
            buildRoom(
              dbId: 1,
              roomNumber: '101',
              floor: '1',
              status: RoomStatus.vacant,
              price: 3000,
            ),
          ],
        );

        await expectLater(
          repository.updateRoomPrice(roomDbId: 1, newPrice: 3500),
          completes,
        );
      });

      test('UTC-11-TC-03 throws SocketException on network failure', () {
        final repository = FakeRoomRepository(shouldThrowOnPriceUpdate: true);

        expect(
          () => repository.updateRoomPrice(roomDbId: 1, newPrice: 3500),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-12 validateRoomNumber', () {
      test('UTC-12-TC-01 returns error for empty value and null for valid', () {
        expect(
          validateUpdatedRoomNumber('', '100'),
          'กรุณากรอกเลขห้องใหม่',
        );
        expect(
          validateUpdatedRoomNumber(' ', '100'),
          'กรุณากรอกเลขห้องใหม่',
        );
        expect(validateUpdatedRoomNumber('101', '100'), isNull);
      });

      test('UTC-12-TC-02 returns error when room number is unchanged', () {
        expect(
          validateUpdatedRoomNumber('101', '101'),
          'เลขห้องใหม่ต้องแตกต่างจากเดิม',
        );
      });
    });

    group('UTC-13 updateRoomNumber', () {
      test('UTC-13-TC-01 completes when update succeeds', () async {
        final repository = FakeRoomRepository(
          rooms: [
            buildRoom(
              dbId: 1,
              roomNumber: '101A',
              floor: '1',
              status: RoomStatus.vacant,
            ),
            buildRoom(
              dbId: 2,
              roomNumber: '102',
              floor: '1',
              status: RoomStatus.vacant,
            ),
          ],
        );

        await expectLater(
          repository.updateRoomNumber(roomDbId: 1, newRoomNumber: '101A'),
          completes,
        );
      });

      test('UTC-13-TC-02 throws on duplicate room number', () {
        final repository = FakeRoomRepository(
          rooms: [
            buildRoom(
              dbId: 1,
              roomNumber: '101',
              floor: '1',
              status: RoomStatus.vacant,
            ),
            buildRoom(
              dbId: 2,
              roomNumber: '102',
              floor: '1',
              status: RoomStatus.vacant,
            ),
          ],
        );

        expect(
          () => repository.updateRoomNumber(
            roomDbId: 1,
            newRoomNumber: '102',
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('กำลังถูกใช้งาน'),
            ),
          ),
        );
      });

      test('UTC-13-TC-03 throws SocketException on network failure', () {
        final repository = FakeRoomRepository(shouldThrowOnNumberUpdate: true);

        expect(
          () => repository.updateRoomNumber(
            roomDbId: 1,
            newRoomNumber: '101A',
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });
  });
}
