# Pull-to-Refresh, Invoice Sync & Typography — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ให้ทุกหน้าลากลงเพื่อรีเฟรชได้โดยเนื้อหาไม่หาย, ให้บิลค้างชำระมียอดตรงกับข้อมูลล่าสุดของงวดโดยไม่ต้องออกใบใหม่, และให้ตัวอักษร/ท่าทางย้อนกลับ/การจัดหน้าเป็นมาตรฐานเดียวกันทุกอุปกรณ์

**Architecture:** สถานะโหลดแยกสองชั้นผ่าน mixin `RefreshableViewModel` (ครั้งแรก = `isLoading`, ครั้งถัดไป = `isRefreshing`) คู่กับวิดเจ็ต `PullToRefresh` / `CenteredScrollable` ที่ไม่รู้จัก ViewModel ตัวไหนเลย · การคำนวณยอดบิลใหม่เป็นฟังก์ชัน Dart ล้วนใน `invoice_calculator.dart` ที่ `InvoiceService` เรียกใช้ตอนเขียน ไม่ใช่ตอนอ่าน · ท่าทางย้อนกลับและฟอนต์ตั้งที่ `buildAppTheme()` จุดเดียว

**Tech Stack:** Flutter 3.44.1 / Dart 3 · provider (ChangeNotifier) · go_router · Supabase (PostgREST) · flutter_test

**Spec:** [2026-08-12-pull-to-refresh-and-invoice-sync-design.md](../specs/2026-08-12-pull-to-refresh-and-invoice-sync-design.md)

## Global Constraints

- **ห้ามรัน `git commit` หรือ `git push`** — จบแต่ละคอมมิท ให้ `git add` ไฟล์ให้ครบแล้วส่ง Commit Name + Commit Description **เป็นภาษาอังกฤษ** ให้ผู้ใช้ commit เอง
- คอมมิทที่แตะ `database/` หรือ `docs/` ต้องเขียนกำกับในข้อความคอมมิทให้ `git add` โฟลเดอร์นั้นด้วย — สองโฟลเดอร์นี้เคยหลุดจากคอมมิทมาก่อน
- คอมเมนต์ในโค้ดเป็นภาษาไทย อธิบาย **เหตุผล** ไม่ใช่สิ่งที่โค้ดบอกอยู่แล้ว ตามแบบไฟล์รอบข้าง
- ทุกคอมมิทต้องผ่าน `flutter analyze` (0 issues) และ `flutter test` ทั้งชุดก่อนส่งมอบ
- ห้ามแตะการประกาศฟอนต์ Sarabun ใต้ `assets:` ใน `pubspec.yaml` — แพ็กเกจ pdf โหลดผ่าน `rootBundle` เอง
- บิลที่สถานะไม่ใช่ `unpaid` ห้ามถูกแก้ยอดในทุกเส้นทาง
- ห้ามเขียนคอลัมน์ `invoices.total` (เป็น `GENERATED ALWAYS AS`)

---

## Task 1 — สถานะโหลดสองชั้น + วิดเจ็ตรีเฟรชกลาง

**Files:**
- Create: `lib/viewmodels/refreshable.dart`
- Create: `lib/widgets/refreshable.dart`
- Create: `test/refreshable_view_model_unit_test.dart`
- Modify: `lib/viewmodels/tenant_bills_view_model.dart`, `tenant_dashboard_view_model.dart`, `tenant_maintenance_view_model.dart`, `tenant_profile_view_model.dart`, `dashboard_view_model.dart`, `rooms_view_model.dart`, `maintenance_overview_view_model.dart`, `maintenance_view_model.dart`
- Modify: `lib/screens/tenant/tenant_bills_screen.dart`, `tenant_dashboard_screen.dart`, `tenant_maintenance_screen.dart`, `tenant_profile_screen.dart`, `lib/screens/admin/dashboard_screen.dart`, `rooms_screen.dart`, `maintenance_overview_screen.dart`, `maintenance_history_screen.dart`

**Interfaces:**
- Produces: `RefreshableViewModel` (mixin on `ChangeNotifier`) — ฟิลด์ `isLoading`, `isRefreshing`, getter `hasLoadedOnce`, เมธอด `Future<void> runLoad(Future<void> Function() body)`
- Produces: `PullToRefresh({required Future<void> Function() onRefresh, required Widget child})`
- Produces: `CenteredScrollable({required Widget child, EdgeInsetsGeometry padding})`
- Consumes: `SafeNotifier` (`lib/viewmodels/safe_notifier.dart`) — mixin ทั้งสองตัวเป็น `on ChangeNotifier` จึงวางต่อกันได้: `class X extends ChangeNotifier with SafeNotifier, RefreshableViewModel`

- [ ] **Step 1: เขียนเทสต์ที่ยังล้ม**

`test/refreshable_view_model_unit_test.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/viewmodels/refreshable.dart';

class _Fake extends ChangeNotifier with RefreshableViewModel {
  _Fake({this.shouldThrow = false});

  final bool shouldThrow;
  int loadCount = 0;
  final List<({bool loading, bool refreshing})> flagsSeen = [];

  Future<void> load() => runLoad(() async {
        loadCount++;
        flagsSeen.add((loading: isLoading, refreshing: isRefreshing));
        if (shouldThrow) throw Exception('boom');
      });
}

void main() {
  test('โหลดครั้งแรกตั้ง isLoading ไม่ใช่ isRefreshing', () async {
    final vm = _Fake();
    expect(vm.isLoading, isTrue, reason: 'ค่าเริ่มต้นต้องเป็นกำลังโหลด');

    await vm.load();

    expect(vm.flagsSeen.single.loading, isTrue);
    expect(vm.flagsSeen.single.refreshing, isFalse);
    expect(vm.isLoading, isFalse);
    expect(vm.hasLoadedOnce, isTrue);
  });

  test('โหลดครั้งถัดไปตั้ง isRefreshing และไม่แตะ isLoading', () async {
    final vm = _Fake();
    await vm.load();
    await vm.load();

    expect(vm.flagsSeen.last.loading, isFalse,
        reason: 'เนื้อหาเดิมต้องอยู่ครบระหว่างรีเฟรช');
    expect(vm.flagsSeen.last.refreshing, isTrue);
    expect(vm.isRefreshing, isFalse);
  });

  test('ความล้มไม่ทำให้ธงค้าง', () async {
    final vm = _Fake(shouldThrow: true);

    await expectLater(vm.load(), throwsException);

    expect(vm.isLoading, isFalse);
    expect(vm.isRefreshing, isFalse);
  });

  test('แจ้ง listener ทั้งตอนเริ่มและตอนจบ', () async {
    final vm = _Fake();
    var notifications = 0;
    vm.addListener(() => notifications++);

    await vm.load();

    expect(notifications, 2);
  });
}
```

- [ ] **Step 2: รันเทสต์ให้เห็นว่าล้ม**

Run: `flutter test test/refreshable_view_model_unit_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:horplug/viewmodels/refreshable.dart'`

- [ ] **Step 3: เขียน mixin**

`lib/viewmodels/refreshable.dart`

```dart
import 'package:flutter/foundation.dart';

/// แยก "โหลดครั้งแรก" ออกจาก "ดึงข้อมูลใหม่ทั้งที่มีของอยู่แล้ว"
///
/// ViewModel ทุกตัวเคยมี `isLoading` ตัวเดียว แล้วหน้าจอแปลว่า "วาดตัวหมุน
/// เต็มพื้นที่เนื้อหา" — พอผู้ใช้ลากเพื่อรีเฟรช เนื้อหาหายทั้งหน้ากลางท่าทาง
/// พร้อมกับวงแหวนของ RefreshIndicator ที่ถูกถอดไปด้วย และตำแหน่งที่เลื่อนค้าง
/// ไว้ก็หายตาม · การรีเฟรชที่ดีต้องไม่ทำให้จอว่าง วงแหวนคือคำตอบเดียวที่ผู้ใช้
/// ต้องการ
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
  /// ผู้ใช้จะเห็นการ์ด error เดิมค้างไว้พร้อมวงแหวนที่หมุนอยู่ ซึ่งบอกได้ว่า
  /// "กำลังลองใหม่" ดีกว่าจอว่างที่ไม่ได้บอกว่ากำลังทำอะไรอยู่
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
```

- [ ] **Step 4: รันเทสต์ให้ผ่าน**

Run: `flutter test test/refreshable_view_model_unit_test.dart`
Expected: PASS ทั้ง 4 เคส

