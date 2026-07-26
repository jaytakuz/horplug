import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/maintenance_view_model.dart';
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
      child: _MaintenanceHistoryView(roomNumber: roomNumber, readOnly: readOnly),
    );
  }
}

class _MaintenanceHistoryView extends StatelessWidget {
  const _MaintenanceHistoryView({required this.roomNumber, required this.readOnly});

  final String roomNumber;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MaintenanceViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text('ประวัติการแจ้งซ่อม/ทำความสะอาด ห้อง $roomNumber')),
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

    return RefreshIndicator(
      onRefresh: viewModel.loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: viewModel.requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _RequestCard(
            request: viewModel.requests[index],
            viewModel: viewModel,
            readOnly: readOnly),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.viewModel,
    required this.readOnly,
  });

  final MaintenanceRequest request;
  final MaintenanceViewModel viewModel;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    BadgeVariant variant;
    switch (request.status) {
      case MaintenanceStatus.pending:
        variant = BadgeVariant.warning;
        break;
      case MaintenanceStatus.inProgress:
        variant = BadgeVariant.primary;
        break;
      case MaintenanceStatus.completed:
        variant = BadgeVariant.success;
        break;
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      request.requestType == MaintenanceRequestType.repair
                          ? Icons.build_outlined
                          : Icons.cleaning_services_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        maintenanceRequestTypeLabel(request.requestType),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: maintenanceStatusLabel(request.status),
                variant: variant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(request.description,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            'แจ้งโดย ${request.tenantName} • ${_formatDate(request.requestedAt)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          ),
          if (request.completedAt != null)
            Text(
              'เสร็จสิ้นเมื่อ ${_formatDate(request.completedAt!)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          if (request.requestType == MaintenanceRequestType.cleaning &&
              (!readOnly || request.cleaningFee > 0))
            _buildCleaningFeeRow(context),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCleaningFeeRow(BuildContext context) {
    final feeLabel = Row(
      children: [
        const Icon(Icons.attach_money, size: 16, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          request.cleaningFee > 0
              ? 'ค่าทำความสะอาด: ฿${request.cleaningFee.toStringAsFixed(0)}'
              : 'กำหนดค่าทำความสะอาด',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        if (!readOnly) ...[
          const SizedBox(width: 4),
          const Icon(Icons.edit_outlined,
              size: 14, color: AppColors.mutedForeground),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: readOnly
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: feeLabel,
            )
          : InkWell(
              onTap: () => _showEditFeeDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: feeLabel,
              ),
            ),
    );
  }

  Future<void> _showEditFeeDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: request.cleaningFee > 0
          ? request.cleaningFee.toStringAsFixed(0)
          : '',
    );

    final fee = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('ค่าทำความสะอาด'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '฿ ',
            hintText: '0',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim()) ?? 0;
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (fee != null) {
      await viewModel.updateCleaningFee(request, fee);
    }
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
