import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/auth_view_model.dart' show AuthScope;
import '../viewmodels/invoice_actions_view_model.dart';
import '../viewmodels/tenant_dashboard_view_model.dart'
    show billStatusLabelOf, billStatusVariant, thaiMonthName;
import 'reusable_widgets.dart';
import 'slip_review_sheet.dart';

/// เปิดแผ่นรายละเอียดบิลฝั่งเจ้าของหอ
///
/// รับแค่ [Invoice] จึงเปิดได้ทั้งจากการ์ดบิลในหน้ารายการบิลและการ์ดบิลใน
/// แชท ไม่ผูกกับ ViewModel ตัวใดตัวหนึ่งโดยเฉพาะ [dormitoryId] ต้องส่งมาเพราะ
/// การออกใบแทน (reissueInvoice) ต้องรู้ว่าจะประกอบร่างบิลจากหอไหน
///
/// คืน true เมื่อสถานะบิลถูกเปลี่ยนระหว่างเปิดแผ่นนี้ (ผ่านแผ่นตรวจสลิปหรือ
/// การยกเลิกบิลที่เปิดต่อ) เพื่อให้หน้าที่เรียกรีเฟรชรายการของตัวเอง
Future<bool> showInvoiceDetailSheet(
  BuildContext context, {
  required Invoice invoice,
  required int dormitoryId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => InvoiceActionsViewModel(
        invoice: invoice,
        dormitoryId: dormitoryId,
      ),
      child: const _InvoiceDetailSheet(),
    ),
  );
  return result ?? false;
}

class _InvoiceDetailSheet extends StatefulWidget {
  const _InvoiceDetailSheet();

