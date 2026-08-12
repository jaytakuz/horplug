import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'maintenance_view_model.dart';
import 'refreshable.dart';
import 'safe_notifier.dart';

/// ตัวเลือกตัวกรองสถานะ — 'ทั้งหมด' บวกกับ label ของทุกสถานะ
const tenantMaintenanceFilters = [
  'ทั้งหมด',
  'รอดำเนินการ',
  'กำลังดำเนินการ',
  'เสร็จสิ้น',
  'ยกเลิก',
];

class TenantMaintenanceViewModel extends ChangeNotifier
    with SafeNotifier, RefreshableViewModel {
  TenantMaintenanceViewModel({
    required this.roomId,
    required this.tenantId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int? roomId;
  final String? tenantId;
  final SupabaseService _service;

  /// ชนิดคำขอที่กำลังส่งอยู่ (null = ไม่ได้ส่งอะไร) — เก็บเป็นชนิดแทน bool
  /// เพื่อให้ spinner ขึ้นบนปุ่มที่ผู้ใช้กดจริง ไม่ใช่ปุ่มแรกเสมอ
  MaintenanceRequestType? submittingType;
  bool get isSubmitting => submittingType != null;
  String? errorMessage;
  List<MaintenanceRequest> requests = [];
  String selectedFilter = 'ทั้งหมด';
  String searchQuery = '';

  List<MaintenanceRequest> get filteredRequests => filterMaintenanceRequests(
        requests,
        selectedFilter,
        searchQuery: searchQuery,
      );

  void setFilter(String filter) {
    if (selectedFilter == filter) return;
    selectedFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    if (searchQuery == value) return;
    searchQuery = value;
    notifyListeners();
  }

  Future<void> loadRequests() async {
    final room = roomId;
    if (room == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    return runLoad(() async {
      errorMessage = null;
      try {
        requests = await _service.fetchMaintenanceRequests(roomId: room);
      } catch (error) {
        errorMessage = formatErrorMessage(error);
      }
    });
  }

  /// ส่งคำขอแจ้งซ่อม/ทำความสะอาด
  ///
  /// createMaintenanceRequest จะโพสต์ข้อความเข้าแชทให้เจ้าของหอด้วยในตัว
  /// จึงไม่ต้องแจ้งเตือนซ้ำจากฝั่งนี้
  Future<ActionResult> submitRequest({
    required String description,
    required MaintenanceRequestType requestType,
  }) async {
    final room = roomId;
    final tenant = tenantId;
    if (room == null || tenant == null) {
      return const ActionResult(
        success: false,
        message: 'ยังไม่ได้เข้าพักในห้องใด',
      );
    }

    submittingType = requestType;
    notifyListeners();

    try {
      await _service.createMaintenanceRequest(
        roomId: room,
        tenantId: tenant,
        description: description.trim(),
        requestType: requestType,
      );

      await loadRequests();

      return const ActionResult(
        success: true,
        message: 'ส่งคำขอแล้ว เจ้าของหอจะติดต่อกลับ',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ส่งคำขอไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      submittingType = null;
      notifyListeners();
    }
  }
}