- [ ] **Step 5: เขียนวิดเจ็ตกลาง**

`lib/widgets/refreshable.dart`

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ท่าทางลากลงเพื่อรีเฟรชแบบเดียวกันทั้งแอป
///
/// ต้องอยู่ **ใน** `body` ของ Scaffold เท่านั้น ห้ามครอบ Scaffold ทั้งตัว —
/// header กับแถบนำทางเป็นพารามิเตอร์ของ Scaffold คนละ subtree กับ body
/// การครอบทั้งก้อนจะลากแถบพวกนั้นตามลงมาด้วย ซึ่งไม่ใช่สิ่งที่ผู้ใช้คาดจาก
/// ท่าทางนี้บนแพลตฟอร์มไหนเลย
///
/// ลูกต้องเป็น scroll view ที่มี `AlwaysScrollableScrollPhysics` ไม่งั้นหน้าที่
/// เนื้อหาสั้นกว่าจอจะลากไม่ได้ · สถานะว่าง/ผิดพลาดใช้ [CenteredScrollable]
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // .adaptive ให้ตัวหมุนแบบ Cupertino บน iOS/macOS และวงแหวน Material
    // ที่อื่น — ท่าทางเดียวกันแต่หน้าตาตรงกับที่ผู้ใช้แต่ละแพลตฟอร์มคุ้นเคย
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      child: child,
    );
  }
}

