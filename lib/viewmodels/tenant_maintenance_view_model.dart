import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'maintenance_view_model.dart';

/// ตัวเลือกตัวกรองสถานะ — 'ทั้งหมด' บวกกับ label ของทุกสถานะ
const tenantMaintenanceFilters = [
  'ทั้งหมด',
  'รอดำเนินการ',
  'กำลังดำเนินการ',
  'เสร็จสิ้น',
];

/// กรองรายการตาม label สถานะ ('ทั้งหมด' = ไม่กรอง)
List<MaintenanceRequest> filterMaintenanceRequests(
  List<MaintenanceRequest> requests,
  String filter,
) {
  if (filter == 'ทั้งหมด') return requests;
  return requests
      .where((request) => maintenanceStatusLabel(request.status) == filter)
      .toList();
}

class TenantMaintenanceViewModel extends ChangeNotifier {
  TenantMaintenanceViewModel({
    required this.roomId,
    required this.tenantId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int? roomId;
  final String? tenantId;
  final SupabaseService _service;

  /// true เฉพาะการโหลดครั้งแรก — pull-to-refresh ไม่ควรล้างรายการทิ้ง
  bool isLoading = true;
  bool _hasLoadedOnce = false;

  /// ชนิดคำขอที่กำลังส่งอยู่ (null = ไม่ได้ส่งอะไร) — เก็บเป็นชนิดแทน bool
  /// เพื่อให้ spinner ขึ้นบนปุ่มที่ผู้ใช้กดจริง ไม่ใช่ปุ่มแรกเสมอ
  MaintenanceRequestType? submittingType;
  bool get isSubmitting => submittingType != null;
  String? errorMessage;
  List<MaintenanceRequest> requests = [];
  String selectedFilter = 'ทั้งหมด';

  List<MaintenanceRequest> get filteredRequests =>
      filterMaintenanceRequests(requests, selectedFilter);

  void setFilter(String filter) {
    if (selectedFilter == filter) return;
    selectedFilter = filter;
    notifyListeners();
  }

  Future<void> loadRequests() async {
    final room = roomId;
    if (room == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = !_hasLoadedOnce;
    errorMessage = null;
    notifyListeners();

    try {
      requests = await _service.fetchMaintenanceRequests(roomId: room);
    } catch (error) {
      errorMessage = formatErrorMessage(error);
    } finally {
      isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
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
