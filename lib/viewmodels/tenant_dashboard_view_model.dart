import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/tenant_billing_source.dart';
import '../widgets/reusable_widgets.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'safe_notifier.dart';
import 'tenant_slip_submission.dart';

// ── Pure helpers ────────────────────────────────────────────────────────────
// อยู่นอกคลาสเพราะ SupabaseService สร้าง client ตอน field initializer ทำให้
// สร้าง ViewModel ใน unit test ไม่ได้ — ตรรกะที่ต้องเทสต์จึงต้องเป็น top-level

enum TrendDirection { up, down, flat }

class UtilityTrend {
  final double delta;

  /// null เมื่อเดือนก่อนเป็น 0 (คำนวณ % ไม่ได้)
  final double? percent;
  final TrendDirection direction;

  const UtilityTrend({
    required this.delta,
    required this.percent,
    required this.direction,
  });
}

/// เปรียบเทียบการใช้งานเดือนนี้กับเดือนก่อน
UtilityTrend utilityTrend({required double current, required double previous}) {
  final delta = current - previous;

  final TrendDirection direction;
  if (delta > 0) {
    direction = TrendDirection.up;
  } else if (delta < 0) {
    direction = TrendDirection.down;
  } else {
    direction = TrendDirection.flat;
  }

  // หารด้วยศูนย์ไม่ได้ — เดือนก่อนไม่มีข้อมูลก็ไม่ควรโชว์เปอร์เซ็นต์
  final percent = previous == 0 ? null : (delta / previous) * 100;

  return UtilityTrend(delta: delta, percent: percent, direction: direction);
}

const _thaiMonthNames = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

/// ชื่อเดือนภาษาไทย — ใช้ปี ค.ศ. เหมือนหน้าบิลฝั่งเจ้าของหอ เพื่อไม่ให้
/// สองฝั่งอ่านงวดเดียวกันไม่ตรงกัน
String thaiMonthName(int month) {
  if (month < 1 || month > 12) return '-';
  return _thaiMonthNames[month - 1];
}

/// ป้ายสถานะจากสถานะอย่างเดียว
///
/// `pending` ใช้คำกลางๆ ว่า "รอยืนยัน" เพราะครอบทั้งบิลที่แนบสลิปมาและบิลที่แจ้ง
/// จ่ายเงินสด · ฟังก์ชันนี้ถูกใช้เป็นตัวกรองรายการด้วย ([filterBills]) ข้อความ
/// จึงต้องตรงกับชิปตัวกรอง ถ้าอยากได้คำที่เจาะจงกว่าให้ใช้ [billStatusLabelOf]
String billStatusLabel(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.unpaid:
      return 'ค้างชำระ';
    case InvoiceStatus.pending:
      return 'รอยืนยัน';
    case InvoiceStatus.paid:
      return 'ชำระแล้ว';
    case InvoiceStatus.voided:
      return 'ยกเลิกแล้ว';
  }
}

/// ป้ายสถานะที่รู้ด้วยว่าผู้เช่าแจ้งชำระมาด้วยวิธีไหน
///
/// บิลที่ `pending` มีสองหน้าตาที่เจ้าของหอต้องทำคนละอย่าง — ตรวจสลิป กับ
/// ยืนยันรับเงินสด · ป้ายที่บอกว่า "รอตรวจสลิป" บนบิลที่จ่ายสดมาทำให้ทั้งสอง
/// ฝ่ายไปตามหาสลิปที่ไม่มีอยู่
String billStatusLabelOf(Invoice invoice) {
  if (invoice.awaitsCashConfirmation) return 'รอยืนยันรับเงินสด';
  if (invoice.awaitsSlipReview) return 'รอตรวจสลิป';
  return billStatusLabel(invoice.status);
}

BadgeVariant billStatusVariant(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.unpaid:
      return BadgeVariant.destructive;
    case InvoiceStatus.pending:
      return BadgeVariant.warning;
    case InvoiceStatus.paid:
      return BadgeVariant.success;
    case InvoiceStatus.voided:
      return BadgeVariant.muted;
  }
}

// ── ViewModel ───────────────────────────────────────────────────────────────

