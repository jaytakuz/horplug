import 'package:flutter/foundation.dart';

import '../models/quick_action.dart';
import '../services/quick_action_store.dart';
import 'safe_notifier.dart';

/// ลำดับทางลัดบนแดชบอร์ดผู้เช่า
///
/// แยกจาก [TenantDashboardViewModel] เพราะไม่ได้แตะเครือข่ายเลยและมีอายุคนละ
/// แบบ — การรีเฟรชแดชบอร์ดไม่ควรทำให้ปุ่มกระพริบ และการจัดปุ่มไม่ควรทำให้ต้อง
/// โหลดบิลใหม่
class QuickActionsViewModel extends ChangeNotifier with SafeNotifier {
  QuickActionsViewModel({
    required this.userId,
    QuickActionStore? store,
  }) : _store = store ?? QuickActionStore();

  /// คีย์ที่ใช้แยกการตั้งค่าของแต่ละบัญชีบนเครื่องเดียวกัน
  final String userId;
  final QuickActionStore _store;

  bool isLoading = true;
  List<QuickAction> actions = defaultQuickActions;

  List<QuickAction> get available => QuickAction.values
      .where((action) => !actions.contains(action))
      .toList(growable: false);

  bool get canAddMore => actions.length < maxQuickActions;

  Future<void> load() async {
    try {
      actions = await _store.load(userId);
    } catch (_) {
      // อ่านค่าที่จัดไว้ไม่ได้ไม่ใช่เหตุให้แดชบอร์ดไม่มีปุ่ม — ใช้ค่าตั้งต้นไป
      actions = defaultQuickActions;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// [newIndex] คือตำแหน่งปลายทาง **หลังถอดตัวที่ลากออกแล้ว**
  ///
  /// ตรงกับที่ `onReorderItem` ของ ReorderableListView ส่งมา · ห้ามต่อกับ
  /// `onReorder` ตัวเก่าซึ่งรายงานตำแหน่งแบบก่อนถอด แล้วผู้เรียกต้องลบหนึ่งเอง
  /// เมื่อลากลง — ต่อผิดตัวจะได้บั๊ก "วางเลยไปหนึ่งช่อง"
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex == oldIndex) return;

    final updated = [...actions];
    updated.insert(newIndex, updated.removeAt(oldIndex));
    await _commit(updated);
  }

  Future<void> add(QuickAction action) async {
    if (actions.contains(action) || !canAddMore) return;
    await _commit([...actions, action]);
  }

  Future<void> remove(QuickAction action) async {
    // ปล่อยให้ลบจนหมดได้ — การ์ดจะซ่อนตัวเองเมื่อไม่มีปุ่มเหลือ ซึ่งเป็นทางเดียว
    // ที่ผู้เช่าที่ไม่อยากได้การ์ดนี้เลยจะเอามันออกจากหน้าจอได้
    await _commit(actions.where((item) => item != action).toList());
  }

  Future<void> resetToDefault() async {
    await _store.reset(userId);
    actions = defaultQuickActions;
    notifyListeners();
  }

  Future<void> _commit(List<QuickAction> updated) async {
    // อัปเดตหน้าจอก่อนเขียนลงดิสก์ การลากแล้วปุ่มค้างรอ I/O รู้สึกเหมือนแอปหน่วง
    actions = updated;
    notifyListeners();
    await _store.save(userId, updated);
  }
}
