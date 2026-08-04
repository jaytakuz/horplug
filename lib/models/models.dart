enum RoomStatus { occupied, vacant, maintenance }

enum InvoiceStatus { unpaid, pending, paid, voided }

/// เหตุผลที่ห้องหนึ่งออกบิลในงวดนี้ไม่ได้
enum SkipReason { noTenant, noMeterReading, alreadyIssued }

/// ค่ามิเตอร์ที่คำนวณเสร็จแล้วหนึ่งชนิด — แยกออกมาเพื่อให้ buildDraft
/// รับข้อมูลที่มีชนิดชัดเจนแทน Map ดิบจาก PostgREST
class MeterCharge {
  final double units;
  final double amount;

  const MeterCharge({required this.units, required this.amount});
}

enum MessageType {
  text,
  maintenanceRequest,
  parcelNotification,
  maintenanceUpdate,
  image,
  cleaningRequest,
  cleaningUpdate,
}

enum AppRole { landlord, tenant }

enum JoinRequestStatus { pending, accepted, rejected, cancelled }

class UserProfile {
  final String id;
  final AppRole role;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final int? dormitoryId;
  final String? dormitoryName;
  final int? dormitoryTotalFloors;
  final int? roomId;
  final String? roomNumber;

  const UserProfile({
    required this.id,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.dormitoryId,
    this.dormitoryName,
    this.dormitoryTotalFloors,
    this.roomId,
    this.roomNumber,
  });

  String get fullName => '$firstName $lastName'.trim();

  UserProfile copyWith({
    String? id,
    AppRole? role,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    int? dormitoryId,
    String? dormitoryName,
    int? dormitoryTotalFloors,
    int? roomId,
    String? roomNumber,
    bool clearDormitoryId = false,
    bool clearDormitoryName = false,
    bool clearDormitoryTotalFloors = false,
    bool clearRoomId = false,
    bool clearRoomNumber = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dormitoryId: clearDormitoryId ? null : (dormitoryId ?? this.dormitoryId),
      dormitoryName:
          clearDormitoryName ? null : (dormitoryName ?? this.dormitoryName),
      dormitoryTotalFloors: clearDormitoryTotalFloors
          ? null
          : (dormitoryTotalFloors ?? this.dormitoryTotalFloors),
      roomId: clearRoomId ? null : (roomId ?? this.roomId),
      roomNumber: clearRoomNumber ? null : (roomNumber ?? this.roomNumber),
    );
  }
}

class Room {
  final int dbId;
  final String id;
  final String floor;
  final RoomStatus status;
  final String? currentTenantId;
  final String? tenantName;
  final String? tenantEmail;
  final String? phoneNumber;
  final double price;

  Room({
    required this.dbId,
    required this.id,
    required this.floor,
    required this.status,
    this.currentTenantId,
    this.tenantName,
    this.tenantEmail,
    this.phoneNumber,
    required this.price,
  });
}

class Tenant {
  final String id;
  final String name;
  final String roomNumber;
  final String? email;
  final String phoneNumber;

  Tenant({
    required this.id,
    required this.name,
    this.roomNumber = '',
    this.email,
    required this.phoneNumber,
  });
}

class Invoice {
  final String id;
  final String roomNumber;
  final String tenantName;
  final double waterUnits;
  final double electricityUnits;
  final double roomPrice;
  final double waterCost;
  final double electricityCost;
  final double cleaningFee;
  final InvoiceStatus status;
  final DateTime date;
  final bool hasSlip;

  Invoice({
    required this.id,
    required this.roomNumber,
    required this.tenantName,
    required this.waterUnits,
    required this.electricityUnits,
    required this.roomPrice,
    required this.waterCost,
    required this.electricityCost,
    this.cleaningFee = 0,
    required this.status,
    required this.date,
    this.hasSlip = false,
  });

  double get total => roomPrice + waterCost + electricityCost + cleaningFee;
}

