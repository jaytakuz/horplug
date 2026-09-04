import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../services/invoice_service.dart';
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
/// [service] มีไว้ให้เทสต์ฉีด fake เข้ามาแทน `InvoiceService()` จริง — ผู้เรียก
/// ปกติไม่ต้องส่งมา (เหมือน [InvoiceActionsViewModel] เองที่รับ service?
/// เป็น optional อยู่แล้ว)
///
/// คืน true เมื่อสถานะบิลถูกเปลี่ยนระหว่างเปิดแผ่นนี้ (ผ่านแผ่นตรวจสลิปหรือ
/// การยกเลิกบิลที่เปิดต่อ) เพื่อให้หน้าที่เรียกรีเฟรชรายการของตัวเอง
Future<bool> showInvoiceDetailSheet(
  BuildContext context, {
  required Invoice invoice,
  required int dormitoryId,
  InvoiceService? service,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => InvoiceActionsViewModel(
        invoice: invoice,
        dormitoryId: dormitoryId,
        service: service,
      )..loadExtraFees(),
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

  /// ส่งการ์ดบิลใบนี้เข้าแชทห้องอีกครั้ง
  ///
  /// ปิดแผ่นเมื่อส่งสำเร็จ — การกดแล้วแผ่นค้างอยู่ที่เดิมอ่านเหมือนยังไม่มีอะไร
  /// เกิดขึ้น เจ้าของหอต้องมองหา SnackBar ที่โผล่ใต้แผ่นเพื่อจะรู้ว่าสำเร็จ
  ///
  /// คืน false เพราะสถานะบิลไม่ได้เปลี่ยน หน้าที่เรียกจึงไม่ต้องรีโหลดรายการ
  /// ส่วนการ์ดใบใหม่ในห้องแชทมาถึงเองผ่าน stream ของข้อความอยู่แล้ว
  ///
  /// ส่งไม่สำเร็จให้แผ่นค้างไว้ ปุ่มยังอยู่ที่เดิมให้กดซ้ำได้ทันที
  Future<void> _sendCardToChat() async {
    final actions = context.read<InvoiceActionsViewModel>();
    if (actions.isBusy) return;

    // จับ messenger ไว้ก่อนปิดแผ่น — ScaffoldMessenger.of(context) หลัง pop
    // จะอ้าง context ที่ถูกถอดออกจาก tree ไปแล้ว
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final result = await actions.sendCardToChat();
    if (!mounted) return;

    if (result.success) navigator.pop(false);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
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

  /// เจ้าของหอบันทึกเองว่าบิลใบนี้ได้รับเงินแล้ว โดยผู้เช่าไม่ได้แจ้งมาก่อน
  ///
  /// ถามวิธีที่รับเงินก่อนเสมอ ไม่เดาให้ — ผู้เช่าที่ไม่ได้กดอะไรเลยควรอ่านออก
  /// จากประวัติได้ว่าเจ้าของหอรับรองการจ่ายแบบไหน · และเตือนว่าย้อนกลับไม่ได้
  /// ด้วยเหตุผลเดียวกับ [_confirmCash] คือ canTransition ปิดทาง paid → unpaid
  Future<void> _markPaidDirectly() async {
    final actions = context.read<InvoiceActionsViewModel>();
    if (actions.isBusy) return;

    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (_) =>
          _MarkPaidDialog(invoice: actions.invoice, total: actions.liveTotal),
    );
    if (method == null || !mounted) return;

    final result = await actions.markPaid(method);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.of(context).pop(true);
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
          'ได้รับเงินสด ${formatBaht(actions.liveTotal)} '
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
                          if (invoice.recalculatedAt != null) ...[
                            const SizedBox(height: 4),
                            RecalculatedNote(
                                previousTotal: invoice.previousTotal),
                            Text(
                              'ปรับเมื่อ ${formatRelativeTime(invoice.recalculatedAt!)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
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
                const SizedBox(height: 4),
                Text('ค่าใช้จ่ายเพิ่มเติม',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 8),
                if (actions.isLoadingExtraFees)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                        child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                else
                  for (final fee in actions.extraFees)
                    _ExtraFeeRow(
                      fee: fee,
                      onRemove: invoice.status == InvoiceStatus.unpaid &&
                              !actions.isBusy
                          ? () => actions.removeExtraFee(fee)
                          : null,
                    ),
                if (invoice.status == InvoiceStatus.unpaid) ...[
                  const SizedBox(height: 4),
                  const _AddExtraFeeCard(),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ยอดรวมสุทธิ',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      formatBaht(actions.liveTotal),
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
                  // บิลที่ยังไม่มีใครแจ้งอะไรมา — เจ้าของหอบันทึกเองได้เลย
                  // สำหรับเงินที่จ่ายกันนอกแอป ซึ่งไม่งั้นจะไม่มีทางทำให้บิล
                  // ตรงกับความจริงได้เลยนอกจากรอให้ผู้เช่ากดแจ้งย้อนหลัง
                  if (invoice.status == InvoiceStatus.unpaid) ...[
                    PrimaryButton(
                      label: 'บันทึกว่าชำระแล้ว',
                      icon: Icons.check_circle_outline,
                      fullWidth: true,
                      isLoading: actions.isBusy,
                      onPressed: actions.isBusy ? null : _markPaidDirectly,
                    ),
                    const SizedBox(height: 8),
                  ],
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
                  // ทวงบิลได้เฉพาะใบที่ยังมีอะไรให้ทวง — บิลที่ชำระแล้วการส่ง
                  // การ์ดซ้ำอ่านเหมือนถูกเรียกเก็บอีกรอบ
                  if (invoice.status == InvoiceStatus.unpaid ||
                      invoice.status == InvoiceStatus.pending) ...[
                    OutlinedButton.icon(
                      onPressed: actions.isBusy ? null : _sendCardToChat,
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('ส่งบิลเข้าแชท'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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

/// แถวเดียวของรายการ "ค่าใช้จ่ายเพิ่มเติม" — ชื่อ, ป้ายบอกประเภท, จำนวนเงิน,
/// ปุ่มลบ (ซ่อนเมื่อ [onRemove] เป็น null — บิลที่ไม่ใช่ ค้างชำระ แก้ไม่ได้แล้ว)
class _ExtraFeeRow extends StatelessWidget {
  const _ExtraFeeRow({required this.fee, required this.onRemove});

  final ExtraFee fee;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fee.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  StatusBadge(
                    label: fee.isRecurring ? 'ทุกเดือน' : 'ครั้งนี้เท่านั้น',
                    variant: fee.isRecurring
                        ? BadgeVariant.primary
                        : BadgeVariant.info,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatBaht(fee.amount),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppColors.destructive, size: 20),
                onPressed: onRemove,
                tooltip: 'ลบรายการ',
              ),
          ],
        ),
      ),
    );
  }
}

/// การ์ดเพิ่มรายการค่าใช้จ่ายเพิ่มเติมใหม่ — ชื่อ + จำนวนเงิน + เลือกว่าครั้งนี้
/// เท่านั้นหรือทุกเดือน แล้วกด + เพื่อเพิ่ม เป็นเจ้าของ TextEditingController
/// เองเหมือน _CleaningFeeDialog เดิม
class _AddExtraFeeCard extends StatefulWidget {
  const _AddExtraFeeCard();

  @override
  State<_AddExtraFeeCard> createState() => _AddExtraFeeCardState();
}

class _AddExtraFeeCardState extends State<_AddExtraFeeCard> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isRecurring = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (name.isEmpty || amount == null || amount <= 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final actions = context.read<InvoiceActionsViewModel>();
    final result = await actions.addExtraFee(
      name: name,
      amount: amount,
      isRecurring: _isRecurring,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      _nameController.clear();
      _amountController.clear();
      setState(() => _isRecurring = false);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'ชื่อรายการ เช่น ค่าปรับ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixText: '฿ ',
                    hintText: '0',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: false, label: Text('ครั้งนี้เท่านั้น')),
                    ButtonSegment(value: true, label: Text('ทุกเดือน')),
                  ],
                  selected: {_isRecurring},
                  onSelectionChanged: (selected) =>
                      setState(() => _isRecurring = selected.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
              ),
            ],
          ),
        ],
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
/// ถามวิธีที่ได้รับเงินก่อนบันทึกว่าบิลชำระแล้ว — คืน null เมื่อยกเลิก
///
/// เป็น StatefulWidget เพื่อให้ตัวเลือกที่กดค้างอยู่ในตัวมันเอง ไม่ต้องยก state
/// ขึ้นไปไว้ที่แผ่นรายละเอียดซึ่งไม่ได้ใช้ค่านี้ต่อหลังกล่องปิด
class _MarkPaidDialog extends StatefulWidget {
  const _MarkPaidDialog({required this.invoice, required this.total});