/// เนื้อหาสั้นๆ ที่อยู่กลางจอแต่ยัง "ลากได้"
///
/// สถานะว่างกับสถานะผิดพลาดเคยเป็น `Center` เฉยๆ ซึ่งไม่มี scrollable ให้
/// RefreshIndicator เกาะ หน้าที่โหลดล้มจึงกลายเป็นทางตันที่ท่าทางประจำของแอป
/// ใช้ไม่ได้ ทั้งที่เป็นหน้าที่ต้องการการลองใหม่มากที่สุด
class CenteredScrollable extends StatelessWidget {
  const CenteredScrollable({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: padding,
            child: Center(child: child),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: ย้าย ViewModel ที่มี `_hasLoadedOnce` อยู่แล้วมาใช้ mixin**

สามตัวนี้มีตรรกะเดียวกันเขียนซ้ำอยู่ — ลบของเดิมทิ้ง ใช้ `runLoad` แทน

| ไฟล์ | ทำอะไร |
|---|---|
| `tenant_bills_view_model.dart` | ลบ `isLoading` + `_hasLoadedOnce` · เติม `with SafeNotifier, RefreshableViewModel` · `load()` ห่อเนื้อในด้วย `runLoad(() async { ... })` โดยเก็บ try/catch ที่ตั้ง `errorMessage` ไว้ข้างใน |
| `tenant_dashboard_view_model.dart` | เหมือนกัน · `isLoadingRequests` ใน `loadPendingRequests()` เป็นธงคนละตัว ปล่อยไว้ตามเดิม |
| `tenant_maintenance_view_model.dart` | เหมือนกัน · คง early-return เมื่อ `roomId == null` ไว้ก่อนเรียก `runLoad` |

ตัวอย่างรูปแบบที่ต้องได้ (จาก `tenant_bills_view_model.dart`):

```dart
class TenantBillsViewModel extends ChangeNotifier
    with SafeNotifier, RefreshableViewModel, TenantSlipSubmission {
  // ...

  Future<void> load() async {
    final room = roomId;
    if (room == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    return runLoad(() async {
      errorMessage = null;
      try {
        bills = await _source.fetchBillHistory(roomDbId: room, monthCount: 6);
        await loadPaymentChannel(dormitoryId);
      } catch (error) {
        errorMessage = formatErrorMessage(error);
      }
    });
  }
}
```

- [ ] **Step 7: ย้าย ViewModel ที่เหลือมาใช้ mixin**

`tenant_profile_view_model.dart` (`load`), `dashboard_view_model.dart` (`loadRooms`), `rooms_view_model.dart` (`loadData`), `maintenance_overview_view_model.dart` (`load`), `maintenance_view_model.dart` (`loadRequests`) — ทุกตัวลบ `bool isLoading = true;` ของตัวเองออก (mixin ประกาศให้แล้ว) แล้วห่อเนื้อในเมธอดโหลดด้วย `runLoad` โดยคง try/catch ที่ตั้ง `errorMessage` ไว้ที่เดิม

`billing_view_model.dart` และ `meter_view_model.dart` ก็ทำเหมือนกันในขั้นนี้ (Task 2 กับ 3 จะมาต่อยอด)

- [ ] **Step 8: แก้หน้าจอให้เลิกลบเนื้อหาทิ้งตอนรีเฟรช**

ทุกหน้าที่เขียนว่า `if (viewModel.isLoading) return const Center(child: CircularProgressIndicator());` ยังคงบรรทัดนั้นไว้ได้ — ตอนนี้ `isLoading` เป็นจริงเฉพาะครั้งแรกแล้ว จึงไม่ต้องแก้อะไรนอกจาก:

1. เปลี่ยน `RefreshIndicator(...)` ทุกจุดเป็น `PullToRefresh(...)` (ลบ `onRefresh:` ที่ส่ง method reference ไว้ตามเดิมได้เลย)
2. สถานะว่าง/ผิดพลาดที่เป็น `Center(...)` ล้วน เปลี่ยนเป็น `CenteredScrollable(child: ...)` แล้วครอบด้วย `PullToRefresh`
3. ปุ่ม "ลองใหม่" ในการ์ด error เปลี่ยนป้ายเป็น `'กำลังลองใหม่...'` และตั้ง `onPressed: null` เมื่อ `viewModel.isRefreshing == true`

ไฟล์ที่ต้องไล่: `tenant_bills_screen.dart` (3 จุด), `tenant_dashboard_screen.dart`, `tenant_maintenance_screen.dart` (3 จุด), `tenant_profile_screen.dart`, `admin/dashboard_screen.dart`, `admin/rooms_screen.dart`, `admin/maintenance_overview_screen.dart`, `admin/maintenance_history_screen.dart`, `admin/chat_screen.dart`

- [ ] **Step 9: ตรวจทั้งชุด**

Run: `flutter analyze && flutter test`
Expected: analyze 0 issues · เทสต์เดิมทั้งหมดยังผ่าน + เทสต์ใหม่ 4 เคสผ่าน

- [ ] **Step 10: `git add` แล้วส่งข้อความคอมมิท (ห้าม commit เอง)**

```bash
git add lib/viewmodels/refreshable.dart lib/widgets/refreshable.dart \
        test/refreshable_view_model_unit_test.dart \
        lib/viewmodels lib/screens
```

---

## Task 2 — ลากเพื่อรีเฟรชหน้ามิเตอร์

**Files:**
- Modify: `lib/viewmodels/meter_view_model.dart`
- Modify: `lib/screens/admin/meter_screen.dart`
- Modify: `test/meter_unit_test.dart`

**Interfaces:**
- Consumes: `PullToRefresh`, `CenteredScrollable`, `RefreshableViewModel` จาก Task 1
- Produces: `MeterViewModel.modifiedElectricityRoomIds` (`Set<int>`), `MeterViewModel.hasUnsavedInput` (`bool` — เกณฑ์ของกล่องถามก่อนทิ้ง), `MeterViewModel.hasUnsavedEdits` (`bool` — เกณฑ์ของปุ่มบันทึก)

**แก้ระหว่างลงมือ:** เดิมวางไว้ตัวเดียวคือ `hasUnsavedEdits` แล้วให้ทั้งปุ่มบันทึกและกล่อง
ถามก่อนทิ้งใช้ร่วมกัน · ใช้ไม่ได้ เพราะงวดใหม่มีแถวค่าน้ำที่ `id == null` ครบทุกห้อง
ตั้งแต่โหลดเสร็จ กล่องจะเด้งทุกครั้งที่ลากรีเฟรชทั้งที่ยังไม่มีใครพิมพ์อะไร ซึ่งสอนให้ผู้ใช้
กด "ทิ้ง" โดยไม่อ่าน · จึงแยกเป็น `hasUnsavedInput` (เฉพาะสิ่งที่คนพิมพ์) กับ
`hasUnsavedEdits` (รวมแถวที่ต้องสร้างจริง)

- [ ] **Step 1: เขียนเทสต์ dirty tracking ที่ยังล้ม**

เติมใน `test/meter_unit_test.dart` (ทำตามรูปแบบ fake service ที่ไฟล์นี้ใช้อยู่แล้ว)

```dart
  test('ยังไม่แก้อะไร = ไม่มีอะไรให้บันทึก', () {
    final vm = buildLoadedMeterViewModel();   // helper ที่มีอยู่ในไฟล์นี้

    expect(vm.hasUnsavedEdits, isFalse);
    expect(vm.canSave, isFalse,
        reason: 'ปุ่มบันทึกไม่ควรกดได้ทั้งที่ไม่มีอะไรเปลี่ยน');
  });

  test('พิมพ์เลขมิเตอร์ไฟแล้วถือว่ามีของค้าง', () {
    final vm = buildLoadedMeterViewModel();
    final record = vm.electricityRecords.first;

    vm.setElectricityReading(record, 1234);

    expect(vm.modifiedElectricityRoomIds, contains(record.roomDbId));
    expect(vm.hasUnsavedEdits, isTrue);
    expect(vm.canSave, isTrue);
  });

  test('บันทึกสำเร็จแล้วล้างธงทั้งสองฝั่ง', () async {
    final vm = buildLoadedMeterViewModel();
    vm.setElectricityReading(vm.electricityRecords.first, 1234);
    vm.setWaterAmount(vm.waterRecords.first, 120);

    await vm.saveAll();

    expect(vm.modifiedElectricityRoomIds, isEmpty);
    expect(vm.modifiedWaterRoomIds, isEmpty);
    expect(vm.hasUnsavedEdits, isFalse);
  });
```

- [ ] **Step 2: รันให้เห็นว่าล้ม**

Run: `flutter test test/meter_unit_test.dart`
Expected: FAIL — ไม่มี getter `hasUnsavedEdits` / `modifiedElectricityRoomIds`

- [ ] **Step 3: เพิ่ม dirty tracking ใน ViewModel**

`lib/viewmodels/meter_view_model.dart`

```dart
  /// ห้องที่เจ้าของหอเพิ่งพิมพ์เลขมิเตอร์ไฟ ยังไม่ได้บันทึก
  ///
  /// มีคู่กับ [modifiedWaterRoomIds] ที่มีอยู่เดิม เพราะ [canSave] ตัวเก่าตอบว่า
  /// "บันทึกได้" เพียงเพราะมีห้องไหนสักห้องที่มีเลขมิเตอร์ ซึ่งเป็นจริงเสมอหลัง
  /// โหลดข้อมูลที่เคยบันทึกไว้ — ปุ่มจึงกดได้ตลอดเวลาแม้ไม่มีอะไรเปลี่ยน และ
  /// ที่สำคัญกว่านั้นคือไม่มีทางรู้ว่าการรีเฟรชจะทิ้งงานของใครไปบ้าง
  final Set<int> modifiedElectricityRoomIds = {};

  /// เกณฑ์ของกล่อง "ถามก่อนทิ้ง" — เฉพาะสิ่งที่คนพิมพ์ในรอบนี้
  bool get hasUnsavedInput =>
      modifiedElectricityRoomIds.isNotEmpty || modifiedWaterRoomIds.isNotEmpty;

  /// เกณฑ์ของปุ่มบันทึก — รวมแถวค่าน้ำของงวดที่ยังไม่เคยถูกบันทึก
  bool get hasUnsavedEdits =>
      hasUnsavedInput || waterRecords.any((r) => r.id == null);

  bool get canSave => !isLoading && !isSaving && hasUnsavedEdits;
```

ใน `setElectricityReading` เพิ่ม `modifiedElectricityRoomIds.add(record.roomDbId);`
ใน `saveAll()` หลังบันทึกสำเร็จ เพิ่ม `modifiedElectricityRoomIds.clear();` ข้างที่เดิมล้าง `modifiedWaterRoomIds`

- [ ] **Step 4: รันเทสต์ให้ผ่าน**

Run: `flutter test test/meter_unit_test.dart`
Expected: PASS ทั้งไฟล์ (เทสต์เดิมต้องไม่พังด้วย)

- [ ] **Step 5: ใส่ท่าทางรีเฟรชในหน้าจอ พร้อมกล่องถามก่อนทิ้ง**

`lib/screens/admin/meter_screen.dart` — เพิ่มเมธอดใน `_MeterViewState`

```dart
  /// รีเฟรชที่ถามก่อนทิ้งงานที่ยังไม่ได้บันทึก
  ///
  /// `reloadTick` ล้าง TextEditingController ทั้งชุดทุกครั้งที่โหลดใหม่ ถ้าปล่อย
  /// ให้ท่าทางลากเรียก loadAllRecords() ตรงๆ เลขมิเตอร์ที่เพิ่งพิมพ์มาทั้งชั้น
  /// จะหายไปเงียบๆ ด้วยท่าทางที่ผู้ใช้ตั้งใจใช้เพื่อ "ดูข้อมูลล่าสุด" ไม่ใช่
  /// เพื่อล้างงานตัวเอง
  Future<void> _handleRefresh(MeterViewModel viewModel) async {
    if (viewModel.hasUnsavedInput) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('มีเลขมิเตอร์ที่ยังไม่ได้บันทึก'),
          content: const Text('รีเฟรชแล้วค่าที่พิมพ์ไว้จะหายทั้งหมด'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive,
              ),
              child: const Text('ทิ้งแล้วรีเฟรช'),
            ),
          ],
        ),
      );
      // กด "ยกเลิก" หรือปิดกล่องทิ้ง = คืน Future ทันที วงแหวนหดกลับเอง
      if (discard != true) return;
    }

    await viewModel.loadAllRecords();
  }
```

แล้วครอบ `ListView.builder` ของทั้งสองแท็บ (`_buildElectricityList` และ `_buildWaterList`) ด้วย `PullToRefresh(onRefresh: () => _handleRefresh(viewModel), child: ...)` · สถานะ `_buildEmptyState` และ `_buildNoResultState` เปลี่ยนเป็น `CenteredScrollable` ที่อยู่ใน `PullToRefresh` เช่นกัน

หัวหน้าจอ ตัวเลือกงวด ช่องค้นหา และ `TabBar` อยู่นอกกรอบทั้งหมด — ห้ามย้ายเข้าไปใน scroll view

- [ ] **Step 6: ตรวจด้วยตาบนเว็บ**

Run: `flutter run -d chrome`
ตรวจ: ลากที่รายการค่าไฟ → วงแหวนหมุน หัวหน้าจอกับ TabBar ไม่ขยับ · พิมพ์เลขห้องหนึ่งแล้วลาก → กล่องเด้ง · กด "ยกเลิก" → วงแหวนหดกลับ เลขที่พิมพ์ยังอยู่

- [ ] **Step 7: ตรวจทั้งชุดแล้วส่งข้อความคอมมิท**

Run: `flutter analyze && flutter test`

```bash
git add lib/viewmodels/meter_view_model.dart lib/screens/admin/meter_screen.dart test/meter_unit_test.dart
```

---

## Task 3 — ลากเพื่อรีเฟรชหน้าบิลทั้งสองฝั่ง

**Files:**
- Modify: `lib/screens/admin/billing_screen.dart`
- Modify: `lib/screens/tenant/tenant_bills_screen.dart`
- Modify: `lib/viewmodels/billing_view_model.dart`

**Interfaces:**
- Consumes: `PullToRefresh`, `CenteredScrollable`, `RefreshableViewModel`
- Produces: `BillingViewModel.refresh()` — `Future<void>`; Task 6 จะแทรกการคำนวณยอดใหม่ไว้ในเมธอดนี้

- [ ] **Step 1: เพิ่ม `refresh()` ใน BillingViewModel**

```dart
  /// จุดเดียวที่ท่าทางลากเรียก
  ///
  /// แยกจาก [loadInvoices] เพราะ Task 6 จะแทรกการปรับยอดบิลค้างชำระไว้ตรงนี้
  /// ก่อนโหลด — ที่นั่นเป็นการ "เขียน" ซึ่งต้องเกิดจากท่าทางของเจ้าของหอเท่านั้น
  /// ไม่ใช่ทุกครั้งที่หน้าถูก build
  Future<void> refresh() => loadInvoices();
```

- [ ] **Step 2: ครอบรายการบิลฝั่งเจ้าของหอ**

`lib/screens/admin/billing_screen.dart` — ใน `Expanded(...)` เปลี่ยนสามกิ่งให้อยู่ใต้ `PullToRefresh` เดียวกัน:

```dart
        Expanded(
          child: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : PullToRefresh(
                  onRefresh: viewModel.refresh,
                  child: viewModel.errorMessage != null
                      ? CenteredScrollable(
                          child: _buildErrorContent(context, viewModel))
                      : filteredInvoices.isEmpty
                          ? CenteredScrollable(
                              child: _buildEmptyContent(context, viewModel))
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredInvoices.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) =>
                                  _InvoiceCard(invoice: filteredInvoices[index]),
                            ),
                ),
        ),
```

`_buildErrorState` / `_buildEmptyState` เดิมคืน `Center(child: Padding(...))` — เปลี่ยนชื่อเป็น `_buildErrorContent` / `_buildEmptyContent` แล้วคืนเฉพาะ `Column` ข้างใน (ตัด `Center` กับ `Padding` ออก เพราะ `CenteredScrollable` จัดให้แล้ว)

- [ ] **Step 3: ฝั่งผู้เช่า**

`lib/screens/tenant/tenant_bills_screen.dart` — เปลี่ยน `RefreshIndicator` ทั้งสองจุดเป็น `PullToRefresh` (ถ้า Task 1 ยังไม่ได้ทำ) และตรวจว่า `if (viewModel.isLoading)` ยังคงอยู่เหนือ `PullToRefresh` เพื่อให้การโหลดครั้งแรกเป็นตัวหมุนกลางจอ ส่วนการรีเฟรชคงเนื้อหาเดิม

- [ ] **Step 4: ตรวจด้วยตาทั้งสองฝั่ง**

Run: `flutter run -d chrome`
ตรวจ: ฝั่งเจ้าของหอ — ลากที่รายการ วงแหวนหมุน ปุ่ม "ออกบิลใหม่" กับชิปตัวกรองไม่ขยับ · เลือกตัวกรองที่ไม่มีบิล แล้วลากบนข้อความ "ไม่มีบิลในตัวกรองนี้" ต้องลากได้ · ฝั่งผู้เช่า — ลากแล้วรายการเดิมไม่หาย

- [ ] **Step 5: ตรวจทั้งชุดแล้วส่งข้อความคอมมิท**

Run: `flutter analyze && flutter test`

```bash
git add lib/screens/admin/billing_screen.dart lib/screens/tenant/tenant_bills_screen.dart lib/viewmodels/billing_view_model.dart
```

---

## Task 4 — ท่าทางปัดขอบจอย้อนกลับ

**Files:**
- Modify: `lib/theme/app_theme.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- ไม่มี API ใหม่ · ผลกระทบครอบทุกเส้นทางที่ `Navigator.push` โดยไม่ต้องแก้หน้าจอ

- [ ] **Step 1: ตั้ง pageTransitionsTheme**

`lib/theme/app_theme.dart` — เพิ่ม `import 'package:flutter/foundation.dart' show kIsWeb;` แล้วใส่ใน `baseTheme.copyWith(...)`:

```dart
    // ปัดจากขอบซ้ายเพื่อย้อนกลับ ตั้งที่เดียวครอบทุกเส้นทางที่ push
    //
    // Android (แอป) — PredictiveBack ให้ท่าทางพร้อมพรีวิวหน้าถัดไปตาม
    // มาตรฐาน Android 14+ ซึ่งต้องเปิด enableOnBackInvokedCallback ใน
    // AndroidManifest คู่กัน
    //
    // เว็บ — ต้องแยกด้วย kIsWeb เพราะ PredictiveBack อาศัย platform channel
    // ของ Android ที่ไม่มีบนเบราว์เซอร์ แล้วจะตกกลับไปเป็น zoom transition
    // ซึ่งไม่มีท่าทางลากเลย · CupertinoPageTransitionsBuilder พก
    // CupertinoBackGestureDetector มาในตัว จึงลากกลับได้ทั้งด้วยนิ้วบนมือถือ
    // และด้วยเมาส์บนเดสก์ท็อป
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: kIsWeb
            ? const CupertinoPageTransitionsBuilder()
            : const PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: const CupertinoPageTransitionsBuilder(),
      },
    ),
```

- [ ] **Step 2: เปิด predictive back ฝั่ง Android**

`android/app/src/main/AndroidManifest.xml` — เพิ่มแอตทริบิวต์ที่แท็ก `<application>`:

```xml
    android:enableOnBackInvokedCallback="true"
```

- [ ] **Step 3: ตรวจบนเว็บ**

Run: `flutter run -d chrome`
ตรวจ: เข้าหน้าห้องพัก → เปิดรายละเอียดห้อง → ลากจากขอบซ้ายด้วยเมาส์ → หน้าเลื่อนกลับตามนิ้ว ปล่อยกลางทางแล้วเด้งคืน · เมื่อกลับถึงหน้าห้องพัก ตำแหน่งที่เลื่อนค้างไว้ยังอยู่

- [ ] **Step 4: ตรวจทั้งชุดแล้วส่งข้อความคอมมิท**

Run: `flutter analyze && flutter test`

```bash
git add lib/theme/app_theme.dart android/app/src/main/AndroidManifest.xml
```

---

## Task 5 — คำนวณยอดบิลค้างชำระใหม่ (ตรรกะ + ฐานข้อมูล)

**Files:**
- Modify: `lib/services/invoice_calculator.dart`
- Modify: `lib/services/invoice_service.dart`
- Modify: `lib/models/models.dart`
- Create: `database/invoices_recalculation.sql`
- Modify: `database/invoices_schema.sql`, `database/README.md`
- Create: `test/invoice_revaluation_unit_test.dart`

**Interfaces:**
- Produces: `InvoiceAdjustment` — ฟิลด์ `invoice`, `roomPrice`, `electricityUnits`, `electricityCost`, `waterCost`, `cleaningFee`, `previousTotal`, `newTotal`
- Produces: `InvoiceAdjustment? revalueInvoice({required Invoice invoice, required Room room, MeterCharge? electricity, double? waterAmount, required double cleaningFee})`
- Produces: `Future<List<InvoiceAdjustment>> InvoiceService.syncUnpaidInvoices({required int dormitoryId, required int month, required int year})`
- Produces: `Invoice.recalculatedAt` (`DateTime?`), `Invoice.previousTotal` (`double?`)
- Consumes: `meterUnitsUsed`, `MeterCharge`, `Room` ที่มีอยู่แล้ว

- [ ] **Step 1: เขียนเทสต์กฎทั้งเจ็ดข้อ**

`test/invoice_revaluation_unit_test.dart` — helper `_invoice({status, roomPrice, elecUnits, elecCost, water, cleaning})` และ `_room({price})` สร้างข้อมูลตัวอย่าง แล้วครอบกฎตามสเปก §4.1:

```dart
void main() {
  group('revalueInvoice', () {
    test('บิลที่จ่ายแล้วไม่ถูกแตะ', () {
      final result = revalueInvoice(
        invoice: _invoice(status: InvoiceStatus.paid, elecCost: 300),
        room: _room(price: 3000),
        electricity: const MeterCharge(units: 200, amount: 1000),
        waterAmount: 200,
        cleaningFee: 0,
      );
      expect(result, isNull);
    });

    test('บิลที่รอตรวจสลิปไม่ถูกแตะ', () {
      final result = revalueInvoice(
        invoice: _invoice(status: InvoiceStatus.pending, elecCost: 300),
        room: _room(price: 3000),
        electricity: const MeterCharge(units: 200, amount: 1000),
        waterAmount: 200,
        cleaningFee: 0,
      );
      expect(result, isNull);
    });

    test('งวดที่ไม่มีเลขมิเตอร์ไฟไม่ถูกแตะ แม้ค่าน้ำจะเปลี่ยน', () {
      final result = revalueInvoice(
        invoice: _invoice(elecCost: 300, water: 100),
        room: _room(price: 3000),
        electricity: null,
        waterAmount: 250,
        cleaningFee: 0,
      );
      expect(result, isNull,
          reason: 'เลขมิเตอร์ที่หายไปคือข้อมูลถูกลบ ไม่ใช่ใช้ไฟน้อยลง');
    });

    test('ค่าไฟที่แก้แล้วสะท้อนทั้งหน่วยและจำนวนเงิน', () {
      final result = revalueInvoice(
        invoice: _invoice(elecUnits: 50, elecCost: 300, roomPrice: 3000),
        room: _room(price: 3000),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: null,
        cleaningFee: 0,
      );
      expect(result, isNotNull);
      expect(result!.electricityUnits, 90);
      expect(result.electricityCost, 540);
      expect(result.newTotal, 3540);
      expect(result.previousTotal, 3300);
    });

    test('ไม่มีแถวค่าน้ำ = คงค่าเดิมในบิล', () {
      final result = revalueInvoice(
        invoice: _invoice(elecCost: 300, water: 150, roomPrice: 3000),
        room: _room(price: 3000),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: null,
        cleaningFee: 0,
      );
      expect(result!.waterCost, 150);
    });

    test('ค่าน้ำเป็น 0 ที่กรอกมาจริง = ใช้ 0', () {
      final result = revalueInvoice(
        invoice: _invoice(elecCost: 540, water: 150, roomPrice: 3000),
        room: _room(price: 3000),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: 0,
        cleaningFee: 0,
      );
      expect(result!.waterCost, 0);
    });

    test('ค่าห้องขยับตามราคาห้องปัจจุบัน', () {
      final result = revalueInvoice(
        invoice: _invoice(roomPrice: 3000, elecCost: 540),
        room: _room(price: 3300),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: null,
        cleaningFee: 0,
      );
      expect(result!.roomPrice, 3300);
    });

    test('ทุกค่าเท่าเดิม = ไม่ต้องแก้', () {
      final result = revalueInvoice(
        invoice: _invoice(roomPrice: 3000, elecUnits: 90, elecCost: 540, water: 150, cleaning: 200),
        room: _room(price: 3000),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: 150,
        cleaningFee: 200,
      );
      expect(result, isNull, reason: 'กันข้อความสแปมในแชททุกครั้งที่กดบันทึก');
    });

    test('ค่าทำความสะอาดที่ถูกยกเลิกหายจากบิล', () {
      final result = revalueInvoice(
        invoice: _invoice(roomPrice: 3000, elecCost: 540, cleaning: 200),
        room: _room(price: 3000),
        electricity: const MeterCharge(units: 90, amount: 540),
        waterAmount: null,
        cleaningFee: 0,
      );
      expect(result!.cleaningFee, 0);
    });
  });
}
```

- [ ] **Step 2: รันให้เห็นว่าล้ม**

Run: `flutter test test/invoice_revaluation_unit_test.dart`
Expected: FAIL — ไม่รู้จัก `revalueInvoice`

- [ ] **Step 3: เขียน `revalueInvoice` + `InvoiceAdjustment`**

`lib/services/invoice_calculator.dart` (ต่อท้ายไฟล์ ยังคงเป็น Dart ล้วน ไม่ import supabase/flutter)

```dart
/// สิ่งที่ต้องแก้ในบิลใบหนึ่งเมื่อเทียบกับข้อมูลล่าสุดของงวด
class InvoiceAdjustment {
  const InvoiceAdjustment({
    required this.invoice,
    required this.roomPrice,
    required this.electricityUnits,
    required this.electricityCost,
    required this.waterCost,
    required this.cleaningFee,
    required this.previousTotal,
  });

