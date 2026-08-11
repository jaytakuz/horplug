import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/invoice_pdf.dart';
import '../services/promptpay.dart';
import '../theme/app_theme.dart';
import '../viewmodels/action_result.dart';
import '../viewmodels/auth_view_model.dart' show AuthScope;
import '../viewmodels/error_message.dart';
import '../viewmodels/tenant_dashboard_view_model.dart' show thaiMonthName;
import 'promptpay_qr.dart';
import 'reusable_widgets.dart';
import '../utils/formatters.dart';

/// true เมื่อบิลใบนี้เปิดแผ่นชำระเงินได้ — เฉพาะบิลที่ยังค้างชำระเท่านั้น
///
/// เงื่อนไขนี้เคยกระจายอยู่ที่ผู้เรียกทั้งสามที่: [TenantBillCard] แสดงปุ่ม
/// "ชำระเงิน" เฉพาะ unpaid · การ์ดบิลในแชทเช็คก่อนเปิด · แดชบอร์ดเหมือนกัน
/// แปลว่าผู้เรียกรายที่สี่ที่ลืมเช็คจะพาผู้เช่าไปแนบสลิปทับบิลที่จ่ายไปแล้ว
/// (อัปโหลดสำเร็จก่อน แล้วค่อยโดน RPC ปฏิเสธ) หรือเห็นคิวอาร์ที่สแกนจ่ายซ้ำได้
///
/// เป็นกฎของแผ่นนี้ ไม่ใช่กฎของหน้าจอที่บังเอิญเปิดมัน จึงย้ายมาอยู่ที่นี่
bool canOpenPaymentSheet(Invoice bill) =>
    bill.status == InvoiceStatus.unpaid;

