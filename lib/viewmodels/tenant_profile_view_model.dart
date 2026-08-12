import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'error_message.dart';
import 'refreshable.dart';
import 'safe_notifier.dart';

String roomStatusLabel(RoomStatus status) {
  switch (status) {
    case RoomStatus.occupied:
      return 'เข้าพักอยู่';
    case RoomStatus.maintenance:
      return 'อยู่ระหว่างซ่อม';
    case RoomStatus.vacant:
      return 'ว่าง';
  }
}

class TenantProfileViewModel extends ChangeNotifier
    with SafeNotifier, RefreshableViewModel {
  TenantProfileViewModel({
    required this.roomId,
    required this.dormitoryId,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int? roomId;
  final int? dormitoryId;
  final SupabaseService _service;

  String? errorMessage;
  Room? room;
  DormitoryInfo? dormitory;

  Future<void> load() async {
    final roomDbId = roomId;
    if (roomDbId == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    return runLoad(() async {
      errorMessage = null;
      try {
        room = await _service.fetchRoom(roomDbId: roomDbId);
      } catch (error) {
        errorMessage = formatErrorMessage(error);
      }

      // ข้อมูลติดต่อเจ้าของหอต้องรัน rls_tenant_access.sql ก่อนจึงจะอ่านได้ —
      // ถ้าอ่านไม่ได้ให้เงียบไว้แล้วโชว์ "ไม่พบข้อมูลผู้ติดต่อ" แทนขึ้น error
      final dorm = dormitoryId;
      if (dorm != null) {
        try {
          dormitory = await _service.fetchDormitoryInfo(dormitoryId: dorm);
        } catch (_) {}
      }
    });
  }
}