  @override
  State<_InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends State<_InvoiceDetailSheet> {
  /// เปิดแผ่นตรวจสลิปต่อ แล้วส่งต่อผลลัพธ์ (สถานะเปลี่ยนหรือไม่) ให้ผู้เรียก
  /// แผ่นนี้ทันที — ไม่มีเหตุผลจะค้างแผ่นรายละเอียดไว้เบื้องหลังทั้งที่สถานะ
  /// ที่แสดงอยู่กลายเป็นของเก่าไปแล้ว
  Future<void> _openSlipReview() async {
    final actions = context.read<InvoiceActionsViewModel>();
    final changed = await showSlipReviewSheet(
      context,
      invoice: actions.invoice,
      dormitoryId: actions.dormitoryId,
    );
    if (!changed || !mounted) return;
    Navigator.of(context).pop(true);
  }

  /// ยกเลิกบิล (บังคับเหตุผล) แล้วถามแยกต่างหากว่าจะออกใบแทนหรือไม่ — สอง
  /// คำถามคนละก้อน เพราะบางกรณี (ผู้เช่าย้ายออกกลางคัน) เจ้าของหอต้องการแค่
  /// ยกเลิก ไม่ต้องมีใบใหม่
  Future<void> _voidBill() async {
    final actions = context.read<InvoiceActionsViewModel>();
    if (actions.isBusy) return;

    final changed = await runVoidInvoiceFlow(context, actions: actions);

    if (!mounted) return;
    if (changed) Navigator.of(context).pop(true);
  }

  /// ยืนยันว่าได้รับเงินสดจากผู้เช่าแล้ว
  ///
  /// ถามยืนยันก่อนเพราะกดแล้วบิลเป็น "ชำระแล้ว" ทันทีและถอยกลับไม่ได้ —
  /// canTransition ปิดทาง paid → pending ไว้ ทางแก้เดียวคือยกเลิกบิลแล้วออกใหม่
  Future<void> _confirmCash() async {
    final actions = context.read<InvoiceActionsViewModel>();
    if (actions.isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('ยืนยันรับเงินสด'),
        content: Text(
          'ได้รับเงินสด ${formatBaht(actions.invoice.total)} '
          'จาก ${actions.invoice.tenantName} แล้วใช่ไหม\n\n'
          'บิลจะเปลี่ยนเป็น "ชำระแล้ว" ทันที และย้อนกลับไม่ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยังไม่ได้รับ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ได้รับแล้ว'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await actions.confirmCash();
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.of(context).pop(true);
  }

  /// ปฏิเสธการแจ้งจ่ายเงินสด — บิลกลับไปค้างชำระพร้อมเหตุผลให้ผู้เช่าอ่าน
  ///
  /// คู่กับ [_confirmCash] เสมอ ไม่งั้นเจ้าของหอที่เจอผู้เช่ากดแจ้งทั้งที่ยัง
  /// ไม่จ่าย จะติดอยู่กับบิลที่ค้างเป็น "รอยืนยัน" ตลอดไป หรือต้องยกเลิกบิลทิ้ง
  /// ทั้งใบซึ่งกินเลขที่บิลเพิ่มโดยไม่จำเป็น
  Future<void> _rejectCash() async {
    final actions = context.read<InvoiceActionsViewModel>();
    if (actions.isBusy) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(
        title: 'ยังไม่ได้รับเงินสด',
        hint: 'ระบุเหตุผล เช่น ยังไม่ได้รับเงิน จำนวนเงินไม่ครบ',
        confirmLabel: 'ยืนยัน',
      ),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    final result = await actions.rejectCash(reason);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.of(context).pop(true);
  }

  /// สร้างและแชร์ PDF โดยไม่ปิดแผ่น — ต่างจากปุ่มอื่นตรงที่ไม่ได้เปลี่ยนสถานะ
  /// อะไรเลย เจ้าของหอจึงควรอยู่หน้าเดิมได้หลังแชร์เสร็จ
  Future<void> _sharePdf() async {
    final actions = context.read<InvoiceActionsViewModel>();
    if (actions.isBusy) return;

    final result = await actions.sharePdf(
      dormitoryName: AuthScope.of(context).dormitoryName ?? 'หอพัก',
    );

    if (!mounted || result.success) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final actions = context.watch<InvoiceActionsViewModel>();
    final invoice = actions.invoice;

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invoice.invoiceNo,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            'งวด${thaiMonthName(invoice.billingMonth)} ${invoice.billingYear} · ห้อง ${invoice.roomNumber} · ${invoice.tenantName}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: billStatusLabelOf(invoice),
                      variant: billStatusVariant(invoice.status),
                    ),
                  ],
                ),
                const Divider(height: 24),
                InfoRow(label: 'ค่าห้อง', value: formatBaht(invoice.roomPrice)),
                InfoRow(
                  label: 'ค่าไฟ',
                  value:
                      '${formatBaht(invoice.electricityCost)} (${formatUnits(invoice.electricityUnits)} หน่วย)',
                ),
                InfoRow(label: 'ค่าน้ำ', value: formatBaht(invoice.waterCost)),
                InfoRow(
                  label: 'ค่าทำความสะอาด',
                  value: formatBaht(invoice.cleaningFee),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ยอดรวมสุทธิ',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      formatBaht(invoice.total),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                if (invoice.isVoided) ...[
                  const SizedBox(height: 16),
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
                        Text('เหตุผลที่ยกเลิกบิล',
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(
                          invoice.voidReason?.trim().isNotEmpty == true
                              ? invoice.voidReason!
                              : 'ไม่ได้ระบุเหตุผล',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // ปุ่มเปลี่ยนสถานะทั้งหมดหายไปเมื่อบิลถูกยกเลิกแล้ว — ยกเลิก
                // แล้วคือจบ (canTransition บล็อกไว้ที่ชั้น service อยู่แล้ว)
                // เหลือแค่ "บันทึก PDF" ที่ยังทำได้เสมอเพราะไม่แตะสถานะ
                if (!invoice.isVoided) ...[
                  // pending มีสองหน้าตา — จ่ายสดไม่มีสลิปให้ตรวจ ปุ่ม "ตรวจสลิป"
                  // จะพาไปหน้าจอที่ว่างเปล่า จึงต้องเป็นการยืนยันรับเงินแทน
                  if (invoice.awaitsCashConfirmation) ...[
                    PrimaryButton(
                      label: 'ยืนยันรับเงินสดแล้ว',
                      icon: Icons.payments_outlined,
                      fullWidth: true,
                      isLoading: actions.isBusy,
                      onPressed: actions.isBusy ? null : _confirmCash,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: actions.isBusy ? null : _rejectCash,
                      icon: const Icon(Icons.money_off_outlined),
                      label: const Text('ยังไม่ได้รับเงิน'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: AppColors.destructive,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else if (invoice.awaitsSlipReview) ...[
                    PrimaryButton(
                      label: 'ตรวจสลิป',
                      icon: Icons.image_outlined,
                      fullWidth: true,
                      onPressed: _openSlipReview,
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: actions.isBusy ? null : _voidBill,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('ยกเลิกบิล'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: AppColors.destructive,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: actions.isBusy ? null : _sharePdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('บันทึก PDF'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ลำดับยกเลิกบิล: กล่องเหตุผล (บังคับ) → ยกเลิก → ถามแยกว่าจะออกใบแทนไหม
///
/// ใช้ร่วมกันทั้งปุ่ม "ยกเลิกบิล" ในแผ่นรายละเอียดและเมนู ⋮ บนการ์ดบิลใน
/// billing_screen.dart เพื่อไม่ให้สองที่นี้มีพฤติกรรมเพี้ยนไปจากกัน
///
/// คืน true เมื่อยกเลิกสำเร็จ (ไม่ว่าจะตอบออกใบแทนหรือไม่ก็ตาม) เพื่อให้
/// ผู้เรียกรีเฟรชรายการของตัวเอง คืน false เมื่อกดยกเลิกกล่องเหตุผลหรือ
/// การยกเลิกล้มเหลว
Future<bool> runVoidInvoiceFlow(
  BuildContext context, {
  required InvoiceActionsViewModel actions,
}) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => const _ReasonDialog(
      title: 'ยกเลิกบิล',
      hint: 'ระบุเหตุผลที่ยกเลิก เช่น มิเตอร์อ่านผิด ลืมใส่ค่าทำความสะอาด',
      confirmLabel: 'ยืนยันยกเลิก',
    ),
  );
  if (reason == null || reason.trim().isEmpty || !context.mounted) {
    return false;
  }

  final voided = await actions.voidBill(reason);
  if (!voided.success) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(voided.message)));
    }
    return false;
  }

  if (!context.mounted) return true;

  final shouldReissue = await showDialog<bool>(
    context: context,
    builder: (_) => const _ReissueConfirmDialog(),
  );

  // ข้อความเดียวท้ายสุดที่สรุปทั้งการยกเลิกและผลของการออกใบแทน (ถ้าตอบใช่)
  // แทนที่จะยิง SnackBar ซ้อนกันหลายอัน — ViewModel.reissue() จึงประกอบข้อความ
  // ที่เล่าครบทั้งสองขั้น รวมถึงเคสที่ reissueInvoice คืน null เงียบๆ
  var message = voided.message;
  if (shouldReissue == true && context.mounted) {
    message = (await actions.reissue()).message;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  return true;
}

/// กล่องกรอกเหตุผลการยกเลิก — โครงเดียวกับ _RejectReasonDialog ใน
/// slip_review_sheet.dart: เป็น StatefulWidget เพื่อให้ตัวมันเองเป็นเจ้าของ
/// TextEditingController และ dispose ใน State.dispose() ห้าม dispose
/// controller ทันทีหลัง showDialog คืนค่า (เช่นใน finally ของผู้เรียก) เพราะ
/// ตอนนั้น dialog เพิ่งเริ่ม animate ปิด ValueListenableBuilder ข้างในยัง
/// subscribe กับ controller อยู่ ทำให้เกิด "A TextEditingController was used
/// after being disposed"
/// กล่องขอเหตุผลก่อนทำสิ่งที่ผู้เช่าจะได้อ่านทีหลัง — ใช้ทั้งตอนยกเลิกบิลและ
/// ตอนแจ้งว่ายังไม่ได้รับเงินสด สองอย่างนี้ต่างกันแค่ถ้อยคำ
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String hint;
  final String confirmLabel;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
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
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ปิด'),
        ),
        // ปิดปุ่มไว้จนกว่าจะพิมพ์เหตุผล — เหตุผลว่างทำให้ไม่มีบันทึกว่าทำไม
        // บิลใบนี้ถึงถูกยกเลิก
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, value, __) => ElevatedButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
            ),
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}

/// กล่องถามแยกต่างหากว่าจะออกใบแทนหรือไม่ — ไม่มี TextEditingController จึง
/// เป็น StatelessWidget ได้ ไม่ต้องมีเรื่อง dispose ให้กังวล
class _ReissueConfirmDialog extends StatelessWidget {
  const _ReissueConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('ออกบิลใบใหม่แทนเลยไหม'),
      content: const Text(
        'ระบบจะประกอบบิลใหม่จากมิเตอร์งวดเดียวกันให้ทันที หากผู้เช่าย้ายออก '
        'หรือไม่ต้องการออกใบแทน เลือก "ไม่ออกใบแทน" ได้',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ไม่ออกใบแทน'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('ออกใบใหม่'),
        ),
      ],
    );
  }
}
