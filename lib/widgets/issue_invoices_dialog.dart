import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/invoice_calculator.dart';
import '../services/invoice_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/invoice_issue_view_model.dart';
import '../viewmodels/tenant_dashboard_view_model.dart' show thaiMonthName;
import 'reusable_widgets.dart';

/// เปิดกล่องตรวจก่อนออกบิล — คืน true เมื่อออกบิลสำเร็จ
///
/// กล่องเปิดทันทีแล้วโหลดร่างบิลข้างใน เหมาะกับปุ่มที่ผู้ใช้ตั้งใจกด เพราะ
/// ผลลัพธ์ทุกแบบรวมทั้ง "ไม่มีห้องที่ออกบิลได้" คือคำตอบที่เขากดมาหา
/// สำหรับตัวเรียกอัตโนมัติให้ใช้ [maybeShowIssueInvoicesDialog] แทน
Future<bool> showIssueInvoicesDialog(
  BuildContext context, {
  required int dormitoryId,
  required int month,
  required int year,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => InvoiceIssueViewModel(
        dormitoryId: dormitoryId,
        month: month,
        year: year,
      )..load(),
      child: const _IssueInvoicesDialog(),
    ),
  );
  return result ?? false;
}

/// ผลของการเสนอออกบิลอัตโนมัติ
///
/// [nothingToIssue] กับ [checkFailed] ต้องแยกกัน — อย่างแรกคือ "ไม่มีอะไรค้าง"
/// ซึ่งเงียบได้ อย่างหลังคือ "ยังไม่รู้ว่ามีอะไรค้างไหม" ซึ่งถ้าเงียบด้วย
/// เจ้าของหอจะเข้าใจว่าบิลงวดนี้จัดการครบแล้วทั้งที่ระบบยังไม่ได้ตรวจสักห้อง
enum IssuePromptOutcome { issued, dismissed, nothingToIssue, checkFailed }

/// เสนอออกบิลหลังเหตุการณ์ที่ทำให้ออกบิลได้ — เปิดกล่องเฉพาะเมื่อมีห้องให้ออก
///
/// โหลดร่างบิลก่อนแล้วค่อยตัดสินใจว่าจะเปิดกล่องไหม กลับกันกับ
/// [showIssueInvoicesDialog] · ถ้าเปิดก่อนแล้วค่อยโหลด เจ้าของหอที่แก้ค่าน้ำของ
/// งวดที่ออกบิลครบไปแล้วจะโดนกล่องเปล่าเด้งใส่ทุกครั้งที่กดบันทึก ซึ่งสอนให้เขา
/// กดปิดโดยไม่อ่าน แล้วกล่องที่มีห้องรอออกบิลจริงก็จะโดนปิดไปด้วยแบบเดียวกัน
Future<IssuePromptOutcome> maybeShowIssueInvoicesDialog(
  BuildContext context, {
  required int dormitoryId,
  required int month,
  required int year,
}) async {
  // สร้างเองแทนที่จะให้ ChangeNotifierProvider สร้าง เพราะต้องได้ผลของ load()
  // ก่อนตัดสินใจว่าจะมี widget tree ให้ provider อยู่ข้างในหรือเปล่า —
  // ความรับผิดชอบในการ dispose จึงเป็นของฟังก์ชันนี้ ไม่ใช่ของ provider
  final viewModel = InvoiceIssueViewModel(
    dormitoryId: dormitoryId,
    month: month,
    year: year,
  );

  try {
    await viewModel.load();

    if (viewModel.errorMessage != null) return IssuePromptOutcome.checkFailed;
    if (!viewModel.hasIssuableDrafts) return IssuePromptOutcome.nothingToIssue;
    if (!context.mounted) return IssuePromptOutcome.dismissed;

    final issued = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: const _IssueInvoicesDialog(),
      ),
    );

    return (issued ?? false)
        ? IssuePromptOutcome.issued
        : IssuePromptOutcome.dismissed;
  } finally {
    viewModel.dispose();
  }
}

class _IssueInvoicesDialog extends StatelessWidget {
  const _IssueInvoicesDialog();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<InvoiceIssueViewModel>();
    final preview = viewModel.preview;

