import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quick_action.dart';
import '../theme/app_theme.dart';
import '../viewmodels/quick_actions_view_model.dart';

/// เปิดแผ่นจัดการทางลัด
///
/// รับ ViewModel ตัวเดิมจากแดชบอร์ดผ่าน [ChangeNotifierProvider.value] แทนการ
/// สร้างใหม่ การ์ดข้างหลังจึงขยับตามทันทีที่ลาก ไม่ต้องรอปิดแผ่นก่อน
Future<void> showQuickActionsEditor(
  BuildContext context, {
  required QuickActionsViewModel viewModel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: const _QuickActionsEditor(),
    ),
  );
}

class _QuickActionsEditor extends StatelessWidget {
  const _QuickActionsEditor();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<QuickActionsViewModel>();

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        // ครึ่งจอกำลังดี — เห็นรายการพอสมควรโดยยังเห็นการ์ดที่กำลังแก้อยู่ข้างหลัง
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('จัดการทางลัด',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: viewModel.resetToDefault,
                  child: const Text('คืนค่าเริ่มต้น'),
                ),
              ],
            ),
            Text(
              'ลากเพื่อสลับตำแหน่ง · แตะเครื่องหมายลบเพื่อเอาออก',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildSelected(context, viewModel),
                  if (viewModel.available.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('เพิ่มทางลัด',
                        style: Theme.of(context).textTheme.titleSmall),
                    if (!viewModel.canAddMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'วางได้สูงสุด $maxQuickActions ปุ่ม '
                          'เอาบางปุ่มออกก่อนถึงจะเพิ่มได้',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.warning,
                              ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ...viewModel.available.map(
                      (action) => _AvailableRow(action: action),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelected(
    BuildContext context,
    QuickActionsViewModel viewModel,
  ) {
    if (viewModel.actions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'ยังไม่ได้เลือกทางลัดไว้ — การ์ดทางลัดจะไม่แสดงบนหน้าหลัก',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
        ),
      );
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // onReorderItem ไม่ใช่ onReorder — ตัวใหม่ปรับ newIndex ให้เรียบร้อยแล้ว
      // ตัวเก่ารายงานตำแหน่งแบบก่อนถอดของที่ลากออก ผู้เรียกจึงต้องลบหนึ่งเองตอน
      // ลากลง ซึ่งเป็นที่มาของบั๊ก "วางเลยไปหนึ่งช่อง" คลาสสิก
      onReorderItem: viewModel.reorder,
      children: [
        for (final action in viewModel.actions)
          ListTile(
            // ทุกตัวใน ReorderableListView ต้องมี key ที่ต่างกันและคงที่
            key: ValueKey(action),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.drag_handle,
                color: AppColors.mutedForeground),
            title: Text(action.label),
            subtitle: Text(action.description,
                style: Theme.of(context).textTheme.bodySmall),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppColors.destructive),
              tooltip: 'เอา${action.label}ออก',
              onPressed: () => viewModel.remove(action),
            ),
          ),
      ],
    );
  }
}

class _AvailableRow extends StatelessWidget {
  const _AvailableRow({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<QuickActionsViewModel>();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(action.label),
      subtitle: Text(action.description,
          style: Theme.of(context).textTheme.bodySmall),
      trailing: IconButton(
        icon: Icon(
          Icons.add_circle_outline,
          color: viewModel.canAddMore
              ? AppColors.primary
              : AppColors.mutedForeground,
        ),
        tooltip: 'เพิ่ม${action.label}',
        onPressed: viewModel.canAddMore ? () => viewModel.add(action) : null,
      ),
    );
  }
}