/// ร่างบิลที่คำนวณสดจากมิเตอร์ ยังไม่มีตัวตนในฐานข้อมูล
///
/// แยกจาก [Invoice] ที่เป็นแถวจริง เพื่อให้ compiler ปฏิเสธการเผลอเอาตัวเลข
/// ที่คำนวณสดไปแสดงหรือไปพิมพ์ลง PDF แทนตัวเลขที่ตรึงไว้
class InvoiceDraft {
  final int roomDbId;
  final String roomNumber;
  final String? tenantId;
  final String tenantName;
  final int billingMonth;
  final int billingYear;
  final double roomPrice;
  final double electricityUnits;
  final double electricityCost;
  final double waterCost;
  final double cleaningFee;
  final SkipReason? skipReason;

  const InvoiceDraft({
    required this.roomDbId,
    required this.roomNumber,
    this.tenantId,
    required this.tenantName,
    required this.billingMonth,
    required this.billingYear,
    this.roomPrice = 0,
    this.electricityUnits = 0,
    this.electricityCost = 0,
    this.waterCost = 0,
    this.cleaningFee = 0,
    this.skipReason,
  });

  bool get canIssue => skipReason == null;

  double get total => roomPrice + electricityCost + waterCost + cleaningFee;
}

enum UtilityType { electricity, water }

class ElectricityRecord {
  final String? id;
  final int roomDbId;
  final String roomNumber;
  final String? tenantName;
  final int billingMonth;
  final int billingYear;
  final double previousReading;
  double? currentReading;
  final double unitRate;
  final String? floor;
  final RoomStatus? roomStatus;

  ElectricityRecord({
    this.id,
    required this.roomDbId,
    required this.roomNumber,
    this.tenantName,
    required this.billingMonth,
    required this.billingYear,
    required this.previousReading,
    this.currentReading,
    required this.unitRate,
    this.floor,
    this.roomStatus,
  });

  // Returns true when meter wrapped around from 9999 → 0000
  bool get isOverflow => currentReading != null && currentReading! < previousReading;

  // Handles 4-digit meter overflow: (10000 - prev) + current
  double get unitsUsed {
    if (currentReading == null) return 0;
    if (currentReading! >= previousReading) return currentReading! - previousReading;
    return (10000 - previousReading) + currentReading!;
  }

  double get amount => unitsUsed * unitRate;

  Map<String, dynamic> toJson() {
    final data = {
      'room_id': roomDbId,
      'billing_month': billingMonth,
      'billing_year': billingYear,
      'previous_reading': previousReading,
      'current_reading': currentReading,
      'unit_rate': unitRate,
      'amount': amount,
    };
    if (id != null) {
      final parsedId = int.tryParse(id!);
      if (parsedId != null) data['id'] = parsedId;
    }
    return data;
  }
}

class WaterRecord {
  final String? id;
  final int roomDbId;
  final String roomNumber;
  final String? tenantName;
  final int billingMonth;
  final int billingYear;
  double amount;
  final String? floor;
  final RoomStatus? roomStatus;

  WaterRecord({
    this.id,
    required this.roomDbId,
    required this.roomNumber,
    this.tenantName,
    required this.billingMonth,
    required this.billingYear,
    required this.amount,
    this.floor,
    this.roomStatus,
  });

  Map<String, dynamic> toJson() {
    final data = {
      'room_id': roomDbId,
      'billing_month': billingMonth,
      'billing_year': billingYear,
      'amount': amount,
    };
    if (id != null) {
      final parsedId = int.tryParse(id!);
      if (parsedId != null) data['id'] = parsedId;
    }
    return data;
  }
}

class ChatMessage {
  final String id;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isFromOwner;
  final MessageType type;
  final String? attachmentUrl;
  final int? maintenanceRequestId;

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isFromOwner,
    this.type = MessageType.text,
    this.attachmentUrl,
    this.maintenanceRequestId,
  });
}

