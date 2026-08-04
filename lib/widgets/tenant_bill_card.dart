import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../viewmodels/tenant_dashboard_view_model.dart'
    show billStatusLabel, billStatusVariant, thaiMonthName;
import 'reusable_widgets.dart';
import '../utils/formatters.dart';

/// การ์ดบิลหนึ่งใบในมุมมองผู้เช่า — รายการค่าใช้จ่ายแบบละเอียด + ปุ่มชำระ
class TenantBillCard extends StatelessWidget {
  const TenantBillCard({
    super.key,
    required this.bill,
    this.onPay,
  });

  final TenantBill bill;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final invoice = bill.invoice;
    final period = bill.period;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'บิลเดือน${thaiMonthName(period.month)} ${period.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                label: billStatusLabel(bill.status),
                variant: billStatusVariant(bill.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LineItem(label: '🏠 ค่าห้อง', amount: invoice.roomPrice),
          _LineItem(
            label:
                '⚡ ค่าไฟ ${formatUnits(invoice.electricityUnits)} หน่วย',
            amount: invoice.electricityCost,
          ),
          _LineItem(label: '💧 ค่าน้ำ', amount: invoice.waterCost),
          if (invoice.cleaningFee > 0)
            _LineItem(label: '🧹 ค่าทำความสะอาด', amount: invoice.cleaningFee),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ยอดรวมสุทธิ',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    formatBaht(bill.total),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 20),
                  ),
                ],
              ),
              _buildAction(context),
            ],
          ),
          if (bill.dueDate != null && bill.status == InvoiceStatus.unpaid) ...[
            const SizedBox(height: 8),
            Text(
              'ครบกำหนด ${bill.dueDate!.day} ${thaiMonthName(bill.dueDate!.month)} ${bill.dueDate!.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    switch (bill.status) {
      case InvoiceStatus.unpaid:
        return PrimaryButton(
          label: 'ชำระเงิน',
          icon: Icons.qr_code_2,
          onPressed: onPay,
        );
      case InvoiceStatus.pending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top,
                size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              'รอเจ้าของหอตรวจสลิป',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.warning),
            ),
          ],
        );
      case InvoiceStatus.paid:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Text(
              'ชำระแล้ว',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.success),
            ),
          ],
        );
    }
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child:
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            formatBaht(amount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