/// เปิดแผ่นชำระเงินสำหรับบิลหนึ่งใบ
///
/// เรียกได้ทั้งจากการ์ดยอดค้างบนแดชบอร์ด (ชำระได้ในแตะเดียว) จากแท็บบิล และจาก
/// การ์ดบิลในแชท คืน true เมื่อส่งสลิปสำเร็จ เพื่อให้หน้าที่เรียกรีเฟรชตัวเอง
///
/// **เปิดได้เฉพาะบิลที่ยังค้างชำระ** — ดู [canOpenPaymentSheet]
Future<bool> showPaymentSheet(
  BuildContext context, {
  required Invoice bill,
  required PaymentChannel? channel,
  required Future<ActionResult> Function(File slip) onSubmit,
  required Future<ActionResult> Function() onSubmitCash,
}) async {
  if (!canOpenPaymentSheet(bill)) {
    debugPrint('showPaymentSheet ถูกเรียกด้วยบิลสถานะ ${bill.status.name} — '
        'ผู้เรียกต้องกรองก่อน แผ่นจะไม่ถูกเปิด');
    return false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentSheet(
      bill: bill,
      channel: channel,
      onSubmit: onSubmit,
      onSubmitCash: onSubmitCash,
    ),
  );
  return result ?? false;
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.bill,
    required this.channel,
    required this.onSubmit,
    required this.onSubmitCash,
  });

  final Invoice bill;
  final PaymentChannel? channel;
  final Future<ActionResult> Function(File slip) onSubmit;
  final Future<ActionResult> Function() onSubmitCash;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  File? _slip;
  bool _isSubmitting = false;
  bool _isSharingPdf = false;

  /// เริ่มที่โอนเงินเพราะเป็นทางที่ผู้เช่าส่วนใหญ่ใช้ และเป็นทางเดียวที่จบได้
  /// ในตัวมันเองโดยไม่ต้องรอใคร
  PaymentMethod _method = PaymentMethod.transfer;

  Future<void> _submitCash() async {
    if (_isSubmitting) return;

    // เงินสดไม่มีหลักฐานให้ระบบตรวจ ผู้เช่ากดแล้วบิลจะไปค้างรอเจ้าของหอทันที
    // จึงถามยืนยันก่อน ต่างจากการส่งสลิปที่ตัวไฟล์เป็นเครื่องยืนยันในตัวอยู่แล้ว
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('ยืนยันการจ่ายเงินสด'),
        content: Text(
          'แจ้งว่าได้จ่ายเงินสด ${formatBaht(widget.bill.total)} '
          'ให้เจ้าของหอแล้วใช่ไหม\n\n'
          'บิลจะขึ้นสถานะรอยืนยัน จนกว่าเจ้าของหอจะกดรับเงินในระบบ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยังไม่ใช่'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ใช่ จ่ายแล้ว'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final result = await widget.onSubmitCash();
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.of(context).pop(true);
  }

  Widget _buildMethodPicker(BuildContext context) {
    return SegmentedButton<PaymentMethod>(
      segments: const [
        ButtonSegment(
          value: PaymentMethod.transfer,
          icon: Icon(Icons.qr_code_2, size: 18),
          label: Text('โอนเงิน'),
        ),
        ButtonSegment(
          value: PaymentMethod.cash,
          icon: Icon(Icons.payments_outlined, size: 18),
          label: Text('เงินสด'),
        ),
      ],
      selected: {_method},
      onSelectionChanged: _isSubmitting
          ? null
          : (selected) => setState(() => _method = selected.first),
      showSelectedIcon: false,
    );
  }

  Widget _buildCashSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.mutedForeground),
                  const SizedBox(width: 8),
                  Text('จ่ายเงินสดให้เจ้าของหอโดยตรง',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ยอดที่ต้องจ่าย ${formatBaht(widget.bill.total)}\n'
                'หลังกดแจ้ง บิลจะขึ้นสถานะ "รอยืนยัน" จนกว่าเจ้าของหอจะกด'
                'รับเงินในระบบ ถ้ากดผิดยกเลิกได้จากการ์ดบิล',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// บันทึกบิลเป็น PDF โดยไม่ปิดแผ่น — ผู้เช่ามักเก็บไฟล์ไว้ก่อนแล้วค่อยโอน
  ///
  /// ส่ง [PaymentChannel] เข้าไปด้วย เอกสารฝั่งผู้เช่าจึงมี QR กับเลขบัญชี
  /// ติดไปในไฟล์ ไม่ต้องเปิดแอปซ้ำตอนจะจ่าย
  Future<void> _sharePdf() async {
    if (_isSharingPdf) return;
    setState(() => _isSharingPdf = true);

    final dormitoryName = AuthScope.of(context).dormitoryName ?? 'หอพัก';
    String? error;
    try {
      await shareInvoicePdf(
        invoice: widget.bill,
        dormitoryName: dormitoryName,
        channel: widget.channel,
      );
    } catch (failure) {
      error = 'สร้างไฟล์ PDF ไม่สำเร็จ: ${formatErrorMessage(failure)}';
    }

    if (!mounted) return;
    setState(() => _isSharingPdf = false);
    if (error == null) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _pickSlip() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: const Text('เลือกจากคลังภาพ'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.primary),
                title: const Text('ถ่ายรูป'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;

    setState(() => _slip = File(picked.path));
  }

  Future<void> _submit() async {
    final slip = _slip;
    if (slip == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final result = await widget.onSubmit(slip);
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));

    // ปิดแผ่นเฉพาะเมื่อส่งสำเร็จ — ถ้าล้มแล้วปิด ผู้ใช้จะเสียรูปที่เลือกไว้
    // และต้องเริ่มเลือกใหม่ทั้งที่เพิ่งเห็นข้อความว่าส่งไม่สำเร็จ
    if (result.success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.bill.period;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('ชำระเงิน',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'บิลเดือน${thaiMonthName(period.month)} ${period.year} · ${formatBaht(widget.bill.total)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildMethodPicker(context),
                const SizedBox(height: 16),
                if (_method == PaymentMethod.transfer) ...[
                  // null ครอบทั้ง "เจ้าของหอยังไม่ได้ตั้งค่า" และ "โหลดไม่สำเร็จ"
                  // ข้อความจึงต้องจริงกับทั้งสองกรณี และต้องไม่ทำให้ผู้เช่าโอนไป
                  // ก่อนโดยเดาเลขบัญชีเอา — แต่ยังแนบสลิปได้ เผื่อจ่ายทางอื่นแล้ว
                  widget.channel == null
                      ? const SectionErrorNote(
                          message: 'ยังไม่มีข้อมูลช่องทางชำระเงินของหอนี้ '
                              'กรุณาสอบถามเจ้าของหอก่อนโอน')
                      : _buildChannel(context, widget.channel!),
                  const Divider(height: 24),
                  Text('แนบสลิปโอนเงิน',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildSlipPicker(context),
                ] else
                  _buildCashSection(context),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _method == PaymentMethod.transfer
                          ? PrimaryButton(
                              label: 'ส่งสลิป',
                              fullWidth: true,
                              isLoading: _isSubmitting,
                              onPressed: _slip == null ? null : _submit,
                            )
                          : PrimaryButton(
                              label: 'แจ้งว่าจ่ายเงินสดแล้ว',
                              icon: Icons.payments_outlined,
                              fullWidth: true,
                              isLoading: _isSubmitting,
                              onPressed: _submitCash,
                            ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isSharingPdf ? null : _sharePdf,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(52, 48),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSharingPdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined,
                              size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannel(BuildContext context, PaymentChannel channel) {
    // null ได้สองทาง: หอนี้ไม่ได้ตั้งเลขพร้อมเพย์ไว้ หรือเลขที่ตั้งไว้ผิดรูปแบบ
    // จนสร้าง payload ไม่ได้ ทั้งสองกรณีจบลงเหมือนกันคือไม่แสดง QR แล้วให้โอน
    // ด้วยเลขบัญชีแทน ดีกว่าโชว์กล่องเปล่าให้สแกนไม่ติด
    final qrPayload = channel.hasPromptPay
        ? promptPayPayload(
            promptPayId: channel.promptPayId!,
            amount: widget.bill.total,
          )
        : null;

    return Column(
      children: [
        Text('ยอดที่ต้องชำระ',
            style: Theme.of(context).textTheme.labelSmall),
        Text(formatBaht(widget.bill.total),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        // QR ถูกสร้างสดจากเลขพร้อมเพย์ของหอบวกยอดของบิลใบนี้ จำนวนเงินจึงฝังอยู่
        // ในตัว QR แล้ว ผู้เช่าไม่ต้องพิมพ์ยอดเอง — ซึ่งเคยเป็นสาเหตุอันดับต้นๆ
        // ที่สลิปถูกปฏิเสธแล้วต้องโอนใหม่
        if (qrPayload != null) ...[
          PromptPayQr(payload: qrPayload, size: 200),
          const SizedBox(height: 8),
          Text(
            'สแกนแล้วยอดจะขึ้นให้อัตโนมัติ ไม่ต้องกรอกเอง',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 12),
        ],
        if (channel.hasBankAccount) ...[
          if (qrPayload != null)
            Text('หรือโอนเข้าบัญชี',
                style: Theme.of(context).textTheme.labelSmall),
          Text(channel.bankName!,
              style: Theme.of(context).textTheme.bodyMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SelectableText(
                channel.accountNo!,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(letterSpacing: 1.2),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'คัดลอกเลขบัญชี',
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: channel.accountNo!));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('คัดลอกเลขบัญชีแล้ว')),
                  );
                },
              ),
            ],
          ),
        ],
        Text(channel.accountName,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildSlipPicker(BuildContext context) {
    final slip = _slip;

    if (slip == null) {
      // Ink วาด decoration ลงบน Material บรรพบุรุษโดยตรง splash ของ InkWell
      // จึงวาดทับได้ — ต่างจาก Container ที่เป็นชั้นทึบคั่นบัง splash ไว้
      // (ใช้ Ink แทน Material เพราะต้องคง Border.all ไว้)
      return Ink(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: _pickSlip,
          borderRadius: BorderRadius.circular(12),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 32, color: AppColors.mutedForeground),
              SizedBox(height: 8),
              Text('แตะเพื่อแนบสลิป',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(slip,
              width: 120, height: 120, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: _isSubmitting ? null : _pickSlip,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('เปลี่ยนรูป'),
          style: TextButton.styleFrom(foregroundColor: AppColors.ring),
        ),
      ],
    );
  }
}
