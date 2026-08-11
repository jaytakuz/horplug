# Invoice Generation — Demo Mode Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ให้ผู้ใช้ล็อกอินด้วยบัญชีนำเสนอสองบัญชีแล้วเดินผ่านฟีเจอร์ Invoice Generation ได้ครบวงจรบนแอปจริง โดยไม่ต่อเครือข่ายเลย

**Architecture:** ข้อมูลทั้งหมดของโหมดนำเสนออยู่ในหน่วยความจำ เสียบเข้าระบบผ่านรูที่ ViewModel มีอยู่แล้ว (ทุกตัวรับ service ผ่าน constructor และ default ไปที่ตัวจริง) อุปสรรคเดียวคือ `SupabaseService` และ `InvoiceService` อ่าน `Supabase.instance` ตอน field initializer จึงสืบทอดไม่ได้ — เปลี่ยนเป็น getter แล้วสร้างคลาสลูกที่ override เฉพาะเมธอดที่โหมดนำเสนอใช้

**Tech Stack:** Flutter 3 / Dart 3 · provider (MVVM) · `pdf` + `printing` (เพิ่มใน D5)

**แผนหลักที่อ้างอิง:** `docs/superpowers/plans/2026-08-04-invoice-generation.md`
**สเปก:** `docs/superpowers/specs/2026-08-04-invoice-generation-design.md`

## ลำดับที่ใช้จริง (ตัดสินใจ 2026-08-04)

สลับลำดับตามที่ผู้ใช้เลือก: **สร้างหน้าจอ Task 4-9 ของแผนหลักให้ครบก่อน แล้วค่อยวางชั้นออฟไลน์ทับ**

เหตุผลคือหน้าจอเห็นผลทันทีและเป็นของจริงทุกบรรทัด ส่วน D1 (รากฐานออฟไลน์) เป็นงานที่หนักที่สุด
แต่ไม่ทำให้เห็นอะไรใหม่บนจอเลย จึงย้ายไปท้ายสุด

| ลำดับ | ทำอะไร | อ้างอิง |
|---|---|---|
| 1 | ออกบิลทั้งหอจากกล่องตรวจก่อนออก | แผนหลัก Task 4 |
| 2 | ช่องทางชำระเงินจริงในแผ่นชำระเงิน | แผนหลัก Task 5 |
| 3 | การ์ดบิลในแชท | แผนหลัก Task 6 |
| 4 | อนุมัติหรือปฏิเสธสลิป | แผนหลัก Task 7 |
| 5 | ยกเลิกบิลแล้วออกใบแทน | แผนหลัก Task 8 |
| 6 | Export PDF | แผนหลัก Task 9 |
| 7 | รากฐานออฟไลน์ + ปุ่มเริ่มการนำเสนอใหม่ | D1 และ D5 ท้ายไฟล์นี้ |

ระหว่างขั้นที่ 1-6 แอปยังต่อ Supabase จริง โหมดนำเสนอแบบไม่ต่อเน็ตเกิดขึ้นที่ขั้นที่ 7
D2-D4 ในไฟล์นี้จึงถูกกลืนเข้าไปในขั้นที่ 1-6 แล้ว เหลือ D1 และส่วน "ปุ่มเริ่มการนำเสนอใหม่" ของ D5

## ความสัมพันธ์กับแผนหลัก

แผนหลักหยุดไว้ที่ Task 3 (อ่านบิลจากฐานข้อมูลได้ทั้งสองฝั่ง) ส่วน Task 4-9 ยังไม่ได้ทำ

**UI ที่แผนนี้สร้างคือ UI ของ Task 4-9 ตัวจริง ไม่ใช่ของทิ้ง** ทุก widget ต้องสร้างตามที่แผนหลักระบุไว้เป๊ะ ต่างกันแค่ปลายทางของข้อมูล วันที่กลับมาทำ Task 4-9 ให้สมบูรณ์ งานที่เหลือคือเขียนเมธอดฝั่ง Supabase ให้ครบแล้วเลิก override ไม่ต้องแตะหน้าจอ

เมื่อสร้าง widget ตัวใดตัวหนึ่ง **ให้เปิดแผนหลักหัวข้อ Task ที่ตรงกันอ่านก่อนเสมอ** — โค้ดและเหตุผลอยู่ที่นั่น