  final Invoice invoice;
  final double roomPrice;
  final double electricityUnits;
  final double electricityCost;
  final double waterCost;
  final double cleaningFee;
  final double previousTotal;

  double get newTotal => roomPrice + electricityCost + waterCost + cleaningFee;
}

/// เทียบบิลใบหนึ่งกับข้อมูลล่าสุดของงวด · null = ไม่ต้องแตะใบนี้
///
/// บิลตรึงตัวเลข ณ วันออกมาตั้งแต่ spec แรก ซึ่งถูกสำหรับใบที่ผู้เช่าจ่ายไปแล้ว
/// แต่แปลว่าเลขมิเตอร์ที่พิมพ์ผิดหลักเดียวต้องแก้ด้วยการยกเลิกใบเดิมแล้วออกใหม่
/// ซึ่งกินเลขที่บิลและทิ้งการ์ดยอดผิดไว้ในแชทของผู้เช่า · ที่นี่จึงคำนวณใหม่
/// เฉพาะใบที่ยังไม่มีใครจ่าย โดยคงเลขที่บิลและ revision ไว้ตามเดิม
InvoiceAdjustment? revalueInvoice({
  required Invoice invoice,
  required Room room,
  MeterCharge? electricity,
  double? waterAmount,
  required double cleaningFee,
}) {
  // ใบที่ส่งสลิป/จ่าย/ยกเลิกแล้วตรึงตลอดไป — ผู้เช่าจ่ายตามยอดที่เห็น
  // การขยับยอดทีหลังทำให้สลิปกับบิลไม่ตรงกันโดยไม่มีใครผิด
  if (invoice.status != InvoiceStatus.unpaid) return null;

  // บิลที่ออกไปแล้วแปลว่าเคยมีเลขมิเตอร์ การที่มันหายคือข้อมูลถูกลบ ไม่ใช่
  // ผู้เช่าใช้ไฟน้อยลง · กันการลบพลาดกลายเป็นส่วนลดเงียบๆ
  if (electricity == null) return null;

  // "ยังไม่กรอกค่าน้ำ" กับ "กรอกว่าไม่เก็บค่าน้ำ" คนละความหมาย อย่างแรกต้อง
  // คงยอดเดิมของบิลไว้ อย่างหลังคือ 0 ที่ตั้งใจ
  final water = waterAmount ?? invoice.waterCost;

  final adjustment = InvoiceAdjustment(
    invoice: invoice,
    roomPrice: room.price,
    electricityUnits: electricity.units,
    electricityCost: electricity.amount,
    waterCost: water,
    cleaningFee: cleaningFee,
    previousTotal: invoice.total,
  );

  // เศษสตางค์ที่ต่างกันจากการปัดเลขทศนิยมไม่ใช่การเปลี่ยนยอด · เขียนซ้ำโดย
  // ไม่มีอะไรเปลี่ยนแปลว่าผู้เช่าได้ข้อความในแชททุกครั้งที่เจ้าของหอกดบันทึก
  const epsilon = 0.005;
  final unchanged =
      (adjustment.roomPrice - invoice.roomPrice).abs() < epsilon &&
          (adjustment.electricityUnits - invoice.electricityUnits).abs() <
              epsilon &&
          (adjustment.electricityCost - invoice.electricityCost).abs() <
              epsilon &&
          (adjustment.waterCost - invoice.waterCost).abs() < epsilon &&
          (adjustment.cleaningFee - invoice.cleaningFee).abs() < epsilon;

  return unchanged ? null : adjustment;
}
```

- [ ] **Step 4: รันเทสต์ให้ผ่าน**

Run: `flutter test test/invoice_revaluation_unit_test.dart`
Expected: PASS ทั้ง 9 เคส

- [ ] **Step 5: เพิ่มสองฟิลด์ใน `Invoice`**

`lib/models/models.dart` — เพิ่ม `final DateTime? recalculatedAt;` และ `final double? previousTotal;` พร้อมพารามิเตอร์ใน constructor และส่งต่อใน `copyWith` (ทั้งสองตัวไม่อยู่ในรายการที่ `copyWith` รับให้แก้ เพราะเปลี่ยนได้จากการคำนวณใหม่เท่านั้น)

`lib/services/invoice_service.dart` ใน `_invoiceFromRow` อ่านแบบทนคอลัมน์ที่ยังไม่มี ตามแบบเดียวกับ `payment_method`:

```dart
      recalculatedAt: row['recalculated_at'] == null
          ? null
          : DateTime.parse(row['recalculated_at'] as String),
      previousTotal: row['previous_total'] == null
          ? null
          : _toDouble(row['previous_total']),
```

- [ ] **Step 6: เขียน `syncUnpaidInvoices`**

`lib/services/invoice_service.dart` — แยกการดึงข้อมูลงวดที่ `previewDrafts` ใช้อยู่ออกมาเป็น `_fetchPeriodInputs()` (คืน records ของ `electricity_record`, `water_meter`, และแมปค่าทำความสะอาด) แล้วให้ทั้ง `previewDrafts` และเมธอดใหม่ใช้ร่วมกัน

```dart
  /// ปรับยอดบิลค้างชำระของงวดให้ตรงกับข้อมูลล่าสุด · คืนเฉพาะใบที่เปลี่ยนจริง
  ///
  /// เขียนตอนที่เจ้าของหอทำอะไรบางอย่าง ไม่ใช่ตอนที่ใครสักคนเปิดหน้าดู —
  /// ผู้เช่าไม่มีสิทธิ์ UPDATE ตารางนี้ (RLS) และถ้าคำนวณสดตอนแสดงผล QR
  /// พร้อมเพย์กับแถวในฐานข้อมูลจะพูดคนละยอด
  Future<List<InvoiceAdjustment>> syncUnpaidInvoices({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    final rooms = await _service.fetchRooms(dormitoryId: dormitoryId);
    if (rooms.isEmpty) return [];

    final inputs = await _fetchPeriodInputs(
      roomIds: rooms.map((room) => room.dbId).toList(),
      month: month,
      year: year,
    );

    final invoices = await fetchInvoices(
      dormitoryId: dormitoryId,
      month: month,
      year: year,
    );

    final roomsById = {for (final room in rooms) room.dbId: room};
    final adjustments = <InvoiceAdjustment>[];

    for (final invoice in invoices) {
      final room = roomsById[invoice.roomDbId];
      if (room == null) continue;

      final adjustment = revalueInvoice(
        invoice: invoice,
        room: room,
        electricity: inputs.electricityFor(invoice.roomDbId),
        waterAmount: inputs.waterFor(invoice.roomDbId),
        cleaningFee: inputs.cleaningFor(invoice.roomDbId),
      );
      if (adjustment != null) adjustments.add(adjustment);
    }

    for (final a in adjustments) {
      await _client
          .from('invoices')
          .update({
            'room_price': a.roomPrice,
            'electricity_units': a.electricityUnits,
            'electricity_cost': a.electricityCost,
            'water_cost': a.waterCost,
            'cleaning_fee': a.cleaningFee,
            'previous_total': a.previousTotal,
            'recalculated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', a.invoice.dbId)
          // ไม่ใช่ของประดับ — ถ้าผู้เช่ากดส่งสลิปในวินาทีเดียวกัน แถวจะเป็น
          // pending ไปแล้วและคำสั่งนี้จะไม่ match อะไรเลย บิลที่มีสลิปแนบอยู่
          // จึงไม่มีทางถูกขยับยอดแม้ในภาวะแข่งกัน
          .eq('status', InvoiceStatus.unpaid.name);
    }

    return adjustments;
  }
```

`total` ห้ามอยู่ในชุดที่เขียน — เป็น `GENERATED ALWAYS AS` ฐานข้อมูลคำนวณเอง

- [ ] **Step 7: ไฟล์ migration**

`database/invoices_recalculation.sql`

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- HorPlug — ปรับยอดบิลค้างชำระตามข้อมูลล่าสุดของงวด
-- รันหลัง invoices_cash_payment.sql
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ร่องรอยว่าใบนี้เคยถูกคำนวณใหม่ · หน้าจอใช้ขึ้นป้าย "ปรับยอดแล้ว" และผู้เช่า
-- ใช้ดูว่ายอดที่ตัวเองแคปหน้าจอ QR ไว้ยังใช้ได้อยู่ไหม
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS recalculated_at TIMESTAMPTZ;

-- ยอดก่อนการคำนวณครั้งล่าสุด · เก็บไว้เพื่อให้การ์ดบิลบอกได้ว่า "จากเท่าไร"
-- ไม่ใช่แค่ "เปลี่ยนแล้ว" ซึ่งไม่พอให้ผู้เช่าตรวจสอบอะไรได้เลย
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS previous_total NUMERIC;

COMMIT;
```

แก้คอมเมนต์ใน `database/invoices_schema.sql` บรรทัดเหนือ `room_price` จาก
`-- ตัวเลขที่ตรึงไว้ ณ วันออกบิล ห้ามคำนวณใหม่จากมิเตอร์อีก` เป็นข้อความที่บอกความจริงใหม่:
ตรึงสำหรับใบที่ผู้เช่าจ่าย/ส่งสลิป/ยกเลิกแล้ว ส่วนใบที่ยังค้างชำระถูกคำนวณใหม่ได้ตาม
`invoices_recalculation.sql` · เพิ่มไฟล์ใหม่เข้าลำดับการรันใน `database/README.md`

- [ ] **Step 8: ตรวจทั้งชุดแล้วส่งข้อความคอมมิท**

Run: `flutter analyze && flutter test`

```bash
git add lib/services/invoice_calculator.dart lib/services/invoice_service.dart \
        lib/models/models.dart test/invoice_revaluation_unit_test.dart \
        database/invoices_recalculation.sql database/invoices_schema.sql database/README.md
```

ข้อความคอมมิทต้องเตือนให้รัน `database/invoices_recalculation.sql` บน Supabase ก่อนใช้ฟีเจอร์

---

## Task 6 — ยิงการคำนวณจากหน้าจอ + แจ้งผู้เช่า

**Files:**
- Modify: `lib/services/invoice_service.dart`
- Modify: `lib/viewmodels/billing_view_model.dart`, `lib/viewmodels/meter_view_model.dart`
- Modify: `lib/screens/admin/meter_screen.dart`, `lib/screens/admin/billing_screen.dart`
- Modify: `lib/widgets/tenant_bill_card.dart`, `lib/widgets/invoice_detail_sheet.dart`

**Interfaces:**
- Consumes: `syncUnpaidInvoices`, `InvoiceAdjustment`, `Invoice.recalculatedAt`, `Invoice.previousTotal` (Task 5) · `BillingViewModel.refresh()` (Task 3) · `MeterViewModel.saveAll()` (Task 2)
- Produces: `Future<int> InvoiceService.postAdjustmentNotices(List<InvoiceAdjustment>)`

- [ ] **Step 1: ข้อความแจ้งในแชท**

`lib/services/invoice_service.dart`

```dart
  /// แจ้งผู้เช่าว่ายอดบิลเปลี่ยน · คืนจำนวนข้อความที่โพสต์
  ///
  /// เป็น text ไม่ใช่การ์ดบิล — การ์ดใบเดิมที่อยู่ในแชทแล้ว resolve ข้อมูลสด
  /// ผ่าน invoicesByIdForRoom จึงแสดงยอดใหม่เองอยู่แล้ว การส่งการ์ดซ้ำจะได้
  /// การ์ดสองใบที่ยอดเท่ากันในห้องแชทเดียว
  ///
  /// ระบุทั้งยอดเก่าและยอดใหม่ เพราะผู้เช่าที่แคปหน้าจอ QR ระบุยอดไว้ต้องรู้ว่า
  /// ใบที่ถืออยู่ใช้ไม่ได้แล้ว · ไม่ตั้ง invoice_id เพื่อไม่ให้ข้อความนี้ถูก
  /// ตีความเป็นการ์ดโดยตัวเรนเดอร์
  Future<int> postAdjustmentNotices(List<InvoiceAdjustment> adjustments) async {
    if (adjustments.isEmpty) return 0;

    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final rows = adjustments.map((a) {
      return {
        'room_id': a.invoice.roomDbId,
        'sender_id': senderId,
        'is_from_owner': true,
        'body': 'ยอดบิล ${a.invoice.invoiceNo} '
            'งวด${thaiMonthName(a.invoice.billingMonth)} ${a.invoice.billingYear} '
            'เปลี่ยนจาก ${formatBaht(a.previousTotal)} '
            'เป็น ${formatBaht(a.newTotal)} หลังปรับตามเลขมิเตอร์ล่าสุด',
        'message_type': MessageType.text.name,
      };
    }).toList();

    await _client.from('messages').insert(rows);
    return rows.length;
  }
```

- [ ] **Step 2: ต่อเข้าหน้ามิเตอร์**

`lib/viewmodels/meter_view_model.dart` — เพิ่มเมธอดที่คืนจำนวนใบที่ปรับ (ให้หน้าจอเอาไปประกอบข้อความ):

```dart
  /// ปรับยอดบิลค้างชำระของงวดที่เลือก แล้วแจ้งผู้เช่าที่ยอดเปลี่ยน
  ///
  /// แยกจาก [saveAll] เพราะความล้มของสองอย่างนี้มีน้ำหนักต่างกัน — มิเตอร์คือ
  /// ของจริงที่บันทึกไปแล้ว การปรับบิลคือผลพวงของมัน ล้มแล้วบอกได้ ไม่ต้องย้อน
  Future<int> syncInvoicesForPeriod() async { ... }
```

`lib/screens/admin/meter_screen.dart` ใน `_handleSave` — หลัง snackbar "บันทึกข้อมูลมิเตอร์เรียบร้อยแล้ว" และ **ก่อน** `maybeShowIssueInvoicesDialog`:

```dart
    try {
      final adjusted = await viewModel.syncInvoicesForPeriod();
      if (mounted && adjusted > 0) {
        messenger.showSnackBar(SnackBar(
          content: Text('ปรับยอดบิลที่ยังค้างชำระ $adjusted ใบ '
              'และแจ้งผู้เช่าแล้ว'),
        ));
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('ปรับยอดบิลไม่สำเร็จ: ${formatErrorMessage(error)}'),
        ));
      }
    }
```

- [ ] **Step 3: ต่อเข้าหน้าบิล**

`lib/viewmodels/billing_view_model.dart` — `refresh()` ที่ Task 3 สร้างไว้ เปลี่ยนเป็น:

```dart
  /// ท่าทางลากของเจ้าของหอ = ปรับยอดให้ตรงข้อมูลล่าสุดก่อน แล้วค่อยโหลด
  ///
  /// การเขียนจากท่าทางรีเฟรชเป็นเรื่องผิดปกติ จึงทำเฉพาะที่นี่ซึ่งเป็นหน้าของ
  /// เจ้าของหอ (ฝั่งผู้เช่าถูก RLS ปิดอยู่แล้ว) และเป็น no-op เมื่อไม่มีอะไร
  /// เปลี่ยน — ไม่มีการเขียน ไม่มีข้อความ
  String? syncErrorMessage;

  Future<void> refresh() async {
    syncErrorMessage = null;
    try {
      final adjusted = await _service.syncUnpaidInvoices(
        dormitoryId: dormitoryId,
        month: selectedMonth,
        year: selectedYear,
      );
      if (adjusted.isNotEmpty) {
        await _service.postAdjustmentNotices(adjusted);
      }
    } catch (error) {
      // ปรับยอดล้มไม่ควรทำให้ผู้ใช้ไม่ได้เห็นรายการบิลเลย
      syncErrorMessage = formatErrorMessage(error);
    }
    await loadInvoices();
  }
```

`lib/screens/admin/billing_screen.dart` — หลังท่าทางรีเฟรชจบ ถ้า `syncErrorMessage != null` ยิง SnackBar หนึ่งครั้ง (ที่นี่ใช้ SnackBar ได้เพราะผู้ใช้เพิ่งทำท่าทางบนแท็บที่เห็นอยู่ ต่างจาก error ตอนโหลดอัตโนมัติที่หน้านี้จงใจแสดงในตัวหน้าจอ)

- [ ] **Step 4: ป้ายบนการ์ด**

`lib/widgets/tenant_bill_card.dart` และ `_InvoiceCard` ใน `lib/screens/admin/billing_screen.dart` — เมื่อ `invoice.recalculatedAt != null` แสดง `StatusBadge(label: 'ปรับยอดแล้ว', variant: BadgeVariant.warning)` และเมื่อมี `previousTotal` เพิ่มบรรทัดใต้ยอดรวม:

```dart
              Text(
                'ยอดเดิม ${formatBaht(invoice.previousTotal!)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
```

`lib/widgets/invoice_detail_sheet.dart` — เพิ่มแถวแสดงวันที่ปรับยอดเมื่อมี `recalculatedAt`

- [ ] **Step 5: ตรวจด้วยตา (ต้องรัน SQL บน Supabase ก่อน)**

Run: `flutter run -d chrome`
ตรวจ: ออกบิลงวดหนึ่ง → กลับไปหน้ามิเตอร์ แก้เลขมิเตอร์ห้องนั้น → บันทึก → snackbar บอกจำนวนใบที่ปรับ · เปิดหน้าบิลด้วยบัญชีผู้เช่า ลากรีเฟรช → ยอดใหม่ + ป้าย "ปรับยอดแล้ว" + ข้อความในแชท

- [ ] **Step 6: ตรวจทั้งชุดแล้วส่งข้อความคอมมิท**

Run: `flutter analyze && flutter test`

```bash
git add lib/services/invoice_service.dart lib/viewmodels lib/screens lib/widgets
```

---

## Task 7 — Open Sans + Noto Sans Thai

**Files:**
- Create: `lib/assets/fonts/OpenSans-{Regular,SemiBold,Bold}.ttf`, `lib/assets/fonts/NotoSansThai-{Regular,SemiBold,Bold}.ttf`, `lib/assets/fonts/OFL-OpenSans.txt`, `lib/assets/fonts/OFL-NotoSansThai.txt`
- Modify: `pubspec.yaml`, `lib/theme/app_theme.dart`, `lib/main.dart`, `web/index.html`

**Interfaces:**
- ไม่มี API ใหม่ · ทุก `Text` ในแอปได้ฟอนต์ใหม่ผ่าน `DefaultTextStyle` โดยไม่ต้องแก้จุดเรียก

- [ ] **Step 1: ดาวน์โหลดฟอนต์**

```bash
cd lib/assets/fonts
for f in OpenSans-Regular OpenSans-SemiBold OpenSans-Bold; do
  curl -fsSL -o "$f.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/opensans/static/$f.ttf"
done
for f in NotoSansThai-Regular NotoSansThai-SemiBold NotoSansThai-Bold; do
  curl -fsSL -o "$f.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthai/static/$f.ttf"
done
curl -fsSL -o OFL-OpenSans.txt "https://raw.githubusercontent.com/google/fonts/main/ofl/opensans/OFL.txt"
curl -fsSL -o OFL-NotoSansThai.txt "https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthai/OFL.txt"
du -ch *.ttf | tail -1
```

ถ้ารวมทั้งหกไฟล์เกิน 1MB ให้ลบน้ำหนัก SemiBold ทั้งสองตระกูลทิ้ง แล้วประกาศแค่ 400/700
(Flutter เลือกน้ำหนักใกล้เคียงให้เอง) — ต้องตัดสินใจจากตัวเลขจริงที่คำสั่งข้างบนพิมพ์ออกมา

- [ ] **Step 2: ประกาศใน pubspec**

`pubspec.yaml` ใต้ `flutter:` เพิ่มบล็อก `fonts:` (แยกจาก `assets:` ที่ Sarabun ใช้ ห้ามแตะของเดิม)

```yaml
  # ประกาศใต้ fonts: ไม่ใช่ assets: เพราะสองอย่างนี้ทำคนละหน้าที่ — Sarabun
  # ด้านบนเป็น asset เพราะแพ็กเกจ pdf โหลดเองผ่าน rootBundle ส่วนที่นี่ต้องให้
  # ระบบฟอนต์ของ Flutter รู้จักชื่อตระกูลและน้ำหนัก
  fonts:
    - family: Open Sans
      fonts:
        - asset: lib/assets/fonts/OpenSans-Regular.ttf
          weight: 400
        - asset: lib/assets/fonts/OpenSans-SemiBold.ttf
          weight: 600
        - asset: lib/assets/fonts/OpenSans-Bold.ttf
          weight: 700
    - family: Noto Sans Thai
      fonts:
        - asset: lib/assets/fonts/NotoSansThai-Regular.ttf
          weight: 400
        - asset: lib/assets/fonts/NotoSansThai-SemiBold.ttf
          weight: 600
        - asset: lib/assets/fonts/NotoSansThai-Bold.ttf
          weight: 700
```

- [ ] **Step 3: ต่อเข้าธีม**

`lib/theme/app_theme.dart` ใน `ThemeData(...)` ของ `baseTheme`:

```dart
    // Open Sans ไม่มีอักษรไทยสักตัว (มีแค่ latin/greek/cyrillic/hebrew) ตัวไทย
    // จึงตกไป Noto Sans Thai ทีละตัวอักษรผ่าน fallback — ไม่ใช่ทั้งบรรทัด
    // เลขกับคำอังกฤษในประโยคไทยเดียวกันจึงยังเป็น Open Sans
    //
    // ถ้าไม่ประกาศ fallback ตัวไทยจะตกไปใช้ฟอนต์ของระบบ ซึ่งต่างกันทุกเครื่อง
    // (Android=Noto, Windows=Tahoma, iOS=Thonburi) และคุมระยะสระบน-ล่างไม่ได้
    fontFamily: 'Open Sans',
    fontFamilyFallback: const ['Noto Sans Thai'],
```

ห้ามแตะ `_buildTextTheme` — คอมเมนต์ที่มีอยู่อธิบายไว้แล้วว่าการยัด `const TextStyle` ก้อนใหม่
จะทิ้ง `fontFamily`/`height`/`letterSpacing` ไป งานนี้ยิ่งทำให้ข้อนั้นเป็นจริงกว่าเดิม

- [ ] **Step 4: ลงทะเบียนใบอนุญาต**

`lib/main.dart` ใน `main()` ก่อน `runApp`:

```dart
  // ฟอนต์ที่ฝังมากับแอปเป็น SIL OFL 1.1 ทั้งคู่ ซึ่งกำหนดให้แจกใบอนุญาตไปด้วย
  // — หน้า licenses ของ Flutter คือที่ที่ผู้ใช้หามันเจอ
  LicenseRegistry.addLicense(() async* {
    for (final path in const [
      'lib/assets/fonts/OFL-OpenSans.txt',
      'lib/assets/fonts/OFL-NotoSansThai.txt',
    ]) {
      yield LicenseEntryWithLineBreaks(
        const ['google_fonts_bundled'],
        await rootBundle.loadString(path),
      );
    }
  });
```

ต้องเพิ่มไฟล์ `OFL-*.txt` ทั้งสองใต้ `assets:` ใน pubspec ด้วย ไม่งั้น `rootBundle` หาไม่เจอ

- [ ] **Step 5: เว็บ**

`web/index.html` — เพิ่มใน `<head>`:

```html
  <!-- โหลดฟอนต์หลักคู่กับ engine ไม่ใช่หลังจากนั้น · ไม่มีบรรทัดนี้ ตัวหนังสือ
       ชุดแรกจะขึ้นด้วยฟอนต์ระบบแล้วกระโดดเปลี่ยนเมื่อฟอนต์จริงมาถึง -->
  <link rel="preload" as="font" type="font/ttf" crossorigin
        href="assets/lib/assets/fonts/OpenSans-Regular.ttf">
  <link rel="preload" as="font" type="font/ttf" crossorigin
        href="assets/lib/assets/fonts/NotoSansThai-Regular.ttf">
```

และเปลี่ยน `font-family` ของ `#loading` เป็น `"Noto Sans Thai", system-ui, sans-serif`

- [ ] **Step 6: ตรวจด้วยตา**

Run: `flutter run -d chrome`
ตรวจ: ตัวเลขกับคำอังกฤษเป็น Open Sans · ตัวไทยเป็น Noto Sans Thai ไม่ใช่ฟอนต์ระบบ ·
สระบน-ล่าง (เช่น "บันทึกมิเตอร์", "ค้างชำระ") ไม่ชนกับบรรทัดข้างเคียง

- [ ] **Step 7: ตรวจทั้งชุดแล้วส่งข้อความคอมมิท**

Run: `flutter analyze && flutter test`

```bash
git add lib/assets/fonts pubspec.yaml lib/theme/app_theme.dart lib/main.dart web/index.html
```

---

## Task 8 — การแสดงผลทุกขนาดจอ

**Files:**
- Create: `test/responsive_widget_test.dart`
- Modify: หน้าจอที่พบว่าล้น (คาดไว้: `lib/screens/admin/meter_screen.dart`, `billing_screen.dart`, `lib/widgets/tenant_bill_card.dart`)

**Interfaces:**
- Consumes: วิดเจ็ตสาธารณะทั้งหมดจาก Task 1–7

- [ ] **Step 1: เขียนเทสต์ overflow สามขนาด**

`test/responsive_widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/theme/app_theme.dart';
import 'package:horplug/widgets/reusable_widgets.dart';

const _sizes = <String, Size>{
  'compact 360x740': Size(360, 740),
  'medium 800x1280': Size(800, 1280),
  'expanded 1440x900': Size(1440, 900),
};

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: child),
  ));
}

void main() {
  _sizes.forEach((label, size) {
    testWidgets('MobileHeader ไม่ล้นที่ $label', (tester) async {
      await _pumpAt(tester, size,
          const MobileHeader(dormitoryName: 'หอพักสวนดอกไม้บานสะพรั่งยามเช้า'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('StatCard สองใบเรียงกันไม่ล้นที่ $label', (tester) async {
      await _pumpAt(tester, size, const Row(children: [
        Expanded(child: StatCard(
          title: 'ค้างชำระ', value: '฿12,345.00',
          icon: Icons.error_outline, variant: BadgeVariant.warning)),
        SizedBox(width: 12),
        Expanded(child: StatCard(
          title: 'ชำระแล้วปีนี้', value: '฿123,456.00',
          icon: Icons.check_circle_outline, variant: BadgeVariant.success)),
      ]));
      expect(tester.takeException(), isNull);
    });
  });
}
```

เพิ่มเคสของ `TenantBillCard` (พร้อม `recalculatedAt` และ `previousTotal` ที่ Task 6 เพิ่มเข้าไป
เพราะป้ายใหม่คือของที่เสี่ยงล้นที่สุด) และ `AdaptiveNavigationScaffold` ที่มีปลายทางห้าอัน

- [ ] **Step 2: รันแล้วดูว่าอันไหนล้มจริง**

Run: `flutter test test/responsive_widget_test.dart`
Expected: เคสที่ล้มคือรายการงานของ Step 3 — ถ้าไม่ล้มสักเคส ให้เพิ่มข้อความยาวขึ้นจนสะท้อน
ข้อมูลจริงที่ยาวที่สุดที่ระบบรับได้ (ชื่อหอ 60 ตัวอักษร, ยอด 7 หลัก, ชื่อผู้เช่าเต็มยศ)

- [ ] **Step 3: แก้จุดที่ล้น**

รูปแบบที่ใช้ตามลำดับความชอบ: `Expanded`/`Flexible` + `overflow: TextOverflow.ellipsis` →
`Wrap` เมื่อสองก้อนอยู่บรรทัดเดียวไม่ได้จริงๆ → `FittedBox` เป็นทางเลือกสุดท้ายเพราะย่อ
ตัวอักษรจนอ่านไม่ออกได้

จุดที่คาดไว้ล่วงหน้า: หัวหน้ามิเตอร์และหัวหน้าบิล (`Row` ที่มีคอลัมน์ข้อความคู่กับ
`PrimaryButton` ที่ป้ายยาวขึ้นเป็น "กำลังบันทึก...") · การ์ดมิเตอร์ค่าไฟ · การ์ดบิลที่มีป้าย
"ปรับยอดแล้ว" เพิ่มเข้ามา

- [ ] **Step 4: ตรวจด้วยตาบนเว็บ**

Run: `flutter run -d chrome`
ตรวจ: ย่อหน้าต่างจนแคบสุด (~360px) แล้วไล่ทุกแท็บทั้งสองบทบาท ต้องไม่มีแถบเหลือง-ดำ ·
ขยายเต็มจอ 1440px ต้องไม่มีเนื้อหาทอดยาวติดขอบทั้งสองข้าง

- [ ] **Step 5: ตรวจทั้งชุดแล้วส่งข้อความคอมมิท**

Run: `flutter analyze && flutter test`

```bash
git add test/responsive_widget_test.dart lib/screens lib/widgets
```

---

## Self-Review

**Spec coverage:**

| สเปก | งานที่ทำ |
|---|---|
| §1 โครงการรีเฟรช | Task 1 |
| §2 หน้ามิเตอร์ | Task 2 (§2.4 การยิงคำนวณอยู่ใน Task 6) |
| §3 หน้าบิล | Task 3 (§3.1 การยิงคำนวณอยู่ใน Task 6) |
| §4 คำนวณยอดใหม่ | Task 5 |
| §5 แจ้งผู้เช่า | Task 6 |
| §6 ท่าทางย้อนกลับ | Task 4 |
| §7 ฟอนต์ | Task 7 |
| §8 ข้ามอุปกรณ์ | Task 8 |
| §9 เทสต์ | กระจายอยู่ใน Task 1, 2, 5, 8 |

**Type consistency:** `RefreshableViewModel.runLoad` · `PullToRefresh(onRefresh:child:)` ·
`CenteredScrollable(child:padding:)` · `MeterViewModel.hasUnsavedEdits` ·
`BillingViewModel.refresh()` · `revalueInvoice(...) → InvoiceAdjustment?` ·
`InvoiceAdjustment.previousTotal/newTotal` · `syncUnpaidInvoices(...) → List<InvoiceAdjustment>` ·
`postAdjustmentNotices(...) → int` — ชื่อเดียวกันทุกที่ที่ถูกอ้างถึงข้ามงาน
