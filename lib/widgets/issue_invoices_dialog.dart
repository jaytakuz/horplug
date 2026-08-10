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
          onPressed: viewModel.isIssuing ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
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
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Text('ข้าม ${preview.skipped.length} ห้อง',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            // ต้องเห็นเหตุผลทุกห้อง ถ้าเงียบไปเจ้าของหอจะไม่รู้ว่าลืมจดมิเตอร์
            // จนกระทั่งผู้เช่าทักมาถามว่าทำไมไม่ได้บิล
            ...preview.skipped.map((draft) => _SkippedRow(draft: draft)),
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
