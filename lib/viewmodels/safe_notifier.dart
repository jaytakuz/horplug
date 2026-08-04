import 'package:flutter/foundation.dart';

/// ทำให้ `notifyListeners()` หลัง dispose เป็น no-op แทนที่จะ throw
///
/// ฝั่งผู้เช่า TenantShell ใช้ `key: ValueKey(profile?.roomId)` ⇒ เมื่อผู้เช่า
/// ตอบรับคำขอเข้าหอ (roomId เปลี่ยนจาก null เป็นค่าจริง) subtree ทั้งชุดถูก
/// ถอดและ ViewModel ทุกตัวถูก dispose ทันที แต่ `load()` ที่ยิงไปก่อนหน้ายัง
/// ค้าง await network อยู่ พอ response กลับมาก็จะ notifyListeners() บน
/// ViewModel ที่ตายแล้ว ได้ assert แดงเต็มจอในโหมด debug
///
/// pull-to-refresh ก็เข้าเคสเดียวกัน เพราะ onRefresh เรียก refreshProfile()
/// ก่อน load()
mixin SafeNotifier on ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
