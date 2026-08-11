import 'package:shared_preferences/shared_preferences.dart';

import '../models/quick_action.dart';

/// เก็บลำดับทางลัดที่ผู้เช่าจัดเอง
///
/// อยู่ในเครื่อง ไม่ใช่ฐานข้อมูล เพราะเป็นความชอบส่วนตัวที่ไม่มีใครอื่นต้องอ่าน
/// และไม่ควรทำให้การเปิดแดชบอร์ดต้องรอ network เพิ่มอีกหนึ่งรอบ · แลกกับการที่
/// ผู้เช่าซึ่งเปลี่ยนเครื่องจะได้ค่าตั้งต้นกลับมา ซึ่งยอมรับได้สำหรับการจัดปุ่ม
///
/// แยกคีย์ตามผู้ใช้ เพราะเครื่องเดียวอาจถูกใช้ล็อกอินหลายบัญชี (เช่นตอนสาธิต)
/// ถ้าใช้คีย์เดียวกันหมด คนหลังจะได้การจัดปุ่มของคนก่อนหน้าไปโดยไม่รู้ตัว
class QuickActionStore {
  QuickActionStore({SharedPreferences? preferences})
      : _injected = preferences;

  final SharedPreferences? _injected;
  SharedPreferences? _resolved;

  Future<SharedPreferences> get _prefs async =>
      _resolved ??= _injected ?? await SharedPreferences.getInstance();

  static String _keyFor(String userId) => 'quick_actions.$userId';

  /// ลำดับที่บันทึกไว้ · คืนค่าตั้งต้นเมื่อยังไม่เคยจัด
  Future<List<QuickAction>> load(String userId) async {
    final stored = (await _prefs).getStringList(_keyFor(userId));
    if (stored == null) return defaultQuickActions;

    // ชื่อที่ถอดรหัสไม่ออกถูกทิ้งเงียบๆ — เกิดได้เมื่ออัปเดตแอปแล้วทางลัดตัวเก่า
    // ถูกลบออกจาก enum การล้มทั้งรายการเพราะปุ่มเดียวที่หายไปแย่กว่ามาก
    final actions = <QuickAction>[];
    for (final name in stored) {
      for (final action in QuickAction.values) {
        if (action.name == name) actions.add(action);
      }
    }

    // รายการว่างแปลว่าข้อมูลเสียหรือผู้ใช้ลบหมด — ทั้งสองกรณีการ์ดที่ว่างเปล่า
    // ไม่มีประโยชน์กับใคร คืนค่าตั้งต้นดีกว่า
    return actions.isEmpty ? defaultQuickActions : actions;
  }

  Future<void> save(String userId, List<QuickAction> actions) async {
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
