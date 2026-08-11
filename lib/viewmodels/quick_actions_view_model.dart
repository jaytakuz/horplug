import 'package:flutter/foundation.dart';

import '../models/quick_action.dart';
import '../services/quick_action_store.dart';
import 'safe_notifier.dart';

/// ลำดับทางลัดบนแดชบอร์ด — ตัวเดียวกันทั้งฝั่งผู้เช่าและฝั่งเจ้าของหอ
///
/// แยกจาก ViewModel ของแดชบอร์ดเพราะไม่ได้แตะเครือข่ายเลยและมีอายุคนละแบบ —
/// การรีเฟรชแดชบอร์ดไม่ควรทำให้ปุ่มกระพริบ และการจัดปุ่มไม่ควรทำให้ต้องโหลด
/// ข้อมูลใหม่
///
/// รายการทางลัดที่เลือกได้กับค่าตั้งต้นมาจาก [QuickActionStore.catalog] ไม่ได้
/// รับซ้ำเข้ามาอีกทาง เพื่อไม่ให้มีสภาพที่ ViewModel ถือแคตตาล็อกของบทบาทหนึ่ง
/// แต่เขียนลงคีย์ของอีกบทบาท
class QuickActionsViewModel<T extends QuickActionSpec> extends ChangeNotifier
    with SafeNotifier {
  QuickActionsViewModel({
    required this.userId,
    required QuickActionStore<T> store,
  })  : _store = store,
        actions = store.catalog.defaults;

  /// คีย์ที่ใช้แยกการตั้งค่าของแต่ละบัญชีบนเครื่องเดียวกัน
  final String userId;
  final QuickActionStore<T> _store;

  bool isLoading = true;
  List<T> actions;

  QuickActionCatalog<T> get catalog => _store.catalog;

  List<T> get available => catalog.values
      .where((action) => !actions.contains(action))
      .toList(growable: false);

  bool get canAddMore => actions.length < maxQuickActions;

  Future<void> load() async {
    try {
      actions = await _store.load(userId);
    } catch (_) {
      // อ่านค่าที่จัดไว้ไม่ได้ไม่ใช่เหตุให้แดชบอร์ดไม่มีปุ่ม — ใช้ค่าตั้งต้นไป
      actions = catalog.defaults;
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

  Future<void> add(T action) async {
    if (actions.contains(action) || !canAddMore) return;
    await _commit([...actions, action]);
  }

  Future<void> remove(T action) async {
    // ปล่อยให้ลบจนหมดได้ — การ์ดจะยุบเหลือแถบเดียวที่ยังมีปุ่มเข้าตัวจัดการอยู่
    // ผู้ใช้ที่ไม่ใช้ทางลัดเลยจึงเอาปุ่มออกจากหน้าจอได้โดยไม่ตัดทางกลับ
    await _commit(actions.where((item) => item != action).toList());
  }

  Future<void> resetToDefault() async {
    await _store.reset(userId);
    actions = catalog.defaults;
    notifyListeners();
  }

  Future<void> _commit(List<T> updated) async {
    // อัปเดตหน้าจอก่อนเขียนลงดิสก์ การลากแล้วปุ่มค้างรอ I/O รู้สึกเหมือนแอปหน่วง
    actions = updated;
    notifyListeners();
    await _store.save(userId, updated);
  }
}
