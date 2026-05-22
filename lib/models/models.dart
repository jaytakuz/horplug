enum RoomStatus { occupied, vacant, maintenance }
enum InvoiceStatus { unpaid, pending, paid }
enum MessageType { text, maintenanceRequest, parcelNotification, maintenanceUpdate }
enum AppRole { landlord, tenant }

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
  });

  String get fullName => '$firstName $lastName'.trim();
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
    required this.status,
    required this.date,
    this.hasSlip = false,
  });

  double get waterCost => waterUnits * 18;
  double get electricityCost => electricityUnits * 8;
  double get total => roomPrice + waterCost + electricityCost;
}

class MeterReading {
  final String roomNumber;
  final String tenantName;
  final double previousValue;
  double? currentValue;

  MeterReading({
    required this.roomNumber,
    required this.tenantName,
    required this.previousValue,
    this.currentValue,
  });
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
