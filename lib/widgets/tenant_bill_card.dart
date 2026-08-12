import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../viewmodels/tenant_dashboard_view_model.dart'
    show billStatusLabelOf, billStatusVariant, thaiMonthName;
import 'reusable_widgets.dart';
import '../utils/formatters.dart';

/// การ์ดบิลหนึ่งใบในมุมมองผู้เช่า — รายการค่าใช้จ่ายแบบละเอียด + ปุ่มชำระ
class TenantBillCard extends StatelessWidget {
  const TenantBillCard({
    super.key,
    required this.bill,
    this.onPay,
    this.onSavePdf,
    this.onCancelCash,
  });

  final Invoice bill;
  final VoidCallback? onPay;

  /// บันทึกบิลใบนี้เป็น PDF
  ///
  /// อยู่บนการ์ดไม่ใช่ในแผ่นชำระเงิน เพราะแผ่นนั้นเปิดได้เฉพาะบิลที่ยังค้างชำระ
  /// ผู้เช่าจึงเคยบันทึกได้แต่บิลที่ยังไม่จ่าย ส่วนใบที่จ่ายแล้ว — ซึ่งเป็นใบที่
  /// ต้องเก็บไว้เป็นหลักฐานจริงๆ และเป็นเหตุผลที่เอกสารมีลายน้ำ "ชำระแล้ว" —
  /// ไม่มีทางเข้าถึงเลยสักทาง
  final VoidCallback? onSavePdf;

  /// ถอนการแจ้งจ่ายเงินสดที่ยังรอเจ้าของหอยืนยัน
  final VoidCallback? onCancelCash;

  @override
  Widget build(BuildContext context) {
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
                label: billStatusLabelOf(bill),
                variant: billStatusVariant(bill.status),
              ),
            ],
          ),
          Text(
            bill.revision > 1
                ? '${bill.invoiceNo} · แก้ไขครั้งที่ ${bill.revision}'
                : bill.invoiceNo,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (bill.recalculatedAt != null) ...[
            const SizedBox(height: 4),
            RecalculatedNote(previousTotal: bill.previousTotal),
          ],
          const SizedBox(height: 12),
          _LineItem(label: '🏠 ค่าห้อง', amount: bill.roomPrice),
          _LineItem(
            label: '⚡ ค่าไฟ ${formatUnits(bill.electricityUnits)} หน่วย',
            amount: bill.electricityCost,
          ),
          _LineItem(label: '💧 ค่าน้ำ', amount: bill.waterCost),
          if (bill.cleaningFee > 0)
            _LineItem(label: '🧹 ค่าทำความสะอาด', amount: bill.cleaningFee),
          const Divider(height: 24),
          // ข้อมูลทั้งหมดก่อน แล้วปุ่มไว้ท้ายสุด — เดิมปุ่มอยู่ระหว่างยอดรวมกับ
          // วันครบกำหนด ผู้เช่าจึงเจอปุ่มให้กดก่อนจะอ่านครบว่าต้องจ่ายเมื่อไหร่
          // และเหตุผลที่สลิปรอบก่อนถูกปฏิเสธ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ยอดรวมสุทธิ',
                  style: Theme.of(context).textTheme.labelSmall),
              Flexible(
                child: Text(
                  formatBaht(bill.total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 20),
                ),
              ),
            ],
          ),
          if (bill.status == InvoiceStatus.unpaid) ...[
            const SizedBox(height: 4),
            Text(
              'ครบกำหนด ${bill.dueDate.day} ${thaiMonthName(bill.dueDate.month)} ${bill.dueDate.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          // ผู้เช่าต้องอ่านเหตุผลที่สลิปถูกปฏิเสธก่อนจ่ายรอบสอง
          if (bill.rejectionReason != null &&
              bill.status == InvoiceStatus.unpaid) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.destructiveBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'สลิปถูกปฏิเสธ: ${bill.rejectionReason}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.destructive),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: _buildAction(context)),
              // ทุกสถานะบันทึก PDF ได้ เพราะเอกสารไม่แตะสถานะบิลเลย และคิวอาร์
              // ในไฟล์ถูกกันไว้แล้วให้ขึ้นเฉพาะบิลค้างชำระ (ดู invoiceQrPayload)
              // ใบที่จ่ายแล้วจึงเป็นใบเสร็จ ไม่ใช่ช่องทางจ่ายซ้ำ
              if (onSavePdf != null)
                TextButton.icon(
                  onPressed: onSavePdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('บันทึก PDF'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mutedForeground,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
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
        // pending มีสองหน้าตา — รอตรวจสลิป กับ รอยืนยันรับเงินสด ผู้เช่าต้อง
        // รู้ว่ากำลังรออะไรอยู่ ไม่งั้นคนที่จ่ายสดจะงงว่าทำไมระบบพูดถึงสลิป
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Text(
                  bill.awaitsCashConfirmation
                      ? 'รอยืนยันรับเงินสด'
                      : 'รอเจ้าของหอตรวจสลิป',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.warning),
                ),
              ],
            ),
            // ถอนได้เฉพาะการแจ้งเงินสด — สลิปที่อัปไปแล้วมีไฟล์อยู่ใน storage
            // การถอนต้องลบไฟล์ด้วย ซึ่งเป็นคนละเรื่องและยังไม่มีทางทำ
            if (bill.awaitsCashConfirmation && onCancelCash != null)
              TextButton(
                onPressed: onCancelCash,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('ยกเลิกการแจ้ง'),
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
      case InvoiceStatus.voided:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 16, color: AppColors.mutedForeground),
            const SizedBox(width: 6),
            Text(
              'ยกเลิกแล้ว',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
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
