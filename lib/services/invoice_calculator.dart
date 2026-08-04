/// ตรรกะการประกอบร่างบิล — Dart ล้วน ไม่ import supabase หรือ flutter
///
/// เดิมตรรกะนี้ฝังอยู่กลาง SupabaseService.fetchInvoices ซึ่งเปิดด้วยการเรียก
/// เครือข่าย จึงเขียน unit test ไม่ได้เลย ทั้งที่เป็นส่วนที่เกี่ยวกับเงิน
library;

import '../models/models.dart';

/// ประกอบร่างบิลของห้องหนึ่งในงวดหนึ่ง
///
/// [alreadyIssued] ให้ผู้เรียกเป็นคนบอก ฟังก์ชันนี้จึงไม่ต้องแตะฐานข้อมูล
/// ลำดับการตัดสินเหตุผลที่ข้าม: ไม่มีผู้เช่า → ออกบิลไปแล้ว → ไม่มีข้อมูลคิดเงิน
InvoiceDraft buildDraft({
  required Room room,
  required int billingMonth,
  required int billingYear,
  MeterCharge? electricity,
  double? waterAmount,
  double cleaningFee = 0,
  bool alreadyIssued = false,
}) {
  final electricityCost = electricity?.amount ?? 0;
  final waterCost = waterAmount ?? 0;

  SkipReason? skipReason;
  if (room.currentTenantId == null) {
    // ห้องภายใต้การซ่อมยังมีผู้เช่าและยังต้องออกบิล — เฉพาะห้องที่ไม่มีคนอยู่
    // เท่านั้นที่ข้าม เงื่อนไขเดิมใน fetchInvoices ก็ใช้เกณฑ์นี้
    skipReason = SkipReason.noTenant;
  } else if (alreadyIssued) {
    skipReason = SkipReason.alreadyIssued;
  } else if (electricity == null && waterAmount == null && cleaningFee <= 0) {
    skipReason = SkipReason.noMeterReading;
  }

  return InvoiceDraft(
    roomDbId: room.dbId,
    roomNumber: room.id,
    tenantId: room.currentTenantId,
    tenantName: room.tenantName ?? '-',
    billingMonth: billingMonth,
    billingYear: billingYear,
    roomPrice: room.price,
    electricityUnits: electricity?.units ?? 0,
    electricityCost: electricityCost,
    waterCost: waterCost,
    cleaningFee: cleaningFee,
    skipReason: skipReason,
  );
}

/// ครบกำหนดชำระวันที่ 5 ของเดือนถัดจากงวด
///
/// DateTime รับ month = 13 แล้วขึ้นปีใหม่ให้เอง งวดธันวาคมจึงได้ 5 มกราคม
/// ปีถัดไปโดยไม่ต้องเขียนเงื่อนไขแยก
DateTime dueDateFor(int year, int month) => DateTime(year, month + 1, 5);

/// เลขที่บิล — `INV-{YYYYMM}-{เลขห้อง}` และต่อท้าย `-R{n}` เมื่อเป็นใบที่ออกใหม่
String invoiceNoFor({
  required int year,
  required int month,
  required String roomNumber,
  int revision = 1,
}) {
  final period = '$year${month.toString().padLeft(2, '0')}';
  final base = 'INV-$period-$roomNumber';
  return revision > 1 ? '$base-R$revision' : base;
}

/// ข้อความที่แสดงในรายการ "ข้าม N ห้อง" ของกล่องตรวจก่อนออกบิล
String skipReasonLabel(SkipReason reason) {
  switch (reason) {
    case SkipReason.noTenant:
      return 'ห้องว่าง ไม่มีผู้เช่า';
    case SkipReason.noMeterReading:
      return 'ยังไม่จดมิเตอร์';
    case SkipReason.alreadyIssued:
      return 'ออกบิลงวดนี้ไปแล้ว';
  }
}
