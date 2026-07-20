import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

class TenantChatViewModel extends ChangeNotifier {
  TenantChatViewModel({
    required this.roomId,
    required this.tenantId,
    required this.tenantName,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int roomId;
  final String tenantId;
  final String tenantName;
  final SupabaseService _service;

  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;
  List<ChatMessage> conversation = [];

  StreamSubscription<List<ChatMessage>>? _subscription;

  void start() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _service
        .watchMessages(
      roomId: roomId,
      ownerName: 'เจ้าของหอ',
      tenantName: tenantName,
    )
        .listen((messages) {
      conversation = messages;
      isLoading = false;
      notifyListeners();
    }, onError: (error) {
      errorMessage = error.toString();
      isLoading = false;
      notifyListeners();
    });

    _service.markRoomRead(roomId: roomId, userId: tenantId);
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
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
