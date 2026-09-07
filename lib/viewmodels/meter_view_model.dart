import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/invoice_service.dart';
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
  MeterViewModel({
    required this.dormitoryId,
    SupabaseService? service,
    InvoiceService? invoices,
  })  : _service = service ?? SupabaseService(),
        _invoices = invoices ?? InvoiceService();

  final int dormitoryId;
  final SupabaseService _service;
  final InvoiceService _invoices;

  bool isSaving = false;
  String? errorMessage;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  final Set<int> modifiedWaterRoomIds = {};

  /// ห้องที่เจ้าของหอเพิ่งพิมพ์เลขมิเตอร์ไฟ ยังไม่ได้บันทึก · คู่กับ
  /// [modifiedWaterRoomIds] ที่มีอยู่เดิม — ดู [hasUnsavedEdits]
  final Set<int> modifiedElectricityRoomIds = {};

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

  /// สิ่งที่ผู้ใช้เพิ่งพิมพ์ในรอบนี้และยังไม่ได้บันทึก
  ///
  /// เกณฑ์ของกล่อง "ถามก่อนทิ้ง" ตอนลากรีเฟรช จึงนับเฉพาะสิ่งที่ **คนพิมพ์**
  /// ไม่ใช่สิ่งที่ยังไม่มีในฐานข้อมูล — งวดใหม่มีแถวค่าน้ำที่ `id == null`
  /// ครบทุกห้องตั้งแต่โหลดเสร็จ ถ้านับรวมด้วย กล่องจะเด้งทุกครั้งที่ลาก
  /// ทั้งที่ยังไม่มีใครแตะอะไรเลย ซึ่งสอนให้ผู้ใช้กด "ทิ้ง" โดยไม่อ่าน
  bool get hasUnsavedInput =>
      modifiedElectricityRoomIds.isNotEmpty || modifiedWaterRoomIds.isNotEmpty;

  /// มีอะไรให้กดบันทึกไหม — รวมแถวค่าน้ำของงวดที่ยังไม่เคยถูกบันทึก
  ///
  /// เกณฑ์เดิมตอบว่า "บันทึกได้" เพียงเพราะมีห้องไหนสักห้องที่มีเลขมิเตอร์ ซึ่ง
  /// เป็นจริงเสมอหลังโหลดข้อมูลที่เคยบันทึกไว้ ปุ่มจึงกดได้ตลอดแม้ไม่มีอะไร
  /// เปลี่ยน · แถวค่าน้ำที่ยังไม่มี id ยังนับอยู่ เพราะเป็นเกณฑ์เดียวกับที่
  /// [saveAll] ใช้เลือกแถวที่ต้องส่งขึ้นเซิร์ฟเวอร์จริง
  bool get hasUnsavedEdits =>
      hasUnsavedInput || waterRecords.any((r) => r.id == null);

  bool get canSave => !isLoading && !isSaving && hasUnsavedEdits;

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
        // ล้างหลัง fetch สำเร็จเท่านั้น และล้างพร้อมกับ reloadTick ที่หน้าจอใช้
        // ทิ้ง TextEditingController — สองอย่างนี้ต้องเกิดคู่กันเสมอ ไม่งั้น
        // ธง "มีของค้าง" จะไม่ตรงกับสิ่งที่ผู้ใช้เห็นในช่องกรอก
        modifiedWaterRoomIds.clear();
        modifiedElectricityRoomIds.clear();
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
    modifiedElectricityRoomIds.add(record.roomDbId);
    notifyListeners();
  }

  void setWaterAmount(WaterRecord record, double value) {
    record.amount = value;
    modifiedWaterRoomIds.add(record.roomDbId);
    notifyListeners();
  }

  /// ปรับยอดบิลค้างชำระของงวดที่เลือกให้ตรงกับมิเตอร์ที่เพิ่งบันทึก
  /// แล้วแจ้งผู้เช่าที่ยอดเปลี่ยน
  ///
  /// แยกจาก [saveAll] เพราะความล้มของสองอย่างนี้มีน้ำหนักต่างกัน — มิเตอร์คือ
  /// ของจริงที่บันทึกไปแล้ว การปรับบิลคือผลพวงของมัน ล้มแล้วบอกได้ ไม่ต้องย้อน
  ///
  /// คืนทั้งจำนวนใบที่ปรับสำเร็จ จำนวนใบที่ปรับไม่สำเร็จ และผลของการแจ้ง —
  /// สามอย่างนี้ล้มแยกกันได้ทั้งหมด และการรายงานว่า "ปรับยอดไม่สำเร็จ" ทั้งที่
  /// ยอดเปลี่ยนไปแล้วบางใบแต่แจ้งไม่ออก จะทำให้เจ้าของหอเข้าใจผิดว่าบิลยังเป็น
  /// ยอดเดิมทั้งหมด — [InvoiceService.syncUnpaidInvoices] คืนใบที่ปรับสำเร็จ
  /// แยกจากใบที่ปรับไม่สำเร็จแล้ว จึงส่งแจ้งเตือนเฉพาะใบที่ปรับสำเร็จจริง
  Future<({int adjusted, int failed, bool noticesPosted})>
      syncInvoicesForPeriod() async {
    final result = await _invoices.syncUnpaidInvoices(
      dormitoryId: dormitoryId,
      month: selectedMonth,
      year: selectedYear,
    );
    if (result.applied.isEmpty) {
      return (adjusted: 0, failed: result.failed.length, noticesPosted: true);
    }

    try {
      await _invoices.postAdjustmentNotices(result.applied);
      return (
        adjusted: result.applied.length,
        failed: result.failed.length,
        noticesPosted: true
      );
    } catch (_) {
      // บิลถูกแก้ไปแล้ว การ์ดในแชทก็แสดงยอดใหม่เองอยู่แล้วเพราะ resolve สด
      // สิ่งที่หายไปคือข้อความที่บอกว่า "ยอดเปลี่ยนจากเท่าไร" เท่านั้น
      return (
        adjusted: result.applied.length,
        failed: result.failed.length,
        noticesPosted: false
      );
    }
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
