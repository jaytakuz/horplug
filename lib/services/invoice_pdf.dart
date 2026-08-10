import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../utils/formatters.dart';
import '../viewmodels/tenant_dashboard_view_model.dart' show thaiMonthName;

const _regularFont = 'lib/assets/fonts/Sarabun-Regular.ttf';
const _boldFont = 'lib/assets/fonts/Sarabun-Bold.ttf';

/// สร้างเอกสารบิลจากบิลที่ **ตรึงแล้ว** เท่านั้น
///
/// พารามิเตอร์เป็น [Invoice] ไม่ใช่ `InvoiceDraft` จึงเป็นไปไม่ได้ที่จะเผลอ
/// พิมพ์ตัวเลขที่คำนวณสดลงเอกสารที่ผู้เช่าจะเก็บไว้เป็นหลักฐาน
Future<Uint8List> buildInvoicePdf({
  required Invoice invoice,
  required String dormitoryName,
  PaymentChannel? channel,
}) async {
  // แพ็กเกจ pdf ใช้ Helvetica เป็นค่าเริ่มต้น ซึ่งไม่มี glyph ภาษาไทย ถ้าไม่ฝัง
  // ฟอนต์เอง เอกสารจะออกมาเป็นกล่องว่างทั้งใบโดยไม่มีอะไรเตือนทั้งตอน compile
  // และตอนรัน
  final regular = pw.Font.ttf(await rootBundle.load(_regularFont));
  final bold = pw.Font.ttf(await rootBundle.load(_boldFont));

  Uint8List? qr;
  if (channel != null) {
    final data = await rootBundle.load(channel.qrAssetPath);
    qr = data.buffer.asUint8List();
  }

  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (context) => pw.Stack(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(dormitoryName,
                      style: pw.TextStyle(font: bold, fontSize: 14)),
                  pw.Text('ใบแจ้งค่าเช่า',
                      style: pw.TextStyle(font: bold, fontSize: 14)),
                ],
              ),
              pw.Divider(),
              _row('เลขที่', invoice.invoiceNo),
              _row('งวด',
                  '${thaiMonthName(invoice.billingMonth)} ${invoice.billingYear}'),
              _row('ห้อง', '${invoice.roomNumber}   ${invoice.tenantName}'),
              _row('ออกเมื่อ', _thaiDate(invoice.issuedAt)),
              pw.Divider(),
              _amount('ค่าห้อง', invoice.roomPrice),
              _amount('ค่าไฟ ${formatUnits(invoice.electricityUnits)} หน่วย',
                  invoice.electricityCost),
              _amount('ค่าน้ำ', invoice.waterCost),
              if (invoice.cleaningFee > 0)
                _amount('ค่าทำความสะอาด', invoice.cleaningFee),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ยอดรวมสุทธิ',
                      style: pw.TextStyle(font: bold, fontSize: 13)),
                  pw.Text(formatBaht(invoice.total),
                      style: pw.TextStyle(font: bold, fontSize: 16)),
                ],
              ),
              _row('ครบกำหนดชำระ', _thaiDate(invoice.dueDate)),
              // ใบที่ถูกยกเลิกต้องบอกเหตุผลไว้บนเอกสารด้วย ไม่ใช่แค่ลายน้ำ —
              // คนที่ได้ไฟล์ต่อมาทีหลังจะได้รู้ว่าทำไมถึงใช้ใบนี้ไม่ได้
              if (invoice.isVoided) ...[
                pw.Divider(),
                _row('เหตุผลที่ยกเลิก',
                    invoice.voidReason?.trim().isNotEmpty == true
                        ? invoice.voidReason!
                        : 'ไม่ได้ระบุเหตุผล'),
              ],
              if (channel != null) ...[
                pw.Divider(),
                _row('ชำระผ่าน', channel.bankName),
                _row('เลขบัญชี', channel.accountNo),
                if (qr != null)
                  pw.Center(
                    child:
                        pw.Image(pw.MemoryImage(qr), width: 120, height: 120),
                  ),
              ],
            ],
          ),
          // PDF ที่แชร์ออกไปแล้วเรียกคืนไม่ได้ ใบที่ยกเลิกจึงต้องบอกตัวเองได้
          if (invoice.status == InvoiceStatus.paid)
            _watermark('ชำระแล้ว', PdfColors.green300, bold),
          if (invoice.isVoided) _watermark('ยกเลิก', PdfColors.red300, bold),
        ],
      ),
    ),
  );

  return document.save();
}

/// เปิดแผ่นแชร์ของระบบพร้อมไฟล์ที่ตั้งชื่อตามเลขที่บิล
Future<void> shareInvoicePdf({
  required Invoice invoice,
  required String dormitoryName,
  PaymentChannel? channel,
}) async {
  final bytes = await buildInvoicePdf(
    invoice: invoice,
    dormitoryName: dormitoryName,
    channel: channel,
  );
  await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNo}.pdf');
}

pw.Widget _row(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label),
          // เหตุผลการยกเลิกยาวกว่าหนึ่งบรรทัดได้ ถ้าไม่จำกัดความกว้างไว้
          // ข้อความจะล้นออกนอกหน้ากระดาษ A5
          pw.Expanded(
            child: pw.Text(value, textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );

pw.Widget _amount(String label, double value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label), pw.Text(formatBaht(value))],
      ),
    );

pw.Widget _watermark(String text, PdfColor color, pw.Font font) => pw.Center(
      child: pw.Transform.rotate(
        angle: 0.6,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: 60, color: color),
        ),
      ),
    );

String _thaiDate(DateTime date) =>
    '${date.day} ${thaiMonthName(date.month)} ${date.year}';
