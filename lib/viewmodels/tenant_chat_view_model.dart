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

  static const int _pageSize = 10;
  static const String _ownerLabel = 'เจ้าของหอ';

  final int roomId;
  final String tenantId;
  final String tenantName;
  final SupabaseService _service;

  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;
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
    _service.markRoomRead(roomId: roomId, userId: tenantId);
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
