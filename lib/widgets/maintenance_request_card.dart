import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../viewmodels/action_result.dart';
import '../viewmodels/maintenance_view_model.dart';
import 'reusable_widgets.dart';

/// การ์ดแสดงคำขอแจ้งซ่อม/ทำความสะอาดหนึ่งรายการ
///
/// ใช้ร่วมกันทั้งฝั่งเจ้าของหอและฝั่งผู้เช่า ([readOnly] = true) — รับ
/// callback แทนที่จะผูกกับ MaintenanceViewModel โดยตรง เพื่อให้หน้าไหนก็
/// เอาไปใช้ได้
class MaintenanceRequestCard extends StatelessWidget {
  const MaintenanceRequestCard({
    super.key,
    required this.request,
    required this.readOnly,
    this.onUpdateStatus,
    this.isUpdating = false,
  });

  final MaintenanceRequest request;

  /// มุมมองผู้เช่า: ซ่อนการแตะเปลี่ยนสถานะ เจ้าของหอเท่านั้นที่ทำได้
  final bool readOnly;

  /// เจ้าของหอเท่านั้น: แตะที่การ์ดเพื่อเปลี่ยนสถานะคำขอ
  final Future<ActionResult> Function(MaintenanceStatus status)?
      onUpdateStatus;
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

    final canUpdateStatus = !readOnly && onUpdateStatus != null;

    final content = Column(
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
        if (canUpdateStatus) ...[
          const SizedBox(height: 4),
          Text('แตะเพื่ออัปเดตสถานะ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 10,
                  )),
        ],
      ],
    );

    if (!canUpdateStatus) {
      return PaperCard(child: content);
    }

    // เหตุผลเดียวกับปุ่มแก้ค่าทำความสะอาด — ต้องมี Material ผิวโปร่งใสของ
    // ตัวเอง ไม่งั้น ripple ของ InkWell จะโดน Container ทึบของ PaperCard บัง
    return PaperCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isUpdating ? null : () => _handleUpdateStatus(context),
          child: Padding(padding: const EdgeInsets.all(16), child: content),
        ),
      ),
    );
  }

  Future<void> _handleUpdateStatus(BuildContext context) async {
    final onUpdateStatus = this.onUpdateStatus;
    if (onUpdateStatus == null) return;

    final status = await showModalBottomSheet<MaintenanceStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        // Material จริง (ไม่ใช่แค่ Container ที่มีสี) ให้ ListTile ด้านใน มี
        // พื้นผิวทึบให้ ink splash วาดทับได้ — ตัว showModalBottomSheet เอง
        // ตั้ง backgroundColor เป็นโปร่งใสไว้แล้ว (เพื่อให้เห็นมุมโค้ง) ทำให้
        // Material ที่ห่อ sheet ไว้ตามปกติโปร่งใสไปด้วย ถ้าใช้ Container
        // เฉยๆ ตรงนี้ ripple ของปุ่มจะไม่โชว์และ Flutter จะแจ้ง exception
        // "ListTile background color or ink splashes may be invisible"
        child: Material(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('เปลี่ยนสถานะแจ้งซ่อม',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.pending_outlined,
                    color: AppColors.warning),
                title: const Text('รอดำเนินการ'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(MaintenanceStatus.pending),
              ),
              ListTile(
                leading:
                    const Icon(Icons.build_outlined, color: AppColors.primary),
                title: const Text('กำลังดำเนินการ'),
                onTap: () => Navigator.of(sheetContext)
                    .pop(MaintenanceStatus.inProgress),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: AppColors.success),
                title: const Text('เสร็จสิ้น'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(MaintenanceStatus.completed),
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined,
                    color: AppColors.destructive),
                title: const Text('ยกเลิก'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(MaintenanceStatus.cancelled),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (status == null) return;

    final result = await onUpdateStatus(status);
    if (!context.mounted || result.success) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