  final Invoice invoice;

  /// ยอดรวมสด ณ ตอนเปิดกล่อง — ไม่ใช่ [Invoice.total] เพราะอาจมีค่าใช้จ่าย
  /// เพิ่มเติมที่เพิ่ง/ยังไม่ถูกเขียนลงบิลใบนี้ระหว่างเปิดแผ่นอยู่
  final double total;

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  // ค่าตั้งต้นเป็นเงินสด เพราะเป็นเหตุผลที่พบบ่อยที่สุดที่ทำให้ต้องบันทึกเอง —
  // ผู้เช่าที่โอนมักกดแจ้งในแอปอยู่แล้วเพราะต้องแนบสลิป
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('บันทึกว่าชำระแล้ว'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ได้รับเงิน ${formatBaht(widget.total)} '
            'จาก ${widget.invoice.tenantName} แล้วใช่ไหม\n\n'
            'บิลจะเปลี่ยนเป็น "ชำระแล้ว" ทันทีโดยไม่ต้องรอผู้เช่าแจ้ง '
            'และย้อนกลับไม่ได้',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text('ได้รับเงินมาทางไหน',
              style: Theme.of(context).textTheme.labelLarge),
          // RadioGroup ถือค่าที่เลือกให้ทั้งกลุ่ม — `groupValue`/`onChanged`
          // บน RadioListTile แต่ละใบถูก deprecate ไปตั้งแต่ Flutter 3.32
          RadioGroup<PaymentMethod>(
            groupValue: _method,
            onChanged: (value) => setState(() => _method = value!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final method in PaymentMethod.values)
                  RadioListTile<PaymentMethod>(
                    value: method,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      method == PaymentMethod.cash ? 'เงินสด' : 'เงินโอน',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_method),
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}

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
