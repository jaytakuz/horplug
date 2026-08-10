import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/formatters.dart';
import '../viewmodels/tenant_dashboard_view_model.dart'
    show billStatusLabel, thaiMonthName;

/// การ์ดบิลในฟองแชท — งวด ยอด ครบกำหนด และสถานะสด
///
/// [invoice] เป็น null ได้เมื่อโหลดสถานะไม่สำเร็จ กรณีนั้นแสดงข้อความสำรอง
/// แทนที่จะทำให้ทั้งแชทพัง
class InvoiceChatCard extends StatelessWidget {
  const InvoiceChatCard({
    super.key,
    required this.invoice,
    required this.fallbackText,
    required this.textColor,
    this.onOpen,
  });

  final Invoice? invoice;
  final String fallbackText;
  final Color textColor;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final bill = invoice;
    if (bill == null) {
      return Text(fallbackText, style: TextStyle(color: textColor));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long, size: 16, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'บิลค่าเช่าเดือน${thaiMonthName(bill.billingMonth)} ${bill.billingYear}',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(bill.invoiceNo,
            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 10)),
        const SizedBox(height: 8),
        Text('ยอดรวม ${formatBaht(bill.total)}',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(
          'ครบกำหนด ${bill.dueDate.day} ${thaiMonthName(bill.dueDate.month)} ${bill.dueDate.year}',
          style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(billStatusLabel(bill.status),
            style: TextStyle(color: textColor, fontSize: 11)),
        if (onOpen != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('แตะเพื่อเปิดบิล ›',
                style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 10)),
          ),
        ],
      ],
    );
  }
}
