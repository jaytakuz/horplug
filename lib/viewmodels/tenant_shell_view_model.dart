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