class ChatPreview {
  final int roomDbId;
  final String roomNumber;
  final String floor;
  final String tenantName;
  final String lastMessage;
  final int unreadCount;

  ChatPreview({
    required this.roomDbId,
    required this.roomNumber,
    required this.floor,
    required this.tenantName,
    required this.lastMessage,
    required this.unreadCount,
  });
}

class TenantJoinRequest {
  final int id;
  final String tenantId;
  final String landlordId;
  final int dormitoryId;
  final int? requestedRoomId;
  final String dormitoryName;
  final String landlordName;
  final String? roomNumber;
  final JoinRequestStatus status;
  final DateTime createdAt;

  const TenantJoinRequest({
    required this.id,
    required this.tenantId,
    required this.landlordId,
    required this.dormitoryId,
    this.requestedRoomId,
    required this.dormitoryName,
    required this.landlordName,
    this.roomNumber,
    required this.status,
    required this.createdAt,
  });
}

/// ข้อมูลหอพัก + ช่องทางติดต่อเจ้าของหอ (ใช้ในหน้าโปรไฟล์ผู้เช่า)
class DormitoryInfo {
  final int id;
  final String name;
  final String? landlordName;
  final String? landlordPhone;
  final String? landlordEmail;
  final double baseWaterRate;
  final double baseElectricityRate;

  const DormitoryInfo({
    required this.id,
    required this.name,
    this.landlordName,
    this.landlordPhone,
    this.landlordEmail,
    this.baseWaterRate = 0,
    this.baseElectricityRate = 0,
  });

  bool get hasContact =>
      (landlordName != null && landlordName!.trim().isNotEmpty) ||
      (landlordPhone != null && landlordPhone!.trim().isNotEmpty) ||
      (landlordEmail != null && landlordEmail!.trim().isNotEmpty);
}

/// บิลหนึ่งใบในมุมมองของผู้เช่า
///
/// [invoice] คือรายการค่าใช้จ่ายจริงที่คำนวณจากมิเตอร์ ส่วน [status] /
/// [dueDate] / [paidAt] / [slipUrl] ยังเป็นค่าจำลอง เพราะยังไม่มีตาราง
/// invoices — ฟีเจอร์ถัดไป "Invoice Generation" จะมาแทนที่เฉพาะส่วนนี้
/// โดยที่ UI ไม่ต้องแก้ (ดู lib/services/tenant_billing_source.dart)
class TenantBill {
  final Invoice invoice;
  final InvoiceStatus status;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? slipUrl;

  const TenantBill({
    required this.invoice,
    required this.status,
    this.dueDate,
    this.paidAt,
    this.slipUrl,
  });

  String get id => invoice.id;
  DateTime get period => invoice.date;
  double get total => invoice.total;

  TenantBill copyWith({
    InvoiceStatus? status,
    DateTime? dueDate,
    DateTime? paidAt,
    String? slipUrl,
  }) {
    return TenantBill(
      invoice: invoice,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
      slipUrl: slipUrl ?? this.slipUrl,
    );
  }
}

/// ช่องทางรับชำระเงินของหอพัก (ยังเป็นค่าจำลอง)
class PaymentChannel {
  final String promptPayId;
  final String accountName;

  const PaymentChannel({
    required this.promptPayId,
    required this.accountName,
  });
}

enum MaintenanceRequestType { repair, cleaning }

enum MaintenanceStatus { pending, inProgress, completed }

class MaintenanceRequest {
  final int id;
  final int roomId;
  final String roomNumber;
  final String tenantId;
  final String tenantName;
  final MaintenanceRequestType requestType;
  final String description;
  final String? imageUrl;
  final MaintenanceStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final double cleaningFee;

  const MaintenanceRequest({
    required this.id,
    required this.roomId,
    required this.roomNumber,
    required this.tenantId,
    required this.tenantName,
    required this.requestType,
    required this.description,
    this.imageUrl,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.cleaningFee = 0,
  });
}
