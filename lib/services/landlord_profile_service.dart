import '../models/models.dart';
import 'supabase_service.dart';

/// อ่านและบันทึกข้อมูลในหน้าโปรไฟล์เจ้าของหอ
///
/// แยกการบันทึกเป็นสองเมธอดตามตาราง ไม่ใช่เมธอดเดียวที่เขียนทั้งสองแถว —
/// หน้าจอบันทึกเฉพาะส่วนที่แก้ เจ้าของหอที่เปลี่ยนแค่ค่าไฟไม่ควรเสี่ยงให้
/// การเขียนแถวโปรไฟล์ที่ไม่ได้แตะล้มแล้วลากค่าไฟล้มตามไปด้วย
class LandlordProfileService {
  LandlordProfileService({SupabaseService? service})
      : _service = service ?? SupabaseService();

  final SupabaseService _service;

  Future<LandlordSettings> fetch({
    required String landlordId,
    required int dormitoryId,
  }) async {
    // สองแถวไม่ขึ้นต่อกัน ยิงพร้อมกันเพื่อให้หน้าโปรไฟล์เปิดเร็วขึ้น
    final rows = await Future.wait<Map<String, dynamic>?>([
      _service.client
          .from('landlord_profiles')
          .select('first_name, last_name, phone, email')
          .eq('id', landlordId)
          .maybeSingle(),
      _service.client
          .from('dormitories')
          .select('name, location, base_electricity_rate, base_water_rate')
          .eq('id', dormitoryId)
          .maybeSingle(),
    ]);

    final profile = rows[0];
    final dormitory = rows[1];
    if (profile == null || dormitory == null) {
      throw Exception('ไม่พบข้อมูลโปรไฟล์หรือหอพักของบัญชีนี้');
    }

    return LandlordSettings(
      firstName: profile['first_name'] as String? ?? '',
      lastName: profile['last_name'] as String? ?? '',
      phone: profile['phone'] as String? ?? '',
      email: profile['email'] as String? ?? '',
      dormitoryName: dormitory['name'] as String? ?? '',
      location: dormitory['location'] as String? ?? '',
      baseElectricityRate: _toDouble(dormitory['base_electricity_rate']),
      baseWaterRate: _toDouble(dormitory['base_water_rate']),
    );
  }

  Future<void> saveProfile({
    required String landlordId,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final rows = await _service.client
        .from('landlord_profiles')
        .update({
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
        })
        .eq('id', landlordId)
        .select('id');
    _ensureUpdated(rows);
  }

  Future<void> saveDormitory({
    required int dormitoryId,
    required String name,
    required String location,
    required double baseElectricityRate,
    required double baseWaterRate,
  }) async {
    final rows = await _service.client
        .from('dormitories')
        .update({
          'name': name.trim(),
          'location': location.trim(),
          'base_electricity_rate': baseElectricityRate,
          'base_water_rate': baseWaterRate,
        })
        .eq('id', dormitoryId)
        .select('id');
    _ensureUpdated(rows);
  }
}

/// RLS ที่ไม่อนุญาตให้ UPDATE ไม่ได้โยน error — PostgREST คืนผลเป็นศูนย์แถว
/// เงียบๆ ถ้าไม่ตรวจตรงนี้ หน้าจอจะขึ้น "บันทึกแล้ว" ทั้งที่ค่าในฐานข้อมูล
/// ไม่เปลี่ยน แล้วเจ้าของหอก็เจอค่าไฟเดิมตอนออกบิลเดือนถัดไป
void _ensureUpdated(dynamic rows) {
  if (rows is List && rows.isNotEmpty) return;
  throw Exception('บันทึกไม่สำเร็จ: บัญชีนี้ไม่มีสิทธิ์แก้ไขข้อมูลนี้');
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
