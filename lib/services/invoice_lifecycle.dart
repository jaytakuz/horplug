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
      // ตรงไป paid ได้ด้วย — เจ้าของหอบันทึกเองว่าได้รับเงินแล้ว โดยไม่ต้องรอ
      // ให้ผู้เช่ากดแจ้งก่อน · เงินที่จ่ายกันนอกแอป (ยื่นเงินสดหน้าห้อง โอนแล้ว
      // ทักบอกในไลน์) เกิดขึ้นจริงและบ่อย ถ้าบังคับให้ผ่าน pending เสมอ ทางเดียว
      // ที่เหลือคือให้เจ้าของหอไปกดแทนผู้เช่า ซึ่งทำไม่ได้ หรือปล่อยบิลค้างทั้งที่
      // เก็บเงินครบแล้ว — สถานะในระบบจะเพี้ยนจากความจริงโดยที่ไม่มีใครแก้ได้
      return to == InvoiceStatus.pending || to == InvoiceStatus.paid;
    case InvoiceStatus.pending:
      return to == InvoiceStatus.paid || to == InvoiceStatus.unpaid;
    case InvoiceStatus.paid:
      return false;
    case InvoiceStatus.voided:
      return false;
  }
}
