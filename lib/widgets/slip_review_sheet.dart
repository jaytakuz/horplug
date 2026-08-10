import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/action_result.dart';
import '../viewmodels/invoice_actions_view_model.dart';
import 'reusable_widgets.dart';

/// เปิดแผ่นตรวจสลิปเต็มจอสำหรับบิลหนึ่งใบ
///
/// คืน true เมื่อเจ้าของหอเปลี่ยนสถานะบิลสำเร็จ (อนุมัติหรือปฏิเสธ) เพื่อให้
/// หน้าที่เรียกรีเฟรชรายการของตัวเอง
Future<bool> showSlipReviewSheet(
  BuildContext context, {
  required Invoice invoice,
  required int dormitoryId,
}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => InvoiceActionsViewModel(
          invoice: invoice,
          dormitoryId: dormitoryId,
        ),
        child: const _SlipReviewSheet(),
      ),
    ),
  );
  return result ?? false;
}

class _SlipReviewSheet extends StatefulWidget {
  const _SlipReviewSheet();

  @override
  State<_SlipReviewSheet> createState() => _SlipReviewSheetState();
}

class _SlipReviewSheetState extends State<_SlipReviewSheet> {
  late final Future<String> _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    // สร้าง signed URL ใหม่ทุกครั้งที่เปิดแผ่นนี้ (ใน initState ไม่ใช่ build)
    // เพื่อไม่ให้ยิงซ้ำทุกครั้งที่ widget rebuild แต่ก็ไม่ cache ข้าม session —
    // ปิดแล้วเปิดใหม่คือ widget instance ใหม่ ได้ URL ใหม่เสมอ
    _signedUrlFuture = context.read<InvoiceActionsViewModel>().slipUrl();
  }

  Future<void> _approve() async {
    final actions = context.read<InvoiceActionsViewModel>();
    if (actions.isBusy) return;
    _settle(await actions.approve());
  }

  Future<void> _openRejectDialog() async {
    final actions = context.read<InvoiceActionsViewModel>();
    if (actions.isBusy) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectReasonDialog(),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    _settle(await actions.reject(reason));
  }

  /// ปิดแผ่นเมื่อสถานะเปลี่ยนสำเร็จ ไม่งั้นบอกเหตุผลแล้วอยู่ที่เดิมให้ลองใหม่
  void _settle(ActionResult result) {
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final actions = context.watch<InvoiceActionsViewModel>();
    final invoice = actions.invoice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: const Text('ตรวจสลิปการชำระเงิน'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: PaperCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invoice.invoiceNo,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('ห้อง ${invoice.roomNumber} · ${invoice.tenantName}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Text(
                      formatBaht(invoice.total),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<String>(
                future: _signedUrlFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: SectionErrorNote(message: 'โหลดสลิปไม่สำเร็จ'),
                      ),
                    );
                  }
                  return InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        snapshot.data!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(24),
                          child:
                              SectionErrorNote(message: 'โหลดสลิปไม่สำเร็จ'),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // ปุ่มอนุมัติ/ปฏิเสธ เฉพาะบิลที่ยัง "รอตรวจสลิป" เท่านั้น — บิลที่
            // อนุมัติ ปฏิเสธ หรือยกเลิกไปแล้วยังมี slip_url ค้างอยู่ (ไม่มีขั้น
            // ตอนไหนล้าง column นี้ทิ้งตอนอนุมัติ หรือตอนยกเลิก) ปุ่มดูสลิปที่
            // การ์ดจึงยังกดได้เสมอที่ hasSlip แต่ปุ่มเปลี่ยนสถานะต้องไม่ตาม
            // ไปด้วย ไม่งั้น _assertTransition ใน service โยน exception ใส่
            // หน้าจอ (เช่นกดปฏิเสธบิลที่ชำระแล้ว)
            if (invoice.status == InvoiceStatus.pending)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: actions.isBusy ? null : _openRejectDialog,
                        icon: const Icon(Icons.close),
                        label: const Text('ปฏิเสธ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.destructive,
                          side: const BorderSide(color: AppColors.destructive),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'อนุมัติ',
                        icon: Icons.check,
                        isLoading: actions.isBusy,
                        onPressed: actions.isBusy ? null : _approve,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// กล่องกรอกเหตุผลการปฏิเสธ — เป็น StatefulWidget เพื่อให้ตัวมันเองเป็นเจ้าของ
/// TextEditingController และ dispose ใน State.dispose()
///
/// ห้าม dispose controller ทันทีหลัง showDialog คืนค่า (เช่นใน finally ของ
/// ผู้เรียก) เพราะตอนนั้น dialog เพิ่งเริ่ม animate ปิด ValueListenableBuilder
/// ข้างในยัง subscribe กับ controller อยู่ ทำให้เกิด "A TextEditingController
/// was used after being disposed" — บั๊กเดียวกับที่ commit 64bb83e เคยแก้ใน
/// กล่องแจ้งซ่อม
class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('ปฏิเสธสลิป'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'ระบุเหตุผลที่ปฏิเสธ เพื่อให้ผู้เช่าอ่านและแนบสลิปใหม่',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        // ปิดปุ่มไว้จนกว่าจะพิมพ์เหตุผล — เหตุผลว่างทำให้ผู้เช่าไม่รู้ว่า
        // ต้องแก้อะไรก่อนอัปสลิปใหม่
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, value, __) => ElevatedButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text),
            child: const Text('ยืนยันปฏิเสธ'),
          ),
        ),
      ],
    );
  }
}
