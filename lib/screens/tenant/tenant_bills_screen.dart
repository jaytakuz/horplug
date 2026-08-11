import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/invoice_pdf.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/error_message.dart';
import '../../viewmodels/tenant_bills_view_model.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/reusable_widgets.dart';
import '../../widgets/tenant_bill_card.dart';
import '../../utils/formatters.dart';

class TenantBillsScreen extends StatelessWidget {
  const TenantBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;

    return ChangeNotifierProvider(
      key: ValueKey(profile?.roomId),
      create: (_) => TenantBillsViewModel(
        roomId: profile?.roomId,
        dormitoryId: profile?.dormitoryId,
      )..load(),
      child: const _TenantBillsView(),
    );
  }
}

class _TenantBillsView extends StatelessWidget {
  const _TenantBillsView();

  Future<void> _handlePay(
    BuildContext context,
    TenantBillsViewModel viewModel,
    Invoice bill,
  ) async {
    await showPaymentSheet(
      context,
      bill: bill,
      channel: viewModel.paymentChannel,
      onSubmit: (slip) => viewModel.submitSlip(bill: bill, slip: slip),
      onSubmitCash: () => viewModel.submitCash(bill: bill),
    );
  }

  Future<void> _handleCancelCash(
    BuildContext context,
    TenantBillsViewModel viewModel,
    Invoice bill,
  ) async {
    final result = await viewModel.cancelCash(bill: bill);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _handleSavePdf(
    BuildContext context,
    TenantBillsViewModel viewModel,
    Invoice bill,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final dormitoryName = AuthScope.of(context).dormitoryName ?? 'หอพัก';

    try {
      await shareInvoicePdf(
        invoice: bill,
        dormitoryName: dormitoryName,
        channel: viewModel.paymentChannel,
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(
        content: Text('สร้างไฟล์ PDF ไม่สำเร็จ: ${formatErrorMessage(error)}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;
    final viewModel = context.watch<TenantBillsViewModel>();

    if (profile?.roomId == null) {
      return _buildNoRoomState(context, viewModel);
    }

    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('บิลของฉัน', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('ห้อง ${profile?.roomNumber ?? '—'}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'ค้างชำระ',
                  value: formatBaht(viewModel.outstanding),
                  icon: Icons.error_outline,
                  variant: BadgeVariant.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'ชำระแล้วปีนี้',
                  value: formatBaht(viewModel.paidThisYear),
                  icon: Icons.check_circle_outline,
                  variant: BadgeVariant.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilterChipGroup(
            title: 'สถานะ',
            options: tenantBillFilters,
            selectedValue: viewModel.selectedFilter,
            onSelected: viewModel.setFilter,
          ),
          const SizedBox(height: 16),
          ..._buildList(context, viewModel),
        ],
      ),
    );
  }

  List<Widget> _buildList(
    BuildContext context,
    TenantBillsViewModel viewModel,
  ) {
    if (viewModel.errorMessage != null) {
      return [
        PaperCard(
          child: Column(
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.destructive, size: 32),
              const SizedBox(height: 12),
              Text('โหลดบิลไม่สำเร็จ',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(viewModel.errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'ลองใหม่',
                icon: Icons.refresh,
                onPressed: viewModel.load,
              ),
            ],
          ),
        ),
      ];
    }

    final bills = viewModel.filteredBills;
    if (bills.isEmpty) {
      final isFiltered = viewModel.selectedFilter != 'ทั้งหมด';
      return [
        PaperCard(
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  color: AppColors.mutedForeground, size: 48),
              const SizedBox(height: 12),
              Text(
                isFiltered ? 'ไม่มีบิลในสถานะนี้' : 'ยังไม่มีบิล',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                isFiltered
                    ? 'ลองเลือกสถานะอื่น'
                    : 'บิลจะแสดงที่นี่หลังเจ้าของหอจดมิเตอร์ประจำเดือน',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ];
    }

    return [
      for (final bill in bills) ...[
        TenantBillCard(
          bill: bill,
          onPay: () => _handlePay(context, viewModel, bill),
          onSavePdf: () => _handleSavePdf(context, viewModel, bill),
          onCancelCash: () => _handleCancelCash(context, viewModel, bill),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  /// ครอบด้วย RefreshIndicator + ListView ที่ scroll ได้ — เดิมเป็น Center
  /// เฉยๆ ทำให้ผู้เช่าที่รอเข้าห้องดึงรีเฟรชไม่ได้ กลายเป็นทางตัน
  Widget _buildNoRoomState(
    BuildContext context,
    TenantBillsViewModel viewModel,
  ) {
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 48, color: AppColors.mutedForeground),
          const SizedBox(height: 12),
          Text('ยังไม่มีบิล',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'บิลจะเริ่มออกหลังเจ้าของหอเพิ่มคุณเข้าห้อง',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
