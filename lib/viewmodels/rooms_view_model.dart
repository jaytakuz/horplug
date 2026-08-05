import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import '../utils/formatters.dart';

String roomStatusText(RoomStatus status) {
  switch (status) {
    case RoomStatus.occupied:
      return 'มีคนอยู่';
    case RoomStatus.vacant:
      return 'ว่าง';
    case RoomStatus.maintenance:
      return 'ซ่อมบำรุง';
  }
}

class RoomsViewModel extends ChangeNotifier {
  RoomsViewModel({required this.dormitoryId, SupabaseService? service})
      : _service = service ?? SupabaseService();

  final int dormitoryId;
  final SupabaseService _service;

  static const paymentStatusFilters = [
    'ทั้งหมด',
    'ชำระแล้ว',
    'รอดำเนินการ',
    'ค้างชำระ',
  ];

  bool isLoading = true;
  bool isUpdatingTenant = false;
  String? errorMessage;
  List<Room> rooms = [];
  List<Tenant> availableTenants = [];
  Set<String> floors = {};

  StreamSubscription<List<Map<String, dynamic>>>? _roomChangesSubscription;

  String selectedFilter = 'ทั้งหมด';
  String selectedFloor = 'ทั้งหมด';
  String selectedPaymentStatus = 'ทั้งหมด';
  String searchQuery = '';

  int get activeFilterCount => [
        selectedFloor != 'ทั้งหมด',
        selectedFilter != 'ทั้งหมด',
        selectedPaymentStatus != 'ทั้งหมด',
      ].where((active) => active).length;

  List<Room> get filteredRooms {
    return rooms.where((room) {
      final normalizedQuery = searchQuery.trim().toLowerCase();
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
      if (selectedFilter == 'มีคนอยู่') return room.status == RoomStatus.occupied;
      if (selectedFilter == 'ว่าง') return room.status == RoomStatus.vacant;
      if (selectedFilter == 'ซ่อมบำรุง') {
        return room.status == RoomStatus.maintenance;
      }
      return true;
    }).toList();
  }