| widget | แผนหลัก |
|---|---|
| `issue_invoices_dialog.dart` | Task 4 |
| ช่องทางชำระเงินใน `payment_sheet.dart` | Task 5 |
| `invoice_chat_card.dart` | Task 6 |
| `slip_review_sheet.dart` · `invoice_detail_sheet.dart` | Task 7 |
| ยกเลิก + ออกใบแทน | Task 8 |
| `invoice_pdf.dart` | Task 9 |

## Global Constraints

- **ผู้ใช้เป็นคน commit และ push เอง** ทุก Task จบด้วยการรายงานแล้วหยุด ห้ามรัน `git commit` หรือ `git push`
- `flutter analyze` baseline **14 issues** · `flutter test` baseline **154 ผ่าน** — ห้ามเกิน ห้ามลด ห้ามไปแก้ baseline
- บัญชีนำเสนอ: **`jaylandlord@gmail.com`** (เจ้าของหอ) และ **`jaytenant@gmail.com`** (ผู้เช่า) — รหัสผ่านอะไรก็ผ่าน
- **โหมดนำเสนอต้องเงียบ** ไม่มีแบนเนอร์ ไม่มีป้าย ไม่มีคำว่า demo/ตัวอย่าง/ทดสอบ ให้ผู้ชมเห็น หน้าจอต้องดูเหมือนของจริงทุกประการ
- **ห้ามเรียกเครือข่ายในโหมดนำเสนอแม้แต่ครั้งเดียว** ถ้าเมธอดไหนไม่ได้ override แล้วถูกเรียก ต้องโยน `UnimplementedError` พร้อมชื่อเมธอด ไม่ใช่เงียบๆ ไปเรียก Supabase
- ผู้ใช้จริงคนอื่นต้องไม่ได้รับผลกระทบเลย — โหมดนำเสนอเปิดเฉพาะเมื่ออีเมลตรงสองตัวนี้
- จำนวนเงินผ่าน `formatBaht()` หน่วยผ่าน `formatUnits()` เดือนผ่าน `thaiMonthName()` ปีเป็น ค.ศ.
- ข้อความผู้ใช้เป็นภาษาไทย
- ค่าใน `InvoiceStatus` คือ `unpaid` `pending` `paid` `voided`
- เลขที่บิล `INV-{YYYYMM}-{เลขห้อง}` ต่อท้าย `-R{n}` เมื่อ revision > 1 · ครบกำหนดวันที่ 5 ของเดือนถัดไป
- ช่องทางชำระ: ธนาคารกสิกรไทย **1438323216** · QR `lib/assets/sample_paymant_qrcode.jpg`

## File Structure

**สร้างใหม่**

| ไฟล์ | รับผิดชอบอะไร |
|---|---|
| `lib/services/demo/demo_mode.dart` | รู้ว่าโหมดนำเสนอเปิดอยู่หรือไม่ และเปิดให้ใคร |
| `lib/services/demo/demo_dataset.dart` | ข้อมูลตั้งต้นทั้งหมด — หอ ห้อง ผู้เช่า มิเตอร์ บิล แชท คำขอซ่อม |
| `lib/services/demo/demo_store.dart` | สถานะที่เปลี่ยนได้ระหว่างนำเสนอ + `reset()` |
| `lib/services/demo/demo_data_service.dart` | `extends SupabaseService` override เมธอดที่หน้าจอเรียก |
| `lib/services/demo/demo_invoice_service.dart` | `extends InvoiceService` override ทั้งหมด |
| `lib/services/demo/demo_tenant_billing_source.dart` | `implements TenantBillingSource` |
| `lib/services/service_factory.dart` | จุดเดียวที่ตัดสินว่าจะสร้างตัวจริงหรือตัวนำเสนอ |
| `lib/widgets/issue_invoices_dialog.dart` | กล่องตรวจก่อนออกบิล (Task 4) |
| `lib/widgets/invoice_chat_card.dart` | การ์ดบิลในฟองแชท (Task 6) |
| `lib/widgets/slip_review_sheet.dart` | แผ่นตรวจสลิป (Task 7) |
| `lib/widgets/invoice_detail_sheet.dart` | รายละเอียดบิลฝั่งเจ้าของหอ (Task 7) |
| `lib/viewmodels/invoice_issue_view_model.dart` | สถานะกล่องตรวจก่อนออกบิล (Task 4) |
| `lib/services/invoice_pdf.dart` | เอกสาร PDF (Task 9) |
| `test/demo_mode_unit_test.dart` | การเลือกโหมด และความสมเหตุสมผลของชุดข้อมูล |

