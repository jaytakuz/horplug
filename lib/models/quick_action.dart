/// ทางลัดหนึ่งปุ่มบนแดชบอร์ดผู้เช่า
///
/// ทุกแท็บใน bottom navigation เข้าถึงได้ในแตะเดียวอยู่แล้ว การ์ดทางลัดจึงมีค่า
/// ที่สุดกับสิ่งที่ **ทำอะไรบางอย่างทันที** — เปิดกล่องแจ้งซ่อม เปิดแผ่นชำระเงิน
/// — มากกว่าการพาไปหน้าที่อยู่ใต้นิ้วอยู่แล้ว ค่าเริ่มต้นจึงเป็นการกระทำล้วน
/// ส่วนทางลัดที่ซ้ำกับแท็บยังเลือกเปิดได้ถ้าผู้เช่าอยากได้จริง
enum QuickAction {
  reportRepair,
  requestCleaning,
  payLatestBill,
  saveLatestBillPdf,
  openBills,
  openMaintenance,
  openChat,
  openProfile;

  /// ชื่อที่แสดงใต้ไอคอน — สั้นพอให้ไม่ตัดบรรทัดบนจอ 360dp
  String get label => switch (this) {
        QuickAction.reportRepair => 'แจ้งซ่อม',
        QuickAction.requestCleaning => 'ทำความสะอาด',
        QuickAction.payLatestBill => 'ชำระบิล',
        QuickAction.saveLatestBillPdf => 'บันทึกบิล',
        QuickAction.openBills => 'ดูบิล',
        QuickAction.openMaintenance => 'ประวัติซ่อม',
        QuickAction.openChat => 'แชท',
        QuickAction.openProfile => 'โปรไฟล์',
      };

  /// คำอธิบายในหน้าจัดการ — บอกว่ากดแล้วเกิดอะไร ไม่ใช่แค่ทวนชื่อ
  String get description => switch (this) {
        QuickAction.reportRepair => 'เปิดกล่องแจ้งซ่อมทันที',
        QuickAction.requestCleaning => 'เปิดกล่องแจ้งทำความสะอาดทันที',
        QuickAction.payLatestBill => 'เปิดแผ่นชำระเงินของบิลที่ค้างอยู่',
        QuickAction.saveLatestBillPdf => 'บันทึกบิลล่าสุดเป็นไฟล์ PDF',
        QuickAction.openBills => 'ไปแท็บบิล',
        QuickAction.openMaintenance => 'ไปแท็บแจ้งซ่อม',
        QuickAction.openChat => 'ไปแท็บแชท',
        QuickAction.openProfile => 'ไปแท็บโปรไฟล์',
      };

  /// true เมื่อทางลัดนี้ทำงานได้เฉพาะตอนมีบิลที่เกี่ยวข้อง
  ///
  /// ปุ่มยังแสดงอยู่แต่กดไม่ได้ ดีกว่าหายไปมาโผล่มาเอง ซึ่งทำให้ตำแหน่งปุ่ม
  /// ที่ผู้เช่าจำไว้ขยับทุกครั้งที่สถานะบิลเปลี่ยน
  bool get needsBill =>
      this == QuickAction.payLatestBill ||
      this == QuickAction.saveLatestBillPdf;
}

/// ทางลัดที่แสดงเมื่อผู้เช่ายังไม่เคยจัดเอง
///
/// สี่อันพอดีกับหนึ่งแถวบนจอแคบ และเป็นการกระทำล้วน — ไม่มีอันไหนซ้ำกับแท็บ
/// ด้านล่างซึ่งกดถึงอยู่แล้ว
const defaultQuickActions = <QuickAction>[
  QuickAction.reportRepair,
  QuickAction.requestCleaning,
  QuickAction.payLatestBill,
  QuickAction.saveLatestBillPdf,
];

/// จำนวนสูงสุดที่วางได้ — เกินกว่านี้ปุ่มจะแคบจนป้ายอ่านไม่ออกบนจอ 360dp
const maxQuickActions = 8;
