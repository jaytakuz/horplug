import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../utils/formatters.dart';
import '../viewmodels/tenant_dashboard_view_model.dart' show thaiMonthName;
import 'promptpay.dart';

const _regularFont = 'lib/assets/fonts/Sarabun-Regular.ttf';
const _boldFont = 'lib/assets/fonts/Sarabun-Bold.ttf';

/// payload ของ QR ที่ควรอยู่ในเอกสารของบิลใบนี้ · null แปลว่าไม่ต้องมี QR
///
/// **QR ขึ้นเฉพาะบิลที่ยังค้างชำระ** เอกสารที่แชร์ออกไปแล้วเรียกคืนไม่ได้ ถ้าบิล
/// ที่จ่ายหรือยกเลิกไปแล้วยังมี QR ที่สแกนจ่ายได้ ไฟล์ที่ผู้เช่าเก็บไว้จะกลาย
/// เป็นช่องทางจ่ายซ้ำ ลายน้ำ "ชำระแล้ว" ไม่พอ เพราะคนที่ยกมือถือขึ้นมาสแกนมองที่
/// QR ไม่ได้อ่านลายน้ำ
///
/// แยกออกมาเป็นฟังก์ชันของตัวเองเพื่อให้เทสต์ตรวจกฎนี้ได้ตรงๆ — การเดาจากขนาด
/// ไฟล์ PDF ใช้ไม่ได้ เพราะข้อความไทยที่เพิ่มเข้ามาทำให้ฟอนต์ฝัง glyph เพิ่มจน
/// ขนาดขยับด้วยเหตุผลที่ไม่เกี่ยวกับ QR เลย
String? invoiceQrPayload({
  required Invoice invoice,
  PaymentChannel? channel,
}) {
  if (invoice.status != InvoiceStatus.unpaid) return null;
  if (channel == null || !channel.hasPromptPay) return null;

  return promptPayPayload(
    promptPayId: channel.promptPayId!,
    amount: invoice.total,
  );
}

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

  final qrPayload = invoiceQrPayload(invoice: invoice, channel: channel);

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
              if (invoice.extraFeesTotal > 0)
                _amount('ค่าใช้จ่ายเพิ่มเติม', invoice.extraFeesTotal),
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
                _row('ชื่อบัญชี', channel.accountName),
                if (channel.hasBankAccount) ...[
                  _row('ชำระผ่าน', channel.bankName!),
                  _row('เลขบัญชี', channel.accountNo!),
                ],
                // วาด QR จาก payload ตรงๆ ไม่ต้องโหลดรูปจากเครือข่าย การสร้าง
                // เอกสารจึงทำงานได้แม้ออฟไลน์ และไม่มีทางล้มกลางคันเพราะรูป
                if (qrPayload != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrPayload,
                      width: 120,
                      height: 120,
                      // ไม่วาดข้อความใต้บาร์โค้ด — ค่าเริ่มต้นคือวาด payload
                      // ดิบด้วยฟอนต์ Courier ซึ่งไม่รองรับ Unicode (มี warning
                      // ตอนสร้างเอกสาร) และผู้อ่านไม่ได้ประโยชน์อะไรจากสตริง
                      // EMVCo ยาวๆ อยู่แล้ว บรรทัดที่มีความหมายเราวาดเองข้างล่าง
                      drawText: false,
                    ),
                  ),
                  pw.Center(
                    child: pw.Text('สแกนเพื่อชำระ ${formatBaht(invoice.total)}',
                        style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.SizedBox(height: 2),
                  // เหมือน _ComingSoonNotice ในแอป (promptpay_qr.dart) — ฟีเจอร์
                  // ชำระเงินผ่านแอปยังไม่เปิดใช้งาน คนที่ได้ไฟล์ PDF นี้ต้องรู้
                  // ก่อนสแกนเหมือนคนที่เห็น QR ในแอป
                  pw.Center(
                    child: pw.Text(
                      'ระบบชำระเงินจะมาเร็วๆ นี้',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 8,
                        color: PdfColors.orange800,
                      ),
                    ),
                  ),
                ],
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