**แก้ไข**

| ไฟล์ | ทำอะไร |
|---|---|
| `lib/services/supabase_service.dart` | `client` จาก field เป็น getter |
| `lib/services/invoice_service.dart` | ทำให้สืบทอดได้ · เมธอดที่ demo ต้อง override ต้องไม่เป็น private |
| `lib/services/auth_service.dart` | สองอีเมลนี้เข้าได้โดยไม่เรียกเครือข่าย |
| `lib/screens/**` ที่สร้าง ViewModel | สร้าง service ผ่าน `service_factory.dart` |
| `lib/widgets/payment_sheet.dart` | ช่องทางชำระเงินจริง + ปุ่ม PDF (Task 5, 9) |
| `lib/widgets/chat_conversation_view.dart` | เรนเดอร์ `MessageType.invoice` (Task 6) |
| `lib/models/models.dart` | `MessageType.invoice` · `ChatMessage.invoiceId` (Task 6) |
| `lib/screens/admin/billing_screen.dart` | ปุ่มออกบิล · เมนู ⋮ · ตรวจสลิป (Task 4, 7, 8) |
| `pubspec.yaml` | dependency `pdf` `printing` · asset ฟอนต์ Sarabun |

---

## D1: รากฐาน — สลับ service ได้ ล็อกอินได้ และมีข้อมูลครบ

Task ที่ใหญ่ที่สุดในแผนนี้ ทุก Task ที่เหลือยืนบนมัน จบ D1 แล้วต้องล็อกอินสองบัญชีแล้วเห็นทุกหน้าจอที่มีอยู่วันนี้ทำงานได้โดยไม่ต่อเน็ต

**Files:**
- Modify: `lib/services/supabase_service.dart` (`client` เป็น getter)
- Modify: `lib/services/invoice_service.dart` (ทำให้สืบทอดได้)
- Modify: `lib/services/auth_service.dart`
- Create: `lib/services/demo/demo_mode.dart` · `demo_dataset.dart` · `demo_store.dart` · `demo_data_service.dart` · `demo_invoice_service.dart` · `demo_tenant_billing_source.dart`
- Create: `lib/services/service_factory.dart`
- Modify: หน้าจอทุกหน้าที่สร้าง ViewModel เอง
- Test: `test/demo_mode_unit_test.dart`

**Interfaces (Task ถัดไปพึ่งพาชื่อเหล่านี้):**
- `DemoMode.activate(String email)` · `DemoMode.isActive` · `DemoMode.role` · `DemoMode.deactivate()`
- `DemoStore.instance` — ถือสถานะที่เปลี่ยนได้ · `DemoStore.instance.reset()`
- `createDataService()` → `SupabaseService` · `createInvoiceService()` → `InvoiceService` · `createTenantBillingSource()` → `TenantBillingSource`

- [ ] **Step 1: เปิดทางให้สืบทอด**

`lib/services/supabase_service.dart`

```dart
class SupabaseService {
  // เป็น getter ไม่ใช่ field เพื่อให้คลาสลูก (โหมดนำเสนอ, เทสต์) สร้างตัวเองได้
  // โดยไม่ไปแตะ Supabase.instance ซึ่ง assert เมื่อยังไม่ initialize
  SupabaseClient get client => Supabase.instance.client;
```

ทำแบบเดียวกันกับ `InvoiceService` และตรวจว่าเมธอดที่โหมดนำเสนอต้องเปลี่ยนพฤติกรรมไม่ได้เป็น private — ถ้าเป็น ให้เปลี่ยนเป็น `@protected` แทนการทำ public เต็มตัว

รัน `flutter test` ทันทีหลังแก้สองบรรทัดนี้ ต้องยังผ่าน 154

- [ ] **Step 2: `lib/services/demo/demo_mode.dart`**

```dart
/// โหมดนำเสนอ — เปิดเฉพาะสองบัญชีที่ใช้สาธิตฟีเจอร์ให้ผู้อื่นดู
///
/// เจตนาคือให้แอปทั้งแอปทำงานจากหน่วยความจำ ไม่แตะเครือข่ายแม้แต่ครั้งเดียว
/// เพราะการนำเสนอมักเกิดในที่ที่เน็ตเชื่อถือไม่ได้
library;

import '../../models/models.dart';

const _landlordEmail = 'jaylandlord@gmail.com';
const _tenantEmail = 'jaytenant@gmail.com';

class DemoMode {
  static AppRole? _role;

  static bool get isActive => _role != null;
  static AppRole? get role => _role;

  static bool accepts(String email) {
    final normalized = email.trim().toLowerCase();
    return normalized == _landlordEmail || normalized == _tenantEmail;
  }

  static void activate(String email) {
    final normalized = email.trim().toLowerCase();
    _role = normalized == _landlordEmail ? AppRole.landlord : AppRole.tenant;
  }

  static void deactivate() => _role = null;
}
```

