import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../mock/mock_data.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String selectedFilter = 'ทั้งหมด';

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = MockData.invoices.where((inv) {
      if (selectedFilter == 'ทั้งหมด') return true;
      if (selectedFilter == 'ค้างชำระ') return inv.status == InvoiceStatus.unpaid;
      if (selectedFilter == 'รอตรวจสลิป') return inv.status == InvoiceStatus.pending;
      if (selectedFilter == 'ชำระแล้ว') return inv.status == InvoiceStatus.paid;
      return true;
    }).toList();

    return Scaffold(
      appBar: const MobileHeader(subtitle: 'จัดการบิล'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('บิลเดือน มี.ค. 2569', style: Theme.of(context).textTheme.titleMedium),
                PrimaryButton(label: 'สร้างบิล', icon: Icons.description_outlined, onPressed: () {}),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['ทั้งหมด', 'ค้างชำระ', 'รอตรวจสลิป', 'ชำระแล้ว'].map((filter) {
                final isActive = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isActive,
                    onSelected: (val) => setState(() => selectedFilter = filter),
                    backgroundColor: AppColors.card,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isActive ? Colors.white : AppColors.primary, fontSize: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(color: isActive ? AppColors.primary : AppColors.border),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredInvoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final invoice = filteredInvoices[index];
                return _InvoiceCard(invoice: invoice);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    BadgeVariant variant;
    String statusText;

    switch (invoice.status) {
      case InvoiceStatus.paid:
        variant = BadgeVariant.success;
        statusText = 'ชำระแล้ว';
        break;
      case InvoiceStatus.pending:
        variant = BadgeVariant.warning;
        statusText = 'รอตรวจสลิป';
        break;
      case InvoiceStatus.unpaid:
        variant = BadgeVariant.destructive;
        statusText = 'ค้างชำระ';
        break;
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ห้อง ${invoice.roomNumber}  ${invoice.tenantName}', style: Theme.of(context).textTheme.labelLarge),
              StatusBadge(label: statusText, variant: variant),
            ],
          ),
          const SizedBox(height: 12),
          _buildItemRow('💧 น้ำ ${invoice.waterUnits} หน่วย', '฿${invoice.waterCost.toStringAsFixed(0)}'),
          _buildItemRow('⚡ ไฟ ${invoice.electricityUnits} หน่วย', '฿${invoice.electricityCost.toStringAsFixed(0)}'),
          _buildItemRow('🏠 ค่าห้อง', '฿${invoice.roomPrice.toStringAsFixed(0)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('฿${invoice.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              if (invoice.hasSlip)
                OutlinedButton.icon(
                  onPressed: () => _showSlipDialog(context),
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('ดูสลิป'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _showSlipDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตรวจสอบสลิป'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image, size: 64, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.destructive, side: const BorderSide(color: AppColors.destructive)),
                    child: const Text('ปฏิเสธ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'อนุมัติ',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
