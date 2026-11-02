import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../models/picked_image.dart';
import '../services/invoice_service.dart';
import '../services/supabase_service.dart';
import '../services/tenant_billing_source.dart';
import 'error_message.dart';
import 'safe_notifier.dart';
import 'tenant_slip_submission.dart';

class TenantChatViewModel extends ChangeNotifier
    with SafeNotifier, TenantSlipSubmission {
  TenantChatViewModel({
    required this.roomId,
    required this.tenantId,
    required this.tenantName,
    this.dormitoryId,
    this.onLandlordUpdate,
    SupabaseService? service,
    InvoiceService? invoiceService,
    TenantBillingSource? billingSource,
  })  : _service = service ?? SupabaseService(),
        _invoiceService = invoiceService ?? InvoiceService(),
        _billingSource = billingSource ?? SupabaseTenantBillingSource();

  static const int _pageSize = 10;
  static const String _ownerLabel = 'เจ้าของหอ';

  final int roomId;
  final String tenantId;
  final String tenantName;
  final int? dormitoryId;

  /// เรียกเมื่อเจ้าของหอส่งข้อความที่หมายถึง "ข้อมูลของผู้เช่าเปลี่ยน" เข้ามาใหม่
  /// ระหว่างที่แอปเปิดอยู่ — เรื่องบิล (การ์ดบิล, รับ/ปฏิเสธการชำระ, ยกเลิกบิล,
  /// แจ้งยอดเปลี่ยน ซึ่งผูก invoice_id) และอัปเดตสถานะแจ้งซ่อม/ทำความสะอาด
  /// ผู้เช่าไม่มี realtime ของตารางพวกนี้ ข้อความในแชทจึงเป็นสัญญาณเดียวที่บอกว่า
  /// แท็บหน้าหลัก/บิล/แจ้งซ่อมควรดึงข้อมูลใหม่
  final VoidCallback? onLandlordUpdate;

  final SupabaseService _service;
  final InvoiceService _invoiceService;
  final TenantBillingSource _billingSource;

  bool isLoading = true;
  bool isSending = false;
  bool isUploadingImage = false;
  bool isRequestingMaintenance = false;
  String? errorMessage;

  Map<int, Invoice> invoicesById = {};

  @override
  TenantBillingSource get billingSource => _billingSource;

  /// รีเฟรชบิลของห้องหลังส่งสลิป เพื่อให้ป้ายสถานะบนการ์ดในแชทเปลี่ยนทันที
  @override
  Future<void> reloadAfterSlip() => _loadInvoices();

  /// error จากการ "ส่ง" (ต่างจาก errorMessage ที่เป็น error ของการโหลดแชท)
  /// View อ่านค่านี้ไปขึ้น SnackBar แล้วเรียก clearSendError()
  String? sendErrorMessage;

  List<ChatMessage> conversation = [];
  bool hasMoreMessages = true;
  bool isLoadingMore = false;

  int _messageLimit = _pageSize;
  StreamSubscription<List<ChatMessage>>? _subscription;

  /// id ของข้อความที่เคยเห็นแล้ว ไว้แยกข้อความ "ใหม่" ออกจากที่เคยประมวลผลแล้ว
  /// เมื่อ stream ส่งรายการทั้งก้อนมาซ้ำทุกครั้งที่มีการเปลี่ยนแปลง — ใช้ทั้งกับ
  /// การเช็คบิลที่ต้องโหลดใหม่และ (ในอนาคต) อย่างอื่นที่ต้องรู้ว่า "เพิ่งมาถึง"
  bool _invoiceBaselineSet = false;
  Set<String> _knownMessageIds = {};

  void start() {
    isLoading = true;
    errorMessage = null;
    _messageLimit = _pageSize;
    hasMoreMessages = true;
    notifyListeners();

    _subscribeToMessages();
    // จงใจไม่ markRoomRead ที่นี่ — IndexedStack ใน TenantShell build ทุกแท็บ
    // ตั้งแต่เฟรมแรก start() จึงทำงานทันทีที่เปิดแอปแม้ผู้ใช้ยังไม่เคยเข้า
    // แท็บแชท ถ้า mark ตรงนี้ last_read_at จะถูกดันไปเป็นเวลาเปิดแอปเสมอ
    // ทำให้ badge นับได้ 0 ตลอดและข้อความที่เข้ามาตอนแอปปิดไม่เคยแจ้งเตือน
    // ให้ TenantShellViewModel.markChatRead() เป็นเจ้าของเรื่องนี้คนเดียว
    // (เรียกเมื่ออยู่แท็บแชทจริง)
    _loadInvoices();
    _loadPaymentChannel();
  }

  // โหลดครั้งเดียวตอนเปิดแชท แล้ว resolve ตาม invoiceId — เพิ่ม query เดียว
  // แลกกับการไม่มีการ์ดค้างที่ยังบอกว่าค้างชำระทั้งที่จ่ายไปแล้วเมื่อวาน
  Future<void> _loadInvoices() async {
    try {
      invoicesById = await _invoiceService.invoicesByIdForRoom(roomDbId: roomId);
    } catch (_) {
      // การ์ดจะ fallback ไปแสดงข้อความสำรอง แชทต้องไม่พังเพราะบิลโหลดไม่ได้
      invoicesById = {};
    }
    notifyListeners();
  }

  Future<void> _loadPaymentChannel() async {
    await loadPaymentChannel(dormitoryId);
    notifyListeners();
  }

  void _subscribeToMessages() {
    _subscription?.cancel();
    _subscription = _service
        .watchMessages(
      roomId: roomId,
      ownerName: _ownerLabel,
      tenantName: tenantName,
      limit: _messageLimit,
    )
        .listen((messages) {
      hasMoreMessages = messages.length >= _messageLimit;
      conversation = messages;
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
      _signalIfNewLandlordUpdate(messages);
      _reloadInvoicesIfNewCardArrived(messages);
    }, onError: (error) {
      errorMessage = formatErrorMessage(error);
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
    });
  }

  /// เรียกจากปุ่ม "ลองใหม่" หลังการเชื่อมต่อแบบเรียลไทม์ล้มเหลว
  ///
  /// แท็บนี้ไม่เคย dispose ตราบใดที่แอปยังเปิดอยู่ (อยู่ใน IndexedStack ของ
  /// TenantShell) ถ้าปล่อยให้ errorMessage ค้างอยู่เฉยๆ ผู้เช่าจะเห็นข้อความ
  /// นี้ไปตลอดจนกว่าจะปิดแอปทั้งแอปแล้วเปิดใหม่
  void retryConnection() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    _subscribeToMessages();
  }

  /// รีเฟรช invoicesById เมื่อการ์ดบิล "ใหม่" โผล่เข้ามาในแชท — ทั้งบิลที่ไม่
  /// เคยเห็นมาก่อน (ออกบิลใหม่) และบิลเดิมที่เจ้าของหอส่งการ์ดซ้ำหลังสถานะ
  /// เปลี่ยน เช่น ปฏิเสธการแจ้งเงินสดแล้วส่งการ์ดเดิมอีกครั้ง
  ///
  /// เดิมเช็คแค่ "invoiceId ที่ยังไม่มีใน invoicesById" ซึ่งพลาดกรณีที่สอง —
  /// บิลที่เคย resolve ไปแล้วครั้งหนึ่ง (ตอนสถานะยังเป็นรอยืนยันรับเงินสด) จะไม่
  /// ถูกโหลดสถานะใหม่เลยแม้สถานะจริงในฐานข้อมูลเปลี่ยนไปแล้ว ผู้เช่าเห็นสถานะ
  /// เก่าค้างอยู่บนการ์ด กดจ่ายไม่ได้ (canOpenPaymentSheet เช็คจากสถานะเก่า)
  /// ทั้งที่เจ้าของหอเพิ่งส่งการ์ดใหม่มาเตือนให้จ่ายจริง — ขัดกับที่
  /// invoicesByIdForRoom ตั้งใจให้การ์ดแสดง "สถานะสด ไม่ใช่สถานะตอนส่ง"
  ///
  /// เช็คจาก id ข้อความที่เคยเห็นแล้วแทน id ของบิล เพื่อแยก "การ์ดที่เพิ่งส่ง
  /// มาใหม่" ออกจาก "การ์ดเก่าที่ยังอยู่ในหน้าต่างข้อความเดิม" (ซึ่ง stream
  /// ส่งรายการทั้งก้อนมาซ้ำทุกครั้ง ไม่ใช่เฉพาะที่เปลี่ยน) การส่งครั้งแรกเป็น
  /// แค่ฐานเทียบ ไม่โหลดซ้ำกับที่ start() โหลดไปแล้ว
  void _reloadInvoicesIfNewCardArrived(List<ChatMessage> messages) {
    final currentIds = messages.map((message) => message.id).toSet();

    if (!_invoiceBaselineSet) {
      _invoiceBaselineSet = true;
      _knownMessageIds = currentIds;
      return;
    }

    final hasNewInvoiceCard = messages.any((message) =>
        message.type == MessageType.invoice &&
        message.invoiceId != null &&
        !_knownMessageIds.contains(message.id));
    _knownMessageIds = currentIds;
    if (hasNewInvoiceCard) _loadInvoices();
  }

  static bool _isLandlordUpdate(ChatMessage message) =>
      message.type == MessageType.invoice ||
      message.type == MessageType.maintenanceUpdate ||
      message.type == MessageType.cleaningUpdate ||
      message.invoiceId != null;

  bool _updateBaselineSet = false;
  DateTime? _latestUpdateAt;

  /// เทียบตามเวลาของข้อความที่เข้าเงื่อนไขที่ใหม่ที่สุด ไม่ใช่ตาม id ที่เคยเห็น —
  /// [loadMoreMessages] ขยายหน้าต่างให้เห็นข้อความเก่าขึ้น ซึ่งไม่ใช่เหตุการณ์ใหม่
  /// และต้องไม่ยิงสัญญาณ · การส่งครั้งแรกเป็นแค่ฐานเทียบ (ประวัติที่มีอยู่แล้วตอน
  /// เปิดแอป) ไม่ยิงสัญญาณ · นับเฉพาะที่เจ้าของหอส่ง เพราะสิ่งที่ผู้เช่าทำเอง
  /// (แนบสลิป ฯลฯ) โหลดข้อมูลใหม่ของตัวเองอยู่แล้ว
  void _signalIfNewLandlordUpdate(List<ChatMessage> messages) {
    DateTime? newest;
    for (final message in messages) {
      if (!message.isFromOwner) continue;
      if (!_isLandlordUpdate(message)) continue;
      if (newest == null || message.timestamp.isAfter(newest)) {
        newest = message.timestamp;
      }
    }

    final isFirstEmission = !_updateBaselineSet;
    _updateBaselineSet = true;

    final previous = _latestUpdateAt;
    final isNewer = newest != null && (previous == null || newest.isAfter(previous));
    if (isNewer) _latestUpdateAt = newest;

    if (!isFirstEmission && isNewer) onLandlordUpdate?.call();
  }

  /// Widens the live window and re-subscribes to pull in older history.
  void loadMoreMessages() {
    if (isLoadingMore || !hasMoreMessages) return;

    isLoadingMore = true;
    notifyListeners();

    _messageLimit += _pageSize;
    _subscribeToMessages();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    isSending = true;
    notifyListeners();

    try {
      await _service.sendMessage(
        roomId: roomId,
        senderId: tenantId,
        isFromOwner: false,
        body: trimmed,
      );
      errorMessage = null;
    } catch (error) {
      // เดิม finally เปล่าทำให้ error หลุดออกไปเป็น unhandled async exception
      // (ผู้เรียกไม่ await) ผู้ใช้เห็นแค่ข้อความที่พิมพ์หายไปเฉยๆ
      sendErrorMessage = 'ส่งข้อความไม่สำเร็จ: ${formatErrorMessage(error)}';
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> pickAndSendImage(ImageSource source) async {
    if (isUploadingImage) return;

    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    isUploadingImage = true;
    notifyListeners();

    try {
      final path = await _service.uploadChatImage(
        roomId: roomId,
        image: await PickedImage.fromXFile(picked),
      );
      await _service.sendMessage(
        roomId: roomId,
        senderId: tenantId,
        isFromOwner: false,
        body: 'รูปภาพ',
        type: MessageType.image,
        attachmentUrl: path,
      );
    } catch (error) {
      sendErrorMessage = 'ส่งรูปไม่สำเร็จ: ${formatErrorMessage(error)}';
    } finally {
      isUploadingImage = false;
      notifyListeners();
    }
  }

  Future<void> requestMaintenance(
      String description, MaintenanceRequestType type) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty || isRequestingMaintenance) return;

    isRequestingMaintenance = true;
    notifyListeners();

    try {
      await _service.createMaintenanceRequest(
        roomId: roomId,
        tenantId: tenantId,
        description: trimmed,
        requestType: type,
      );
    } catch (error) {
      sendErrorMessage = 'ส่งคำขอไม่สำเร็จ: ${formatErrorMessage(error)}';
    } finally {
      isRequestingMaintenance = false;
      notifyListeners();
    }
  }

  void clearSendError() {
    if (sendErrorMessage == null) return;
    sendErrorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
