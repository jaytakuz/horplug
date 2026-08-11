import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/promptpay.dart';
import '../utils/formatters.dart';
import '../viewmodels/tenant_dashboard_view_model.dart'
    show billStatusLabelOf, thaiMonthName;
import 'promptpay_qr.dart';

/// การ์ดบิลในฟองแชท — งวด ยอด ครบกำหนด สถานะสด และ QR ที่จ่ายได้เลย
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
    this.promptPayId,
  });

  final Invoice? invoice;
  final String fallbackText;
  final Color textColor;
  final VoidCallback? onOpen;

  /// เลขพร้อมเพย์ของหอ — มีค่าเมื่อผู้ที่กำลังดูการ์ดใบนี้คือผู้เช่าเท่านั้น
  ///
  /// ฝั่งเจ้าของหอส่ง null ลงมา การ์ดจึงเป็นการ์ดเปล่าเหมือนเดิม เพราะ QR ของ
  /// ตัวเองสแกนแล้วไม่มีอะไรเกิดขึ้น มันกินที่ในฟองแชทของทุกบิลไปเปล่าๆ
  final String? promptPayId;

  /// payload พร้อมเพย์ของบิลใบนี้ · null เมื่อไม่ควรให้จ่าย หรือสร้างไม่ได้
  ///
  /// จำกัดไว้ที่บิลที่ยัง `unpaid` เท่านั้น — บิลที่ส่งสลิปแล้วหรือจ่ายแล้วยัง
  /// โชว์ QR คือการเชิญให้จ่ายซ้ำ ส่วนบิลที่ถูกยกเลิกคือการเชิญให้จ่ายใบที่ตาย
  /// ไปแล้ว ซึ่งเงินที่โอนออกไปตามนั้นไม่มีบิลใบไหนรองรับ
  ///
  /// ยอดศูนย์ถูกตัดออกด้วย เพราะ QR ที่ระบุยอด ฿0 ธนาคารไม่รับ และมันแปลว่าบิล
  /// ใบนั้นมีอะไรผิดตั้งแต่ตอนออกอยู่แล้ว
  String? _payableQrPayload(Invoice bill) {
    final id = promptPayId?.trim() ?? '';
    if (id.isEmpty) return null;
    if (bill.status != InvoiceStatus.unpaid) return null;
    if (bill.total <= 0) return null;

    return promptPayPayload(promptPayId: id, amount: bill.total);
  }

  @override
  Widget build(BuildContext context) {
    final bill = invoice;
    if (bill == null) {
      return Text(fallbackText, style: TextStyle(color: textColor));
    }

    final qrPayload = _payableQrPayload(bill);

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
        Text(billStatusLabelOf(bill),
            style: TextStyle(color: textColor, fontSize: 11)),
        if (qrPayload != null) ...[
          const SizedBox(height: 10),
          // ฟองแชทกว้างสุด 280 หักช่องว่างข้างใน 12 สองด้าน เหลือ 256 · QR ขนาด
          // 168 บวกกรอบขาวของตัวมันเอง 12 สองด้าน = 192 จึงไม่ดันฟองให้บาน
          Center(child: PromptPayQr(payload: qrPayload, size: 168)),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'สแกนเพื่อจ่าย ${formatBaht(bill.total)}',
              style: TextStyle(color: textColor, fontSize: 11),
            ),
          ),
        ],
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
