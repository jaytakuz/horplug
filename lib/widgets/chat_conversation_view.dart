import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Message list + input bar shared by the landlord and tenant chat screens.
/// Callers own the conversation data/header; this widget only renders the
/// scrolling bubble list and handles composing/sending a new message.
class ChatConversationView extends StatefulWidget {
  const ChatConversationView({
    super.key,
    required this.messages,
    required this.isSending,
    required this.onSend,
    required this.isCurrentUserOwner,
    this.showQuickChips = true,
    this.hasMoreMessages = false,
    this.isLoadingMore = false,
    this.onLoadMore,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final Future<void> Function(String text) onSend;

  /// Whether the person viewing this conversation is the landlord (owner).
  /// Bubble alignment is relative to the viewer: a message shows on the
  /// right when it was sent by whichever role is currently looking at it.
  final bool isCurrentUserOwner;
  final bool showQuickChips;

  /// Whether older history exists beyond what's currently loaded.
  final bool hasMoreMessages;
  final bool isLoadingMore;

  /// Called when the user scrolls up to the oldest loaded message.
  final VoidCallback? onLoadMore;

  @override
  State<ChatConversationView> createState() => _ChatConversationViewState();
}

class _ChatConversationViewState extends State<ChatConversationView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // The list is `reverse: true`, so the oldest loaded message sits at
  // maxScrollExtent — scrolling near there means "reached the top" visually.
  void _handleScroll() {
    if (!widget.hasMoreMessages || widget.isLoadingMore) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      widget.onLoadMore?.call();
    }
  }

  Future<void> _handleSend() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    _messageController.clear();
    await widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.messages.isEmpty
            ? Center(
                child: Text(
                  'ยังไม่มีข้อความ เริ่มพูดคุยได้เลย',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                reverse: true,
                itemCount:
                    widget.messages.length + (widget.hasMoreMessages ? 1 : 0),
                itemBuilder: (context, index) {
                  // Reverse:true renders the last index at the very top of
                  // the screen — the correct spot for a "loading older" cue.
                  if (index == widget.messages.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: widget.isLoadingMore
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  }
                  final message = widget.messages.reversed.toList()[index];
                  return _buildChatBubble(context, message);
                },
              ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildInputBar(),
        ),
      ],
    );
  }

  Widget _buildChatBubble(BuildContext context, ChatMessage message) {
    final isMine = message.isFromOwner == widget.isCurrentUserOwner;
    final localTimestamp = message.timestamp.toLocal();
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 0),
                  bottomRight: Radius.circular(isMine ? 0 : 16),
                ),
              ),
              child: _buildMessageContent(message, isMine),
            ),
            const SizedBox(height: 2),
            Text(
              '${localTimestamp.hour.toString().padLeft(2, '0')}:${localTimestamp.minute.toString().padLeft(2, '0')} น.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isMine) {
    final textColor = isMine ? Colors.white : AppColors.primary;

    if (message.type == MessageType.maintenanceRequest) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build, size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('แจ้งซ่อม',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(message.text, style: TextStyle(color: textColor)),
        ],
      );
    }

    if (message.type == MessageType.maintenanceUpdate) {
      return Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text(message.text, style: TextStyle(color: textColor))),
        ],
      );
    }

    return Text(message.text, style: TextStyle(color: textColor));
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showQuickChips) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickChip('🔧 กำลังซ่อม',
                      () => _messageController.text = 'กำลังซ่อม'),
                  const SizedBox(width: 8),
                  _buildQuickChip('✅ ซ่อมเสร็จ',
                      () => _messageController.text = 'ซ่อมเสร็จ'),
                  const SizedBox(width: 8),
                  _buildQuickChip('📦 มีพัสดุมาส่ง',
                      () => _messageController.text = 'มีพัสดุมาส่ง'),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'พิมพ์ข้อความ...',
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: widget.isSending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: widget.isSending ? null : _handleSend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.primary)),
      ),
    );
  }
}
