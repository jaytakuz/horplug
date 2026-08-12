import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/tenant_maintenance_view_model.dart';
import '../../widgets/maintenance_request_card.dart';
import '../../widgets/maintenance_request_dialog.dart';
import '../../widgets/maintenance_search_and_filter.dart';
import '../../widgets/reusable_widgets.dart';

class TenantMaintenanceScreen extends StatelessWidget {
  const TenantMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;

    return ChangeNotifierProvider(
      key: ValueKey(profile?.roomId),
      create: (_) => TenantMaintenanceViewModel(
        roomId: profile?.roomId,
        tenantId: profile?.id,
      )..loadRequests(),
      child: const _TenantMaintenanceView(),
    );
  }
}

class _TenantMaintenanceView extends StatelessWidget {
  const _TenantMaintenanceView();

  Future<void> _handleNewRequest(
    BuildContext context,
    TenantMaintenanceViewModel viewModel,
    MaintenanceRequestType type,
  ) async {
    if (viewModel.isSubmitting) return;

    final description = await showMaintenanceRequestDialog(context, type);
    if (description == null || !context.mounted) return;

    final result = await viewModel.submitRequest(
      description: description,
      requestType: type,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;
    final viewModel = context.watch<TenantMaintenanceViewModel>();

    if (profile?.roomId == null) {
      return _buildNoRoomState(context, viewModel);
    }

    return RefreshIndicator(
      onRefresh: viewModel.loadRequests,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: contentInsets(context, availableWidth: constraints.maxWidth),
        children: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'แจ้งซ่อม',
                  icon: Icons.build,
                  fullWidth: true,
                  // spinner ขึ้นเฉพาะปุ่มที่กดจริง
                  isLoading: viewModel.submittingType ==
                      MaintenanceRequestType.repair,
                  onPressed: () => _handleNewRequest(
                      context, viewModel, MaintenanceRequestType.repair),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: viewModel.isSubmitting
                      ? null
                      : () => _handleNewRequest(
                          context, viewModel, MaintenanceRequestType.cleaning),
                  icon: viewModel.submittingType ==
                          MaintenanceRequestType.cleaning
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.cleaning_services, size: 18),
                  label: const Text('ทำความสะอาด'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          MaintenanceSearchAndFilter(
            searchQuery: viewModel.searchQuery,
            onSearchChanged: viewModel.setSearchQuery,
            statusOptions: tenantMaintenanceFilters,
            selectedStatus: viewModel.selectedFilter,
            onStatusChanged: viewModel.setFilter,
          ),
          const SizedBox(height: 16),
          ..._buildList(context, viewModel),
        ],
        ),
      ),
    );
  }

  List<Widget> _buildList(
    BuildContext context,
    TenantMaintenanceViewModel viewModel,
  ) {
    if (viewModel.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (viewModel.errorMessage != null) {
      return [
        PaperCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.destructive, size: 32),
              const SizedBox(height: 12),
              Text('โหลดข้อมูลไม่สำเร็จ',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(viewModel.errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'ลองใหม่',
                icon: Icons.refresh,
                onPressed: viewModel.loadRequests,
              ),
            ],
          ),
        ),
      ];
    }

    final requests = viewModel.filteredRequests;
    if (requests.isEmpty) {
      final hasSearch = viewModel.searchQuery.trim().isNotEmpty;
      final hasStatusFilter = viewModel.selectedFilter != 'ทั้งหมด';
      final isFiltered = hasSearch || hasStatusFilter;
      return [
        PaperCard(
          child: Column(
            children: [
              const Icon(Icons.build_outlined,
                  color: AppColors.mutedForeground, size: 48),
              const SizedBox(height: 12),
              Text(
                isFiltered
                    ? 'ไม่พบรายการที่ค้นหา'
                    : 'ยังไม่มีประวัติการแจ้งซ่อม/ทำความสะอาด',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                hasSearch && hasStatusFilter
                    ? 'ลองเปลี่ยนคำค้นหาหรือสถานะ'
                    : hasSearch
                        ? 'ลองเปลี่ยนคำค้นหา'
                        : hasStatusFilter
                            ? 'ลองเลือกสถานะอื่น'
                            : 'แตะปุ่มด้านบนเพื่อแจ้งซ่อมหรือขอทำความสะอาด',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ];
    }

    return [
      for (final request in requests) ...[
        MaintenanceRequestCard(request: request, readOnly: true),
        const SizedBox(height: 12),
      ],
    ];
  }

  /// ครอบด้วย RefreshIndicator + ListView ที่ scroll ได้ — เดิมเป็น Center
  /// เฉยๆ ทำให้ผู้เช่าที่รอเข้าห้องดึงรีเฟรชไม่ได้ กลายเป็นทางตัน
  Widget _buildNoRoomState(
    BuildContext context,
    TenantMaintenanceViewModel viewModel,
  ) {
    return RefreshIndicator(
      onRefresh: viewModel.loadRequests,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          const Icon(Icons.meeting_room_outlined,
              size: 48, color: AppColors.mutedForeground),
          const SizedBox(height: 12),
          Text('ยังไม่ได้เข้าพัก',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'แจ้งซ่อมได้หลังเจ้าของหอเพิ่มคุณเข้าห้อง',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
