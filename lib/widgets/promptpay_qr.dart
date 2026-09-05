import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';

/// QR พร้อมเพย์จาก payload ที่สร้างไว้แล้ว
///
/// รับ payload ไม่ใช่เลขพร้อมเพย์กับจำนวนเงิน เพื่อให้ตัวสร้าง payload อยู่ที่
/// เดียวคือ `promptPayPayload` ใน services/promptpay.dart ซึ่ง PDF ก็เรียกตัว
/// เดียวกัน QR บนหน้าจอกับในเอกสารจึงเป็นอันเดียวกันเสมอ
///
/// ไม่ได้ใช้ widget `QRCodeGenerate` ที่ package export มาให้ เพราะมันสร้าง
/// payload เองจาก generateQRCode ซึ่งยัง**ไม่ได้ซ่อม checksum ที่ยาวไม่ครบ**
/// (ดู promptPayPayload) และหน้าตาเป็นกรอบสีน้ำเงินพร้อมโลโก้กับข้อความอังกฤษ
/// ตายตัวที่แทรกเข้ากับหน้าจอของแอปไม่ได้
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // พื้นขาวเสมอ ไม่อิงธีม — โมดูลสีเข้มบนพื้นสว่างคือสิ่งที่กล้องธนาคาร
            // ถูกออกแบบมาให้อ่าน สลับสีเมื่อไหร่สแกนไม่ติดทันที
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            // ระดับ M เป็นค่าที่มาตรฐาน EMVCo แนะนำสำหรับ QR ชำระเงิน — สูงกว่านี้
            // ทำให้โมดูลถี่ขึ้นโดยไม่ได้ช่วยอะไรบนหน้าจอที่ไม่มีรอยเปื้อน
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(height: 8),
        const _ComingSoonNotice(),
      ],
    );
  }
}

/// ป้ายเตือนใต้ QR ทุกจุด — ฟีเจอร์ชำระเงินผ่านแอปยังไม่เปิดใช้งานจริง (อยู่ใน
/// แผนพัฒนารอบถัดไป) QR ที่แสดงยังสแกนได้จริงตามเลขพร้อมเพย์ที่เจ้าของหอตั้งไว้
/// แต่แอปยังไม่มีระบบยืนยันการชำระอัตโนมัติ ผู้ใช้จึงต้องรู้ก่อนสแกนว่านี่ยังไม่
/// ใช่ช่องทางที่แอปติดตามผลให้เอง
class _ComingSoonNotice extends StatelessWidget {
  const _ComingSoonNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'ระบบชำระเงินจะมาเร็วๆ นี้',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
