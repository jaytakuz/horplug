import 'package:flutter/foundation.dart';

/// แยก "โหลดครั้งแรก" ออกจาก "ดึงข้อมูลใหม่ทั้งที่มีของอยู่แล้ว"
///
/// ViewModel ทุกตัวเคยมี `isLoading` ตัวเดียว แล้วหน้าจอแปลว่า "วาดตัวหมุนเต็ม
/// พื้นที่เนื้อหา" — พอผู้ใช้ลากเพื่อรีเฟรช เนื้อหาหายทั้งหน้ากลางท่าทาง พร้อมกับ
/// วงแหวนของ RefreshIndicator ที่ถูกถอดไปด้วย และตำแหน่งที่เลื่อนค้างไว้ก็หายตาม
/// · การรีเฟรชที่ดีต้องไม่ทำให้จอว่าง วงแหวนคือคำตอบเดียวที่ผู้ใช้ต้องการ
///
/// `TenantBillsViewModel` เคยแก้เรื่องนี้ไว้ตัวเดียวด้วย `_hasLoadedOnce` —
/// ที่นี่คือตรรกะเดียวกันที่ยกขึ้นมาให้ทุกตัวใช้ร่วมกัน แทนที่จะก๊อปไปอีกแปดไฟล์
/// แล้วมีบางไฟล์ที่ลืม
mixin RefreshableViewModel on ChangeNotifier {
  /// โหลดครั้งแรก ยังไม่มีอะไรให้แสดง
  bool isLoading = true;

  /// มีข้อมูลอยู่แล้ว กำลังดึงใหม่ — หน้าจอต้องคงเนื้อหาเดิมไว้
  bool isRefreshing = false;

  bool _hasLoadedOnce = false;
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// ครอบงานโหลดหนึ่งครั้งแล้วตั้งธงให้ถูกชั้นเอง
  ///
  /// ปลดธงใน `finally` เสมอ ความล้มจึงไม่ทิ้งหน้าไว้กับตัวหมุนตลอดไป และ
  /// [hasLoadedOnce] ขึ้นเป็น true แม้ครั้งนั้นจะโหลดไม่สำเร็จ — ครั้งถัดไป
  /// ผู้ใช้จะเห็นการ์ด error เดิมค้างไว้พร้อมวงแหวนที่หมุนอยู่ ซึ่งบอกว่า
  /// "กำลังลองใหม่" ได้ดีกว่าจอว่างที่ไม่ได้บอกว่ากำลังทำอะไรอยู่
  @protected
  Future<void> runLoad(Future<void> Function() body) async {
    if (_hasLoadedOnce) {
      isRefreshing = true;
    } else {
      isLoading = true;
    }
    notifyListeners();

    try {
      await body();
    } finally {
      isLoading = false;
      isRefreshing = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }
}
