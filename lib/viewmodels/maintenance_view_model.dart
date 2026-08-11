import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

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

class MaintenanceViewModel extends ChangeNotifier {
  MaintenanceViewModel({
    required this.roomId,
    required this.landlordId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int roomId;
  final String landlordId;
  final SupabaseService _service;

  bool isLoading = true;
  String? errorMessage;
  List<MaintenanceRequest> requests = [];
  bool isUpdating = false;
  String searchQuery = '';
  String selectedStatusFilter = maintenanceHistoryStatusFilters.first;

  List<MaintenanceRequest> get filteredRequests {
    final query = searchQuery.trim().toLowerCase();
    return requests.where((request) {
      final matchesStatus =
          selectedStatusFilter == maintenanceHistoryStatusFilters.first ||
              maintenanceStatusLabel(request.status) == selectedStatusFilter;
      final searchableText = [
        request.description,
        maintenanceRequestTypeLabel(request.requestType),
      ].join(' ').toLowerCase();
      return matchesStatus && (query.isEmpty || searchableText.contains(query));
    }).toList();
  }

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

  Future<void> loadRequests() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      requests = await _service.fetchMaintenanceRequests(roomId: roomId);
      isLoading = false;
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(
      MaintenanceRequest request, MaintenanceStatus status) async {
    if (isUpdating) return;

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
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> updateCleaningFee(MaintenanceRequest request, double fee) async {
    if (isUpdating) return;

    isUpdating = true;
    notifyListeners();

    try {
      await _service.updateCleaningFee(requestId: request.id, fee: fee);
      await loadRequests();
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }
}
