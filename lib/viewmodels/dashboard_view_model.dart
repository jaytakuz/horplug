import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/invoice_service.dart';
import '../services/supabase_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'refreshable.dart';

class DashboardViewModel extends ChangeNotifier with RefreshableViewModel {
  DashboardViewModel({
    required this.dormitoryId,
    SupabaseService? service,
    InvoiceService? invoices,
  })  : _service = service ?? SupabaseService(),
        _invoices = invoices ?? InvoiceService();

  final int dormitoryId;
  final SupabaseService _service;
  final InvoiceService _invoices;

  bool isUpdatingTenant = false;
  String? errorMessage;
  List<Room> rooms = [];
  List<Tenant> availableTenants = [];
  int unreadMessageCount = 0;

  /// บิลที่ผู้เช่าแจ้งชำระแล้วและรอเจ้าของหอตรวจ — ใช้เป็น badge บนทางลัด
  ///
  /// นับไม่สำเร็จให้เป็น 0 คือไม่มี badge · ไม่ทำให้ทั้งแดชบอร์ดล้ม เพราะตัวเลข
  /// บนปุ่มทางลัดไม่คุ้มกับการที่แผนผังห้องกับการ์ดสรุปหายไปทั้งหน้า
  int pendingSlipCount = 0;

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

  Future<void> loadRooms() {
    return runLoad(() async {
      errorMessage = null;
      try {
        final fetchedRooms =
            await _service.fetchRooms(dormitoryId: dormitoryId);
        final tenants = await _service.fetchAvailableTenants();
        final unread =
            await _service.countUnreadMessages(dormitoryId: dormitoryId);

        rooms = fetchedRooms;
        availableTenants = tenants;
        unreadMessageCount = unread;
        pendingSlipCount = await _countPendingSlips();
      } catch (error) {
        errorMessage = formatErrorMessage(error);
      }
    });
  }

  /// นับบิลที่รอตรวจ · คืน 0 เมื่อนับไม่ได้ ไม่ปล่อยให้ล้มทั้ง [loadRooms]
  ///
  /// ฐานข้อมูลที่ยังไม่ได้รัน migration ของตาราง invoices จะตอบ error ที่นี่
  /// การปล่อยให้ทะลุขึ้นไปแปลว่าแดชบอร์ดทั้งหน้าขึ้น "โหลดข้อมูลไม่สำเร็จ"
  /// เพราะตัวเลขบน badge ปุ่มเดียว
  Future<int> _countPendingSlips() async {
    try {
      return await _invoices.countAwaitingReview(dormitoryId: dormitoryId);
    } catch (error) {
      debugPrint('นับบิลที่รอตรวจไม่สำเร็จ ข้ามไป: $error');
      return 0;
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