- [ ] **Step 3: ชุดข้อมูลตั้งต้น `demo_dataset.dart`**

ต้องเล่าเรื่องได้ครบในหน้าจอเดียว ให้สร้าง

- หอ 1 แห่ง ชื่อไทย · 8 ห้องบน 3 ชั้น · 6 ห้องมีผู้เช่า 2 ห้องว่าง
- ห้องของ `jaytenant@gmail.com` คือห้อง **301**
- มิเตอร์ไฟและน้ำย้อนหลัง 6 เดือนทุกห้องที่มีผู้เช่า ตัวเลขสมจริง ไม่ใช่เลขกลม
- **งวดล่าสุดมีมิเตอร์ครบแต่ยังไม่ออกบิล** เพื่อให้กดปุ่ม "ออกบิลใหม่" สาธิตสดได้
- หนึ่งห้องในงวดล่าสุด **ยังไม่จดมิเตอร์** เพื่อให้กล่องตรวจก่อนออกบิลมีรายการ "ข้าม" ให้เห็น
- บิลงวดก่อนหน้าครบทั้งสี่สถานะ: ห้องหนึ่ง `unpaid` · ห้องหนึ่ง `pending` พร้อมสลิป · ที่เหลือ `paid` · และหนึ่งคู่ที่เป็น `voided` พร้อมใบแทน `-R2`
- บิลที่ถูกปฏิเสธสลิปหนึ่งใบ มี `rejectionReason` ให้เห็นกล่องเหตุผลฝั่งผู้เช่า
- แชทของห้อง 301 มีข้อความจริง การ์ดบิล และข้อความอนุมัติ/ปฏิเสธคละกัน
- คำขอซ่อมและคำขอทำความสะอาดอย่างละ 1-2 รายการ อันหนึ่งเสร็จแล้วมีค่าบริการเข้าบิล

ชุดข้อมูลเป็น `const` หรือฟังก์ชันที่คืนของใหม่ทุกครั้ง เพื่อให้ `reset()` คืนค่าได้จริง

วันที่ทั้งหมดคำนวณจาก "วันนี้" ไม่ใช่ค่าคงที่ ไม่งั้นเดือนหน้าเปิดมา demo จะดูเก่า

- [ ] **Step 4: `demo_store.dart`**

ถือสำเนาที่แก้ได้ของชุดข้อมูล เปิด `reset()` ให้กลับค่าเริ่มต้น และเป็น singleton เพราะสถานะต้องอยู่รอดข้ามการสลับแท็บ

- [ ] **Step 5: คลาสลูกทั้งสาม**

`DemoDataService extends SupabaseService` — override เมธอดที่หน้าจอเรียกจริง อย่างน้อย `fetchRooms` `fetchRoom` `fetchElectricityRecords` `fetchWaterRecords` `fetchDormitoryInfo` `watchMessages` `sendMessage` `fetchChatPreviews` `countUnreadMessages` `countUnreadMessagesForRoom` `markRoomRead` `fetchLatestMessage` `fetchMaintenanceRequests` `createMaintenanceRequest` `updateMaintenanceStatus` `fetchRoomStream`

เมธอดที่ไม่ override ต้องไม่หลุดไปเรียกเครือข่าย — ถ้าคลาสแม่มีเมธอดที่ demo ไม่รองรับ ให้ override ให้โยน `UnimplementedError('DemoDataService ไม่รองรับ <ชื่อ>')` ชัดๆ

`DemoInvoiceService extends InvoiceService` และ `DemoTenantBillingSource implements TenantBillingSource` — อ่านเขียน `DemoStore` ทั้งหมด `uploadSlip` แค่คืน path ปลอมโดยไม่แตะ storage

- [ ] **Step 6: `service_factory.dart`**

```dart
SupabaseService createDataService() =>
    DemoMode.isActive ? DemoDataService() : SupabaseService();
```
และอีกสองตัวในรูปแบบเดียวกัน จากนั้นแก้ทุกหน้าจอที่สร้าง ViewModel ให้ส่ง service จาก factory เข้าไป

