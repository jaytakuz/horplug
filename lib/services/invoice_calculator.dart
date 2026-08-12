/// ตรรกะการประกอบร่างบิล — Dart ล้วน ไม่ import supabase หรือ flutter
///
/// เดิมตรรกะนี้ฝังอยู่กลาง SupabaseService.fetchInvoices ซึ่งเปิดด้วยการเรียก
/// เครือข่าย จึงเขียน unit test ไม่ได้เลย ทั้งที่เป็นส่วนที่เกี่ยวกับเงิน
library;

import '../models/models.dart';

/// ประกอบร่างบิลของห้องหนึ่งในงวดหนึ่ง
///
/// [alreadyIssued] ให้ผู้เรียกเป็นคนบอก ฟังก์ชันนี้จึงไม่ต้องแตะฐานข้อมูล
/// ลำดับการตัดสินเหตุผลที่ข้าม: ไม่มีผู้เช่า → ออกบิลไปแล้ว → ยังไม่จดมิเตอร์ไฟ
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
  } else if (electricity == null) {
    // เลขมิเตอร์ไฟเป็นเงื่อนไขบังคับ ไม่ใช่หนึ่งในสามอย่างที่มีอย่างใดก็พอ
    //
    // เกณฑ์เดิมข้ามห้องก็ต่อเมื่อขาดครบทั้งไฟ น้ำ และค่าทำความสะอาด ห้องที่มีงาน
    // ทำความสะอาดในงวดนั้นจึงได้บิลที่มีค่าไฟ ฿0 ทั้งที่ยังไม่มีใครอ่านมิเตอร์
    // เลย และเพราะบิลตรึงตัวเลข ณ วันออก การแก้ทีหลังต้องยกเลิกใบนั้นแล้วออกใหม่
    // ระหว่างนั้นผู้เช่าถือ QR ระบุยอดที่ยอดผิดอยู่ในมือแล้ว
    //
    // ค่าไฟเป็นก้อนที่ผันแปรที่สุดในบิล บิลที่ออกโดยยังไม่รู้ค่าไฟจึงไม่ใช่บิลที่
    // ยังไม่ครบ แต่เป็นบิลที่ยอดผิดแน่นอน ส่วนค่าน้ำที่ยังไม่กรอกยังคิดเป็น 0
    // ตามเดิม เพราะบางงวดหอไม่ได้เก็บค่าน้ำจริงๆ
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

/// สิ่งที่ต้องแก้ในบิลใบหนึ่ง เมื่อเทียบกับข้อมูลล่าสุดของงวด
class InvoiceAdjustment {
  const InvoiceAdjustment({
    required this.invoice,
    required this.roomPrice,
    required this.electricityUnits,
    required this.electricityCost,
    required this.waterCost,
    required this.cleaningFee,
  });

  /// ใบเดิม — เลขที่บิลและ revision ติดมากับมัน เพราะนี่คือการแก้ยอดของใบนี้
  /// ไม่ใช่การออกใบแทน
  final Invoice invoice;

  final double roomPrice;
  final double electricityUnits;
  final double electricityCost;
  final double waterCost;
  final double cleaningFee;

  double get previousTotal => invoice.total;

  /// สูตรเดียวกับ GENERATED column `invoices.total` — ที่นี่คำนวณไว้เพื่อบอก
  /// ผู้เช่าว่ายอดจะเปลี่ยนเป็นเท่าไร ส่วนตัวเลขที่นับเป็นทางการยังเป็นของ
  /// ฐานข้อมูล ซึ่งไม่มีทางไม่ตรงกับผลบวกของรายการ
  double get newTotal => roomPrice + electricityCost + waterCost + cleaningFee;
}

/// เทียบบิลใบหนึ่งกับข้อมูลล่าสุดของงวด · null = ไม่ต้องแตะใบนี้
///
/// บิลตรึงตัวเลข ณ วันออกมาตั้งแต่ spec แรก ซึ่งถูกสำหรับใบที่ผู้เช่าจ่ายไปแล้ว
/// แต่แปลว่าเลขมิเตอร์ที่พิมพ์ผิดหลักเดียวต้องแก้ด้วยการยกเลิกใบเดิมแล้วออกใหม่
/// ซึ่งกินเลขที่บิลและทิ้งการ์ดยอดผิดไว้ในแชทของผู้เช่า · ที่นี่จึงคำนวณใหม่
/// เฉพาะใบที่ยังไม่มีใครจ่าย โดยคงเลขที่บิลและ revision ไว้ตามเดิม
InvoiceAdjustment? revalueInvoice({
  required Invoice invoice,
  required Room room,
  MeterCharge? electricity,
  double? waterAmount,
  required double cleaningFee,
}) {
  // ใบที่ส่งสลิป/จ่าย/ยกเลิกแล้วตรึงตลอดไป — ผู้เช่าจ่ายตามยอดที่เห็น
  // การขยับยอดทีหลังทำให้สลิปกับบิลไม่ตรงกันโดยไม่มีใครผิด
  if (invoice.status != InvoiceStatus.unpaid) return null;

  // บิลที่ออกไปแล้วแปลว่าเคยมีเลขมิเตอร์ การที่มันหายคือข้อมูลถูกลบ ไม่ใช่
  // ผู้เช่าใช้ไฟน้อยลง · กันการลบพลาดกลายเป็นส่วนลดเงียบๆ
  if (electricity == null) return null;

  final adjustment = InvoiceAdjustment(
    invoice: invoice,
    roomPrice: room.price,
    electricityUnits: electricity.units,
    electricityCost: electricity.amount,
    // "ยังไม่กรอกค่าน้ำ" กับ "กรอกว่าไม่เก็บค่าน้ำ" คนละความหมาย อย่างแรกต้อง
    // คงยอดเดิมของบิลไว้ อย่างหลังคือ 0 ที่ตั้งใจ
    waterCost: waterAmount ?? invoice.waterCost,
    cleaningFee: cleaningFee,
  );

  return _isUnchanged(adjustment) ? null : adjustment;
}

/// เศษที่ต่างกันจากการปัดเลขทศนิยมไม่ใช่การเปลี่ยนยอด
///
/// การเขียนซ้ำโดยไม่มีอะไรเปลี่ยนแปลว่าผู้เช่าได้ข้อความในแชททุกครั้งที่
/// เจ้าของหอกดบันทึกมิเตอร์ ซึ่งเป็นการแจ้งเตือนที่สอนให้คนเลิกอ่าน
bool _isUnchanged(InvoiceAdjustment a) {
  const epsilon = 0.005;
  final invoice = a.invoice;

  return (a.roomPrice - invoice.roomPrice).abs() < epsilon &&
      (a.electricityUnits - invoice.electricityUnits).abs() < epsilon &&
      (a.electricityCost - invoice.electricityCost).abs() < epsilon &&
      (a.waterCost - invoice.waterCost).abs() < epsilon &&
      (a.cleaningFee - invoice.cleaningFee).abs() < epsilon;
}

/// ข้อความที่แสดงในรายการ "ข้าม N ห้อง" ของกล่องตรวจก่อนออกบิล
String skipReasonLabel(SkipReason reason) {
  switch (reason) {
    case SkipReason.noTenant:
      return 'ห้องว่าง ไม่มีผู้เช่า';
    case SkipReason.noMeterReading:
      return 'ยังไม่จดมิเตอร์ไฟ';
    case SkipReason.alreadyIssued:
      return 'ออกบิลงวดนี้ไปแล้ว';
  }
}
