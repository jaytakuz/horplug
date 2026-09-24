import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../models/picked_image.dart';
import '../services/invoice_service.dart';
import '../services/supabase_service.dart';
import 'error_message.dart';
import 'safe_notifier.dart';

class ChatViewModel extends ChangeNotifier with SafeNotifier {
  ChatViewModel({
    required this.dormitoryId,
    required this.ownerId,
    required this.ownerName,
    SupabaseService? service,
    InvoiceService? invoiceService,
    this.onRoomRead,
    this.onViewedRoomChanged,
  })  : _service = service ?? SupabaseService(),
        _invoiceService = invoiceService ?? InvoiceService();

  static const int _pageSize = 10;

  final int dormitoryId;
  final String ownerId;
  final String ownerName;
  final SupabaseService _service;
  final InvoiceService _invoiceService;

  /// เรียกทันทีที่ mark ห้องว่าอ่านแล้วสำเร็จตอนเปิดห้อง (ไม่ใช่ตอนปิด) —
  /// ใช้ให้ AdminShellViewModel (เจ้าของ badge บนแท็บแชท) รีเฟรชจำนวนของตัวเอง
  /// เพราะเป็นคนละ ViewModel กับตัวนี้ และไม่ได้ฟังการเปลี่ยนแปลงของตาราง
  /// message_reads ที่ markRoomRead เขียน
  final VoidCallback? onRoomRead;

  /// บอก AdminShellViewModel ว่าตอนนี้เจ้าของหอกำลัง "มองเห็น" ห้องไหนอยู่ (null =
  /// ไม่ได้อ่านห้องไหน) — ห้องนั้นถูกตัดออกจากตัวเลข badge ทันที ไม่ต้องรอให้
  /// last_read_at บนเซิร์ฟเวอร์ขยับ ไม่งั้นข้อความที่เพิ่งเข้ามาระหว่างอ่านอยู่จะ
  /// โผล่เป็น badge ค้างทั้งที่เห็นแล้ว
  final ValueChanged<int?>? onViewedRoomChanged;

  static const String allFloors = 'ทั้งหมด';

  bool isLoadingPreviews = true;
  String? previewsErrorMessage;
  List<ChatPreview> chatPreviews = [];
  String searchQuery = '';
  String selectedFloor = allFloors;

  Set<String> get availableFloors =>
      chatPreviews.map((chat) => chat.floor).toSet();

