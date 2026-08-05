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
