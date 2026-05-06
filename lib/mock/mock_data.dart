import '../models/models.dart';

class MockData {
  static List<Room> rooms = [
    // Floor 1
    Room(id: "101", floor: "1", status: RoomStatus.occupied, tenantName: "คุณตั้ม", phoneNumber: "081-111-XXXX", price: 3500),
    Room(id: "102", floor: "1", status: RoomStatus.vacant, price: 3500),
    Room(id: "103", floor: "1", status: RoomStatus.occupied, tenantName: "คุณนิดหน่อย", phoneNumber: "082-222-XXXX", price: 3500),
    Room(id: "104", floor: "1", status: RoomStatus.occupied, tenantName: "คุณจอย", phoneNumber: "083-333-XXXX", price: 3500),
    Room(id: "105", floor: "1", status: RoomStatus.maintenance, price: 3500),
    Room(id: "106", floor: "1", status: RoomStatus.occupied, tenantName: "คุณเอก", phoneNumber: "084-444-XXXX", price: 3500),
    // Floor 2
    Room(id: "201", floor: "2", status: RoomStatus.occupied, tenantName: "คุณบี", phoneNumber: "085-555-XXXX", price: 3700),
    Room(id: "202", floor: "2", status: RoomStatus.occupied, tenantName: "คุณแอน", phoneNumber: "086-666-XXXX", price: 3700),
    Room(id: "203", floor: "2", status: RoomStatus.vacant, price: 3700),
    Room(id: "204", floor: "2", status: RoomStatus.occupied, tenantName: "คุณกอล์ฟ", phoneNumber: "087-777-XXXX", price: 3700),
    Room(id: "205", floor: "2", status: RoomStatus.occupied, tenantName: "คุณหยก", phoneNumber: "088-888-XXXX", price: 3700),
    Room(id: "206", floor: "2", status: RoomStatus.occupied, tenantName: "คุณนิว", phoneNumber: "089-999-XXXX", price: 3700),
    Room(id: "207", floor: "2", status: RoomStatus.vacant, price: 3700),
    // Floor 3
    Room(id: "301", floor: "3", status: RoomStatus.occupied, tenantName: "คุณเก่ง", phoneNumber: "090-000-XXXX", price: 4000),
    Room(id: "302", floor: "3", status: RoomStatus.occupied, tenantName: "คุณแอม", phoneNumber: "091-111-XXXX", price: 4000),
    Room(id: "303", floor: "3", status: RoomStatus.vacant, price: 4000),
    Room(id: "304", floor: "3", status: RoomStatus.occupied, tenantName: "คุณเจ", phoneNumber: "092-222-XXXX", price: 4000),
    Room(id: "305", floor: "3", status: RoomStatus.occupied, tenantName: "คุณฟ้า", phoneNumber: "089-XXX-XXXX", price: 4000),
    Room(id: "306", floor: "3", status: RoomStatus.occupied, tenantName: "คุณปลา", phoneNumber: "093-333-XXXX", price: 4000),
    Room(id: "307", floor: "3", status: RoomStatus.maintenance, price: 4000),
  ];

  static List<Invoice> invoices = [
    Invoice(id: "INV001", roomNumber: "305", tenantName: "คุณฟ้า", waterUnits: 12, electricityUnits: 85, roomPrice: 3500, status: InvoiceStatus.pending, date: DateTime.now(), hasSlip: true),
    Invoice(id: "INV002", roomNumber: "101", tenantName: "คุณตั้ม", waterUnits: 8, electricityUnits: 120, roomPrice: 3500, status: InvoiceStatus.unpaid, date: DateTime.now()),
    Invoice(id: "INV003", roomNumber: "201", tenantName: "คุณบี", waterUnits: 10, electricityUnits: 95, roomPrice: 3700, status: InvoiceStatus.paid, date: DateTime.now()),
  ];

  static List<MeterReading> electricityReadings = rooms.where((r) => r.status == RoomStatus.occupied).map((r) => MeterReading(roomNumber: r.id, tenantName: r.tenantName ?? "", previousValue: 1200)).toList();
  static List<MeterReading> waterReadings = rooms.where((r) => r.status == RoomStatus.occupied).map((r) => MeterReading(roomNumber: r.id, tenantName: r.tenantName ?? "", previousValue: 500)).toList();

  static List<ChatPreview> chatPreviews = [
    ChatPreview(roomNumber: "305", tenantName: "คุณฟ้า", lastMessage: "ส่งสลิปโอนเงินแล้วค่ะ", unreadCount: 0, hasPendingMaintenance: true),
    ChatPreview(roomNumber: "103", tenantName: "คุณนิดหน่อย", lastMessage: "ก๊อกน้ำรั่วค่ะ ช่วยมาดูหน่อย", unreadCount: 2, hasPendingMaintenance: true),
    ChatPreview(roomNumber: "204", tenantName: "คุณกอล์ฟ", lastMessage: "ขอบคุณครับ", unreadCount: 0),
  ];

  static List<ChatMessage> conversation305 = [
    ChatMessage(id: "m1", senderName: "คุณฟ้า", text: "สวัสดีค่ะคุณลุงศักดิ์ แจ้งซ่อมแอร์หน่อยค่ะ", timestamp: DateTime.now().subtract(const Duration(days: 2)), isFromOwner: false, type: MessageType.maintenanceRequest),
    ChatMessage(id: "m2", senderName: "คุณลุงศักดิ์", text: "รับทราบครับ เดี๋ยวให้ช่างเข้าไปพรุ่งนี้บ่ายนะครับ", timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 22)), isFromOwner: true),
    ChatMessage(id: "m3", senderName: "คุณลุงศักดิ์", text: "ช่างกำลังเข้าไปนะครับ", timestamp: DateTime.now().subtract(const Duration(hours: 4)), isFromOwner: true, type: MessageType.maintenanceUpdate),
    ChatMessage(id: "m4", senderName: "คุณฟ้า", text: "ส่งสลิปโอนเงินแล้วค่ะ", timestamp: DateTime.now().subtract(const Duration(minutes: 30)), isFromOwner: false),
  ];
}
