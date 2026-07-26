import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../viewmodels/billing_view_model.dart';

class BillingScreen extends StatelessWidget {
  final int dormitoryId;
  const BillingScreen({super.key, required this.dormitoryId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BillingViewModel(dormitoryId: dormitoryId)..loadInvoices(),
      child: const _BillingView(),
    );
  }
}

class _BillingView extends StatefulWidget {
  const _BillingView();

  @override
  State<_BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<_BillingView> {
  BillingViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = context.read<BillingViewModel>();
    if (!identical(_viewModel, viewModel)) {
      _viewModel?.removeListener(_onViewModelChanged);
      _viewModel = viewModel..addListener(_onViewModelChanged);
    }
  }

  void _onViewModelChanged() {
    final error = _viewModel?.consumeError();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onViewModelChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BillingViewModel>();
    final filteredInvoices = viewModel.filteredInvoices;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('จัดการบิลรายเดือน', style: Theme.of(context).textTheme.titleMedium),
                  Text('${_getMonthName(viewModel.selectedMonth)} ${viewModel.selectedYear}',
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ],
              ),
              PrimaryButton(
                label: 'ออกบิลใหม่',
                icon: Icons.add_chart,
                onPressed: viewModel.loadInvoices,
              ),
            ],
          ),
        ),
        _buildPeriodSelector(viewModel),
        _buildFilters(viewModel),
        Expanded(
          child: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredInvoices.isEmpty
                  ? _buildEmptyState(viewModel)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredInvoices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _InvoiceCard(invoice: filteredInvoices[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(BillingViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: viewModel.selectedMonth,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                labelText: 'เดือน',
                border: OutlineInputBorder(),
              ),
              items: List.generate(12, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(_getMonthName(i + 1))
              )),
              onChanged: (val) {
                if (val != null) viewModel.setPeriod(month: val);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: viewModel.selectedYear,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                labelText: 'ปี',
                border: OutlineInputBorder(),
              ),
              items: List.generate(5, (i) => DropdownMenuItem(
                value: DateTime.now().year - 1 + i,
                child: Text('${DateTime.now().year - 1 + i}')
              )),
              onChanged: (val) {
                if (val != null) viewModel.setPeriod(year: val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BillingViewModel viewModel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['ทั้งหมด', 'ค้างชำระ', 'รอตรวจสลิป', 'ชำระแล้ว'].map((filter) {
          final isActive = viewModel.selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isActive,
              onSelected: (val) => viewModel.setFilter(filter),
              backgroundColor: AppColors.card,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isActive ? Colors.white : AppColors.primary,
                fontSize: 12
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BillingViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_outlined, size: 64, color: AppColors.mutedForeground),
          const SizedBox(height: 16),
          const Text('ไม่พบข้อมูลบิลในเดือนที่เลือก', style: TextStyle(color: AppColors.mutedForeground)),
          const SizedBox(height: 8),
          const Text('กรุณาบันทึกมิเตอร์ในเมนู "มิเตอร์" ก่อน',
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          const SizedBox(height: 16),
          TextButton(onPressed: viewModel.loadInvoices, child: const Text('ลองโหลดใหม่อีกครั้ง')),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
    return months[month - 1];
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    BadgeVariant variant = BadgeVariant.destructive;
    String statusText = 'ค้างชำระ';

    if (invoice.status == InvoiceStatus.paid) {
      variant = BadgeVariant.success;
      statusText = 'ชำระแล้ว';
    } else if (invoice.status == InvoiceStatus.pending) {
      variant = BadgeVariant.warning;
      statusText = 'รอตรวจสลิป';
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ห้อง ${invoice.roomNumber}  ${invoice.tenantName}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              StatusBadge(label: statusText, variant: variant),
            ],
          ),
          const SizedBox(height: 12),
          _buildItemRow('🏠 ค่าห้อง', '฿${invoice.roomPrice.toStringAsFixed(0)}'),
          _buildItemRow('⚡ ไฟ ${invoice.electricityUnits.toStringAsFixed(1)} หน่วย', '฿${invoice.electricityCost.toStringAsFixed(0)}'),
          _buildItemRow('💧 ค่าน้ำ', '฿${invoice.waterCost.toStringAsFixed(0)}'),
          if (invoice.cleaningFee > 0)
            _buildItemRow('🧹 ค่าทำความสะอาด', '฿${invoice.cleaningFee.toStringAsFixed(0)}'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ยอดรวมสุทธิ', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                  Text('฿${invoice.total.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              if (invoice.hasSlip)
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('ดูสลิป'),
                )
              else if (invoice.status == InvoiceStatus.unpaid)
                const Text('รอการชำระ', style: TextStyle(fontSize: 12, color: AppColors.destructive, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }
}
