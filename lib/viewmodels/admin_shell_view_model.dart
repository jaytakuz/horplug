import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

class AdminShellViewModel extends ChangeNotifier {
  AdminShellViewModel({
    required this.dormitoryId,
    required this.ownerId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int dormitoryId;
  final String ownerId;
  final SupabaseService _service;

  int unreadMessageCount = 0;

  Future<void> refreshUnreadCount() async {
    if (dormitoryId == 0 || ownerId.isEmpty) return;

    try {
      final rooms = await _service.fetchRooms(dormitoryId: dormitoryId);
      final occupiedRoomIds = rooms
          .where((room) => room.status == RoomStatus.occupied)
          .map((room) => room.dbId)
          .toList();

      unreadMessageCount = await _service.countUnreadMessages(
        roomIds: occupiedRoomIds,
        userId: ownerId,
      );
      notifyListeners();
    } catch (_) {
      // Non-critical — badge just keeps its last known value.
    }
  }
}
