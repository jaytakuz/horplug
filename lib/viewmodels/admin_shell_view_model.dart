import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';

class AdminShellViewModel extends ChangeNotifier {
  AdminShellViewModel({
    required this.dormitoryId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int dormitoryId;
  final SupabaseService _service;

  int unreadMessageCount = 0;

  StreamSubscription<void>? _messageSignalSubscription;

  /// ห้องที่เจ้าของหอกำลังเปิดอ่านอยู่บนแท็บแชทตอนนี้ (null = ไม่ได้อ่านห้องไหน)
  int? _viewedRoomId;

  /// นับรอบล่าสุดที่ยิง — คำตอบของรอบเก่าที่มาช้ากว่าต้องไม่ทับรอบใหม่ ไม่งั้น
  /// badge กลับไปโชว์เลขเก่าหลังจากเคลียร์ไปแล้ว
  int _refreshGeneration = 0;

  /// เรียกจากแท็บแชทเมื่อเปิด/ปิดห้อง หรือสลับเข้า/ออกจากแท็บแชท
  void setViewedRoom(int? roomId) {
    if (_viewedRoomId == roomId) return;
    _viewedRoomId = roomId;
    refreshUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    if (dormitoryId == 0) return;

    final generation = ++_refreshGeneration;
    try {
      final count = await _service.countUnreadMessages(
        dormitoryId: dormitoryId,
        excludeRoomId: _viewedRoomId,
      );
      if (generation != _refreshGeneration) return;
      unreadMessageCount = count;
      notifyListeners();
    } catch (_) {
      // Non-critical — badge just keeps its last known value.
    }
  }

  /// ฟังสัญญาณข้อความใหม่ตลอดที่ล็อกอินอยู่ (AdminShellViewModel มีชีวิตเดียว
  /// คลุมทุกแท็บผ่าน IndexedStack) ไม่ต้องรอผู้ใช้แตะแท็บแชทหรือดึงรีเฟรช
  /// badge ตัวเลขจึงขึ้นสดแม้กำลังดูแท็บอื่นอยู่
  void startListeningForNewMessages() {
    if (dormitoryId == 0) return;
    _messageSignalSubscription?.cancel();
    _messageSignalSubscription =
        _service.watchLatestMessageSignal().listen((_) {
      refreshUnreadCount();
    });
  }

  @override
  void dispose() {
    _messageSignalSubscription?.cancel();
    super.dispose();
  }
}
