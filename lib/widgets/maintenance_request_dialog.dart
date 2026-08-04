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
  final isCleaning = type == MaintenanceRequestType.cleaning;
  final controller = TextEditingController();

  try {
    final description = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isCleaning ? 'ขอทำความสะอาด' : 'แจ้งซ่อม'),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ยกเลิก'),
          ),
          // ปิดปุ่มไว้จนกว่าจะพิมพ์ — เดิมกด "ส่ง" ตอนช่องว่างแล้ว dialog ปิด
          // เงียบๆ เหมือนกดยกเลิก ผู้ใช้แยกไม่ออกว่าส่งไปแล้วหรือระบบพัง
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => ElevatedButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('ส่ง'),
            ),
          ),
        ],
      ),
    );

    if (description == null || description.trim().isEmpty) return null;
    return description;
  } finally {
    controller.dispose();
  }
}
