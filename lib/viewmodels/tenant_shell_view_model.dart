import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';
import 'safe_notifier.dart';

class TenantShellViewModel extends ChangeNotifier with SafeNotifier {
  TenantShellViewModel({
    required this.roomId,
    required this.tenantId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int? roomId;
  final String? tenantId;
  final SupabaseService _service;

  int unreadMessageCount = 0;

  StreamSubscription<void>? _messageSignalSubscription;
  StreamSubscription<int?>? _roomSubscription;

  final _dataRefreshController = StreamController<void>.broadcast();

  /// สัญญาณให้แท็บหน้าหลัก/บิล/แจ้งซ่อม/โปรไฟล์ดึงข้อมูลใหม่ · ยิงตอนแอปกลับมา
  /// อยู่หน้าจอ และตอนเจ้าของหอส่งข้อความเรื่องบิล/แจ้งซ่อมเข้ามาในแชท เพราะสอง
  /// อย่างนี้บอกว่าข้อมูลฝั่งเจ้าของหออาจเปลี่ยนไปแล้ว แต่ผู้เช่าไม่มี realtime ของ
  /// ตารางพวกนั้นให้รู้เอง
  Stream<void> get dataRefreshSignal => _dataRefreshController.stream;

  void requestDataRefresh() {
    if (!_dataRefreshController.isClosed) _dataRefreshController.add(null);
  }

  /// ฟังสัญญาณข้อความใหม่ตลอดที่แอปเปิดอยู่ (TenantShellViewModel มีชีวิต
  /// เดียวคลุมทุกแท็บผ่าน IndexedStack) badge จึงขึ้นสดแม้ผู้เช่ากำลังอยู่
  /// แท็บอื่นที่ไม่ใช่แชท ไม่ต้องรอสลับแท็บถึงจะเห็นว่ามีข้อความเข้ามา
  void startListeningForNewMessages() {
    if (roomId == null || tenantId == null) return;
    _messageSignalSubscription?.cancel();
    _messageSignalSubscription =
        _service.watchLatestMessageSignal().listen((_) {
      refreshUnreadCount();
    });
  }

  /// ฟังแถวโปรไฟล์ของตัวเอง — เจ้าของหอเพิ่ม ย้าย หรือเอาผู้เช่าออกจากห้องขณะที่
  /// แอปเปิดอยู่ แล้ว [onChanged] อ่านโปรไฟล์ใหม่ (ไม่พาไป splash) ห้องที่เปลี่ยน
  /// ทำให้ TenantShell ถูกสร้างใหม่ตาม roomId เอง
  ///
  /// ต้องเปิด realtime ให้ตาราง tenant_profiles ก่อน (database/
  /// tenant_profiles_realtime.sql) ไม่งั้นได้แค่ข้อมูลตอนสมัครรับแล้วเงียบ —
  /// ไม่ error แค่ไม่มีอะไรมา ฟังก์ชันอื่นจึงไม่พังถ้ายังไม่ได้รัน
  void startWatchingRoomAssignment(VoidCallback onChanged) {
    final tenant = tenantId;
    if (tenant == null) return;
    _roomSubscription?.cancel();
    _roomSubscription = _service.watchTenantRoomId(tenantId: tenant).listen(
      (newRoomId) {
        if (newRoomId != roomId) onChanged();
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _messageSignalSubscription?.cancel();
    _roomSubscription?.cancel();
    _dataRefreshController.close();
    super.dispose();
  }

  Future<void> refreshUnreadCount() async {
    final room = roomId;
    final user = tenantId;
    if (room == null || user == null) return;

    try {
      unreadMessageCount = await _service.countUnreadMessagesForRoom(
        roomId: room,
        userId: user,
      );
      notifyListeners();
    } catch (_) {
      // ไม่ critical — badge คงค่าเดิมไว้ ดีกว่าขึ้น error ให้ผู้ใช้
    }
  }

  /// เคลียร์ badge ทันทีตอนเปิดแท็บแชท ไม่ต้องรอ round-trip
  /// แล้วค่อยบันทึก last_read_at ตามหลัง
  Future<void> markChatRead() async {
    final room = roomId;
    final user = tenantId;
    if (room == null || user == null) return;

    if (unreadMessageCount != 0) {
      unreadMessageCount = 0;
      notifyListeners();
    }

    try {
      await _service.markRoomRead(roomId: room, userId: user);
    } catch (_) {
      // เงียบไว้ — ครั้งหน้าที่ refresh จะได้ค่าที่ถูกต้องเอง
    }
  }
}
