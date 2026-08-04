import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../viewmodels/action_result.dart';
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
    // PaymentChannel ไม่มี promptPayId แล้ว — หน้าตาของแผ่นนี้จะทำจริงใน Task 5
    final bankName = widget.channel?.bankName ?? '-';
    final accountNo = widget.channel?.accountNo ?? '0XX-XXX-XXXX';

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
                // แถบนี้ลบทิ้งบรรทัดเดียวเมื่อต่อระบบชำระเงินจริงแล้ว
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'โหมดตัวอย่าง — ยังไม่เชื่อมต่อระบบชำระเงินจริง',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
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
                Center(child: _buildQrPlaceholder(context)),
                const SizedBox(height: 12),
                Center(
                  child: Text('$bankName $accountNo',
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: accountNo));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('คัดลอกเลขบัญชีแล้ว')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('คัดลอกเลขบัญชี'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.ring),
                  ),
                ),
                const Divider(height: 24),
                Text('แนบสลิปโอนเงิน',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildSlipPicker(context),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'ส่งสลิป',
                  fullWidth: true,
                  isLoading: _isSubmitting,
                  onPressed: _slip == null ? null : _submit,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrPlaceholder(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.qr_code_2,
              size: 64, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 6),
        Text('QR พร้อมเพย์ (ตัวอย่าง)',
            style: Theme.of(context).textTheme.labelSmall),
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
