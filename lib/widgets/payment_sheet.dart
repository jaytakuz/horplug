import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/invoice_pdf.dart';
import '../theme/app_theme.dart';
import '../viewmodels/action_result.dart';
import '../viewmodels/auth_view_model.dart' show AuthScope;
import '../viewmodels/error_message.dart';
import '../viewmodels/tenant_dashboard_view_model.dart' show thaiMonthName;
import 'reusable_widgets.dart';
import '../utils/formatters.dart';

/// เปิดแผ่นชำระเงินสำหรับบิลหนึ่งใบ
///
/// เรียกได้ทั้งจากการ์ดยอดค้างบนแดชบอร์ด (ชำระได้ในแตะเดียว) และจากแท็บบิล
/// คืน true เมื่อส่งสลิปสำเร็จ เพื่อให้หน้าที่เรียกรีเฟรชตัวเอง
Future<bool> showPaymentSheet(
  BuildContext context, {
  required Invoice bill,
  required PaymentChannel? channel,
  required Future<ActionResult> Function(File slip) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentSheet(
      bill: bill,
      channel: channel,
      onSubmit: onSubmit,
    ),
  );
  return result ?? false;
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.bill,
    required this.channel,
    required this.onSubmit,
  });

  final Invoice bill;
  final PaymentChannel? channel;
  final Future<ActionResult> Function(File slip) onSubmit;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  File? _slip;
  bool _isSubmitting = false;
  bool _isSharingPdf = false;

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
                widget.channel == null
                    ? const SectionErrorNote(
                        message: 'โหลดช่องทางชำระเงินไม่สำเร็จ')
                    : _buildChannel(context, widget.channel!),
                const Divider(height: 24),
                Text('แนบสลิปโอนเงิน',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildSlipPicker(context),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'ส่งสลิป',
                        fullWidth: true,
                        isLoading: _isSubmitting,
                        onPressed: _slip == null ? null : _submit,
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
    return Column(
      children: [
        Text('ยอดที่ต้องชำระ',
            style: Theme.of(context).textTheme.labelSmall),
        Text(formatBaht(widget.bill.total),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(channel.qrAssetPath, width: 200, height: 200),
        ),
        const SizedBox(height: 8),
        // QR เฟสนี้เป็นภาพนิ่งจึงไม่มีจำนวนเงินฝังอยู่ ถ้าไม่บอกตรงนี้ ผู้เช่า
        // จะสแกนแล้วเจอช่องจำนวนเงินว่าง กรอกผิด แล้วสลิปถูกปฏิเสธ
        Text(
          'กรุณากรอกจำนวนเงินเอง',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.warning),
        ),
        const SizedBox(height: 12),
        Text(channel.bankName, style: Theme.of(context).textTheme.bodyMedium),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SelectableText(
              channel.accountNo,
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
                    ClipboardData(text: channel.accountNo));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('คัดลอกเลขบัญชีแล้ว')),
                );
              },
            ),
          ],
        ),
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
