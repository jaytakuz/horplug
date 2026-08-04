import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/maintenance_view_model.dart'
    show maintenanceStatusLabel;
import '../../viewmodels/tenant_dashboard_view_model.dart';
import '../../viewmodels/tenant_shell_view_model.dart';
import '../../widgets/maintenance_request_dialog.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/reusable_widgets.dart';
import '../../utils/formatters.dart';

class TenantDashboardScreen extends StatelessWidget {
  const TenantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;

    return ChangeNotifierProvider(
      key: ValueKey(profile?.roomId),
      create: (_) => TenantDashboardViewModel(
        roomId: profile?.roomId,
        dormitoryId: profile?.dormitoryId,
        tenantId: profile?.id,
        tenantName: profile?.fullName.isNotEmpty == true
            ? profile!.fullName
            : 'ผู้พักอาศัย',
      )..load(),
      child: const _TenantDashboardView(),
    );
  }
}

class _TenantDashboardView extends StatelessWidget {
  const _TenantDashboardView();

  Future<void> _handleRespond(
    BuildContext context,
    TenantDashboardViewModel viewModel,
    TenantJoinRequest request,
    bool accept,
  ) async {
    final result = await viewModel.respondToRequest(
      request: request,
      accept: accept,
    );
    if (!context.mounted) return;

    if (result.success) {
      await AuthScope.of(context).refreshProfile();
    }
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final profile = auth.profile;
    final viewModel = context.watch<TenantDashboardViewModel>();

    return RefreshIndicator(
      onRefresh: () async {
        await auth.refreshProfile();
        await viewModel.load();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _Greeting(profile: profile),
          const SizedBox(height: 16),
          if (profile?.roomId == null)
            ..._buildNoRoomSections(context, viewModel)
          else
            ..._buildDashboardSections(context, viewModel),
        ],
      ),
    );
  }

  // ── ยังไม่มีห้อง: โฟกัสที่คำขอเข้าหออย่างเดียว ────────────────────────────

  List<Widget> _buildNoRoomSections(
    BuildContext context,
    TenantDashboardViewModel viewModel,
  ) {
    if (viewModel.isLoadingRequests) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (viewModel.pendingRequests.isNotEmpty ||
        viewModel.requestErrorMessage != null) {
      return [_buildJoinRequestSection(context, viewModel)];
    }

    return [
      PaperCard(
        child: Column(
          children: [
            const Icon(Icons.hourglass_empty,
                size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(
              'รอเจ้าของหอเพิ่มคุณเข้าห้อง',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'เมื่อเจ้าของหอส่งคำขอเข้าพัก คุณจะเห็นปุ่มตอบรับที่นี่',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'รีเฟรช',
              icon: Icons.refresh,
              onPressed: () async {
                await AuthScope.of(context).refreshProfile();
                await viewModel.load();
              },
            ),
          ],
        ),
      ),
    ];
  }

  // ── มีห้องแล้ว: เนื้อหาแดชบอร์ดจริง ───────────────────────────────────────

  List<Widget> _buildDashboardSections(
    BuildContext context,
    TenantDashboardViewModel viewModel,
  ) {
    if (viewModel.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    return [
      if (viewModel.pendingRequests.isNotEmpty) ...[
        _buildJoinRequestSection(context, viewModel),
        const SizedBox(height: 16),
      ],
      _BillHeroCard(viewModel: viewModel),
      const SizedBox(height: 16),
      _UsageSection(viewModel: viewModel),
      const SizedBox(height: 16),
      _MaintenanceSummary(viewModel: viewModel),
      const SizedBox(height: 16),
      _LatestMessageCard(viewModel: viewModel),
      const SizedBox(height: 16),
      _QuickActions(viewModel: viewModel),
    ];
  }

  Widget _buildJoinRequestSection(
    BuildContext context,
    TenantDashboardViewModel viewModel,
  ) {
    if (viewModel.requestErrorMessage != null) {
      return PaperCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คำขอเข้าหอ', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SectionErrorNote(
              message: viewModel.requestErrorMessage!,
              onRetry: viewModel.load,
            ),
          ],
        ),
      );
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('คำขอเข้าหอ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'ตรวจสอบและตอบรับคำขอจากเจ้าของหอพัก',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ...viewModel.pendingRequests.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.dormitoryName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    InfoRow(label: 'เจ้าของหอ', value: request.landlordName),
                    InfoRow(label: 'ห้อง', value: request.roomNumber ?? '—'),
                    InfoRow(
                      label: 'ส่งเมื่อ',
                      value:
                          '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: viewModel.isResponding
                                ? null
                                : () => _handleRespond(
                                    context, viewModel, request, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.destructive,
                              side: const BorderSide(
                                  color: AppColors.destructive),
                            ),
                            child: const Text('ปฏิเสธ'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: viewModel.isResponding
                                ? null
                                : () => _handleRespond(
                                    context, viewModel, request, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: viewModel.isResponding
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('ตอบรับ'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ยอดที่ต้องชำระ ─────────────────────────────────────────────────────────
// การ์ดที่สำคัญที่สุดของหน้า — ตอบคำถาม "ฉันต้องจ่ายเท่าไหร่" และให้จ่ายได้เลย
// จากที่นี่โดยไม่ต้องเข้าแท็บบิล

class _BillHeroCard extends StatelessWidget {
  const _BillHeroCard({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  Future<void> _pay(BuildContext context, TenantBill bill) async {
    await showPaymentSheet(
      context,
      bill: bill,
      channel: viewModel.paymentChannel,
      onSubmit: (slip) => viewModel.submitSlip(billId: bill.id, slip: slip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bill = viewModel.currentBill;

    return PaperCard(
      onTap: () => context.go('/tenant/bills'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'บิลเดือน${thaiMonthName(now.month)} ${now.year}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (bill != null)
                StatusBadge(
                  label: billStatusLabel(bill.status),
                  variant: billStatusVariant(bill.status),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (viewModel.billErrorMessage != null)
            SectionErrorNote(
              message: viewModel.billErrorMessage!,
              onRetry: viewModel.load,
            )
          else ...[
            Text(
              bill != null ? formatBaht(bill.total) : formatBaht(0),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            if (bill == null)
              Text(
                'ยังไม่ออกบิลเดือนนี้ — เจ้าของหอจะออกบิลหลังจดมิเตอร์',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else ...[
              if (bill.dueDate != null)
                Text(
                  'ครบกำหนด ${bill.dueDate!.day} ${thaiMonthName(bill.dueDate!.month)} ${bill.dueDate!.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              _buildAction(context, bill),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, TenantBill bill) {
    switch (bill.status) {
      case InvoiceStatus.unpaid:
        return PrimaryButton(
          label: 'ชำระเงิน',
          icon: Icons.qr_code_2,
          fullWidth: true,
          onPressed: () => _pay(context, bill),
        );
      case InvoiceStatus.pending:
        return Row(
          children: [
            const Icon(Icons.hourglass_top, size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(
              'รอเจ้าของหอตรวจสลิป',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.warning),
            ),
          ],
        );
      case InvoiceStatus.paid:
        return Row(
          children: [
            const Icon(Icons.check_circle, size: 16, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              'ชำระแล้ว',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.success),
            ),
          ],
        );
    }
  }
}

// ── การใช้ไฟ-น้ำเดือนนี้ ───────────────────────────────────────────────────

class _UsageSection extends StatelessWidget {
  const _UsageSection({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final invoice = viewModel.currentBill?.invoice;
    final hasRecord = invoice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'ค่าไฟ',
                value: hasRecord
                    ? formatBaht(invoice.electricityCost)
                    : '—',
                subtitle: hasRecord
                    ? '${formatUnits(invoice.electricityUnits)} หน่วย'
                    : 'ยังไม่ได้จดมิเตอร์',
                icon: Icons.bolt,
                variant: BadgeVariant.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'ค่าน้ำ',
                value:
                    hasRecord ? formatBaht(invoice.waterCost) : '—',
                subtitle:
                    hasRecord ? 'เหมาจ่ายรายเดือน' : 'ยังไม่ได้จดมิเตอร์',
                icon: Icons.water_drop,
                variant: BadgeVariant.primary,
              ),
            ),
          ],
        ),
        if (viewModel.usageErrorMessage != null) ...[
          const SizedBox(height: 8),
          SectionErrorNote(
            message: viewModel.usageErrorMessage!,
            onRetry: viewModel.load,
          ),
        ] else if (viewModel.electricityTrend != null) ...[
          const SizedBox(height: 8),
          _TrendLine(trend: viewModel.electricityTrend!),
        ],
      ],
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.trend});

  final UtilityTrend trend;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String text;

    final units = formatUnits(trend.delta.abs());
    final percent = trend.percent == null
        ? ''
        : ' (${trend.percent! > 0 ? '+' : ''}${trend.percent!.toStringAsFixed(0)}%)';

    switch (trend.direction) {
      case TrendDirection.up:
        icon = Icons.trending_up;
        color = AppColors.destructive;
        text = 'ใช้ไฟมากกว่าเดือนก่อน $units หน่วย$percent';
        break;
      case TrendDirection.down:
        icon = Icons.trending_down;
        color = AppColors.success;
        text = 'ใช้ไฟน้อยกว่าเดือนก่อน $units หน่วย$percent';
        break;
      case TrendDirection.flat:
        icon = Icons.trending_flat;
        color = AppColors.mutedForeground;
        text = 'ใช้ไฟเท่ากับเดือนก่อน';
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

// ── สถานะแจ้งซ่อม ──────────────────────────────────────────────────────────

class _MaintenanceSummary extends StatelessWidget {
  const _MaintenanceSummary({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final open = viewModel.openRequests.take(2).toList();

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('แจ้งซ่อม/ทำความสะอาด',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () => context.go('/tenant/maintenance'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ring,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('ดูทั้งหมด', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (viewModel.maintenanceErrorMessage != null)
            SectionErrorNote(
              message: viewModel.maintenanceErrorMessage!,
              onRetry: viewModel.load,
            )
          else if (open.isEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Text('ไม่มีงานค้าง',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            )
          else
            ...open.map((request) => _OpenRequestRow(request: request)),
        ],
      ),
    );
  }
}

class _OpenRequestRow extends StatelessWidget {
  const _OpenRequestRow({required this.request});

  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    final isRepair = request.requestType == MaintenanceRequestType.repair;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isRepair ? AppColors.warning : AppColors.ring)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isRepair ? Icons.build : Icons.cleaning_services,
              size: 18,
              color: isRepair ? AppColors.warning : AppColors.ring,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            label: maintenanceStatusLabel(request.status),
            variant: request.status == MaintenanceStatus.pending
                ? BadgeVariant.warning
                : BadgeVariant.primary,
          ),
        ],
      ),
    );
  }
}

// ── ข้อความล่าสุด ──────────────────────────────────────────────────────────

class _LatestMessageCard extends StatelessWidget {
  const _LatestMessageCard({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  String _relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp.toLocal());
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    final local = timestamp.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final message = viewModel.latestMessage;
    // อ่านจาก shell VM ตัวเดียวกับ badge บน nav เพื่อให้ตัวเลขตรงกันเสมอ
    final unreadCount = context.watch<TenantShellViewModel>().unreadMessageCount;

    return PaperCard(
      onTap: () => context.go('/tenant/chat'),
      child: viewModel.chatErrorMessage != null
          ? SectionErrorNote(
              message: viewModel.chatErrorMessage!,
              onRetry: viewModel.load,
            )
          : Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เจ้าของหอ',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message == null
                            ? 'ยังไม่มีข้อความ — แตะเพื่อเริ่มแชท'
                            : (message.text.trim().isEmpty
                                ? 'ส่งรูปภาพ'
                                : message.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (unreadCount > 0)
                        Badge(label: Text('$unreadCount'))
                      else
                        const SizedBox(height: 16),
                      const SizedBox(height: 4),
                      Text(_relativeTime(message.timestamp),
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

// ── ทางลัด ─────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  Future<void> _request(
    BuildContext context,
    MaintenanceRequestType type,
  ) async {
    if (viewModel.isSubmittingRequest) return;

    final description = await showMaintenanceRequestDialog(context, type);
    if (description == null || !context.mounted) return;

    final result = await viewModel.submitMaintenanceRequest(
      description: description,
      requestType: type,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<TenantShellViewModel>().unreadMessageCount;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ทางลัด', style: Theme.of(context).textTheme.titleMedium),
              if (viewModel.isSubmittingRequest) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text('กำลังส่งคำขอ...',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // แบ่งความกว้างเท่ากันแทนความกว้างคงที่ — 4 × 76px = 304px ล้นจอ
          // 360dp ที่มีพื้นที่แค่ W−64 = 296px
          // crossAxisAlignment.start กันแถวบิดเมื่อบางป้ายขึ้นสองบรรทัด
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _QuickActionItem(
                  icon: Icons.build,
                  label: 'แจ้งซ่อม',
                  color: AppColors.warning,
                  onTap: () => _request(context, MaintenanceRequestType.repair),
                ),
              ),
              Expanded(
                child: _QuickActionItem(
                  icon: Icons.cleaning_services,
                  label: 'ทำความสะอาด',
                  color: AppColors.ring,
                  onTap: () =>
                      _request(context, MaintenanceRequestType.cleaning),
                ),
              ),
              Expanded(
                child: _QuickActionItem(
                  icon: Icons.receipt_long,
                  label: 'ดูบิล',
                  color: AppColors.primary,
                  onTap: () => context.go('/tenant/bills'),
                ),
              ),
              Expanded(
                child: _QuickActionItem(
                  icon: Icons.chat_bubble,
                  label: 'แชท',
                  color: AppColors.success,
                  badgeCount: unreadCount,
                  onTap: () => context.go('/tenant/chat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: const BoxDecoration(
                        color: AppColors.destructive,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // ไม่ล็อกความกว้าง — กว้างตามช่อง Expanded และขึ้นบรรทัดที่สองได้
            // เมื่อผู้ใช้ตั้งขนาดตัวอักษรใหญ่ แทนที่จะโดนตัดเป็น '…' เงียบๆ
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final firstName = profile?.firstName.trim();
    final name =
        firstName != null && firstName.isNotEmpty ? firstName : 'ผู้พักอาศัย';

    final roomNumber = profile?.roomNumber;
    final dormName = profile?.dormitoryName;
    final subtitle = [
      if (roomNumber != null) 'ห้อง $roomNumber',
      if (dormName != null) dormName,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('สวัสดี, $name', style: Theme.of(context).textTheme.titleLarge),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
