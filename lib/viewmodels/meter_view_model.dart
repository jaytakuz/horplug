import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'refreshable.dart';

String roomStatusLabel(RoomStatus? status) {
  switch (status) {
    case RoomStatus.occupied:
      return 'มีคนอยู่';
    case RoomStatus.vacant:
      return 'ว่าง';
    case RoomStatus.maintenance:
      return 'ซ่อมบำรุง';
    default:
      return '-';
  }
}

class MeterViewModel extends ChangeNotifier with RefreshableViewModel {
  MeterViewModel({required this.dormitoryId, SupabaseService? service})
      : _service = service ?? SupabaseService();

  final int dormitoryId;
  final SupabaseService _service;

  bool isSaving = false;
  String? errorMessage;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  final Set<int> modifiedWaterRoomIds = {};

  String searchQuery = '';
  String selectedFloor = 'ทั้งหมด';
  String selectedRoomStatus = 'ทั้งหมด';

  List<ElectricityRecord> electricityRecords = [];
  List<WaterRecord> waterRecords = [];

  // Bumped every time a fresh set of records is loaded, so the View knows
  // when to reset its per-room TextEditingControllers/FocusNodes.
  int reloadTick = 0;

  Set<String> get availableFloors => electricityRecords
      .map((r) => r.floor ?? '')
      .where((f) => f.isNotEmpty)
      .toSet();

  int get activeFilterCount => [
        selectedFloor != 'ทั้งหมด',
        selectedRoomStatus != 'ทั้งหมด',
      ].where((v) => v).length;

  bool _matchesFilters({
    required String roomNumber,
    required String? tenantName,
    required String? floor,
    required RoomStatus? roomStatus,
  }) {
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      final matchRoom = roomNumber.toLowerCase().contains(q);
      final matchName = (tenantName ?? '').toLowerCase().contains(q);
      if (!matchRoom && !matchName) return false;
    }
    if (selectedFloor != 'ทั้งหมด' && (floor ?? '') != selectedFloor) {
      return false;
    }
    if (selectedRoomStatus != 'ทั้งหมด' &&
        roomStatusLabel(roomStatus) != selectedRoomStatus) {
      return false;
    }
    return true;
  }

  List<ElectricityRecord> get filteredElectricityRecords => electricityRecords
      .where((r) => _matchesFilters(
          roomNumber: r.roomNumber,
          tenantName: r.tenantName,
          floor: r.floor,
          roomStatus: r.roomStatus))
      .toList();

  List<WaterRecord> get filteredWaterRecords => waterRecords
      .where((r) => _matchesFilters(
          roomNumber: r.roomNumber,
          tenantName: r.tenantName,
          floor: r.floor,
          roomStatus: r.roomStatus))
      .toList();

  int get electricityRecordedCount =>
      electricityRecords.where((r) => r.currentReading != null).length;

  int get waterSavedCount => waterRecords.where((r) => r.id != null).length;

  bool get canSave {
    if (isLoading || isSaving) return false;
    final hasValidElec =
        electricityRecords.any((r) => r.currentReading != null);
    final hasNewOrModifiedWater = modifiedWaterRoomIds.isNotEmpty ||
        waterRecords.any((r) => r.id == null);
    return hasValidElec || hasNewOrModifiedWater;
  }

  void clearFilters() {
    selectedFloor = 'ทั้งหมด';
    selectedRoomStatus = 'ทั้งหมด';
    notifyListeners();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setFloorFilter(String value) {
    selectedFloor = value;
    notifyListeners();
  }

  void setRoomStatusFilter(String value) {
    selectedRoomStatus = value;
    notifyListeners();
  }

  Future<void> loadAllRecords() {
    return runLoad(() async {
      errorMessage = null;
      try {
        final elecs = await _service.fetchElectricityRecords(
          dormitoryId: dormitoryId,
          month: selectedMonth,
          year: selectedYear,
        );
        final waters = await _service.fetchWaterRecords(
          dormitoryId: dormitoryId,
          month: selectedMonth,
          year: selectedYear,
        );

        electricityRecords = elecs;
        waterRecords = waters;
        modifiedWaterRoomIds.clear();
        reloadTick++;
      } catch (error) {
        errorMessage = 'ไม่สามารถโหลดข้อมูลได้: $error';
      }
    });
  }

  Future<void> setPeriod({int? month, int? year}) async {
    if (month != null) selectedMonth = month;
    if (year != null) selectedYear = year;
    await loadAllRecords();
  }

  void setElectricityReading(ElectricityRecord record, double? value) {
    record.currentReading = value;
    notifyListeners();
  }

  void setWaterAmount(WaterRecord record, double value) {
    record.amount = value;
    modifiedWaterRoomIds.add(record.roomDbId);
    notifyListeners();
  }

  Future<bool> saveAll() async {
    if (!canSave) return false;

    isSaving = true;
    notifyListeners();
    try {
      await _service.saveElectricityRecords(electricityRecords);

      final waterToSave = waterRecords
          .where((r) =>
              r.id == null || modifiedWaterRoomIds.contains(r.roomDbId))
          .toList();
      await _service.saveWaterRecords(waterToSave);

      await loadAllRecords();
      return true;
    } catch (e) {
      errorMessage = 'บันทึกไม่สำเร็จ: $e';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