  Map<String, int> get stats {
    final filtered = filteredRooms;
    return {
      'occupied': filtered.where((r) => r.status == RoomStatus.occupied).length,
      'vacant': filtered.where((r) => r.status == RoomStatus.vacant).length,
      'maintenance':
          filtered.where((r) => r.status == RoomStatus.maintenance).length,
      'total': filtered.length,
    };
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setSelectedFloor(String value) {
    selectedFloor = value;
    notifyListeners();
  }

  void setSelectedFilter(String value) {
    selectedFilter = value;
    notifyListeners();
  }

  void setSelectedPaymentStatus(String value) {
    selectedPaymentStatus = value;
    notifyListeners();
  }

  void clearAllFilters() {
    selectedFloor = 'ทั้งหมด';
    selectedFilter = 'ทั้งหมด';
    selectedPaymentStatus = 'ทั้งหมด';
    notifyListeners();
  }

  Future<void> loadData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetchedRooms = await _service.fetchRooms(dormitoryId: dormitoryId);
      final tenants = await _service.fetchAvailableTenants();
      final fetchedFloors = fetchedRooms.map((room) => room.floor).toSet();

      rooms = fetchedRooms;
      availableTenants = tenants;
      floors = fetchedFloors;
      isLoading = false;
      notifyListeners();
    } catch (error) {
      errorMessage = formatErrorMessage(error);
      isLoading = false;
      notifyListeners();
    }
  }

  /// Screens like RoomsScreen stay mounted (IndexedStack) across tab
  /// switches, so room changes made elsewhere (e.g. the chat/maintenance
  /// flow updating a room's status) wouldn't otherwise be picked up. This
  /// listens for any change to this dormitory's rooms and reloads.
  void startWatchingRoomChanges() {
    _roomChangesSubscription?.cancel();
    _roomChangesSubscription = _service
        .watchRoomChanges(dormitoryId: dormitoryId)
        .listen((_) => loadData());
  }

  @override
  void dispose() {
    _roomChangesSubscription?.cancel();
    super.dispose();
  }

  Future<ActionResult> createTenantJoinRequest({
    required String? landlordId,
    required Room room,
    required Tenant tenant,
  }) async {
    isUpdatingTenant = true;
    notifyListeners();

    try {
      if (landlordId == null) {
        throw Exception('ไม่พบข้อมูลเจ้าของหอพัก');
      }

      await _service.createTenantJoinRequest(
        landlordId: landlordId,
        dormitoryId: dormitoryId,
        roomDbId: room.dbId,
        tenantId: tenant.id,
      );

      await loadData();

      return ActionResult(
        success: true,
        message: 'ส่งคำขอถึง ${tenant.name} สำหรับห้อง ${room.id} แล้ว',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ส่งคำขอไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isUpdatingTenant = false;
      notifyListeners();
    }
  }

  Future<ActionResult> removeTenantFromRoom(Room room) async {
    isUpdatingTenant = true;
    notifyListeners();

    try {
      await _service.removeTenantFromRoom(roomDbId: room.dbId);

      await loadData();

      return ActionResult(
        success: true,
        message: 'ลบผู้พักอาศัยออกจากห้อง ${room.id} แล้ว',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ลบไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isUpdatingTenant = false;
      notifyListeners();
    }
  }

  Future<ActionResult> addRoom({
    required String roomNumber,
    required String floor,
    required String basePriceInput,
  }) async {
    if (roomNumber.trim().isEmpty || basePriceInput.trim().isEmpty) {
      return const ActionResult(
        success: false,
        message: 'กรุณากรอกข้อมูลที่จำเป็นทั้งหมด',
      );
    }

    final basePrice = double.tryParse(basePriceInput);
    if (basePrice == null || basePrice < 0) {
      return const ActionResult(success: false, message: 'ราคาไม่ถูกต้อง');
    }

    try {
      await _service.addRoom(
        dormitoryId: dormitoryId,
        roomNumber: roomNumber,
        floor: floor,
        basePrice: basePrice,
      );

      await loadData();

      return ActionResult(success: true, message: 'เพิ่มห้อง $roomNumber สำเร็จ');
    } catch (error) {
      final errorMsg = formatErrorMessage(error);
      if (errorMsg.contains('already exists')) {
        return const ActionResult(success: false, message: 'เลขห้องนี้มีอยู่แล้ว');
      }
      return ActionResult(
        success: false,
        message: 'การเพิ่มห้องไม่สำเร็จ: $errorMsg',
      );
    }
  }

  Future<ActionResult> updateRoomNumber(Room room, String newRoomNumber) async {
    try {
      await _service.updateRoomNumber(
        roomDbId: room.dbId,
        newRoomNumber: newRoomNumber,
      );

      await loadData();

      return ActionResult(
        success: true,
        message: 'เปลี่ยนเลขห้อง ${room.id} เป็น $newRoomNumber เรียบร้อยแล้ว',
      );
    } catch (error) {
      final message = formatErrorMessage(error);
      if (message.contains('กำลังถูกใช้งาน')) {
        return const ActionResult(
          success: false,
          message: 'หมายเลขห้องนี้ถูกใช้งานอยู่แล้ว',
        );
      }
      return ActionResult(
        success: false,
        message: 'เปลี่ยนเลขห้องไม่สำเร็จ: $message',
      );
    }
  }

  Future<ActionResult> updateRoomPrice(Room room, double newPrice) async {
    try {
      await _service.updateRoomPrice(roomDbId: room.dbId, newPrice: newPrice);

      await loadData();

      return ActionResult(
        success: true,
        message:
            'เปลี่ยนราคาห้อง ${room.id} เป็น ${formatBaht(newPrice)}/เดือน แล้ว',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'บันทึกไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    }
  }

  Future<ActionResult> deleteRoom(Room room) async {
    try {
      await _service.deleteRoom(roomDbId: room.dbId);

      await loadData();

      return ActionResult(success: true, message: 'ลบห้อง ${room.id} สำเร็จ');
    } catch (error) {
      return ActionResult(success: false, message: 'ลบห้องไม่สำเร็จ: $error');
    }
  }

  Future<ActionResult> updateRoomStatus(Room room, RoomStatus newStatus) async {
    try {
      await _service.updateRoomStatus(roomDbId: room.dbId, newStatus: newStatus);

      await loadData();

      return ActionResult(
        success: true,
        message: 'เปลี่ยนสถานะห้อง ${room.id} เป็น ${roomStatusText(newStatus)} แล้ว',
      );
    } catch (error) {
      return ActionResult(success: false, message: 'เปลี่ยนสถานะไม่สำเร็จ: $error');
    }
  }
}
