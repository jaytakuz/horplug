import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// เดิมวาด QR พร้อมเพย์จริงจาก payload — ตอนนี้แสดงกล่องบอก "เร็วๆ นี้" แทน
///
/// ฟีเจอร์ชำระเงินผ่านแอปยังไม่เปิดใช้งาน (อยู่ในแผนพัฒนารอบถัดไป) เคยลองแค่
/// เปลี่ยนข้อมูลที่เข้ารหัสลง QR เป็นสตริงเฉื่อยมาก่อน แต่ภาพที่ได้ยังหน้าตา
/// เหมือน QR ใช้งานได้จริงทุกประการ ผู้ใช้จึงสับสนว่าทำไมสแกนแล้วไม่มีอะไร
/// เกิดขึ้น เปลี่ยนมาไม่วาดลาย QR เลยเพื่อไม่ให้ใครเข้าใจผิดว่าใช้จ่ายได้แล้ว
///
/// รับ [payload] ไว้เหมือนเดิมเพราะผู้เรียกทุกจุด (แผ่นตั้งค่าช่องทางรับเงิน,
/// การ์ดบิลของผู้เช่า, การ์ดบิลในแชท, PDF) ใช้ผลลัพธ์ที่ไม่เป็น null ของ
/// `promptPayPayload` (services/promptpay.dart) ตัดสินอยู่แล้วว่าควรมีบล็อกนี้
/// หรือไม่ — ตัวสร้าง payload เองไม่ถูกแตะเลย ยังคำนวณถูกต้องครบตามเดิม (มี
/// เทสต์คุมอยู่แล้ว) เพื่อให้ตอนเปิดใช้งานฟีเจอร์ชำระเงินจริง แค่เปลี่ยน build()
/// ของไฟล์นี้กลับไปวาด QrImageView(data: payload, ...) ไม่ต้องแก้ตัวสร้างหรือ
/// จุดเรียกทั้งสี่จุดเลย
class PromptPayQr extends StatelessWidget {
  const PromptPayQr({
    super.key,
    required this.payload,
    this.size = 200,
  });

  final String payload;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_rounded,
                size: size * 0.32, color: AppColors.mutedForeground),
            const SizedBox(height: 10),
            Text(
              'ระบบชำระเงิน\nจะมาเร็วๆ นี้',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
