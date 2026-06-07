enum RoomStatus { occupied, vacant, maintenance }

enum InvoiceStatus { unpaid, pending, paid }

enum MessageType {
  text,
  maintenanceRequest,
  parcelNotification,
  maintenanceUpdate
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
    required this.status,
    required this.date,
    this.hasSlip = false,
  });

  double get total => roomPrice + waterCost + electricityCost;
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

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isFromOwner,
    this.type = MessageType.text,
  });
}

class ChatPreview {
  final String roomNumber;
  final String tenantName;
  final String lastMessage;
  final int unreadCount;
  final bool hasPendingMaintenance;

  ChatPreview({
    required this.roomNumber,
    required this.tenantName,
    required this.lastMessage,
    required this.unreadCount,
    this.hasPendingMaintenance = false,
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
