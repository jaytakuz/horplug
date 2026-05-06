import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../mock/mock_data.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatPreview? selectedChat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MobileHeader(
        subtitle: selectedChat == null ? 'แชท' : 'ห้อง ${selectedChat!.roomNumber}',
        actions: selectedChat != null
            ? [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  onPressed: () => setState(() => selectedChat = null),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: selectedChat == null ? _buildInboxView() : _buildConversationView(),
    );
  }

  Widget _buildInboxView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: MockData.chatPreviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final chat = MockData.chatPreviews[index];
        return PaperCard(
          onTap: () => setState(() => selectedChat = chat),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('ห้อง ${chat.roomNumber}  ${chat.tenantName}',
                            style: Theme.of(context).textTheme.labelLarge),
                        if (chat.hasPendingMaintenance) ...[
                          const SizedBox(width: 8),
                          const StatusBadge(label: 'แจ้งซ่อม', variant: BadgeVariant.destructive),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.lastMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (chat.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: AppColors.destructive, shape: BoxShape.circle),
                  child: Text(
                    '${chat.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConversationView() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                reverse: true, // Mocking recent at bottom
                itemCount: MockData.conversation305.length,
                itemBuilder: (context, index) {
                  // Reversing for display purpose in mock
                  final message = MockData.conversation305.reversed.toList()[index];
                  return _buildChatBubble(message);
                },
              ),
            ),
            const SizedBox(height: 120), // Space for input bar
          ],
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

  Widget _buildChatBubble(ChatMessage message) {
    final isOwner = message.isFromOwner;
    return Align(
      alignment: isOwner ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOwner ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOwner ? 16 : 0),
                  bottomRight: Radius.circular(isOwner ? 0 : 16),
                ),
              ),
              child: _buildMessageContent(message),
            ),
            const SizedBox(height: 2),
            Text(
              '10:30 น.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message) {
    final textColor = message.isFromOwner ? Colors.white : AppColors.primary;

    if (message.type == MessageType.maintenanceRequest) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build, size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('แจ้งซ่อม', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
        color: AppColors.background.withOpacity(0.9),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip('🔧 กำลังซ่อม'),
                const SizedBox(width: 8),
                _buildQuickChip('✅ ซ่อมเสร็จ'),
                const SizedBox(width: 8),
                _buildQuickChip('📦 มีพัสดุมาส่ง'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'พิมพ์ข้อความ...',
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
    );
  }
}
