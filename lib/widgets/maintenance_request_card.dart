import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../viewmodels/maintenance_view_model.dart';
import 'reusable_widgets.dart';
import '../utils/formatters.dart';

/// การ์ดแสดงคำขอแจ้งซ่อม/ทำความสะอาดหนึ่งรายการ
///
/// ใช้ร่วมกันทั้งฝั่งเจ้าของหอ (แก้ค่าทำความสะอาดได้) และฝั่งผู้เช่า
/// ([readOnly] = true) — รับ callback แทนที่จะผูกกับ MaintenanceViewModel
/// โดยตรง เพื่อให้หน้าไหนก็เอาไปใช้ได้
class MaintenanceRequestCard extends StatelessWidget {
  const MaintenanceRequestCard({
    super.key,
    required this.request,
    required this.readOnly,
    this.onEditCleaningFee,
    this.isUpdating = false,
  });

  final MaintenanceRequest request;

  /// มุมมองผู้เช่า: ซ่อนปุ่มแก้ค่าทำความสะอาด เจ้าของหอเท่านั้นที่กำหนดได้
  final bool readOnly;

  final Future<void> Function(double fee)? onEditCleaningFee;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    BadgeVariant variant;
    switch (request.status) {
      case MaintenanceStatus.pending:
        variant = BadgeVariant.warning;
        break;
      case MaintenanceStatus.inProgress:
        variant = BadgeVariant.primary;
        break;
      case MaintenanceStatus.completed:
        variant = BadgeVariant.success;
        break;
      case MaintenanceStatus.cancelled:
        variant = BadgeVariant.destructive;
        break;
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      request.requestType == MaintenanceRequestType.repair
                          ? Icons.build_outlined
                          : Icons.cleaning_services_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        maintenanceRequestTypeLabel(request.requestType),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: maintenanceStatusLabel(request.status),
                variant: variant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(request.description,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            'แจ้งโดย ${request.tenantName} • ${_formatDate(request.requestedAt)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          ),
          if (request.completedAt != null)
            Text(
              'เสร็จสิ้นเมื่อ ${_formatDate(request.completedAt!)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          if (request.requestType == MaintenanceRequestType.cleaning &&
              (!readOnly || request.cleaningFee > 0))
            _buildCleaningFeeRow(context),
        ],
      ),
    );
  }

  Widget _buildCleaningFeeRow(BuildContext context) {
    final feeLabel = Row(
      children: [
        const Icon(Icons.attach_money, size: 16, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          request.cleaningFee > 0
              ? 'ค่าทำความสะอาด: ${formatBaht(request.cleaningFee)}'
              : 'กำหนดค่าทำความสะอาด',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        if (!readOnly) ...[
          const SizedBox(width: 4),
          const Icon(Icons.edit_outlined,
              size: 14, color: AppColors.mutedForeground),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: readOnly || onEditCleaningFee == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: feeLabel,
            )
          // ให้ splash มี ink surface ของตัวเองเหนือพื้นขาวของ PaperCard —
          // PaperCard ตัวครอบไม่มี onTap จึงยังเป็น Container ทึบที่บัง
          // Material บรรพบุรุษอยู่ เดิมเจ้าของหอกดแล้วเงียบสนิท
          : Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isUpdating ? null : () => _showEditFeeDialog(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: feeLabel,
                ),
              ),
            ),
    );
  }

  Future<void> _showEditFeeDialog(BuildContext context) async {
    final fee = await showDialog<double>(
      context: context,
      builder: (_) => _CleaningFeeDialog(initialFee: request.cleaningFee),
    );

    if (fee != null) {
      await onEditCleaningFee?.call(fee);
    }
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

/// เนื้อหา dialog เป็น StatefulWidget เพื่อให้ตัวมันเองเป็นเจ้าของ
/// TextEditingController
///
/// ห้าม dispose controller ทันทีหลัง showDialog คืนค่า: ตอนนั้น dialog
/// เพิ่งเริ่ม animate ปิด TextField ข้างในยัง rebuild อยู่ จึงเกิด
/// "A TextEditingController was used after being disposed"
/// การ dispose ใน State.dispose() จะเกิดตอน widget ถูกถอดออกจริง
/// ซึ่งคือหลัง animation จบแล้ว
class _CleaningFeeDialog extends StatefulWidget {
  const _CleaningFeeDialog({required this.initialFee});

  final double initialFee;

  @override
  State<_CleaningFeeDialog> createState() => _CleaningFeeDialogState();
}

class _CleaningFeeDialogState extends State<_CleaningFeeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // ค่าตั้งต้นต้องไม่มีตัวคั่นหลักพัน ไม่งั้น double.tryParse จะพัง
    _controller = TextEditingController(
      text: widget.initialFee > 0 ? widget.initialFee.toStringAsFixed(0) : '',
    );
  }

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
      title: const Text('ค่าทำความสะอาด'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          prefixText: '฿ ',
          hintText: '0',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            final parsed = double.tryParse(_controller.text.trim()) ?? 0;
            Navigator.of(context).pop(parsed);
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
