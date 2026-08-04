/// การเปลี่ยนสถานะบิลที่อนุญาต — Dart ล้วน ไม่ import supabase หรือ flutter
///
/// แยกจาก invoice_calculator เพราะเป็นคนละคำถาม ตัวหนึ่งตอบว่าบิลควรมียอด
/// เท่าไร อีกตัวตอบว่าบิลเดินไปทางไหนได้ InvoiceService เรียกตรวจก่อนทุกครั้ง
/// ที่จะ UPDATE เป็นด่านคู่กับที่ฐานข้อมูลบังคับไว้
library;

import '../models/models.dart';

bool canTransition(InvoiceStatus from, InvoiceStatus to) {
  if (from == to) return false;
  // ยกเลิกแล้วคือจบ ต่อให้อนุมัติผิดก็ต้องออกใบใหม่ ไม่ใช่ปลุกใบเดิม
  if (from == InvoiceStatus.voided) return false;
  if (to == InvoiceStatus.voided) return true;

  switch (from) {
    case InvoiceStatus.unpaid:
      return to == InvoiceStatus.pending;
    case InvoiceStatus.pending:
      return to == InvoiceStatus.paid || to == InvoiceStatus.unpaid;
    case InvoiceStatus.paid:
      return false;
    case InvoiceStatus.voided:
      return false;
  }
}
