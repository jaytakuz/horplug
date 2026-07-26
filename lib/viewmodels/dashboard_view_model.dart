import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'action_result.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required this.dormitoryId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int dormitoryId;
  final SupabaseService _service;

  bool isLoading = true;
  bool isUpdatingTenant = false;
  String? errorMessage;
  List<Room> rooms = [];
  List<Tenant> availableTenants = [];
  int unreadMessageCount = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _roomChangesSubscription;

  List<Room> get occupiedRooms =>
      rooms.where((r) => r.status == RoomStatus.occupied).toList();

  int get occupiedCount => occupiedRooms.length;

  int get totalRooms => rooms.length;

  int get vacantCount =>
      rooms.where((r) => r.status == RoomStatus.vacant).length;

  int get occupancyRate =>
      totalRooms == 0 ? 0 : ((occupiedCount / totalRooms) * 100).round();

  double get estimatedMonthlyRevenue =>
      occupiedRooms.fold<double>(0, (sum, room) => sum + room.price);

  List<String> get floorNumbers {
    final floors = rooms.map((room) => room.floor).toSet().toList()
      ..sort((a, b) {
        final ai = int.tryParse(a);
        final bi = int.tryParse(b);
        if (ai != null && bi != null) return ai.compareTo(bi);
        return a.compareTo(b);
      });
    return floors;
  }

  List<Room> roomsOnFloor(String floor) =>
      rooms.where((room) => room.floor == floor).toList();

  String formatErrorMessage(Object error) {
    final message = error.toString().trim();
    final normalized = message.startsWith('Exception: ')
        ? message.substring('Exception: '.length).trim()
        : message;
    final lowerCaseMessage = normalized.toLowerCase();

    if (lowerCaseMessage.contains('failed host lookup') ||
        lowerCaseMessage.contains('socketexception') ||
        lowerCaseMessage.contains('clientexception') ||
        lowerCaseMessage.contains('connection refused') ||
        lowerCaseMessage.contains('network is unreachable') ||
        lowerCaseMessage.contains('connection timed out') ||
        lowerCaseMessage.contains('timed out')) {
      return 'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
    }

    return normalized;
  }

  Future<void> loadRooms() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetchedRooms = await _service.fetchRooms(dormitoryId: dormitoryId);
      final tenants = await _service.fetchAvailableTenants();
      final unread =
          await _service.countUnreadMessages(dormitoryId: dormitoryId);

      rooms = fetchedRooms;
      availableTenants = tenants;
      unreadMessageCount = unread;
      isLoading = false;
      notifyListeners();
    } catch (error) {
      errorMessage = formatErrorMessage(error);
      isLoading = false;
      notifyListeners();
    }
  }

  /// Screens like DashboardScreen stay mounted (IndexedStack) across tab
  /// switches, so room changes made elsewhere (e.g. the chat/maintenance
  /// flow updating a room's status) wouldn't otherwise be picked up. This
  /// listens for any change to this dormitory's rooms and reloads.
  void startWatchingRoomChanges() {
    _roomChangesSubscription?.cancel();
    _roomChangesSubscription = _service
        .watchRoomChanges(dormitoryId: dormitoryId)
        .listen((_) => loadRooms());
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

      await loadRooms();

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

      await loadRooms();

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
}
