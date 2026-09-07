import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/refreshable.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../viewmodels/admin_shell_view_model.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/chat_view_model.dart';
import '../../widgets/chat_conversation_view.dart';
import '../../widgets/invoice_detail_sheet.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;
    final ownerName =
        profile?.fullName.isNotEmpty == true ? profile!.fullName : 'เจ้าของหอ';

    return ChangeNotifierProvider(
      create: (context) => ChatViewModel(
        dormitoryId: profile?.dormitoryId ?? 0,
        ownerId: profile?.id ?? '',
        ownerName: ownerName,
        onRoomRead: () =>
            context.read<AdminShellViewModel>().refreshUnreadCount(),
      )
        ..loadChatPreviews()
        ..startWatchingPreviews(),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();

    // การส่งรูปที่ล้มเหลวเคยเงียบสนิท — เห็นแค่วงกลมหมุนแล้วไม่มีอะไรขึ้น
    final sendError = viewModel.sendErrorMessage;
    if (sendError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(sendError)));
        viewModel.clearSendError();
      });
    }

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

    final filteredChats = viewModel.filteredChatPreviews;

    return ContentBounds(
      gutter: 0,
      child: Column(
      children: [
        _buildSearchSection(viewModel),
        _buildFloorFilterSection(viewModel),
        Expanded(
          child: PullToRefresh(
            onRefresh: viewModel.loadChatPreviews,
            child: filteredChats.isEmpty
                ? _buildNoResultState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredChats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      return PaperCard(
                        onTap: () => viewModel.openChat(chat),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
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
                                    chat.lastMessage.isEmpty
                                        ? 'ยังไม่มีข้อความ'
                                        : chat.lastMessage,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (chat.unreadCount > 0 || chat.lastMessageAt != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
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
                                  if (chat.unreadCount > 0 &&
                                      chat.lastMessageAt != null)
                                    const SizedBox(height: 4),
                                  if (chat.lastMessageAt != null)
                                    Text(
                                      formatRelativeTime(chat.lastMessageAt!),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.mutedForeground,
                                          ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildSearchSection(ChatViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: PaperCard(
        padding: EdgeInsets.zero,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'ค้นหาห้อง หรือชื่อผู้เช่า',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: viewModel.searchQuery.trim().isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      viewModel.setSearchQuery('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: viewModel.setSearchQuery,
        ),
      ),
    );
  }

  Widget _buildFloorFilterSection(ChatViewModel viewModel) {
    final floorOptions = [
      ChatViewModel.allFloors,
      ...viewModel.availableFloors.toList()..sort(),
    ];

    if (floorOptions.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: FilterChipGroup(
        title: '',
        options: floorOptions,
        selectedValue: viewModel.selectedFloor,
        onSelected: viewModel.setFloorFilter,
      ),
    );
  }

  Widget _buildNoResultState() {
    return const CenteredScrollable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: AppColors.mutedForeground),
          SizedBox(height: 12),
          Text('ไม่พบห้องหรือผู้เช่าตามที่ค้นหา',
              style: TextStyle(color: AppColors.mutedForeground)),
        ],
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
            isCurrentUserOwner: true,
            hasMoreMessages: viewModel.hasMoreMessages,
            isLoadingMore: viewModel.isLoadingMore,
            onLoadMore: viewModel.loadMoreMessages,
            onPickImage: viewModel.pickAndSendImage,
            isUploadingImage: viewModel.isUploadingImage,
            onUpdateMaintenanceStatus: (requestId, status, requestType) =>
                viewModel.updateMaintenanceStatus(
                    requestId: requestId,
                    status: status,
                    requestType: requestType),
            invoicesById: viewModel.invoicesById,
            onOpenInvoice: (invoice) async {
              await showInvoiceDetailSheet(
                context,
                invoice: invoice,
                dormitoryId: viewModel.dormitoryId,
              );
              // เหตุผลเดียวกับ billing_screen.dart — เพิ่ม/ลบค่าใช้จ่าย
              // เพิ่มเติมไม่ทำให้แผ่นคืน true แต่การ์ดบิลในแชทต้องอัปเดตยอด
              await viewModel.refreshInvoices();
            },
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
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: AppColors.primary),
            onPressed: viewModel.closeChat,
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              chat.roomNumber,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.tenantName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary),
                ),
                Text(
                  'ห้อง ${chat.roomNumber}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
