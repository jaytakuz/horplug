import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/chat_view_model.dart';
import '../../widgets/chat_conversation_view.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;
    final ownerName =
        profile?.fullName.isNotEmpty == true ? profile!.fullName : 'เจ้าของหอ';

    return ChangeNotifierProvider(
      create: (_) => ChatViewModel(
        dormitoryId: profile?.dormitoryId ?? 0,
        ownerId: profile?.id ?? '',
        ownerName: ownerName,
      )..loadChatPreviews(),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    return viewModel.selectedChat == null
        ? _buildInboxView(context, viewModel)
        : _buildConversationView(context, viewModel);
  }

  // ─── Inbox (รายการช่องแชท) ───────────────────────────────────────────────────

  Widget _buildInboxView(BuildContext context, ChatViewModel viewModel) {
    if (viewModel.isLoadingPreviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.previewsErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.destructive, size: 32),
              const SizedBox(height: 12),
              Text('โหลดข้อความไม่สำเร็จ',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(viewModel.previewsErrorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'ลองใหม่',
                icon: Icons.refresh,
                onPressed: viewModel.loadChatPreviews,
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.chatPreviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline,
                  color: AppColors.mutedForeground, size: 48),
              const SizedBox(height: 12),
              Text('ยังไม่มีบทสนทนา',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('บทสนทนาจะแสดงเมื่อห้องมีผู้พักอาศัยและเริ่มพูดคุยกัน',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.loadChatPreviews,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: viewModel.chatPreviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final chat = viewModel.chatPreviews[index];
          return PaperCard(
            onTap: () => viewModel.openChat(chat),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ห้อง ${chat.roomNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            chat.tenantName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.lastMessage.isEmpty ? 'ยังไม่มีข้อความ' : chat.lastMessage,
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
                    decoration: const BoxDecoration(
                      color: AppColors.destructive,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${chat.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── ห้องแชท ─────────────────────────────────────────────────────────────────

  Widget _buildConversationView(BuildContext context, ChatViewModel viewModel) {
    final chat = viewModel.selectedChat!;
    return Column(
      children: [
        _buildConversationHeader(context, viewModel, chat),
        Expanded(
          child: ChatConversationView(
            messages: viewModel.conversation,
            isSending: viewModel.isSending,
            onSend: viewModel.sendMessage,
          ),
        ),
      ],
    );
  }

  Widget _buildConversationHeader(
      BuildContext context, ChatViewModel viewModel, ChatPreview chat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.primary),
            onPressed: viewModel.closeChat,
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              chat.roomNumber,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.tenantName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                ),
                Text(
                  'ห้อง ${chat.roomNumber}',
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
