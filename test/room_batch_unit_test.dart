import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/services/room_batch.dart';

void main() {
  group('roomNumberFor', () {
    test('ชั้นเดียวหลัก ได้เลขสามหลัก', () {
      expect(roomNumberFor(floor: 1, index: 1), '101');
      expect(roomNumberFor(floor: 1, index: 12), '112');
      expect(roomNumberFor(floor: 7, index: 12), '712');
    });

    // ชั้นสิบขึ้นไปต้องได้เลขสี่หลัก ไม่งั้น "ชั้น 10 ห้อง 1" กับ "ชั้น 1 ห้อง 01"
    // จะกลายเป็น 101 เหมือนกัน แล้วชนกันตอนสร้าง
    test('ชั้นสองหลัก ได้เลขสี่หลัก ไม่ชนกับชั้นเดียวหลัก', () {
      expect(roomNumberFor(floor: 10, index: 1), '1001');
      expect(roomNumberFor(floor: 12, index: 12), '1212');
      expect(
        roomNumberFor(floor: 10, index: 1),
        isNot(roomNumberFor(floor: 1, index: 1)),
      );
    });

    // เลขห้องที่ล้นเกินสองหลักจะไปกินหลักของชั้น: ชั้น 1 ห้องที่ 101 ได้ 1101
    // ซึ่งเป็นเลขเดียวกับชั้น 11 ห้องที่ 1 · generateRooms กันไว้ไม่ให้เกิดขึ้น
    test('เลขห้องเกินสองหลักไปชนกับชั้นอื่น จึงต้องมีเพดาน', () {
      expect(
        roomNumberFor(floor: 1, index: 101),
        roomNumberFor(floor: 11, index: 1),
        reason: 'การชนนี้คือเหตุผลที่ maxRoomsPerFloor มีอยู่',
      );
    });
  });

  group('generateRooms', () {
    test('ชั้นเดียว ห้องเรียงตามลำดับ', () {
      final rooms = generateRooms(fromFloor: 1, toFloor: 1, roomsPerFloor: 3);

      expect(rooms.map((r) => r.number), ['101', '102', '103']);
      expect(rooms.every((r) => r.floor == '1'), isTrue);
    });

    test('เจ็ดชั้น สิบสองห้อง ได้ครบแปดสิบสี่ห้อง', () {
      final rooms = generateRooms(fromFloor: 1, toFloor: 7, roomsPerFloor: 12);

      expect(rooms, hasLength(84));
      expect(rooms.first.number, '101');
      expect(rooms.last.number, '712');
      expect(rooms.map((r) => r.number).toSet(), hasLength(84));
    });

    test('เริ่มจากชั้นกลางได้ สำหรับหอที่ต่อเติมชั้นใหม่', () {
      final rooms = generateRooms(fromFloor: 8, toFloor: 9, roomsPerFloor: 2);

      expect(rooms.map((r) => r.number), ['801', '802', '901', '902']);
    });

    // หน้าจอเรียกทุกครั้งที่ผู้ใช้พิมพ์ รวมถึงตอนที่ยังพิมพ์ไม่เสร็จ
    test('ค่าที่ใช้ไม่ได้คืนลิสต์ว่าง ไม่โยน', () {
      expect(generateRooms(fromFloor: 0, toFloor: 5, roomsPerFloor: 2), isEmpty);
      expect(generateRooms(fromFloor: 5, toFloor: 1, roomsPerFloor: 2), isEmpty);
      expect(generateRooms(fromFloor: 1, toFloor: 5, roomsPerFloor: 0), isEmpty);
    });

    test('ห้องต่อชั้นเกินเพดานถูกปฏิเสธ ไม่ปล่อยให้เลขชนกันเอง', () {
      expect(
        generateRooms(
            fromFloor: 1, toFloor: 1, roomsPerFloor: maxRoomsPerFloor),
        hasLength(maxRoomsPerFloor),
      );
      expect(
        generateRooms(
            fromFloor: 1, toFloor: 1, roomsPerFloor: maxRoomsPerFloor + 1),
        isEmpty,
      );
    });

    test('ชั้นเกินเพดานถูกปฏิเสธ ไม่ปล่อยให้ปั่นห้องเป็นแสน', () {
      expect(
        generateRooms(fromFloor: 1, toFloor: maxFloor, roomsPerFloor: 1),
        hasLength(maxFloor),
      );
      // เคสจริงที่ทำให้จอค้าง: ตั้งใจพิมพ์ "8" แล้วมือลั่นเป็น "8123"
      expect(
        generateRooms(fromFloor: 1, toFloor: 8123, roomsPerFloor: 12),
        isEmpty,
      );
    });

    test('เลขห้องไม่ซ้ำกันเลยในทุกช่วงชั้นที่รองรับ', () {
      final rooms = generateRooms(
        fromFloor: 1,
        toFloor: maxFloor,
        roomsPerFloor: maxRoomsPerFloor,
      );

      expect(rooms.map((r) => r.number).toSet(), hasLength(rooms.length));
    });

    test('ชั้นเดียวกันต้นทางปลายทาง ได้ชั้นนั้นชั้นเดียว', () {
      final rooms = generateRooms(fromFloor: 3, toFloor: 3, roomsPerFloor: 2);

      expect(rooms.map((r) => r.number), ['301', '302']);
    });
  });

  group('planRoomBatch', () {
    // การ insert เป็นชุดเดียว แถวที่ชนกันแถวเดียวจะพาทั้งชุดตกไปด้วย การกรอง
    // จึงต้องเกิดก่อนถึงฐานข้อมูล
    test('ข้ามห้องที่มีอยู่แล้ว และบอกว่าข้ามอันไหน', () {
      final plan = planRoomBatch(
        candidates: generateRooms(fromFloor: 1, toFloor: 1, roomsPerFloor: 3),
        existingRoomNumbers: ['102'],
      );

      expect(plan.toCreate.map((r) => r.number), ['101', '103']);
      expect(plan.skipped, ['102']);
      expect(plan.total, 3);
      expect(plan.hasAnythingToCreate, isTrue);
    });

    test('หอที่ยังไม่มีห้องเลย สร้างได้ทั้งหมด', () {
      final plan = planRoomBatch(
        candidates: generateRooms(fromFloor: 1, toFloor: 2, roomsPerFloor: 2),
        existingRoomNumbers: const [],
      );

      expect(plan.toCreate, hasLength(4));
      expect(plan.skipped, isEmpty);
    });

    test('ทุกห้องมีอยู่แล้ว ไม่มีอะไรให้สร้าง', () {
      final plan = planRoomBatch(
        candidates: generateRooms(fromFloor: 1, toFloor: 1, roomsPerFloor: 2),
        existingRoomNumbers: ['101', '102'],
      );

      expect(plan.hasAnythingToCreate, isFalse);
      expect(plan.skipped, ['101', '102']);
    });

    test('เลขห้องเดิมที่มีช่องว่างติดมาก็ยังถือว่าซ้ำ', () {
      final plan = planRoomBatch(
        candidates: generateRooms(fromFloor: 1, toFloor: 1, roomsPerFloor: 2),
        existingRoomNumbers: [' 101 '],
      );

      expect(plan.skipped, ['101']);
    });

    // เคสจริงของหอที่ใช้ระบบอยู่: มีห้อง 101 แล้ว สมัครไว้ 7 ชั้น 12 ห้อง
    test('หอที่มีห้องเดียวอยู่แล้ว สร้างที่เหลือได้ครบ', () {
      final plan = planRoomBatch(
        candidates: generateRooms(fromFloor: 1, toFloor: 7, roomsPerFloor: 12),
        existingRoomNumbers: ['101'],
      );

      expect(plan.toCreate, hasLength(83));
      expect(plan.skipped, ['101']);
      expect(plan.toCreate.map((r) => r.number).contains('101'), isFalse);
    });
  });
}
