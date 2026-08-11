/// สร้างรายการห้องแบบเป็นชุด สำหรับหอที่เพิ่งเปิดหรือเพิ่งต่อเติมชั้นใหม่
///
/// แยกออกมาเป็นฟังก์ชันบริสุทธิ์เพราะกฎการรันเลขห้องเป็นเรื่องที่ผิดได้เงียบๆ
/// (ชั้นสองหลัก, ห้องเกินเก้าสิบเก้าห้องต่อชั้น) และการทดสอบมันไม่ควรต้องมี
/// ฐานข้อมูล
library;

/// ห้องหนึ่งห้องที่กำลังจะถูกสร้าง
typedef PlannedRoom = ({String number, String floor});

/// เลขห้องมาตรฐาน: หมายเลขชั้นตามด้วยลำดับห้องสองหลัก
///
/// ชั้น 1 ห้องที่ 2 เป็น `102` · ชั้น 7 ห้องที่ 12 เป็น `712`
///
/// ชั้นที่เกินเก้าขึ้นไปได้เลขสี่หลักตามธรรมเนียมอาคารไทย — ชั้น 10 ห้องที่ 1
/// เป็น `1001` ไม่ใช่ `101` ซึ่งจะไปชนกับชั้น 1 ห้องที่ 1
String roomNumberFor({required int floor, required int index}) =>
    '$floor${index.toString().padLeft(2, '0')}';

/// จำนวนห้องต่อชั้นสูงสุดที่รูปแบบเลขนี้รองรับ
///
/// เกินกว่านี้เลขจะล้นไปกินหลักของชั้น: ชั้น 1 ห้องที่ 101 ได้ `1101` ซึ่งเป็น
/// เลขเดียวกับชั้น 11 ห้องที่ 1 — หอที่มีทั้งสองอย่างจะได้ห้องซ้ำโดยไม่มีอะไร
/// เตือน · หอจริงไม่มีร้อยห้องต่อชั้นอยู่แล้ว การกันไว้จึงไม่ตัดอะไรที่ใช้ได้จริง
const maxRoomsPerFloor = 99;

/// ชั้นสูงสุดที่ยอมให้ระบุ
///
/// ตึกที่สูงที่สุดในไทยมี 78 ชั้น หอพักไม่มีทางใกล้เคียง · ที่ต้องมีเพดานเพราะ
/// หน้าจอสร้างแผนใหม่ทุกครั้งที่พิมพ์ ผู้ใช้ที่ตั้งใจพิมพ์ "8" แล้วมือลั่นเป็น
/// "8123" จะสั่งให้สร้าง tuple เกือบแสนตัวระหว่างทาง — จอค้างก่อนจะได้ลบทิ้ง
const maxFloor = 99;

/// รายการห้องทั้งหมดของช่วงชั้นที่ระบุ
///
/// [fromFloor] ถึง [toFloor] รวมปลายทั้งสองข้าง · คืนลิสต์ว่างเมื่อช่วงกลับหัว
/// เกินเพดาน หรือจำนวนห้องต่อชั้นไม่ถึงหนึ่ง แทนที่จะโยน เพราะหน้าจอเรียกใช้
/// ทุกครั้งที่ผู้ใช้พิมพ์ รวมถึงตอนที่ยังพิมพ์ไม่เสร็จ
List<PlannedRoom> generateRooms({
  required int fromFloor,
  required int toFloor,
  required int roomsPerFloor,
}) {
  if (fromFloor < 1 || toFloor < fromFloor || toFloor > maxFloor) {
    return const [];
  }
  if (roomsPerFloor < 1 || roomsPerFloor > maxRoomsPerFloor) return const [];

  return [
    for (var floor = fromFloor; floor <= toFloor; floor++)
      for (var index = 1; index <= roomsPerFloor; index++)
        (
          number: roomNumberFor(floor: floor, index: index),
          floor: '$floor',
        ),
  ];
}

/// ผลของการเทียบรายการที่จะสร้าง กับห้องที่มีอยู่แล้ว
class RoomBatchPlan {
  const RoomBatchPlan({required this.toCreate, required this.skipped});

  /// ห้องที่จะถูกสร้างจริง
  final List<PlannedRoom> toCreate;

  /// เลขห้องที่ข้ามเพราะมีอยู่แล้ว
  ///
  /// ต้องบอกให้เห็น ไม่ใช่ข้ามเงียบๆ — เจ้าของหอที่กดสร้าง 84 ห้องแล้วได้ 83
  /// ห้องต้องรู้ว่าห้องไหนหายไปและเพราะอะไร
  final List<String> skipped;

  int get total => toCreate.length + skipped.length;
  bool get hasAnythingToCreate => toCreate.isNotEmpty;
}

/// เทียบห้องที่จะสร้างกับเลขห้องที่มีอยู่ในหอแล้ว
///
/// การเทียบทำที่นี่ ไม่ใช่ปล่อยให้ฐานข้อมูลปฏิเสธทีละแถว เพราะหน้าจอต้องบอก
/// ล่วงหน้าได้ว่าจะเกิดอะไรก่อนผู้ใช้กดยืนยัน — และเพราะการ insert เป็นชุดเดียว
/// แถวที่ชนกันแถวเดียวจะพาทั้งชุดตกไปด้วย
RoomBatchPlan planRoomBatch({
  required List<PlannedRoom> candidates,
  required Iterable<String> existingRoomNumbers,
}) {
  final existing = existingRoomNumbers.map((number) => number.trim()).toSet();
  final toCreate = <PlannedRoom>[];
  final skipped = <String>[];

  for (final room in candidates) {
    if (existing.contains(room.number)) {
      skipped.add(room.number);
    } else {
      toCreate.add(room);
    }
  }

  return RoomBatchPlan(toCreate: toCreate, skipped: skipped);
}
