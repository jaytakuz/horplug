import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'error_message.dart';
import 'safe_notifier.dart';

/// รายการห้องที่มีประวัติแจ้งซ่อม/ทำความสะอาด ของทั้งหอ
///
/// ตัวกรองเป็นชุดเดียวกับหน้ารวมแชท (ค้นหา + ชั้น) เพราะสองหน้านี้ตอบคำถาม
/// เดียวกันคนละมุม — "ห้องไหนมีอะไรค้างอยู่" การให้ตัวกรองคนละแบบทำให้ผู้ใช้
/// ต้องเรียนรู้สองหน้าจอทั้งที่มันเป็นรายการห้องเหมือนกัน
class MaintenanceOverviewViewModel extends ChangeNotifier with SafeNotifier {
  MaintenanceOverviewViewModel({
    required this.dormitoryId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  static const String allFloors = 'ทั้งหมด';

  final int dormitoryId;
  final SupabaseService _service;

  bool isLoading = true;
  String? errorMessage;
  List<RoomMaintenanceSummary> summaries = [];
  String searchQuery = '';
  String selectedFloor = allFloors;

  Set<String> get availableFloors => summaries
      .map((summary) => summary.floor)
      .where((floor) => floor.isNotEmpty)
      .toSet();

  /// จำนวนห้องที่ยังมีงานค้าง — ใช้เป็นบรรทัดสรุปบนหัวรายการ
  int get roomsWithOpenWork =>
      summaries.where((summary) => summary.openCount > 0).length;

  List<RoomMaintenanceSummary> get filteredSummaries {
    final query = searchQuery.trim().toLowerCase();
    return summaries.where((summary) {
      final matchesQuery = query.isEmpty ||
          summary.roomNumber.toLowerCase().contains(query) ||
          summary.tenantName.toLowerCase().contains(query) ||
          summary.latest.description.toLowerCase().contains(query);
      final matchesFloor =
          selectedFloor == allFloors || summary.floor == selectedFloor;
      return matchesQuery && matchesFloor;
    }).toList();
  }

  void setSearchQuery(String value) {
    if (searchQuery == value) return;
    searchQuery = value;
    notifyListeners();
  }

  void setFloorFilter(String value) {
    if (selectedFloor == value) return;
    selectedFloor = value;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      summaries =
          await _service.fetchMaintenanceSummaries(dormitoryId: dormitoryId);
    } catch (error) {
      errorMessage = formatErrorMessage(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