    return AlertDialog(
      title: Text('ออกบิลเดือน${thaiMonthName(viewModel.month)} ${viewModel.year}'),
      content: SizedBox(
        width: 400,
        child: viewModel.isLoading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : viewModel.errorMessage != null
                ? SectionErrorNote(message: viewModel.errorMessage!)
                : _buildBody(context, preview!),
      ),
      actions: [
        TextButton(
          // ปิดกล่องต้องคืน hasIssued ไม่ใช่ false ตายตัว — เมื่อบิลออกไปแล้วแต่
          // แจ้งเตือนล้ม ผู้ใช้อาจเลือกปิดโดยไม่ลองส่งซ้ำ รายการบิลข้างหลังก็ยัง
          // ต้องรีเฟรชอยู่ดี
          onPressed: viewModel.isIssuing
              ? null
              : () => Navigator.pop(context, viewModel.hasIssued),
          child: Text(viewModel.hasIssued ? 'ปิด' : 'ยกเลิก'),
        ),
        // บิลออกไปแล้วแต่มีบางขั้นหลังจากนั้นยังไม่สำเร็จ — ปุ่มเปลี่ยนหน้าที่
        // ไปเป็นการลองซ้ำเฉพาะขั้นที่ค้าง เพราะการออกบิลไม่มีอะไรให้ทำอีกแล้ว
        // (แจ้งเตือนในแชทมาก่อน เพราะเป็นสิ่งที่ผู้เช่าเห็นได้เร็วที่สุด)
        if (viewModel.unnotified.isNotEmpty)
          PrimaryButton(
            label: 'ส่งแจ้งเตือนอีกครั้ง',
            isLoading: viewModel.isIssuing,
            onPressed: () async {
              final result = await viewModel.retryNotices();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(result.message)));
              if (result.success) Navigator.pop(context, true);
            },
          )
        else if (viewModel.extraFeesCarryForwardFailed.isNotEmpty)
          PrimaryButton(
            label: 'คัดลอกค่าใช้จ่ายเพิ่มเติมอีกครั้ง',
            isLoading: viewModel.isIssuing,
            onPressed: () async {
              final result = await viewModel.retryExtraFeesCarryForward();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(result.message)));
              if (result.success) Navigator.pop(context, true);
            },
          )
        else
          PrimaryButton(
            label: 'ออกบิล ${preview?.drafts.length ?? 0} ห้อง',
            isLoading: viewModel.isIssuing,
            onPressed: (preview?.drafts.isEmpty ?? true)
                ? null
                : () async {
                    final result = await viewModel.issue();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(result.message)));
                    if (result.success) Navigator.pop(context, true);
                  },
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, InvoicePreview preview) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'จะออกบิล ${preview.drafts.length} ห้อง · ยอดรวม ${formatBaht(preview.total)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...preview.drafts.map((draft) => _DraftRow(draft: draft)),
          if (preview.skipped.isNotEmpty) ...[
            const Divider(height: 24),
            // เดิมแสดงทุกห้องที่ข้ามเต็มๆ เสมอ ยาวจนต้องเลื่อนอ่านเหตุผลของ
            // ห้องที่ออกบิลได้ไม่เจอ — ยุบไว้เป็นค่าเริ่มต้น (initiallyExpanded
            // false) ต้องเห็นเหตุผลได้ถ้าอยากดูจริงๆ แต่ไม่บังคับดูทุกครั้ง
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text('ข้าม ${preview.skipped.length} ห้อง',
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                children: [
                  // ต้องเห็นเหตุผลทุกห้องเมื่อขยายดู ถ้าเงียบไปเจ้าของหอจะไม่รู้
                  // ว่าลืมจดมิเตอร์ จนกระทั่งผู้เช่าทักมาถามว่าทำไมไม่ได้บิล
                  ...preview.skipped.map((draft) => _SkippedRow(draft: draft)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.draft});
  final InvoiceDraft draft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(draft.roomNumber)),
          Expanded(
            child: Text(draft.tenantName,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(formatBaht(draft.total),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SkippedRow extends StatelessWidget {
  const _SkippedRow({required this.draft});
  final InvoiceDraft draft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(draft.roomNumber)),
          Expanded(
            child: Text(
              skipReasonLabel(draft.skipReason!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
