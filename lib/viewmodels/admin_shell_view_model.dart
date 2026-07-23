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
}
