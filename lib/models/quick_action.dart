/// สิ่งที่ทางลัดหนึ่งปุ่มต้องบอกได้ ไม่ว่าจะอยู่บนแดชบอร์ดฝั่งไหน
///
/// มีอยู่เพื่อให้ที่เก็บ ตัวจัดการลำดับ และแผ่นจัดการทางลัด ทำงานกับทางลัดของ
/// ทั้งสองบทบาทได้โดยไม่ต้องมีคนละชุด · ถ้าคัดลอกไปอีกชุด บั๊กที่แก้ฝั่งหนึ่ง
/// ต้องจำไปแก้อีกฝั่งตลอดไป ซึ่งเป็นสิ่งที่ไม่มีใครจำได้จริง
/// สืบทอด [Enum] เพื่อให้ `.name` ใช้ได้กับทางลัดทุกตัว — ค่านั้นคือสิ่งที่ถูก
/// เขียนลงดิสก์ · ประกาศ `String get name` ไว้ในนี้ตรงๆ ไม่ได้ เพราะ `.name`
/// ของ enum มาจาก extension `EnumName` ไม่ใช่ getter ของตัวคลาส จึงไม่นับว่า
/// implement ให้
abstract interface class QuickActionSpec implements Enum {
  /// ชื่อที่แสดงใต้ไอคอน
  String get label;

  /// คำอธิบายในหน้าจัดการ — บอกว่ากดแล้วเกิดอะไร ไม่ใช่แค่ทวนชื่อ
  String get description;
}

/// ทางลัดทั้งหมดของบทบาทหนึ่ง พร้อมที่อยู่ของมันบนดิสก์
///
/// รวมสามอย่างที่ต้องเปลี่ยนพร้อมกันเสมอไว้ในก้อนเดียว — รายการทั้งหมด
/// ค่าตั้งต้น และคีย์ที่ใช้เก็บ · แยกกันเมื่อไหร่จะมีวันที่ค่าตั้งต้นของฝั่งหนึ่ง
/// ถูกบันทึกลงคีย์ของอีกฝั่ง
class QuickActionCatalog<T extends QuickActionSpec> {
  const QuickActionCatalog({
    required this.storageKeyPrefix,
    required this.values,
    required this.defaults,
  });

  /// ส่วนหน้าของคีย์ใน SharedPreferences · ต่อท้ายด้วย userId อีกที
  final String storageKeyPrefix;

  final List<T> values;
  final List<T> defaults;
}

/// ทางลัดหนึ่งปุ่มบนแดชบอร์ดผู้เช่า
///
/// ทุกแท็บใน bottom navigation เข้าถึงได้ในแตะเดียวอยู่แล้ว การ์ดทางลัดจึงมีค่า
/// ที่สุดกับสิ่งที่ **ทำอะไรบางอย่างทันที** — เปิดกล่องแจ้งซ่อม เปิดแผ่นชำระเงิน
/// — มากกว่าการพาไปหน้าที่อยู่ใต้นิ้วอยู่แล้ว ค่าเริ่มต้นจึงเป็นการกระทำล้วน
/// ส่วนทางลัดที่ซ้ำกับแท็บยังเลือกเปิดได้ถ้าผู้เช่าอยากได้จริง
enum QuickAction implements QuickActionSpec {
  reportRepair,
  requestCleaning,
  payLatestBill,
  saveLatestBillPdf,
  openBills,
  openMaintenance,
  openChat,
  openProfile;

  /// ชื่อที่แสดงใต้ไอคอน — สั้นพอให้ไม่ตัดบรรทัดบนจอ 360dp
  @override
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
  @override
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

/// ทางลัดทั้งชุดของฝั่งผู้เช่า
///
/// `storageKeyPrefix` เป็นคีย์เดิมตั้งแต่ก่อนมีทางลัดฝั่งเจ้าของหอ **ห้ามเปลี่ยน**
/// — มันถูกใช้อยู่บนเครื่องจริง การเปลี่ยนคีย์เท่ากับล้างการจัดปุ่มของผู้เช่า
/// ทุกคนทิ้งโดยไม่มีอะไรบอก และหน้าตาที่ได้คือ "แอปรีเซ็ตทางลัดของฉันเอง"
const tenantQuickActions = QuickActionCatalog<QuickAction>(
  storageKeyPrefix: 'quick_actions',
  values: QuickAction.values,
  defaults: defaultQuickActions,
);

/// จำนวนสูงสุดที่วางได้ — เกินกว่านี้ปุ่มจะแคบจนป้ายอ่านไม่ออกบนจอ 360dp
const maxQuickActions = 8;
