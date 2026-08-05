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
}