  List<ChatPreview> get filteredChatPreviews {
    final query = searchQuery.trim().toLowerCase();
    return chatPreviews.where((chat) {
      final matchesQuery = query.isEmpty ||
          chat.roomNumber.toLowerCase().contains(query) ||
          chat.tenantName.toLowerCase().contains(query);
      final matchesFloor =
          selectedFloor == allFloors || chat.floor == selectedFloor;
      return matchesQuery && matchesFloor;
    }).toList();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setFloorFilter(String value) {
    selectedFloor = value;
    notifyListeners();
  }

  ChatPreview? selectedChat;

  /// true เมื่อแท็บแชทเป็นแท็บที่แสดงอยู่จริง · IndexedStack สร้างทุกแท็บไว้ตั้งแต่
  /// เฟรมแรกและไม่เคย dispose ห้องที่เปิดค้างไว้จึงยัง "เปิดอยู่" แม้ผู้ใช้ไปอยู่
  /// แท็บอื่นแล้ว — ข้อความที่เข้ามาตอนนั้นยังไม่ได้อ่านจริง ต้องไม่ถูก mark
  bool _tabVisible = false;
  int? _reportedViewedRoom;

  List<ChatMessage> conversation = [];
  bool isSending = false;
  bool isUploadingImage = false;

  /// ข้อความบอกว่าการส่งครั้งล่าสุดล้มเหลว · หน้าจอโชว์แล้วเรียก
  /// [clearSendError] — คู่เดียวกับที่ฝั่งผู้เช่าใช้อยู่
  String? sendErrorMessage;
  bool isUpdatingMaintenance = false;
  bool hasMoreMessages = true;
  bool isLoadingMore = false;

  int _messageLimit = _pageSize;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription<void>? _previewsSignalSubscription;

  Map<int, Invoice> invoicesById = {};

  // โหลดครั้งเดียวตอนเปิดแชท แล้ว resolve ตาม invoiceId — เพิ่ม query เดียว
  // แลกกับการไม่มีการ์ดค้างที่ยังบอกว่าค้างชำระทั้งที่จ่ายไปแล้วเมื่อวาน
  Future<void> _loadInvoices(int roomId) async {
    try {
      final resolved =
          await _invoiceService.invoicesByIdForRoom(roomDbId: roomId);
      // ห้องอาจถูกปิดหรือสลับไปห้องอื่นระหว่างรอผล — ผลที่มาช้าของห้องเก่า
      // ต้องไม่ทับของห้องที่กำลังเปิดอยู่
      if (selectedChat?.roomDbId != roomId) return;
      invoicesById = resolved;
    } catch (_) {
      if (selectedChat?.roomDbId != roomId) return;
      // การ์ดจะ fallback ไปแสดงข้อความสำรอง แชทต้องไม่พังเพราะบิลโหลดไม่ได้
      invoicesById = {};
    }
    notifyListeners();
  }

  /// ฟังสัญญาณข้อความใหม่ตลอดที่แท็บแชทยังมีชีวิตอยู่ (IndexedStack ไม่เคย
  /// dispose แท็บนี้) แล้วโหลดรายการห้องใหม่ทันที ไม่ต้องรอผู้ใช้ดึงรีเฟรช —
  /// ข้ามไปถ้ากำลังเปิดสนทนาห้องใดห้องหนึ่งอยู่ เพราะ badge/ข้อความล่าสุดของ
  /// ห้องนั้นแสดงผ่าน _subscribeToMessages อยู่แล้ว ไม่ต้องโหลดซ้ำ
  void startWatchingPreviews() {
    _previewsSignalSubscription?.cancel();
    _previewsSignalSubscription =
        _service.watchLatestMessageSignal().listen((_) {
      if (selectedChat == null) loadChatPreviews(background: true);
    });
  }

  bool _previewsLoadedOnce = false;

  /// [background] = ดึงเงียบๆ ตอนมีข้อความใหม่/กลับจากห้องแชท — ผู้ใช้ไม่ได้สั่ง
  /// จึงไม่ควรเห็นอะไรเปลี่ยนนอกจากแถวที่อัปเดต
  ///
  /// ตัวหมุนเต็มหน้าจอโชว์เฉพาะตอนยังไม่มีรายการให้ดู (โหลดครั้งแรก หรือกดลอง
  /// ใหม่หลังล้ม) เดิมทุกครั้งที่ผู้เช่าส่งข้อความ รายการทั้งหน้าหายกลายเป็นตัว
  /// หมุนแล้วโผล่กลับมาใหม่ ทั้งที่แค่ต้องอัปเดตแถวเดียว
  Future<void> loadChatPreviews({bool background = false}) async {
    final showSpinner = !_previewsLoadedOnce || previewsErrorMessage != null;
    if (showSpinner) {
      isLoadingPreviews = true;
      previewsErrorMessage = null;
      notifyListeners();
    }

    try {
      chatPreviews = await _service.fetchChatPreviews(dormitoryId: dormitoryId);
      _previewsLoadedOnce = true;
      previewsErrorMessage = null;
      isLoadingPreviews = false;
      notifyListeners();
    } catch (error) {
      // การดึงเบื้องหลังที่ล้ม (เน็ตหลุดชั่วครู่) ไม่ควรแทนรายการที่มีอยู่ด้วยหน้า
      // error — ผู้ใช้ไม่ได้สั่ง และของเดิมยังใช้ได้ · การสั่งเอง (ลากรีเฟรช) ยัง
      // รายงาน error ตามเดิม
      if (background && _previewsLoadedOnce) return;
      previewsErrorMessage = error.toString();
      isLoadingPreviews = false;
      notifyListeners();
    }
  }

  void openChat(ChatPreview chat) {
    selectedChat = chat;
    conversation = [];
    _messageLimit = _pageSize;
    hasMoreMessages = true;
    notifyListeners();

    _subscribeToMessages(chat.roomDbId, chat.tenantName);
    _syncViewedRoom();
    _loadInvoices(chat.roomDbId);
  }

  /// แท็บแชทถูกสลับเข้า/ออกจากหน้าจอ · เรียกจาก ChatScreen ตามตำแหน่งจริงของ
  /// router ไม่ใช่ตามการแตะ nav bar เพราะเข้าแท็บนี้ได้จากทางลัดบนแดชบอร์ดด้วย
  void setTabVisible(bool visible) {
    if (_tabVisible == visible) return;
    _tabVisible = visible;
    _syncViewedRoom();
    // กลับมาที่ห้องที่เปิดค้างไว้ — ข้อความที่เข้ามาระหว่างอยู่แท็บอื่นเพิ่งถูกเห็น
    if (visible) _markViewedRoomRead();
  }

  int? get _viewedRoom => _tabVisible ? selectedChat?.roomDbId : null;

  void _syncViewedRoom() {
    final viewed = _viewedRoom;
    if (viewed == _reportedViewedRoom) return;
    _reportedViewedRoom = viewed;
    onViewedRoomChanged?.call(viewed);
    if (viewed != null) _markViewedRoomRead();
  }

  /// บันทึก last_read_at ของห้องที่กำลังมองอยู่ — ไม่ทำอะไรถ้าไม่ได้มองห้องไหน
  ///
  /// ไม่ await เพราะไม่ควรหน่วงการเปิดแชท แต่ต้องกลืน error เอง ไม่งั้นถ้า upsert
  /// ล้ม (ออฟไลน์ / RLS) จะกลายเป็น unhandled async exception · เรียก onRoomRead
  /// ทันทีที่ mark ผ่าน เพื่อให้ badge นับใหม่จากค่าที่ถูกต้อง
  void _markViewedRoomRead() {
    final roomId = _viewedRoom;
    if (roomId == null) return;
    _service
        .markRoomRead(roomId: roomId, userId: ownerId)
        .then((_) => onRoomRead?.call())
        .catchError((_) {});
  }

  /// รีโหลดแผนที่บิลของห้องที่เปิดอยู่ตอนนี้
  ///
  /// _loadInvoices เดิมโหลดครั้งเดียวตอนเปิดแชท การ์ดบิลจึงค้างสถานะเก่าถ้า
  /// เจ้าของหออนุมัติ ปฏิเสธ หรือยกเลิกบิลผ่านแผ่นรายละเอียดที่เปิดจากในแชท
  /// ผู้เรียก (chat_screen.dart) เรียกเมธอดนี้ต่อเมื่อแผ่นนั้นรายงานว่ามีการ
  /// เปลี่ยนสถานะจริง ไม่ทำอะไรถ้าไม่มีห้องเปิดอยู่แล้ว (เช่นผู้ใช้ปิดแชทไปก่อน)
  Future<void> refreshInvoices() {
    final chat = selectedChat;
    if (chat == null) return Future.value();
    return _loadInvoices(chat.roomDbId);
  }

  void _subscribeToMessages(int roomId, String tenantName) {
    _messagesSubscription?.cancel();
    _messagesSubscription = _service
        .watchMessages(
      roomId: roomId,
      ownerName: ownerName,
      tenantName: tenantName,
      limit: _messageLimit,
    )
        .listen((messages) {
      // Fewer rows than requested means we've reached the start of history.
      hasMoreMessages = messages.length >= _messageLimit;
      conversation = messages;
      isLoadingMore = false;
      notifyListeners();
      // ข้อความใหม่ที่เข้ามาขณะกำลังอ่านห้องนี้อยู่ถือว่าอ่านแล้ว · เดิม mark แค่ตอน
      // เปิดห้อง last_read_at จึงค้างอยู่ที่เวลาเปิด แล้วทุกข้อความหลังจากนั้นถูกนับ
      // เป็นยังไม่อ่านทั้งที่เห็นอยู่ตรงหน้า
      _markViewedRoomRead();
    });
  }

  /// Widens the live window and re-subscribes to pull in older history.
  void loadMoreMessages() {
    final chat = selectedChat;
    if (chat == null || isLoadingMore || !hasMoreMessages) return;

    isLoadingMore = true;
    notifyListeners();

    _messageLimit += _pageSize;
    _subscribeToMessages(chat.roomDbId, chat.tenantName);
  }

  void closeChat() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    selectedChat = null;
    conversation = [];
    invoicesById = {};
    notifyListeners();
    _syncViewedRoom();
    loadChatPreviews(background: true);
  }

