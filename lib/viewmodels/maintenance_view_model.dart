import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'refreshable.dart';

String maintenanceStatusLabel(MaintenanceStatus status) {
  switch (status) {
    case MaintenanceStatus.pending:
      return 'รอดำเนินการ';
    case MaintenanceStatus.inProgress:
      return 'กำลังดำเนินการ';
    case MaintenanceStatus.completed:
      return 'เสร็จสิ้น';
    case MaintenanceStatus.cancelled:
      return 'ยกเลิก';
  }
}

String maintenanceRequestTypeLabel(MaintenanceRequestType type) {
  switch (type) {
    case MaintenanceRequestType.repair:
      return 'แจ้งซ่อม';
    case MaintenanceRequestType.cleaning:
      return 'ทำความสะอาด';
  }
}

const maintenanceHistoryStatusFilters = [
  'ทั้งหมด',
  'รอดำเนินการ',
  'กำลังดำเนินการ',
  'เสร็จสิ้น',
  'ยกเลิก',
];

/// กรองรายการตาม label สถานะ ('ทั้งหมด' = ไม่กรอง) และคำค้นหา (จับคู่กับ
/// รายละเอียดหรือประเภทคำขอ) — ใช้ร่วมกันทั้งฝั่งเจ้าของหอและฝั่งผู้เช่า
List<MaintenanceRequest> filterMaintenanceRequests(
  List<MaintenanceRequest> requests,
  String filter, {
  String searchQuery = '',
}) {
  final query = searchQuery.trim().toLowerCase();
  return requests.where((request) {
    final matchesStatus =
        filter == 'ทั้งหมด' || maintenanceStatusLabel(request.status) == filter;
    final searchableText = [
      request.description,
      maintenanceRequestTypeLabel(request.requestType),
    ].join(' ').toLowerCase();
    return matchesStatus && (query.isEmpty || searchableText.contains(query));
  }).toList();
}

class MaintenanceViewModel extends ChangeNotifier with RefreshableViewModel {
  MaintenanceViewModel({
    required this.roomId,
    required this.landlordId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int roomId;
  final String landlordId;
  final SupabaseService _service;

  String? errorMessage;
  List<MaintenanceRequest> requests = [];
  bool isUpdating = false;
  String searchQuery = '';
  String selectedStatusFilter = maintenanceHistoryStatusFilters.first;

  List<MaintenanceRequest> get filteredRequests => filterMaintenanceRequests(
        requests,
        selectedStatusFilter,
        searchQuery: searchQuery,
      );

  void setSearchQuery(String value) {
    if (searchQuery == value) return;
    searchQuery = value;
    notifyListeners();
  }

  void setStatusFilter(String value) {
    if (selectedStatusFilter == value) return;
    selectedStatusFilter = value;
    notifyListeners();
  }

  Future<void> loadRequests() {
    return runLoad(() async {
      errorMessage = null;
      try {
        requests = await _service.fetchMaintenanceRequests(roomId: roomId);
      } catch (error) {
        errorMessage = error.toString();
      }
    });
  }

  Future<ActionResult> updateStatus(
      MaintenanceRequest request, MaintenanceStatus status) async {
    if (isUpdating) return const ActionResult(success: true, message: '');

    isUpdating = true;
    notifyListeners();

    try {
      await _service.updateMaintenanceStatus(
        requestId: request.id,
        roomId: roomId,
        landlordId: landlordId,
        status: status,
        requestType: request.requestType,
      );
      await loadRequests();
      return const ActionResult(success: true, message: '');
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'อัปเดตสถานะไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }

  Future<ActionResult> updateCleaningFee(
      MaintenanceRequest request, double fee) async {
    if (isUpdating) return const ActionResult(success: true, message: '');

    isUpdating = true;
    notifyListeners();

    try {
      await _service.updateCleaningFee(requestId: request.id, fee: fee);
      await loadRequests();
      return const ActionResult(success: true, message: '');
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'บันทึกค่าทำความสะอาดไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }
}
