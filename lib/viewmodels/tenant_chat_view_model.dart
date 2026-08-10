import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/invoice_service.dart';
import '../services/supabase_service.dart';
import '../services/tenant_billing_source.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'safe_notifier.dart';

class TenantChatViewModel extends ChangeNotifier with SafeNotifier {
  TenantChatViewModel({
    required this.roomId,
    required this.tenantId,
    required this.tenantName,
    this.dormitoryId,
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
  final SupabaseService _service;
  final InvoiceService _invoiceService;
  final TenantBillingSource _billingSource;

  bool isLoading = true;
  bool isSending = false;
  bool isUploadingImage = false;
  bool isRequestingMaintenance = false;
  bool isSubmittingSlip = false;
  String? errorMessage;

  Map<int, Invoice> invoicesById = {};
  PaymentChannel? paymentChannel;

  /// error จากการ "ส่ง" (ต่างจาก errorMessage ที่เป็น error ของการโหลดแชท)
  /// View อ่านค่านี้ไปขึ้น SnackBar แล้วเรียก clearSendError()
  String? sendErrorMessage;

  List<ChatMessage> conversation = [];
  bool hasMoreMessages = true;
  bool isLoadingMore = false;

  int _messageLimit = _pageSize;
  StreamSubscription<List<ChatMessage>>? _subscription;

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
    final dorm = dormitoryId;
    if (dorm == null) return;
    try {
      paymentChannel = await _billingSource.fetchPaymentChannel(dormitoryId: dorm);
      notifyListeners();
    } catch (_) {
      // ช่องทางชำระเงินไม่ critical — แผ่นชำระเงินแสดงได้แม้ไม่มี QR
    }
  }

  /// ส่งสลิปจากการ์ดบิลในแชท แล้วรีเฟรชสถานะบิลของห้องให้สด
  Future<ActionResult> submitSlip({
    required Invoice bill,
    required File slip,
  }) async {
    isSubmittingSlip = true;
    notifyListeners();

    try {
      final result = await _billingSource.submitPaymentSlip(bill: bill, slip: slip);
      if (result.success) await _loadInvoices();
      return result;
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ส่งสลิปไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isSubmittingSlip = false;
      notifyListeners();
    }
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
    }, onError: (error) {
      errorMessage = error.toString();
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
    });
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
        imageFile: File(picked.path),
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