  Future<void> sendMessage(String text) async {
    final chat = selectedChat;
    final trimmed = text.trim();
    if (chat == null || trimmed.isEmpty) return;

    isSending = true;
    notifyListeners();

    try {
      await _service.sendMessage(
        roomId: chat.roomDbId,
        senderId: ownerId,
        isFromOwner: true,
        body: trimmed,
      );
    } catch (error) {
      // เดิมมีแต่ finally — error หลุดเป็น unhandled async exception
      // (ผู้เรียกไม่ await) เจ้าของหอเห็นแค่ข้อความที่พิมพ์หายไปเฉยๆ เหมือนที่
      // เคยเกิดกับฝั่งผู้เช่ามาก่อน ใช้ sendErrorMessage ตัวเดียวกับที่ส่งรูปใช้
      sendErrorMessage = 'ส่งข้อความไม่สำเร็จ: ${formatErrorMessage(error)}';
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> pickAndSendImage(ImageSource source) async {
    final chat = selectedChat;
    if (chat == null || isUploadingImage) return;

    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    isUploadingImage = true;
    notifyListeners();

    try {
      final path = await _service.uploadChatImage(
        roomId: chat.roomDbId,
        image: await PickedImage.fromXFile(picked),
      );
      await _service.sendMessage(
        roomId: chat.roomDbId,
        senderId: ownerId,
        isFromOwner: true,
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

  Future<void> updateMaintenanceStatus({
    required int requestId,
    required MaintenanceStatus status,
    required MaintenanceRequestType requestType,
  }) async {
    final chat = selectedChat;
    if (chat == null || isUpdatingMaintenance) return;

    isUpdatingMaintenance = true;
    notifyListeners();

    try {
      await _service.updateMaintenanceStatus(
        requestId: requestId,
        roomId: chat.roomDbId,
        landlordId: ownerId,
        status: status,
        requestType: requestType,
      );
    } finally {
      isUpdatingMaintenance = false;
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
    _messagesSubscription?.cancel();
    _previewsSignalSubscription?.cancel();
    super.dispose();
  }
}
