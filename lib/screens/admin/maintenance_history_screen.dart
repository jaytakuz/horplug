import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/maintenance_view_model.dart';
import '../../widgets/maintenance_request_card.dart';
import '../../widgets/maintenance_search_and_filter.dart';
import '../../widgets/reusable_widgets.dart';

class MaintenanceHistoryScreen extends StatelessWidget {
  const MaintenanceHistoryScreen({
    super.key,
    required this.roomId,
    required this.roomNumber,
    this.readOnly = false,
  });

  final int roomId;
  final String roomNumber;

  /// Tenant view: hides the cleaning-fee editing affordance. Only landlords
  /// may set the fee (enforced server-side via RLS too).
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final landlordId = AuthScope.of(context).profile?.id ?? '';

    return ChangeNotifierProvider(
      create: (_) => MaintenanceViewModel(
        roomId: roomId,
        landlordId: landlordId,
      )..loadRequests(),
      child:
          _MaintenanceHistoryView(roomNumber: roomNumber, readOnly: readOnly),
    );
  }
}

class _MaintenanceHistoryView extends StatelessWidget {
  const _MaintenanceHistoryView(
      {required this.roomNumber, required this.readOnly});

  final String roomNumber;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MaintenanceViewModel>();

    return Scaffold(
      appBar:
          AppBar(title: Text('ประวัติการแจ้งซ่อม/ทำความสะอาด ห้อง $roomNumber')),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, MaintenanceViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
      );
    }

    if (viewModel.requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.build_outlined,
                  color: AppColors.mutedForeground, size: 48),
              const SizedBox(height: 12),
              Text('ยังไม่มีประวัติการแจ้งซ่อม/ทำความสะอาด',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('รายการจะแสดงเมื่อผู้เช่าแจ้งซ่อม/ทำความสะอาดผ่านหน้าแชท',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    final requests = viewModel.filteredRequests;
    return RefreshIndicator(
      onRefresh: viewModel.loadRequests,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          MaintenanceSearchAndFilter(
            searchQuery: viewModel.searchQuery,
            onSearchChanged: viewModel.setSearchQuery,
            statusOptions: maintenanceHistoryStatusFilters,
            selectedStatus: viewModel.selectedStatusFilter,
            onStatusChanged: viewModel.setStatusFilter,
          ),
          const SizedBox(height: 16),
          if (requests.isEmpty)
            _buildNoResultsState(context, viewModel)
          else
            for (final request in requests) ...[
              MaintenanceRequestCard(
                request: request,
                readOnly: readOnly,
                isUpdating: viewModel.isUpdating,
                onEditCleaningFee: (fee) =>
                    viewModel.updateCleaningFee(request, fee),
                onUpdateStatus: (status) =>
                    viewModel.updateStatus(request, status),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _buildNoResultsState(
      BuildContext context, MaintenanceViewModel viewModel) {
    final hasSearch = viewModel.searchQuery.trim().isNotEmpty;
    final hasStatusFilter =
        viewModel.selectedStatusFilter != maintenanceHistoryStatusFilters.first;
    return PaperCard(
      child: Column(
        children: [
          const Icon(Icons.search_off,
              color: AppColors.mutedForeground, size: 40),
          const SizedBox(height: 12),
          Text('ไม่พบรายการที่ค้นหา',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            hasSearch && hasStatusFilter
                ? 'ลองเปลี่ยนคำค้นหาหรือสถานะ'
                : hasSearch
                    ? 'ลองเปลี่ยนคำค้นหา'
                    : 'ลองเลือกสถานะอื่น',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
