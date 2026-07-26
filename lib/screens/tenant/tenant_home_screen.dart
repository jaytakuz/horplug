import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tenant_home_view_model.dart';
import '../../widgets/reusable_widgets.dart';
import '../admin/maintenance_history_screen.dart';

class TenantHomeScreen extends StatelessWidget {
  const TenantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TenantHomeViewModel()..loadPendingRequests(),
      child: const _TenantHomeView(),
    );
  }
}

class _TenantHomeView extends StatelessWidget {
  const _TenantHomeView();

  Future<void> _handleRespond(
    BuildContext context,
    TenantHomeViewModel viewModel,
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
    final viewModel = context.watch<TenantHomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้พักอาศัย'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await AuthScope.of(context).refreshProfile();
          await viewModel.loadPendingRequests();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สวัสดี ${profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Tenant'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'จัดการคำขอเข้าหอและตรวจสอบข้อมูลบัญชีของคุณ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (viewModel.shouldShowJoinRequestSection) ...[
              const SizedBox(height: 16),
              _buildJoinRequestSection(context, viewModel),
            ],
            const SizedBox(height: 16),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ข้อมูลบัญชี',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'ชื่อ', value: profile?.fullName ?? '-'),
                  _InfoRow(label: 'อีเมล', value: profile?.email ?? '-'),
                  _InfoRow(label: 'เบอร์โทร', value: profile?.phone ?? '-'),
                  _InfoRow(
                    label: 'Dormitory',
                    value: profile?.dormitoryName ?? '-',
                  ),
                  _InfoRow(
                    label: 'Room',
                    value: profile?.roomNumber ?? '-',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PaperCard(
              onTap: () => context.push('/tenant/chat'),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'แชทกับเจ้าของหอ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
                ],
              ),
            ),
            if (profile?.roomId != null) ...[
              const SizedBox(height: 16),
              PaperCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MaintenanceHistoryScreen(
                      roomId: profile!.roomId!,
                      roomNumber: profile.roomNumber ?? '-',
                      readOnly: true,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ประวัติการแจ้งซ่อม/ทำความสะอาด',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.mutedForeground),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'บิล, คำขอซ่อม, ประวัติการชำระเงิน',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinRequestSection(
    BuildContext context,
    TenantHomeViewModel viewModel,
  ) {
    if (viewModel.isLoadingRequests) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (viewModel.requestErrorMessage != null) {
      return PaperCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คำขอเข้าหอ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'โหลดคำขอไม่สำเร็จ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.destructive,
                  ),
            ),
          ],
        ),
      );
    }

    final pendingRequests = viewModel.pendingRequests;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คำขอเข้าหอ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            pendingRequests.isEmpty
                ? 'ยังไม่มีคำขอเข้าหอที่รอการตอบรับ'
                : 'ตรวจสอบและตอบรับคำขอจากเจ้าของหอพัก',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (pendingRequests.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...pendingRequests.map(
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
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'เจ้าของหอ',
                        value: request.landlordName,
                      ),
                      _InfoRow(
                        label: 'ห้อง',
                        value: request.roomNumber ?? '-',
                      ),
                      _InfoRow(
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
                                        context,
                                        viewModel,
                                        request,
                                        false,
                                      ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.destructive,
                                side: const BorderSide(
                                  color: AppColors.destructive,
                                ),
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
                                        context,
                                        viewModel,
                                        request,
                                        true,
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: viewModel.isResponding
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
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
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
