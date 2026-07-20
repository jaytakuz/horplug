import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required this.dormitoryId,
    required this.ownerId,
    required this.ownerName,
    SupabaseService? service,
  }) : _service = service ?? SupabaseService();

  final int dormitoryId;
  final String ownerId;
  final String ownerName;
  final SupabaseService _service;

  bool isLoadingPreviews = true;
  String? previewsErrorMessage;
  List<ChatPreview> chatPreviews = [];

  ChatPreview? selectedChat;
  List<ChatMessage> conversation = [];
  bool isSending = false;

  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  Future<void> loadChatPreviews() async {
    isLoadingPreviews = true;
    previewsErrorMessage = null;
    notifyListeners();

    try {
      chatPreviews = await _service.fetchChatPreviews(dormitoryId: dormitoryId);
      isLoadingPreviews = false;
      notifyListeners();
    } catch (error) {
      previewsErrorMessage = error.toString();
      isLoadingPreviews = false;
      notifyListeners();
    }
  }

  void openChat(ChatPreview chat) {
    selectedChat = chat;
    conversation = [];
    notifyListeners();

    _messagesSubscription?.cancel();
    _messagesSubscription = _service
        .watchMessages(
      roomId: chat.roomDbId,
      ownerName: ownerName,
      tenantName: chat.tenantName,
    )
        .listen((messages) {
      conversation = messages;
      notifyListeners();
    });

    _service.markRoomRead(roomId: chat.roomDbId, userId: ownerId);
  }

  void closeChat() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    selectedChat = null;
    conversation = [];
    notifyListeners();
    loadChatPreviews();
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
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
