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

  static const int _pageSize = 10;

  final int dormitoryId;
  final String ownerId;
  final String ownerName;
  final SupabaseService _service;

  static const String allFloors = 'ทั้งหมด';

  bool isLoadingPreviews = true;
  String? previewsErrorMessage;
  List<ChatPreview> chatPreviews = [];
  String searchQuery = '';
  String selectedFloor = allFloors;

  Set<String> get availableFloors =>
      chatPreviews.map((chat) => chat.floor).toSet();

  List<ChatPreview> get filteredChatPreviews {
    final query = searchQuery.trim().toLowerCase();
    return chatPreviews.where((chat) {
      final matchesQuery = query.isEmpty ||
          chat.roomNumber.toLowerCase().contains(query) ||
          chat.tenantName.toLowerCase().contains(query);
      final matchesFloor =
          selectedFloor == allFloors || chat.floor == selectedFloor;
      return matchesQuery && matchesFloor;
    }).toList();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setFloorFilter(String value) {
    selectedFloor = value;
    notifyListeners();
  }

  ChatPreview? selectedChat;
  List<ChatMessage> conversation = [];
  bool isSending = false;
  bool hasMoreMessages = true;
  bool isLoadingMore = false;

  int _messageLimit = _pageSize;
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
    _messageLimit = _pageSize;
    hasMoreMessages = true;
    notifyListeners();

    _subscribeToMessages(chat.roomDbId, chat.tenantName);
    _service.markRoomRead(roomId: chat.roomDbId, userId: ownerId);
  }

  void _subscribeToMessages(int roomId, String tenantName) {
    _messagesSubscription?.cancel();
    _messagesSubscription = _service
        .watchMessages(
      roomId: roomId,
      ownerName: ownerName,
      tenantName: tenantName,
      limit: _messageLimit,
    )
        .listen((messages) {
      // Fewer rows than requested means we've reached the start of history.
      hasMoreMessages = messages.length >= _messageLimit;
      conversation = messages;
      isLoadingMore = false;
      notifyListeners();
    });
  }

  /// Widens the live window and re-subscribes to pull in older history.
  void loadMoreMessages() {
    final chat = selectedChat;
    if (chat == null || isLoadingMore || !hasMoreMessages) return;

    isLoadingMore = true;
    notifyListeners();

    _messageLimit += _pageSize;
    _subscribeToMessages(chat.roomDbId, chat.tenantName);
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
