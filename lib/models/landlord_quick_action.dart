import 'quick_action.dart';

/// ทางลัดหนึ่งปุ่มบนแดชบอร์ดเจ้าของหอ
///
/// ต่างจากฝั่งผู้เช่าตรงที่งานของเจ้าของหอส่วนใหญ่**อยู่คนละหน้า** ไม่ใช่การ
/// กระทำที่ทำจบได้ในกล่องเดียว ทางลัดที่นี่จึงเป็นการนำทางเป็นหลัก และตัวที่มี
/// ค่าที่สุดคือหน้าที่ bottom navigation ไปไม่ถึง — ตั้งค่าช่องทางชำระเงินกับ
/// สัญญาเช่า ซึ่งวันนี้ต้องเข้าผ่านหน้าอื่นก่อนทุกครั้ง
enum LandlordQuickAction implements QuickActionSpec {
  recordMeter,
  issueInvoice,
  reviewSlips,
  manageRooms,
  lease,
  chat,
  paymentChannel;

  @override
  String get label => switch (this) {
        LandlordQuickAction.recordMeter => 'บันทึกมิเตอร์',
        LandlordQuickAction.issueInvoice => 'ออกบิล',
        LandlordQuickAction.reviewSlips => 'ตรวจสลิป',
        LandlordQuickAction.manageRooms => 'จัดการห้อง',
        LandlordQuickAction.lease => 'สัญญาเช่า',
        LandlordQuickAction.chat => 'แชท',
        LandlordQuickAction.paymentChannel => 'ช่องทางรับเงิน',
      };

  @override
  String get description => switch (this) {
        LandlordQuickAction.recordMeter => 'ไปหน้าจดมิเตอร์ไฟและน้ำ',
        LandlordQuickAction.issueInvoice => 'ไปหน้าบิลเพื่อออกบิลของงวดนี้',
        LandlordQuickAction.reviewSlips =>
          'ไปหน้าบิล พร้อมตัวเลขบิลที่รอตรวจบนปุ่ม',
        LandlordQuickAction.manageRooms => 'ไปหน้าจัดการห้องพัก',
        LandlordQuickAction.lease => 'ไปหน้าสัญญาเช่า',
        LandlordQuickAction.chat => 'ไปหน้าแชทกับผู้เช่า',
        LandlordQuickAction.paymentChannel =>
          'ตั้งเลขพร้อมเพย์และบัญชีธนาคารของหอ',
      };
}

/// ทางลัดที่แสดงเมื่อเจ้าของหอยังไม่เคยจัดเอง
///
/// สี่ตัวเดียวกับที่ hardcode อยู่บนหน้าจอมาตลอด — คนที่ใช้อยู่ทุกวันจึงไม่
/// ตื่นมาเจอปุ่มย้ายที่ในวันที่อัปเดต ส่วนคนที่อยากได้อย่างอื่นเปลี่ยนเองได้แล้ว
const defaultLandlordQuickActions = <LandlordQuickAction>[
  LandlordQuickAction.recordMeter,
  LandlordQuickAction.issueInvoice,
  LandlordQuickAction.lease,
  LandlordQuickAction.chat,
];

/// ทางลัดทั้งชุดของฝั่งเจ้าของหอ
///
/// คีย์แยกจากฝั่งผู้เช่า เพราะเครื่องเดียวถูกใช้ล็อกอินทั้งสองบทบาทได้ (เช่นตอน
/// สาธิต) และทางลัดของสองฝั่งเป็นคนละชนิดกัน ถ้าใช้คีย์เดียวกันจะอ่านกลับมา
/// ไม่ได้สักตัวแล้วตกไปเป็นค่าตั้งต้นทุกครั้งที่สลับบทบาท
const landlordQuickActions = QuickActionCatalog<LandlordQuickAction>(
  storageKeyPrefix: 'landlord_quick_actions',
  values: LandlordQuickAction.values,
  defaults: defaultLandlordQuickActions,
);
