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
  ChatPreview? _selectedChat;
  bool _maintenanceExpanded = true;

  @override
  Widget build(BuildContext context) {
    return _selectedChat == null
        ? _buildInboxView()
        : _buildConversationView();
  }

  // ─── Inbox (รายการช่องแชท) ───────────────────────────────────────────────────

  Widget _buildInboxView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: MockData.chatPreviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final chat = MockData.chatPreviews[index];
        return PaperCard(
          onTap: () => setState(() {
            _selectedChat = chat;
            _maintenanceExpanded = true;
          }),
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
                        if (chat.hasPendingMaintenance) ...[
                          const SizedBox(width: 8),
                          const StatusBadge(
                            label: 'แจ้งซ่อม',
                            variant: BadgeVariant.destructive,
                          ),
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
    );
  }

  // ─── ห้องแชท ─────────────────────────────────────────────────────────────────

  Widget _buildConversationView() {
    final chat = _selectedChat!;
    return Column(
      children: [
        _buildConversationHeader(chat),
        if (chat.hasPendingMaintenance) _buildMaintenanceHistorySection(),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                reverse: true,
                itemCount: MockData.conversation305.length,
                itemBuilder: (context, index) {
                  final message =
                      MockData.conversation305.reversed.toList()[index];
                  return _buildChatBubble(message);
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildInputBar(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversationHeader(ChatPreview chat) {
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
            onPressed: () => setState(() => _selectedChat = null),
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
          if (chat.hasPendingMaintenance)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.build_circle, color: AppColors.warning, size: 22),
            ),
        ],
      ),
    );
  }

  // ─── Maintenance History ──────────────────────────────────────────────────────

  Widget _buildMaintenanceHistorySection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _maintenanceExpanded = !_maintenanceExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.build, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ประวัติการแจ้งซ่อม',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '1 รายการ กำลังดำเนินการ',
                      style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _maintenanceExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
          // Timeline (expanded)
          if (_maintenanceExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _buildMaintenanceTimeline(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaintenanceTimeline() {
    final events = [
      _MaintenanceEvent(
        icon: Icons.report_problem_outlined,
        iconColor: AppColors.destructive,
        title: 'แจ้งซ่อม: แอร์ไม่เย็น',
        detail: 'คุณฟ้า รายงาน',
        dateLabel: '2 วันที่แล้ว',
        isDone: true,
      ),
      _MaintenanceEvent(
        icon: Icons.engineering_outlined,
        iconColor: AppColors.warning,
        title: 'กำลังดำเนินการ',
        detail: 'ช่างเข้าตรวจสอบ · รอเปลี่ยนอะไหล่',
        dateLabel: 'เมื่อวาน',
        isDone: false,
        isActive: true,
      ),
      _MaintenanceEvent(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.mutedForeground,
        title: 'ซ่อมเสร็จ',
        detail: 'รอยืนยันจากผู้เช่า',
        dateLabel: '',
        isDone: false,
        isPending: true,
      ),
    ];

    return Column(
      children: List.generate(events.length, (i) {
        final e = events[i];
        final isLast = i == events.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line + icon
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: e.isDone
                            ? e.iconColor.withValues(alpha: 0.15)
                            : e.isActive
                                ? AppColors.warning.withValues(alpha: 0.15)
                                : AppColors.muted,
                        shape: BoxShape.circle,
                        border: e.isActive
                            ? Border.all(color: AppColors.warning, width: 2)
                            : null,
                      ),
                      child: Icon(e.icon, size: 14,
                        color: e.isPending ? AppColors.mutedForeground : e.iconColor),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            e.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: e.isPending ? AppColors.mutedForeground : AppColors.primary,
                            ),
                          ),
                          if (e.dateLabel.isNotEmpty)
                            Text(e.dateLabel, style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                        ],
                      ),
                      if (e.detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(e.detail, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ─── Chat Bubbles ─────────────────────────────────────────────────────────────

  Widget _buildChatBubble(ChatMessage message) {
    final isOwner = message.isFromOwner;
    return Align(
      alignment: isOwner ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment:
              isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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

  // ─── Input Bar ────────────────────────────────────────────────────────────────

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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
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
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.primary)),
    );
  }
}

// ─── Internal model สำหรับ timeline (concept only) ───────────────────────────

class _MaintenanceEvent {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;
  final String dateLabel;
  final bool isDone;
  final bool isActive;
  final bool isPending;

  const _MaintenanceEvent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
    required this.dateLabel,
    this.isDone = false,
    this.isActive = false,
    this.isPending = false,
  });
}
