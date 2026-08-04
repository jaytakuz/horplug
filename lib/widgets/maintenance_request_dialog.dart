import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// ให้ผู้เช่ากรอกรายละเอียดคำขอแจ้งซ่อม/ทำความสะอาด
///
/// คืนค่าเป็นข้อความที่กรอก หรือ null เมื่อยกเลิก / กรอกว่าง
/// ใช้ร่วมกันระหว่างหน้าแชทกับแท็บแจ้งซ่อม เพื่อให้ถ้อยคำและรูปแบบตรงกัน
Future<String?> showMaintenanceRequestDialog(
  BuildContext context,
  MaintenanceRequestType type,
) async {
  final description = await showDialog<String>(
    context: context,
    builder: (_) => _MaintenanceRequestDialog(type: type),
  );

  if (description == null || description.trim().isEmpty) return null;
  return description;
}

/// เนื้อหา dialog เป็น StatefulWidget เพื่อให้ตัวมันเองเป็นเจ้าของ
/// TextEditingController
///
/// ห้าม dispose controller ทันทีหลัง showDialog คืนค่า: ตอนนั้น dialog
/// เพิ่งเริ่ม animate ปิด widget ข้างในยัง rebuild อยู่ และ
/// ValueListenableBuilder ยัง addListener กับ controller ทำให้เกิด
/// "A TextEditingController was used after being disposed"
/// การ dispose ใน State.dispose() จะเกิดขึ้นตอน widget ถูกถอดออกจริง
/// ซึ่งคือหลัง animation จบแล้ว
class _MaintenanceRequestDialog extends StatefulWidget {
  const _MaintenanceRequestDialog({required this.type});

  final MaintenanceRequestType type;

  @override
  State<_MaintenanceRequestDialog> createState() =>
      _MaintenanceRequestDialogState();
}

class _MaintenanceRequestDialogState extends State<_MaintenanceRequestDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCleaning = widget.type == MaintenanceRequestType.cleaning;

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(isCleaning ? 'ขอทำความสะอาด' : 'แจ้งซ่อม'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: isCleaning
              ? 'อธิบายรายละเอียดที่ต้องการให้ทำความสะอาด'
              : 'อธิบายปัญหาที่ต้องการแจ้งซ่อม',
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        // ปิดปุ่มไว้จนกว่าจะพิมพ์ — เดิมกด "ส่ง" ตอนช่องว่างแล้ว dialog ปิด
        // เงียบๆ เหมือนกดยกเลิก ผู้ใช้แยกไม่ออกว่าส่งไปแล้วหรือระบบพัง
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, value, __) => ElevatedButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text),
            child: const Text('ส่ง'),
          ),
        ),
      ],
    );
  }
}
