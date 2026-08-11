import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/room_batch.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/rooms_view_model.dart';
import 'reusable_widgets.dart';

/// เปิดกล่องสร้างห้องหลายห้องพร้อมกัน · คืน true เมื่อสร้างสำเร็จ
///
/// [defaultTopFloor] มาจากจำนวนชั้นที่เจ้าของหอกรอกตอนสมัคร ใช้เป็นค่าเริ่มต้น
/// เท่านั้น — แก้ได้อิสระ เพราะหอต่อเติมชั้นใหม่ได้ และเจ้าของหออาจอยากสร้าง
/// ทีละชั้นแทนที่จะสร้างทั้งตึกรวดเดียว จำนวนชั้นตอนสมัครจึงไม่ผูกกับห้องจริง
Future<bool> showCreateRoomsDialog(
  BuildContext context, {
  required RoomsViewModel viewModel,
  int? defaultTopFloor,
}) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => _CreateRoomsDialog(
      viewModel: viewModel,
      defaultTopFloor: defaultTopFloor,
    ),
  );
  return created ?? false;
}

class _CreateRoomsDialog extends StatefulWidget {
  const _CreateRoomsDialog({required this.viewModel, this.defaultTopFloor});

  final RoomsViewModel viewModel;
  final int? defaultTopFloor;

  @override
  State<_CreateRoomsDialog> createState() => _CreateRoomsDialogState();
}

class _CreateRoomsDialogState extends State<_CreateRoomsDialog> {
  late final TextEditingController _fromFloor;
  late final TextEditingController _toFloor;
  late final TextEditingController _roomsPerFloor;
  late final TextEditingController _basePrice;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final top = widget.defaultTopFloor;
    _fromFloor = TextEditingController(text: '1');
    _toFloor = TextEditingController(
      text: (top != null && top > 0) ? '$top' : '1',
    );
    _roomsPerFloor = TextEditingController();
    _basePrice = TextEditingController();
  }

  @override
  void dispose() {
    _fromFloor.dispose();
    _toFloor.dispose();
    _roomsPerFloor.dispose();
    _basePrice.dispose();
    super.dispose();
  }

  int get _from => int.tryParse(_fromFloor.text.trim()) ?? 0;
  int get _to => int.tryParse(_toFloor.text.trim()) ?? 0;
  int get _perFloor => int.tryParse(_roomsPerFloor.text.trim()) ?? 0;

  RoomBatchPlan get _plan => widget.viewModel.previewRoomBatch(
        fromFloor: _from,
        toFloor: _to,
        roomsPerFloor: _perFloor,
      );

  Future<void> _create() async {
    if (_isSaving) return;
    final plan = _plan;

    setState(() => _isSaving = true);
    final result = await widget.viewModel.addRoomBatch(
      plan: plan,
      basePriceInput: _basePrice.text,
    );
    if (!mounted) return;

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final width = min(420.0, MediaQuery.of(context).size.width - 48);

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('สร้างห้องหลายห้อง'),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เลขห้องรันตามชั้น เช่น ชั้น 1 ได้ 101 ถึง 112',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _numberField(_fromFloor, 'ตั้งแต่ชั้น',
                        maxDigits: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numberField(_toFloor, 'ถึงชั้น', maxDigits: 2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _numberField(_roomsPerFloor, 'ห้องต่อชั้น',
                  hint: '12', maxDigits: 2),
              const SizedBox(height: 12),
              _numberField(_basePrice, 'ค่าเช่าต่อเดือน (บาท)', hint: '4500'),
              const SizedBox(height: 16),
              _buildPreview(context, plan),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        PrimaryButton(
          label: plan.hasAnythingToCreate
              ? 'สร้าง ${plan.toCreate.length} ห้อง'
              : 'สร้างห้อง',
          isLoading: _isSaving,
          onPressed: plan.hasAnythingToCreate ? _create : null,
        ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    String? hint,
    int? maxDigits,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        // จำกัดตั้งแต่ตอนพิมพ์ ดีกว่าปล่อยให้พิมพ์เกินแล้วค่อยบอกว่าเกิน —
        // แผนถูกสร้างใหม่ทุกตัวอักษร เลขชั้นที่มือลั่นเป็นสี่หลักคือการสั่งให้
        // ปั่น tuple เกือบแสนตัวก่อนที่ผู้ใช้จะทันเห็นข้อความเตือนด้วยซ้ำ
        if (maxDigits != null) LengthLimitingTextInputFormatter(maxDigits),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      // วาดใหม่ทุกตัวอักษรเพื่อให้ตัวอย่างด้านล่างตรงกับที่พิมพ์อยู่เสมอ
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPreview(BuildContext context, RoomBatchPlan plan) {
    if (plan.total == 0) {
      // บอกสาเหตุที่เจาะจงเมื่อเดาได้ — ตัวอย่างที่ว่างเปล่าโดยไม่บอกอะไรเลย
      // ทำให้ผู้ใช้คิดว่าระบบค้าง
      final reason = _perFloor > maxRoomsPerFloor
          ? 'ห้องต่อชั้นได้สูงสุด $maxRoomsPerFloor ห้อง'
          : _to > maxFloor
              ? 'ระบุชั้นได้สูงสุดชั้น $maxFloor'
              : (_from > 0 && _to > 0 && _to < _from)
                  ? 'ชั้นสุดท้ายต้องไม่น้อยกว่าชั้นเริ่มต้น'
                  : 'กรอกชั้นและจำนวนห้องต่อชั้นเพื่อดูตัวอย่าง';

      return Text(
        reason,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
      );
    }

    final preview = plan.toCreate.map((room) => room.number).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.hasAnythingToCreate
                ? 'จะสร้าง ${plan.toCreate.length} ห้อง'
                : 'ไม่มีห้องใหม่ให้สร้าง',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (plan.hasAnythingToCreate) ...[
            const SizedBox(height: 4),
            Text(
              _summarise(preview),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          // ข้ามเงียบๆ ไม่ได้ — เจ้าของหอที่กดสร้าง 84 ห้องแล้วได้ 83 ต้องรู้ว่า
          // ห้องไหนหายไปและเพราะอะไร ไม่ใช่มานั่งไล่ทีหลังว่าตกห้องไหน
          if (plan.skipped.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ข้าม ${plan.skipped.length} ห้องที่มีอยู่แล้ว: '
                    '${_summarise(plan.skipped)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                  ),
                ),
              ],
            ),
          ],
          if (_basePrice.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'ค่าเช่าห้องละ ${formatBaht(double.tryParse(_basePrice.text.trim()) ?? 0)} '
              '· แก้รายห้องได้ภายหลัง',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  /// ย่อรายการยาวให้อ่านได้ — 84 เลขห้องเรียงกันไม่มีใครอ่าน
  String _summarise(List<String> numbers) {
    if (numbers.length <= 6) return numbers.join(', ');
    final head = numbers.take(3).join(', ');
    final tail = numbers.skip(numbers.length - 2).join(', ');
    return '$head … $tail';
  }
}
