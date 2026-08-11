/// จัดกลุ่มคำขอแจ้งซ่อม/ทำความสะอาดเป็นรายห้อง — Dart ล้วน ไม่แตะเครือข่าย
///
/// อยู่นอก SupabaseService ด้วยเหตุผลเดียวกับ invoice_calculator.dart: ตรรกะ
/// ที่ฝังอยู่ในเมธอดที่เปิดด้วยการเรียก network เขียนเทสต์ไม่ได้เลย
library;

import '../models/models.dart';

/// สถานะที่ถือว่ายังเป็นงานค้าง
const _openStatuses = {
  MaintenanceStatus.pending,
  MaintenanceStatus.inProgress,
};

/// ยุบคำขอทั้งหอให้เหลือห้องละแถว เรียงจากห้องที่แจ้งล่าสุดลงไป
///
/// [requests] ต้องเป็นคำขอของทั้งหอ ไม่ต้องเรียงมาก่อน — ฟังก์ชันนี้หาใบล่าสุด
/// ของแต่ละห้องเอง แทนที่จะเชื่อลำดับที่ผู้เรียกส่งมา เพราะการเชื่อลำดับแปลว่า
/// วันที่ query เปลี่ยน `order` แล้วหน้าจอจะแสดง "คำขอล่าสุด" ที่เป็นใบเก่าสุด
/// โดยไม่มีอะไรพัง
///
/// [floorByRoom] มาจากห้องที่ join มากับคำขอ · ห้องที่ไม่มีชั้นได้สตริงว่าง ซึ่ง
/// ตัวกรองชั้นบนหน้าจอมองข้ามไปเอง
List<RoomMaintenanceSummary> summarizeMaintenanceByRoom({
  required List<MaintenanceRequest> requests,
  required Map<int, String> floorByRoom,
}) {
  final byRoom = <int, List<MaintenanceRequest>>{};
  for (final request in requests) {
    byRoom.putIfAbsent(request.roomId, () => []).add(request);
  }

  final summaries = byRoom.entries.map((entry) {
    final roomRequests = entry.value;
    final latest = roomRequests.reduce(
      (a, b) => b.requestedAt.isAfter(a.requestedAt) ? b : a,
    );

    return RoomMaintenanceSummary(
      roomDbId: entry.key,
      roomNumber: latest.roomNumber,
      floor: floorByRoom[entry.key] ?? '',
      // ชื่อผู้เช่ามาจากคำขอล่าสุด ไม่ใช่ผู้เช่าปัจจุบันของห้อง — รายการนี้เล่า
      // ประวัติ ห้องที่เปลี่ยนผู้เช่าไปแล้วจึงควรขึ้นชื่อคนที่แจ้งจริง
      tenantName: latest.tenantName,
      latest: latest,
      openCount:
          roomRequests.where((r) => _openStatuses.contains(r.status)).length,
      totalCount: roomRequests.length,
    );
  }).toList();

  summaries.sort((a, b) => b.lastRequestedAt.compareTo(a.lastRequestedAt));
  return summaries;
}
