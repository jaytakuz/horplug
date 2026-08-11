import 'package:shared_preferences/shared_preferences.dart';

import '../models/quick_action.dart';

/// เก็บลำดับทางลัดที่ผู้ใช้จัดเอง — ใช้ได้ทั้งฝั่งผู้เช่าและฝั่งเจ้าของหอ
///
/// อยู่ในเครื่อง ไม่ใช่ฐานข้อมูล เพราะเป็นความชอบส่วนตัวที่ไม่มีใครอื่นต้องอ่าน
/// และไม่ควรทำให้การเปิดแดชบอร์ดต้องรอ network เพิ่มอีกหนึ่งรอบ · แลกกับการที่
/// คนที่เปลี่ยนเครื่องจะได้ค่าตั้งต้นกลับมา ซึ่งยอมรับได้สำหรับการจัดปุ่ม
///
/// แยกคีย์ตามผู้ใช้ เพราะเครื่องเดียวอาจถูกใช้ล็อกอินหลายบัญชี (เช่นตอนสาธิต)
/// ถ้าใช้คีย์เดียวกันหมด คนหลังจะได้การจัดปุ่มของคนก่อนหน้าไปโดยไม่รู้ตัว —
/// และแยกคีย์ตามบทบาทผ่าน [QuickActionCatalog.storageKeyPrefix] ด้วย เพราะ
/// เจ้าของหอที่ล็อกอินด้วยบัญชีเดียวกันไม่ควรได้ทางลัดของผู้เช่าไปวางบนแดชบอร์ด
class QuickActionStore<T extends QuickActionSpec> {
  QuickActionStore({
    required this.catalog,
    SharedPreferences? preferences,
  }) : _injected = preferences;

  /// รายการทางลัดทั้งหมด ค่าตั้งต้น และคีย์ของบทบาทนี้
  final QuickActionCatalog<T> catalog;

  final SharedPreferences? _injected;
  SharedPreferences? _resolved;

  Future<SharedPreferences> get _prefs async =>
      _resolved ??= _injected ?? await SharedPreferences.getInstance();

  String _keyFor(String userId) => '${catalog.storageKeyPrefix}.$userId';

  /// ลำดับที่บันทึกไว้ · คืนค่าตั้งต้นเมื่อยังไม่เคยจัด
  Future<List<T>> load(String userId) async {
    final stored = (await _prefs).getStringList(_keyFor(userId));

    // ไม่เคยบันทึก = ยังไม่เคยจัด · ต่างจากบันทึกไว้เป็นรายการว่าง ซึ่งคือผู้ใช้
    // ตั้งใจลบทางลัดออกจนหมด · เดิมสองอย่างนี้ถูกปฏิบัติเหมือนกันหมด การลบจน
    // หมดจึงกลับมาเป็นค่าตั้งต้นเองหลังเปิดแอปใหม่ ทั้งที่หน้าจอยอมให้ลบ
    if (stored == null) return catalog.defaults;
    if (stored.isEmpty) return const [];

    // ชื่อที่ถอดรหัสไม่ออกถูกทิ้งเงียบๆ — เกิดได้เมื่ออัปเดตแอปแล้วทางลัดตัวเก่า
    // ถูกลบออกจาก enum การล้มทั้งรายการเพราะปุ่มเดียวที่หายไปแย่กว่ามาก
    final actions = <T>[];
    for (final name in stored) {
      for (final action in catalog.values) {
        if (action.name == name) actions.add(action);
      }
    }

    // มีของบันทึกไว้แต่ถอดไม่ได้สักตัว = ข้อมูลเสีย (คนละเรื่องกับรายการว่าง
    // ข้างบน) คืนค่าตั้งต้นดีกว่าปล่อยให้ผู้ใช้เจอการ์ดเปล่าที่ตัวเองไม่ได้สั่ง
    return actions.isEmpty ? catalog.defaults : actions;
  }

  Future<void> save(String userId, List<T> actions) async {
    await (await _prefs).setStringList(
      _keyFor(userId),
      actions.take(maxQuickActions).map((action) => action.name).toList(),
    );
  }

  /// กลับไปใช้ค่าตั้งต้น
  Future<void> reset(String userId) async {
    await (await _prefs).remove(_keyFor(userId));
  }
}