- [ ] **Step 7: ล็อกอิน**

ใน `AuthService.signIn` ถ้า `DemoMode.accepts(email)` ให้ `DemoMode.activate(email)` แล้วคืนทันทีโดยไม่เรียก `_client.auth` และ `fetchCurrentUserProfile` คืนโปรไฟล์จาก `DemoStore` เมื่อโหมดนำเสนอเปิดอยู่ ส่วน `signOut` ต้องเรียก `DemoMode.deactivate()` และ `DemoStore.instance.reset()`

รหัสผ่านอะไรก็ผ่าน แต่ต้องไม่ว่าง เพื่อไม่ให้ปุ่มเข้าสู่ระบบดูพังตอนสาธิต

- [ ] **Step 8: `test/demo_mode_unit_test.dart`**

ทดสอบสิ่งที่เป็นตรรกะบริสุทธิ์เท่านั้น

- `DemoMode.accepts` ยอมรับสองอีเมลนี้ไม่สนตัวพิมพ์และช่องว่างหัวท้าย และปฏิเสธอีเมลอื่น
- `activate` ให้ role ถูกฝั่ง
- ชุดข้อมูลตั้งต้นสมเหตุสมผล: ทุกบิลมี `total` เท่าผลบวกรายการ · มีบิลครบทั้งสี่สถานะ · งวดล่าสุดมีอย่างน้อยหนึ่งห้องที่ยังไม่ออกบิล · มีอย่างน้อยหนึ่งห้องที่ยังไม่จดมิเตอร์
- `reset()` คืนค่าหลังจากแก้แล้วจริง

- [ ] **Step 9: ตรวจ**

```bash
flutter analyze
flutter test
flutter run
```

ล็อกอินด้วยทั้งสองบัญชี **โดยปิด Wi-Fi และเน็ตมือถือ** แล้วเดินทุกแท็บที่มีอยู่วันนี้ — แดชบอร์ด ห้อง มิเตอร์ บิล แชท ซ่อมบำรุง โปรไฟล์ ต้องไม่มีหน้าไหนค้างโหลดหรือขึ้น error

- [ ] **Step 10: หยุดและรายงานผู้ใช้**

---

## D2: ออกบิลทั้งหอ และช่องทางชำระเงินจริง

**Files:** `lib/viewmodels/invoice_issue_view_model.dart` · `lib/widgets/issue_invoices_dialog.dart` · `lib/screens/admin/billing_screen.dart` · `lib/widgets/payment_sheet.dart` · `pubspec.yaml`

อ่านแผนหลัก **Task 4** และ **Task 5** ก่อนเขียน — โค้ดและเหตุผลอยู่ที่นั่น สร้างตามนั้นทุกประการ ต่างแค่ `InvoiceService` ที่ฉีดเข้ามาเป็นตัวที่ `service_factory` คืนให้

เพิ่มเติมสำหรับโหมดนำเสนอ: `DemoInvoiceService.issueInvoices` ต้องเขียนลง `DemoStore` จริง เพื่อให้กดออกบิลแล้วรายการขึ้นทันทีและอยู่รอดจนจบการนำเสนอ

- [ ] ตรวจ: กด "ออกบิลใหม่" ในงวดล่าสุด ต้องเห็นรายการที่จะออกและรายการที่ข้ามพร้อมเหตุผล กดออกแล้วบิลขึ้นครบ กดซ้ำต้องขึ้น "ออกบิลงวดนี้ไปแล้ว" ทุกห้อง
- [ ] ตรวจ: ฝั่งผู้เช่ากดชำระเงิน เห็น QR และเลขบัญชีกสิกรไทย คัดลอกได้ ไม่มีคำว่าตัวอย่างเหลืออยู่
- [ ] หยุดและรายงานผู้ใช้

## D3: การ์ดบิลในแชท

**Files:** `lib/models/models.dart` · `lib/widgets/invoice_chat_card.dart` · `lib/widgets/chat_conversation_view.dart` · `lib/viewmodels/chat_view_model.dart` · `lib/viewmodels/tenant_chat_view_model.dart`

อ่านแผนหลัก **Task 6** ก่อนเขียน ยกเว้นสองข้อ: ไม่ต้องรัน SQL เพิ่ม (โหมดนำเสนอไม่มีฐานข้อมูล) และ `postIssueNotices` เขียนลง `DemoStore` แทน

