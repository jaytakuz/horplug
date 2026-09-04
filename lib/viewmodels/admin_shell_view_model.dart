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

  Future<void> refreshUnreadCount() async {
    if (dormitoryId == 0) return;

    try {
      unreadMessageCount =
          await _service.countUnreadMessages(dormitoryId: dormitoryId);
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