class TenantDashboardViewModel extends ChangeNotifier
    with SafeNotifier, TenantSlipSubmission {
  TenantDashboardViewModel({
    required this.roomId,
    this.dormitoryId,
    this.tenantId,
    this.tenantName = 'ผู้พักอาศัย',
    SupabaseService? service,
    TenantBillingSource? billingSource,
  })  : _service = service ?? SupabaseService(),
        _billingSource = billingSource ?? SupabaseTenantBillingSource();

  final int? roomId;
  final int? dormitoryId;
  final String? tenantId;
  final String tenantName;
  final SupabaseService _service;
  final TenantBillingSource _billingSource;

  bool isLoadingRequests = true;
  bool isResponding = false;
  List<TenantJoinRequest> pendingRequests = [];
  String? requestErrorMessage;

  /// true เฉพาะการโหลด "ครั้งแรก" — การ pull-to-refresh ไม่ควรล้างหน้าจอ
  /// เป็น spinner เพราะ RefreshIndicator แสดงสถานะให้อยู่แล้ว
  bool isLoading = true;
  bool _hasLoadedOnce = false;

  // แต่ละส่วนมี error ของตัวเอง — ส่วนเดียวพังไม่ควรทำให้ทั้งหน้าว่าง
  String? billErrorMessage;
  String? usageErrorMessage;
  String? maintenanceErrorMessage;
  String? chatErrorMessage;

  Invoice? currentBill;

  @override
  TenantBillingSource get billingSource => _billingSource;

  @override
  Future<void> reloadAfterSlip() => load();

  /// การใช้ไฟเดือนนี้เทียบเดือนก่อน — null เมื่อมีประวัติไม่ถึง 2 เดือน
  UtilityTrend? electricityTrend;

  List<MaintenanceRequest> openRequests = [];
  ChatMessage? latestMessage;

  /// กำลังส่งคำขอแจ้งซ่อม/ทำความสะอาดจากปุ่มทางลัด
  bool isSubmittingRequest = false;

  Future<void> load() async {
    isLoading = !_hasLoadedOnce;
    notifyListeners();

    // คำขอเข้าหอต้องโหลดเสมอ แม้ยังไม่มีห้อง
    await loadPendingRequests();

    if (roomId != null) {
      await _loadRoomSections();
    }

    isLoading = false;
    _hasLoadedOnce = true;
    notifyListeners();
  }

  /// โหลดทุกส่วนพร้อมกัน โดยดัก error แยกรายส่วน — Future.wait จะไม่ล้มทั้งชุด
  /// เพราะทุก future จับ error ของตัวเองไว้แล้ว
  Future<void> _loadRoomSections() async {
    billErrorMessage = null;
    usageErrorMessage = null;
    maintenanceErrorMessage = null;
    chatErrorMessage = null;

    await Future.wait([
      _loadBillAndUsage(),
      _loadMaintenance(),
      _loadChat(),
    ]);
  }

  Future<void> _loadBillAndUsage() async {
    final room = roomId!;
    final now = DateTime.now();

    try {
      currentBill = await _billingSource.fetchCurrentBill(
        roomDbId: room,
        month: now.month,
        year: now.year,
      );

      await loadPaymentChannel(dormitoryId);
    } catch (error) {
      billErrorMessage = formatErrorMessage(error);
    }

    // แนวโน้มการใช้ไฟดึงแยก เพื่อให้บิลเดือนนี้ยังแสดงได้แม้ประวัติล้ม
    // หน่วยไฟมาจากบิลที่ออกแล้ว ไม่ใช่มิเตอร์สด ตัวเลขที่ผู้เช่าเห็นจึงตรงกับ
    // ตัวเลขที่ถูกเรียกเก็บจริงเสมอ
    try {
      final history = await _billingSource.fetchBillHistory(
        roomDbId: room,
        monthCount: 2,
      );
      if (history.length >= 2) {
        electricityTrend = utilityTrend(
          current: history[0].electricityUnits,
          previous: history[1].electricityUnits,
        );
      } else {
        electricityTrend = null;
      }
    } catch (error) {
      usageErrorMessage = formatErrorMessage(error);
    }
  }

  Future<void> _loadMaintenance() async {
    try {
      final all = await _service.fetchMaintenanceRequests(roomId: roomId!);
      openRequests = all
          .where((request) => request.status != MaintenanceStatus.completed)
          .toList();
    } catch (error) {
      maintenanceErrorMessage = formatErrorMessage(error);
    }
  }

  /// ดึงเฉพาะข้อความล่าสุด — จำนวนที่ยังไม่อ่านมาจาก TenantShellViewModel
  /// ตัวเดียวทั้งหน้าจอ ไม่งั้น badge บน nav กับตัวเลขบนแดชบอร์ดจะไม่ตรงกัน
  Future<void> _loadChat() async {
    try {
      latestMessage = await _service.fetchLatestMessage(
        roomId: roomId!,
        ownerName: 'เจ้าของหอ',
        tenantName: tenantName,
      );
    } catch (error) {
      chatErrorMessage = formatErrorMessage(error);
    }
  }

  Future<ActionResult> submitMaintenanceRequest({
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
    if (isSubmittingRequest) {
      return const ActionResult(success: false, message: 'กำลังส่งคำขออยู่');
    }

    isSubmittingRequest = true;
    notifyListeners();

    try {
      await _service.createMaintenanceRequest(
        roomId: room,
        tenantId: tenant,
        description: description.trim(),
        requestType: requestType,
      );
      await _loadMaintenance();

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
      isSubmittingRequest = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingRequests() async {
    // เช่นเดียวกับ load(): pull-to-refresh ไม่ควรทำให้การ์ดคำขอหายกลายเป็น
    // spinner กลางจอ
    isLoadingRequests = !_hasLoadedOnce;
    requestErrorMessage = null;
    notifyListeners();

    try {
      pendingRequests = await _service.fetchPendingJoinRequestsForTenant();
    } catch (error) {
      requestErrorMessage = formatErrorMessage(error);
    } finally {
      isLoadingRequests = false;
      notifyListeners();
    }
  }

  Future<ActionResult> respondToRequest({
    required TenantJoinRequest request,
    required bool accept,
  }) async {
    isResponding = true;
    notifyListeners();

    try {
      await _service.respondToTenantJoinRequest(
        requestId: request.id,
        accept: accept,
      );

      await loadPendingRequests();

      return ActionResult(
        success: true,
        message: accept
            ? 'เข้าหอ ${request.dormitoryName} แล้ว'
            : 'ปฏิเสธเข้าหอ ${request.dormitoryName} แล้ว',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ตอบคำขอไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isResponding = false;
      notifyListeners();
    }
  }
}
