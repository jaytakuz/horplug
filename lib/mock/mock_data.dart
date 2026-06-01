import '../models/models.dart';

class MockData {
  static List<Room> rooms = [
    Room(
      dbId: 1,
      id: "101",
      floor: "1",
      status: RoomStatus.occupied,
      tenantName: "คุณตั้ม",
      phoneNumber: "081-111-1111",
      price: 2500,
    ),
    Room(
      dbId: 2,
      id: "102",
      floor: "1",
      status: RoomStatus.vacant,
      price: 2500,
    ),
    Room(
      dbId: 3,
      id: "103",
      floor: "1",
      status: RoomStatus.occupied,
      tenantName: "คุณนิดหน่อย",
      phoneNumber: "082-222-2222",
      price: 2500,
    ),
  ];

  static List<Invoice> invoices = [
    Invoice(
        id: "INV001",
        roomNumber: "305",
        tenantName: "คุณฟ้า",
        waterUnits: 12,
        electricityUnits: 85,
        roomPrice: 3500,
        waterCost: 216,
        electricityCost: 680,
        status: InvoiceStatus.pending,
        date: DateTime.now(),
        hasSlip: true),
    Invoice(
        id: "INV002",
        roomNumber: "101",
        tenantName: "คุณตั้ม",
        waterUnits: 8,
        electricityUnits: 120,
        roomPrice: 3500,
        waterCost: 144,
        electricityCost: 960,
        status: InvoiceStatus.unpaid,
        date: DateTime.now()),
    Invoice(
        id: "INV003",
        roomNumber: "201",
        tenantName: "คุณบี",
        waterUnits: 10,
        electricityUnits: 95,
        roomPrice: 3700,
        waterCost: 180,
        electricityCost: 760,
        status: InvoiceStatus.paid,
        date: DateTime.now()),
  ];

  static List<ElectricityRecord> mockElectricityReadings = rooms
      .where((r) => r.status == RoomStatus.occupied)
      .map((r) => ElectricityRecord(
          roomDbId: r.dbId,
          roomNumber: r.id,
          tenantName: r.tenantName,
          billingMonth: DateTime.now().month,
          billingYear: DateTime.now().year,
          previousReading: 1200,
          currentReading: 1250,
          unitRate: 8.0))
      .toList();

  static List<WaterRecord> mockWaterReadings = rooms
      .where((r) => r.status == RoomStatus.occupied)
      .map((r) => WaterRecord(
          roomDbId: r.dbId,
          roomNumber: r.id,
          tenantName: r.tenantName,
          billingMonth: DateTime.now().month,
          billingYear: DateTime.now().year,
          amount: 100.0))
      .toList();

  static List<ChatPreview> chatPreviews = [
    ChatPreview(
        roomNumber: "305",
        tenantName: "คุณฟ้า",
        lastMessage: "ส่งสลิปโอนเงินแล้วค่ะ",
        unreadCount: 0,
        hasPendingMaintenance: true),
    ChatPreview(
        roomNumber: "103",
        tenantName: "คุณนิดหน่อย",
        lastMessage: "ก๊อกน้ำรั่วค่ะ ช่วยมาดูหน่อย",
        unreadCount: 2,
        hasPendingMaintenance: true),
    ChatPreview(
        roomNumber: "204",
        tenantName: "คุณกอล์ฟ",
        lastMessage: "ขอบคุณครับ",
        unreadCount: 0),
  ];

  static List<ChatMessage> conversation305 = [
    ChatMessage(
        id: "m1",
        senderName: "คุณฟ้า",
        text: "สวัสดีค่ะคุณลุงศักดิ์ แจ้งซ่อมแอร์หน่อยค่ะ",
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isFromOwner: false,
        type: MessageType.maintenanceRequest),
    ChatMessage(
        id: "m2",
        senderName: "คุณลุงศักดิ์",
        text: "รับทราบครับ เดี๋ยวให้ช่างเข้าไปพรุ่งนี้บ่ายนะครับ",
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 22)),
        isFromOwner: true),
    ChatMessage(
        id: "m3",
        senderName: "คุณลุงศักดิ์",
        text: "ช่างกำลังเข้าไปนะครับ",
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        isFromOwner: true,
        type: MessageType.maintenanceUpdate),
    ChatMessage(
        id: "m4",
        senderName: "คุณฟ้า",
        text: "ส่งสลิปโอนเงินแล้วค่ะ",
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isFromOwner: false),
  ];
}