- [ ] ตรวจ: ออกบิลแล้วการ์ดโผล่ในแชทห้องนั้นทั้งสองฝั่ง กดแล้วเปิดบิลได้ · จ่ายบิลแล้วปิดเปิดแชทใหม่ ป้ายสถานะบนการ์ดต้องเปลี่ยนตาม
- [ ] หยุดและรายงานผู้ใช้

## D4: ตรวจสลิป รายละเอียดบิล ยกเลิกและออกใบแทน

**Files:** `lib/widgets/slip_review_sheet.dart` · `lib/widgets/invoice_detail_sheet.dart` · `lib/viewmodels/billing_view_model.dart` · `lib/screens/admin/billing_screen.dart` · `lib/screens/admin/chat_screen.dart`

อ่านแผนหลัก **Task 7** และ **Task 8** ก่อนเขียน

โหมดนำเสนอไม่มี storage จริง ให้แผ่นตรวจสลิปแสดงรูปสลิปจาก asset แทน signed URL — ใช้ `lib/assets/sample_paymant_qrcode.jpg` ไปก่อนได้ถ้ายังไม่มีรูปสลิปตัวอย่าง

`TextEditingController` ของกล่องกรอกเหตุผลต้องเป็นของ `StatefulWidget` และ dispose ใน `State.dispose()` — **ห้าม dispose ใน `finally` หลัง `showDialog`** ดูเหตุผลใน commit `64bb83e`

- [ ] ตรวจเส้นทางเต็ม: ผู้เช่าอัปสลิป → เจ้าของหอเปิดดู → ปฏิเสธพร้อมเหตุผล → ผู้เช่าเห็นเหตุผล → อัปใหม่ → อนุมัติ → ยกเลิกบิลแล้วออกใบแทน `-R2`
- [ ] ตรวจ: กดยกเลิกกล่องกรอกเหตุผลแทนที่จะยืนยัน ต้องไม่มี exception เรื่อง controller ถูก dispose
- [ ] หยุดและรายงานผู้ใช้

## D5: PDF และการเตรียมพร้อมนำเสนอ

**Files:** `lib/services/invoice_pdf.dart` · `pubspec.yaml` · `lib/assets/fonts/` · `test/invoice_pdf_unit_test.dart` · `lib/screens/tenant/tenant_profile_screen.dart`

อ่านแผนหลัก **Task 9** ก่อนเขียน ระวังเรื่องฟอนต์ไทยเป็นพิเศษ — ไม่ฝังฟอนต์แล้วบิลจะออกมาเป็นกล่องว่างทั้งใบโดยไม่มี error

เพิ่ม **ปุ่มเริ่มการนำเสนอใหม่** ในหน้าโปรไฟล์ เห็นเฉพาะเมื่อ `DemoMode.isActive` เรียก `DemoStore.instance.reset()` แล้วรีเฟรช เพื่อให้สาธิตรอบสองได้โดยไม่ต้องปิดแอป ข้อความบนปุ่มต้องไม่มีคำว่า demo — ใช้ "เริ่มการนำเสนอใหม่"

- [ ] ตรวจ: เปิด PDF จากทั้งฝั่งเจ้าของหอและผู้เช่า ภาษาไทยอ่านออกไม่ใช่กล่องว่าง ตัวเลขตรงกับหน้าจอ บิลที่ชำระแล้วมีลายน้ำ บิลที่ยกเลิกมีลายน้ำ
- [ ] ตรวจซ้อมใหญ่: ปิดเน็ต ล็อกอินเจ้าของหอ เดินครบวงจร แล้วกดเริ่มใหม่ ทำซ้ำอีกรอบต้องได้ผลเหมือนเดิมเป๊ะ
- [ ] หยุดและรายงานผู้ใช้

---

## เมื่อกลับมาทำของจริง

โหมดนำเสนอไม่ได้แทนที่แผนหลัก งานที่เหลือของ Task 4-9 คือเขียนเมธอดฝั่ง Supabase ให้ครบ แล้วลบคลาสลูกในโฟลเดอร์ `demo/` ทิ้ง — หน้าจอทั้งหมดใช้ต่อได้โดยไม่ต้องแก้

รายการที่พักไว้จากรีวิว Task 3 และต้องสะสางตอนนั้น อยู่ใน `.superpowers/sdd/2026-08-04-invoice-generation/progress.md`
