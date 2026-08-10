import '../models/models.dart';
import 'supabase_service.dart';

/// อ่านและบันทึกช่องทางรับเงินของหอ
///
/// แยกออกมาเพราะมีผู้ใช้สองฝั่งที่ต้องการคอลัมน์ชุดเดียวกัน — ผู้เช่าอ่านตอนเปิด
/// แผ่นชำระเงิน เจ้าของหออ่านและเขียนในหน้าตั้งค่า ถ้าปล่อยให้ต่างฝ่ายต่าง query
/// เอง จะมีโค้ด map คอลัมน์สองชุดที่ต้องคอยดูแลให้ตรงกัน ซึ่งเป็นปัญหาแบบเดียว
/// กับที่ submitSlip เคยถูกเขียนซ้ำสามที่แล้วเพี้ยนจากกัน
class PaymentChannelService {
  PaymentChannelService({SupabaseService? service})
      : _service = service ?? SupabaseService();

  final SupabaseService _service;

  static const _table = 'dormitory_payment_channels';
  static const _columns = 'promptpay_id, bank_name, account_no, account_name';

  /// null แปลว่าหอนี้ยังไม่ได้ตั้งค่าช่องทางชำระเงิน
  Future<PaymentChannel?> fetch({required int dormitoryId}) async {
    final row = await _service.client
        .from(_table)
        .select(_columns)
        .eq('dorm_id', dormitoryId)
        .maybeSingle();
    if (row == null) return null;

    return PaymentChannel(
      accountName: row['account_name'] as String,
      promptPayId: row['promptpay_id'] as String?,
      bankName: row['bank_name'] as String?,
      accountNo: row['account_no'] as String?,
    );
  }

  /// เขียนทับของเดิมทั้งแถว
  ///
  /// upsert บน primary key `dorm_id` ทำให้การตั้งค่าครั้งแรกกับการแก้ครั้งถัดไป
  /// เป็นเส้นทางเดียวกัน หน้าตั้งค่าจึงไม่ต้องรู้ว่ามีแถวอยู่แล้วหรือยัง
  ///
  /// ช่องที่เว้นว่างถูกเก็บเป็น null ไม่ใช่สตริงว่าง เพราะ CHECK
  /// `dpc_has_a_channel` ตรวจด้วย IS NOT NULL — สตริงว่างจะผ่าน constraint ไปได้
  /// ทั้งที่ไม่มีช่องทางให้โอนจริง
  Future<void> save({
    required int dormitoryId,
    required PaymentChannel channel,
  }) async {
    await _service.client.from(_table).upsert({
      'dorm_id': dormitoryId,
      'promptpay_id': _nullIfBlank(channel.promptPayId),
      'bank_name': _nullIfBlank(channel.bankName),
      'account_no': _nullIfBlank(channel.accountNo),
      'account_name': channel.accountName.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
