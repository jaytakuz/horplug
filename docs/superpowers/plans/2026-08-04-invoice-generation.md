# Invoice Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ทำให้บิลที่ออกแล้วเป็นแถวจริงในฐานข้อมูลที่ตัวเลขถูกตรึง มีวงจรชำระเงินครบวงตั้งแต่ออกบิลถึงเจ้าของหออนุมัติสลิป โพสต์การ์ดบิลเข้าแชทอัตโนมัติ และ export เป็น PDF ได้

**Architecture:** ตารางเดียว `invoices` เก็บค่าใช้จ่ายสี่ช่องที่ตรึง ณ วันออกบิล พร้อม generated column `total` และ partial unique index ที่บังคับ "หนึ่งห้อง หนึ่งงวด หนึ่งบิล" ฝั่ง Dart แยกตรรกะบริสุทธิ์ (`invoice_calculator.dart`, `invoice_lifecycle.dart`) ออกจากชั้นที่คุยกับ Supabase (`invoice_service.dart`) เพื่อให้เขียน unit test ได้โดยไม่แตะเครือข่าย และแยกชนิด `InvoiceDraft` (คำนวณสด) ออกจาก `Invoice` (ตรึงแล้ว) เพื่อให้ compiler กันการเผลอแสดงตัวเลขผิดชนิด

**Tech Stack:** Flutter 3 / Dart 3 · Supabase (Postgres + RLS + Storage) · provider (MVVM) · `pdf` + `printing` (เพิ่มใหม่ใน Task 9)

**สเปกอ้างอิง:** `docs/superpowers/specs/2026-08-04-invoice-generation-design.md`
**ข้อความคอมมิท:** `docs/superpowers/specs/2026-08-04-invoice-generation-commits.md`

## Global Constraints

- **ผู้ใช้เป็นคน commit และ push เอง** ทุก Task จบด้วยการรายงานผลการตรวจสอบแล้วหยุด ห้ามรัน `git commit` หรือ `git push`
- ทุก Task ต้อง **ไม่เพิ่ม issue ใหม่** ใน `flutter analyze` และ `flutter test` ต้องผ่านทั้งหมดก่อนรายงาน
  - baseline ณ วันเริ่มงานคือ **14 issues** ซึ่งไม่ใช่ของฟีเจอร์นี้: 10 ข้อมาจาก `scripts/populate_utility_records.dart` ที่ยังไม่ถูก track, deprecation ของ `anonKey` ใน `main.dart:39` และ `test/auth_unit_test.dart:102`, `createSignedUrls` ใน `supabase_service.dart:563` และ super parameter ใน `auth_view_model.dart:170`
  - ห้ามไปแก้ baseline ระหว่างทาง เป็นงานคนละเรื่องกับฟีเจอร์นี้ — ถ้าตัวเลขขยับเกิน 14 แปลว่า Task นั้นเพิ่มของใหม่เข้ามา
  - baseline ของเทสต์คือ **131 ตัวผ่านทั้งหมด**
- ข้อความที่ผู้ใช้เห็นทั้งหมดเป็นภาษาไทย · คอมเมนต์อธิบาย "ทำไม" เป็นภาษาไทยหรืออังกฤษตามไฟล์ที่แก้
- ปีทุกที่ในแอปใช้ **ค.ศ.** ห้ามแปลงเป็น พ.ศ.
- ค่าใน `status` ฝั่ง Postgres สะกดตรงกับ `InvoiceStatus.<ชื่อ>.name` ฝั่ง Dart เป๊ะ: `unpaid`, `pending`, `paid`, `voided`
- จำนวนเงินทุกจุดแสดงผ่าน `formatBaht()` และจำนวนหน่วยผ่าน `formatUnits()` จาก `lib/utils/formatters.dart` ห้าม `toStringAsFixed` เอง
- ชื่อเดือนภาษาไทยใช้ `thaiMonthName()` จาก `lib/viewmodels/tenant_dashboard_view_model.dart`
- ไฟล์ที่ไม่ import `package:flutter` หรือ `supabase_flutter` ได้ ให้คงความบริสุทธิ์นั้นไว้ — `formatters.dart` อธิบายเหตุผลไว้แล้วว่า `SupabaseService` สร้าง client ตอน field initializer จึงสร้าง ViewModel ใน unit test ไม่ได้
- เลขบัญชีรับเงินเฟสนี้: **ธนาคารกสิกรไทย 1438323216** · QR: `lib/assets/sample_paymant_qrcode.jpg`
- กำหนดชำระ = วันที่ 5 ของเดือนถัดจากงวด
- รูปแบบเลขที่บิล: `INV-{YYYYMM}-{เลขห้อง}` และ `-R{revision}` ต่อท้ายเมื่อ `revision > 1`

## เปลี่ยนแปลงจากลำดับ commit เดิม

commit 3 (`Read invoices from the new table`) และ commit 5 (`Replace the mocked tenant billing source`) ถูกยุบเป็น Task 3 อันเดียว เพราะการเปลี่ยนรูปร่างของ `Invoice` ทำให้ `TenantBill` และ `MockTenantBillingSource` ที่ห่อมันอยู่พังทันที การแยกสองคอมมิทจะบังคับให้เขียนอะแดปเตอร์ชั่วคราวที่ถูกลบทิ้งในคอมมิทถัดไป และ backfill จาก Task 1 ทำให้ฝั่งผู้เช่าอ่านของจริงได้ตั้งแต่จุดนั้นอยู่แล้ว ลำดับจึงเหลือ 9 Task

## File Structure

**สร้างใหม่**

| ไฟล์ | รับผิดชอบอะไร |
|---|---|
| `database/invoices_schema.sql` | ตาราง index trigger |
| `database/invoices_rls.sql` | policy + RPC `submit_payment_slip` |
| `database/invoices_backfill.sql` | สร้างบิลย้อนหลังจากมิเตอร์เดิม |
| `lib/services/invoice_calculator.dart` | Dart ล้วน — ร่างบิล เหตุผลที่ข้าม กำหนดชำระ เลขที่บิล |
| `lib/services/invoice_lifecycle.dart` | Dart ล้วน — การเปลี่ยนสถานะที่อนุญาต |
| `lib/services/invoice_service.dart` | ทุกอย่างที่คุยกับตาราง `invoices` และ bucket `payment-slip` |
| `lib/services/invoice_pdf.dart` | สร้างเอกสาร PDF จาก `Invoice` |
| `lib/viewmodels/invoice_issue_view_model.dart` | สถานะของกล่องตรวจก่อนออกบิล |
| `lib/widgets/issue_invoices_dialog.dart` | กล่องตรวจก่อนออกบิล |
| `lib/widgets/slip_review_sheet.dart` | แผ่นตรวจสลิปฝั่งเจ้าของหอ |
| `lib/widgets/invoice_detail_sheet.dart` | รายละเอียดบิลฝั่งเจ้าของหอ |
| `lib/widgets/invoice_chat_card.dart` | การ์ดบิลในฟองแชท |
| `test/invoice_calculator_unit_test.dart` | ร่างบิล เหตุผลที่ข้าม กำหนดชำระ เลขที่บิล |
| `test/invoice_lifecycle_unit_test.dart` | ตารางการเปลี่ยนสถานะ |
| `test/invoice_pdf_unit_test.dart` | PDF ออกไบต์ได้ ไม่ throw |

**แก้ไข**

| ไฟล์ | ทำอะไร |
|---|---|
| `lib/models/models.dart` | `InvoiceStatus.voided` · `SkipReason` · `MeterCharge` · `InvoiceDraft` · เขียน `Invoice` ใหม่ · ลบ `TenantBill` · `MessageType.invoice` · `ChatMessage.invoiceId` · ขยาย `PaymentChannel` |
| `lib/services/supabase_service.dart` | ลบ 4 เมธอด billing ออก · `sendMessage` รับ `invoiceId` |
| `lib/services/tenant_billing_source.dart` | ลบตัวจำลองทั้งไฟล์ เขียน `SupabaseTenantBillingSource` |
| `lib/viewmodels/billing_view_model.dart` | อ่านจาก `InvoiceService` · void/approve/reject · แยกสาเหตุรายการว่าง |
| `lib/viewmodels/tenant_bills_view_model.dart` | ชนิดเป็น `Invoice` · source จริง |
| `lib/viewmodels/tenant_dashboard_view_model.dart` | ชนิดเป็น `Invoice` · รองรับ `voided` |
| `lib/viewmodels/chat_view_model.dart` · `tenant_chat_view_model.dart` | resolve บิลที่การ์ดอ้างถึง |
| `lib/screens/admin/billing_screen.dart` | ปุ่มออกบิล · เลขที่บิล · empty state สองแบบ · ชิปยกเลิกแล้ว · เมนู ⋮ |
| `lib/widgets/tenant_bill_card.dart` | เลขที่บิล · เหตุผลปฏิเสธ · ป้ายยกเลิก |
| `lib/widgets/payment_sheet.dart` | ช่องทางชำระจริง · ปุ่ม PDF |
| `lib/widgets/chat_conversation_view.dart` | เรนเดอร์ `MessageType.invoice` |
| `test/tenant_dashboard_unit_test.dart` | ชนิดใหม่ + บิลยกเลิกไม่นับเป็นยอดค้าง |
| `pubspec.yaml` | assets รูป QR และฟอนต์ · dependency `pdf` `printing` |

---

## Task 1: ตาราง invoices, policy และ backfill

**Files:**
- Create: `database/invoices_schema.sql`
- Create: `database/invoices_rls.sql`
- Create: `database/invoices_backfill.sql`

**Interfaces:**
- Consumes: ตารางที่มีอยู่ `dormitories(id, landlord_id)` · `rooms(id, dorm_id, room_number, base_price, current_tenant_id)` · `tenant_profiles(id)` · `electricity_record(room_id, billing_month, billing_year, previous_reading, current_reading, amount)` · `water_meter(room_id, billing_month, billing_year, amount)` · `maintenance_requests(room_id, request_type, status, completed_at, cleaning_fee)`
- Produces: ตาราง `invoices` · RPC `submit_payment_slip(bigint, text)` · bucket `payment-slip` — Task 3 เป็นต้นไปพึ่งพาทั้งหมดนี้

**ทำไมผู้เช่าไม่มี `UPDATE` policy**

RLS policy ของ Postgres จำกัดไม่ได้ว่าคอลัมน์ไหนแก้ได้ (`WITH CHECK` มองเห็นเฉพาะแถวใหม่ อ้าง `OLD` ไม่ได้) และ column-level `GRANT` ก็แยกไม่ออกเพราะทั้งเจ้าของหอและผู้เช่าเป็น role `authenticated` เหมือนกัน ผู้เช่าจึงได้แค่ `SELECT` ส่วนการส่งสลิปไปผ่าน `SECURITY DEFINER` ที่ตรวจเงื่อนไขเองแล้วเขียนเฉพาะคอลัมน์ที่ควรเขียน — สเปกหัวข้อ RLS ถูกแก้ให้ตรงกับที่ทำจริงแล้ว

- [ ] **Step 1: เขียน `database/invoices_schema.sql`**

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- HorPlug — Invoice Generation: schema
-- รันใน Supabase → SQL Editor เป็นไฟล์แรกของชุด
-- ลำดับ: invoices_schema.sql → invoices_rls.sql → invoices_backfill.sql
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS invoices (
  id                  BIGSERIAL PRIMARY KEY,
  invoice_no          TEXT NOT NULL,
  dorm_id             INT  NOT NULL REFERENCES dormitories(id) ON DELETE CASCADE,
  room_id             INT  NOT NULL REFERENCES rooms(id)       ON DELETE CASCADE,
  tenant_id           UUID REFERENCES tenant_profiles(id),
  billing_month       INT  NOT NULL CHECK (billing_month BETWEEN 1 AND 12),
  billing_year        INT  NOT NULL,

  -- ตัวเลขที่ตรึงไว้ ณ วันออกบิล ห้ามคำนวณใหม่จากมิเตอร์อีก
  room_price          NUMERIC NOT NULL DEFAULT 0,
  electricity_units   NUMERIC NOT NULL DEFAULT 0,
  electricity_cost    NUMERIC NOT NULL DEFAULT 0,
  water_cost          NUMERIC NOT NULL DEFAULT 0,
  cleaning_fee        NUMERIC NOT NULL DEFAULT 0,
  -- ยอดรวมคำนวณในฐานข้อมูล จึงเป็นไปไม่ได้ที่จะไม่ตรงกับผลบวกของรายการ
  total               NUMERIC GENERATED ALWAYS AS
                        (room_price + electricity_cost + water_cost + cleaning_fee) STORED,

  -- ค่าสะกดตรงกับ InvoiceStatus.<ชื่อ>.name ฝั่ง Dart จึงไม่ต้องมีตารางแปลงชื่อ
  status              TEXT NOT NULL DEFAULT 'unpaid'
                        CHECK (status IN ('unpaid','pending','paid','voided')),
  due_date            DATE NOT NULL,
  issued_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  issued_by           UUID NOT NULL,
  slip_url            TEXT,
  slip_submitted_at   TIMESTAMPTZ,
  rejection_reason    TEXT,
  paid_at             TIMESTAMPTZ,
  approved_by         UUID,

  voided_at           TIMESTAMPTZ,
  void_reason         TEXT,
  replaces_invoice_id BIGINT REFERENCES invoices(id),
  revision            INT NOT NULL DEFAULT 1,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- หนึ่งห้อง หนึ่งงวด มีบิลที่ยังไม่ถูกยกเลิกได้ใบเดียว
-- partial เพื่อให้ใบที่ยกเลิกยังอยู่เป็นประวัติ และให้ใบแทนที่เกิดได้
CREATE UNIQUE INDEX IF NOT EXISTS invoices_one_active_per_period
  ON invoices (room_id, billing_year, billing_month) WHERE status <> 'voided';

-- เลขที่บิลไม่มีส่วนที่บอกหอ และเลขห้องซ้ำกันข้ามหอได้ ความไม่ซ้ำจึงผูกกับหอ
-- ไม่ใช่ทั้งตาราง — เลขที่เอกสารมีความหมายในขอบเขตของกิจการที่ออกมัน
CREATE UNIQUE INDEX IF NOT EXISTS invoices_no_per_dorm
  ON invoices (dorm_id, invoice_no);

CREATE INDEX IF NOT EXISTS invoices_room_period
  ON invoices (room_id, billing_year DESC, billing_month DESC);
CREATE INDEX IF NOT EXISTS invoices_dorm_period
  ON invoices (dorm_id, billing_year DESC, billing_month DESC);
CREATE INDEX IF NOT EXISTS invoices_tenant
  ON invoices (tenant_id);

CREATE OR REPLACE FUNCTION set_invoice_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS invoices_set_updated_at ON invoices;
CREATE TRIGGER invoices_set_updated_at
  BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION set_invoice_updated_at();

COMMIT;
```

- [ ] **Step 2: เขียน `database/invoices_rls.sql`**

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- HorPlug — Invoice Generation: RLS + RPC ส่งสลิป
-- รันหลัง invoices_schema.sql
--
-- ผู้เช่าได้แค่ SELECT — การส่งสลิปไปผ่าน submit_payment_slip() แทน
-- เพราะ RLS policy จำกัด "คอลัมน์ไหนแก้ได้" ไม่ได้ และเจ้าของหอกับผู้เช่า
-- เป็น role authenticated เหมือนกัน column-level GRANT จึงแยกไม่ออก
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "invoices_landlord_select" ON invoices;
DROP POLICY IF EXISTS "invoices_landlord_insert" ON invoices;
DROP POLICY IF EXISTS "invoices_landlord_update" ON invoices;
DROP POLICY IF EXISTS "invoices_tenant_select"   ON invoices;

-- เจ้าของหอ: บิลของหอตัวเองเท่านั้น
CREATE POLICY "invoices_landlord_select" ON invoices
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM dormitories d
    WHERE d.id = invoices.dorm_id AND d.landlord_id = auth.uid()
  ));

CREATE POLICY "invoices_landlord_insert" ON invoices
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM dormitories d
    WHERE d.id = invoices.dorm_id AND d.landlord_id = auth.uid()
  ));

CREATE POLICY "invoices_landlord_update" ON invoices
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM dormitories d
    WHERE d.id = invoices.dorm_id AND d.landlord_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM dormitories d
    WHERE d.id = invoices.dorm_id AND d.landlord_id = auth.uid()
  ));

-- ผู้เช่า: อ่านบิลของตัวเอง ไม่มีสิทธิ์เขียนใดๆ
CREATE POLICY "invoices_tenant_select" ON invoices
  FOR SELECT TO authenticated
  USING (tenant_id = auth.uid());

-- ─── ส่งสลิป ────────────────────────────────────────────────────────────────
-- SECURITY DEFINER: ตรวจเงื่อนไขเองแล้วเขียนเฉพาะคอลัมน์สลิป ผู้เช่าจึงแก้
-- ยอดเงินหรือกดให้ตัวเองเป็น paid ไม่ได้ต่อให้เรียก API ตรง
CREATE OR REPLACE FUNCTION submit_payment_slip(
  p_invoice_id BIGINT,
  p_slip_url   TEXT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
BEGIN
  SELECT status INTO v_status
  FROM invoices
  WHERE id = p_invoice_id AND tenant_id = auth.uid();

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'ไม่พบบิลใบนี้';
  END IF;

  IF v_status <> 'unpaid' THEN
    RAISE EXCEPTION 'บิลใบนี้ส่งสลิปไม่ได้ในสถานะปัจจุบัน';
  END IF;

  UPDATE invoices
  SET slip_url          = p_slip_url,
      slip_submitted_at = NOW(),
      status            = 'pending',
      rejection_reason  = NULL
  WHERE id = p_invoice_id;
END;
$$;

REVOKE ALL ON FUNCTION submit_payment_slip(BIGINT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION submit_payment_slip(BIGINT, TEXT) TO authenticated;

COMMIT;
```

- [ ] **Step 3: เขียน `database/invoices_backfill.sql`**

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- HorPlug — Invoice Generation: backfill ประวัติบิลจากมิเตอร์เดิม
-- รันหลัง invoices_rls.sql · รันซ้ำได้ (มี NOT EXISTS กัน)
--
-- ใช้กฎเดียวกับ MockPaymentLedger.statusFor ที่กำลังจะถูกลบ:
-- งวดปัจจุบัน = unpaid, งวดก่อนหน้า = paid — เพื่อให้ประวัติที่ผู้เช่าเห็น
-- ไม่เปลี่ยนหน้าตาในวันมายเกรต
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

WITH periods AS (
  SELECT room_id, billing_month, billing_year FROM electricity_record
  UNION
  SELECT room_id, billing_month, billing_year FROM water_meter
),
computed AS (
  SELECT
    p.room_id,
    p.billing_month,
    p.billing_year,
    r.dorm_id,
    r.room_number,
    r.base_price,
    r.current_tenant_id,
    d.landlord_id,
    COALESCE(GREATEST(e.current_reading::numeric - e.previous_reading::numeric, 0), 0)
      AS elec_units,
    COALESCE(e.amount::numeric, 0) AS elec_cost,
    COALESCE(w.amount::numeric, 0) AS water_cost,
    COALESCE((
      SELECT SUM(m.cleaning_fee::numeric)
      FROM maintenance_requests m
      WHERE m.room_id = p.room_id
        AND m.request_type = 'Cleaning'
        AND m.status = 'Completed'
        AND m.completed_at >= make_date(p.billing_year, p.billing_month, 1)
        AND m.completed_at <  make_date(p.billing_year, p.billing_month, 1)
                              + INTERVAL '1 month'
    ), 0) AS cleaning_fee,
    (make_date(p.billing_year, p.billing_month, 1)
      + INTERVAL '1 month' + INTERVAL '4 day')::date AS due_date
  FROM periods p
  JOIN rooms r        ON r.id = p.room_id
  JOIN dormitories d  ON d.id = r.dorm_id
  LEFT JOIN electricity_record e
    ON e.room_id = p.room_id
   AND e.billing_month = p.billing_month
   AND e.billing_year  = p.billing_year
  LEFT JOIN water_meter w
    ON w.room_id = p.room_id
   AND w.billing_month = p.billing_month
   AND w.billing_year  = p.billing_year
  WHERE r.current_tenant_id IS NOT NULL
)
INSERT INTO invoices (
  invoice_no, dorm_id, room_id, tenant_id, billing_month, billing_year,
  room_price, electricity_units, electricity_cost, water_cost, cleaning_fee,
  status, due_date, issued_at, issued_by, paid_at, revision
)
SELECT
  'INV-' || c.billing_year::text
         || lpad(c.billing_month::text, 2, '0')
         || '-' || c.room_number,
  c.dorm_id,
  c.room_id,
  c.current_tenant_id,
  c.billing_month,
  c.billing_year,
  c.base_price,
  c.elec_units,
  c.elec_cost,
  c.water_cost,
  c.cleaning_fee,
  CASE
    WHEN c.billing_year  = EXTRACT(YEAR  FROM CURRENT_DATE)::int
     AND c.billing_month = EXTRACT(MONTH FROM CURRENT_DATE)::int
    THEN 'unpaid' ELSE 'paid'
  END,
  c.due_date,
  make_date(c.billing_year, c.billing_month, 1) + INTERVAL '1 month',
  c.landlord_id,
  CASE
    WHEN c.billing_year  = EXTRACT(YEAR  FROM CURRENT_DATE)::int
     AND c.billing_month = EXTRACT(MONTH FROM CURRENT_DATE)::int
    THEN NULL ELSE c.due_date::timestamptz
  END,
  1
FROM computed c
WHERE NOT EXISTS (
  SELECT 1 FROM invoices i
  WHERE i.room_id       = c.room_id
    AND i.billing_year  = c.billing_year
    AND i.billing_month = c.billing_month
    AND i.status <> 'voided'
);

COMMIT;
```

- [ ] **Step 4: สร้าง bucket `payment-slip` ใน Supabase**

Storage → New bucket → ชื่อ `payment-slip` → **ไม่ติ๊ก Public** แล้วเพิ่ม policy ผ่าน SQL Editor

```sql
-- ผู้ที่ล็อกอินแล้วอัปโหลดและอ่านสลิปได้ ควบคุมสิทธิ์จริงที่ตาราง invoices
-- (ผู้เช่าเห็น path ของบิลตัวเองเท่านั้น เพราะอ่าน path มาจากแถวที่ตัวเองอ่านได้)
CREATE POLICY "payment_slip_authenticated_write" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'payment-slip');

CREATE POLICY "payment_slip_authenticated_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'payment-slip');
```

- [ ] **Step 5: รันสามไฟล์ตามลำดับแล้วตรวจผล**

รันใน Supabase SQL Editor: `invoices_schema.sql` → `invoices_rls.sql` → `invoices_backfill.sql`

จากนั้นรันคำสั่งตรวจ

```sql
-- ต้องได้จำนวนบิลเท่ากับจำนวนงวดที่มีมิเตอร์ของห้องที่มีผู้เช่า
SELECT billing_year, billing_month, status, count(*)
FROM invoices GROUP BY 1,2,3 ORDER BY 1 DESC, 2 DESC;

-- ต้องคืน 0 แถว — ยอดรวมต้องตรงกับผลบวกเสมอ
SELECT id, total, room_price + electricity_cost + water_cost + cleaning_fee AS sum_parts
FROM invoices
WHERE total <> room_price + electricity_cost + water_cost + cleaning_fee;

-- ต้อง error ด้วย duplicate key — พิสูจน์ว่า partial unique index ทำงาน
INSERT INTO invoices (invoice_no, dorm_id, room_id, billing_month, billing_year,
                      due_date, issued_by)
SELECT invoice_no || '-DUP', dorm_id, room_id, billing_month, billing_year,
       due_date, issued_by
FROM invoices LIMIT 1;
```

คำสั่งที่สามต้องล้มเหลว ถ้ามันสำเร็จแปลว่า index ไม่ได้ถูกสร้าง ให้ย้อนกลับไปตรวจ Step 1 และอย่าลืม `DELETE` แถวที่เผลอใส่เข้าไป

- [ ] **Step 6: ตรวจว่าฝั่ง Dart ไม่กระทบ**

```bash
flutter analyze
flutter test
```

Task นี้ไม่แตะ Dart เลย ทั้งสองคำสั่งต้องให้ผลเหมือนก่อนเริ่ม (analyze สะอาด, 131 tests ผ่าน) ถ้าตัวเลขเปลี่ยนแปลว่ามีอะไรหลุดเข้ามา

- [ ] **Step 7: หยุดและรายงานผู้ใช้**

รายงานว่ารันสคริปต์ไปแล้วกี่ไฟล์ backfill สร้างบิลกี่ใบแยกตามสถานะ และผลการตรวจสามข้อ แล้วบอกว่าพร้อม commit ด้วยข้อความหัวข้อ **1** ใน `docs/superpowers/specs/2026-08-04-invoice-generation-commits.md` — **อย่ารัน `git commit` เอง**

ไฟล์ที่ผู้ใช้ต้อง stage: `database/invoices_schema.sql` `database/invoices_rls.sql` `database/invoices_backfill.sql`

---

## Task 2: แยกตรรกะการคำนวณเป็นฟังก์ชันบริสุทธิ์

Refactor ที่**ไม่เปลี่ยนพฤติกรรมของแอปเลย** — หน้าจอทุกหน้าต้องแสดงผลเหมือนเดิมทุกประการหลังจบ Task นี้ สิ่งที่ได้มาคือความสามารถในการเขียนเทสต์ ซึ่งเป็นเงื่อนไขของอีกเจ็ด Task ที่เหลือ

**Files:**
- Modify: `lib/models/models.dart` (เพิ่ม `InvoiceStatus.voided`, `SkipReason`, `MeterCharge`, `InvoiceDraft`)
- Create: `lib/services/invoice_calculator.dart`
- Create: `lib/services/invoice_lifecycle.dart`
- Modify: `lib/services/supabase_service.dart:244-296` (`fetchInvoices` เรียก calculator)
- Modify: `lib/viewmodels/tenant_dashboard_view_model.dart:74-94` (`billStatusLabel`, `billStatusVariant` รองรับ `voided`)
- Modify: `lib/widgets/tenant_bill_card.dart:95-135` (`_buildAction` รองรับ `voided`)
- Test: `test/invoice_calculator_unit_test.dart`
- Test: `test/invoice_lifecycle_unit_test.dart`

**Interfaces:**
- Consumes: `Room` (`dbId`, `id` คือเลขห้อง, `price`, `currentTenantId`, `tenantName`) จาก `models.dart`
- Produces:
  - `enum SkipReason { noTenant, noMeterReading, alreadyIssued }`
  - `class MeterCharge { final double units; final double amount; }`
  - `class InvoiceDraft` — `roomDbId`, `roomNumber`, `tenantId`, `tenantName`, `billingMonth`, `billingYear`, `roomPrice`, `electricityUnits`, `electricityCost`, `waterCost`, `cleaningFee`, `skipReason`, getter `canIssue`, getter `total`
  - `InvoiceDraft buildDraft({required Room room, required int billingMonth, required int billingYear, MeterCharge? electricity, double? waterAmount, double cleaningFee = 0, bool alreadyIssued = false})`
  - `DateTime dueDateFor(int year, int month)`
  - `String invoiceNoFor({required int year, required int month, required String roomNumber, int revision = 1})`
  - `String skipReasonLabel(SkipReason reason)`
  - `bool canTransition(InvoiceStatus from, InvoiceStatus to)`

- [ ] **Step 1: เพิ่มชนิดใหม่ใน `lib/models/models.dart`**

แก้ enum เดิมและเพิ่มชนิดใหม่ต่อท้าย `Invoice` ที่มีอยู่ (ยังไม่แตะ `Invoice` ใน Task นี้)

```dart
enum InvoiceStatus { unpaid, pending, paid, voided }

/// เหตุผลที่ห้องหนึ่งออกบิลในงวดนี้ไม่ได้
enum SkipReason { noTenant, noMeterReading, alreadyIssued }

/// ค่ามิเตอร์ที่คำนวณเสร็จแล้วหนึ่งชนิด — แยกออกมาเพื่อให้ buildDraft
/// รับข้อมูลที่มีชนิดชัดเจนแทน Map ดิบจาก PostgREST
class MeterCharge {
  final double units;
  final double amount;

  const MeterCharge({required this.units, required this.amount});
}

/// ร่างบิลที่คำนวณสดจากมิเตอร์ ยังไม่มีตัวตนในฐานข้อมูล
///
/// แยกจาก [Invoice] ที่เป็นแถวจริง เพื่อให้ compiler ปฏิเสธการเผลอเอาตัวเลข
/// ที่คำนวณสดไปแสดงหรือไปพิมพ์ลง PDF แทนตัวเลขที่ตรึงไว้
class InvoiceDraft {
  final int roomDbId;
  final String roomNumber;
  final String? tenantId;
  final String tenantName;
  final int billingMonth;
  final int billingYear;
  final double roomPrice;
  final double electricityUnits;
  final double electricityCost;
  final double waterCost;
  final double cleaningFee;
  final SkipReason? skipReason;

  const InvoiceDraft({
    required this.roomDbId,
    required this.roomNumber,
    this.tenantId,
    required this.tenantName,
    required this.billingMonth,
    required this.billingYear,
    this.roomPrice = 0,
    this.electricityUnits = 0,
    this.electricityCost = 0,
    this.waterCost = 0,
    this.cleaningFee = 0,
    this.skipReason,
  });

  bool get canIssue => skipReason == null;

  double get total => roomPrice + electricityCost + waterCost + cleaningFee;
}
```

- [ ] **Step 2: เขียนเทสต์ที่ยังล้ม `test/invoice_calculator_unit_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_calculator.dart';

Room _room({
  int dbId = 1,
  String number = '301',
  String? tenantId = 'tenant-uuid',
  double price = 3500,
}) {
  return Room(
    dbId: dbId,
    id: number,
    floor: '3',
    status: RoomStatus.occupied,
    currentTenantId: tenantId,
    tenantName: 'สมชาย ใจดี',
    price: price,
  );
}

void main() {
  group('buildDraft — เหตุผลที่ข้ามห้อง', () {
    test('ห้องไม่มีผู้เช่า ถูกข้ามด้วย noTenant', () {
      final draft = buildDraft(
        room: _room(tenantId: null),
        billingMonth: 8,
        billingYear: 2026,
        electricity: const MeterCharge(units: 142, amount: 1136),
        waterAmount: 404,
      );

      expect(draft.skipReason, SkipReason.noTenant);
      expect(draft.canIssue, isFalse);
    });

    test('ไม่มีมิเตอร์และไม่มีค่าทำความสะอาด ถูกข้ามด้วย noMeterReading', () {
      final draft = buildDraft(
        room: _room(),
        billingMonth: 8,
        billingYear: 2026,
      );

      expect(draft.skipReason, SkipReason.noMeterReading);
    });

    test('มีแต่ค่าทำความสะอาด ออกบิลได้ ไม่ถือว่าไม่มีมิเตอร์', () {
      final draft = buildDraft(
        room: _room(),
        billingMonth: 8,
        billingYear: 2026,
        cleaningFee: 200,
      );

      expect(draft.canIssue, isTrue);
      expect(draft.total, 3700);
    });

    test('ออกบิลงวดนี้ไปแล้ว ถูกข้ามด้วย alreadyIssued', () {
      final draft = buildDraft(
        room: _room(),
        billingMonth: 8,
        billingYear: 2026,
        electricity: const MeterCharge(units: 142, amount: 1136),
        alreadyIssued: true,
      );

      expect(draft.skipReason, SkipReason.alreadyIssued);
    });

    test('ห้องว่างที่ออกบิลไปแล้ว รายงาน noTenant ก่อน', () {
      final draft = buildDraft(
        room: _room(tenantId: null),
        billingMonth: 8,
        billingYear: 2026,
        alreadyIssued: true,
      );

      expect(draft.skipReason, SkipReason.noTenant);
    });
  });

  group('buildDraft — ตัวเลข', () {
    test('รวมค่าห้อง ค่าไฟ ค่าน้ำ ค่าทำความสะอาด', () {
      final draft = buildDraft(
        room: _room(price: 3500),
        billingMonth: 8,
        billingYear: 2026,
        electricity: const MeterCharge(units: 142, amount: 1136),
        waterAmount: 404,
        cleaningFee: 200,
      );

      expect(draft.roomPrice, 3500);
      expect(draft.electricityUnits, 142);
      expect(draft.electricityCost, 1136);
      expect(draft.waterCost, 404);
      expect(draft.cleaningFee, 200);
      expect(draft.total, 5240);
    });

    test('ไม่มีค่าน้ำในงวดนั้น คิดเป็นศูนย์ ไม่ใช่ทำให้ทั้งบิลตก', () {
      final draft = buildDraft(
        room: _room(),
        billingMonth: 8,
        billingYear: 2026,
        electricity: const MeterCharge(units: 142, amount: 1136),
      );

      expect(draft.canIssue, isTrue);
      expect(draft.waterCost, 0);
    });
  });

  group('dueDateFor', () {
    test('ครบกำหนดวันที่ 5 ของเดือนถัดไป', () {
      expect(dueDateFor(2026, 8), DateTime(2026, 9, 5));
    });

    test('งวดธันวาคมครบกำหนด 5 มกราคมปีถัดไป', () {
      expect(dueDateFor(2026, 12), DateTime(2027, 1, 5));
    });
  });

  group('invoiceNoFor', () {
    test('เติมศูนย์หน้าเดือนหลักเดียว', () {
      expect(
        invoiceNoFor(year: 2026, month: 8, roomNumber: '301'),
        'INV-202608-301',
      );
    });

    test('เดือนสองหลักไม่ถูกเติมศูนย์ซ้ำ', () {
      expect(
        invoiceNoFor(year: 2026, month: 12, roomNumber: '301'),
        'INV-202612-301',
      );
    });

    test('ใบที่ออกใหม่ต่อท้ายด้วย -R ตามรอบแก้ไข', () {
      expect(
        invoiceNoFor(year: 2026, month: 8, roomNumber: '301', revision: 2),
        'INV-202608-301-R2',
      );
    });

    test('รอบแก้ไขที่ 1 ไม่มีคำต่อท้าย', () {
      expect(
        invoiceNoFor(year: 2026, month: 8, roomNumber: '301', revision: 1),
        'INV-202608-301',
      );
    });
  });

  group('skipReasonLabel', () {
    test('ทุกเหตุผลมีข้อความภาษาไทยที่ไม่ว่าง', () {
      for (final reason in SkipReason.values) {
        expect(skipReasonLabel(reason).trim(), isNotEmpty);
      }
    });
  });

  // ตรรกะนี้อยู่ใน models.dart มาตลอดแต่ไม่เคยถูกทดสอบผ่านเส้นทางบิลเลย
  // ทั้งที่มิเตอร์วนรอบทำให้ผู้เช่าถูกเรียกเก็บเกินได้เป็นหลักหมื่นหน่วย
  group('ElectricityRecord.unitsUsed — มิเตอร์สี่หลักวนรอบ', () {
    ElectricityRecord record({required double previous, required double current}) {
      return ElectricityRecord(
        roomDbId: 1,
        roomNumber: '301',
        billingMonth: 8,
        billingYear: 2026,
        previousReading: previous,
        currentReading: current,
        unitRate: 8,
      );
    }

    test('เดือนปกติ หักลบตรงๆ', () {
      expect(record(previous: 1200, current: 1342).unitsUsed, 142);
    });

    test('วนจาก 9950 ไป 0092 ได้ 142 หน่วย ไม่ใช่ติดลบ', () {
      final wrapped = record(previous: 9950, current: 92);

      expect(wrapped.isOverflow, isTrue);
      expect(wrapped.unitsUsed, 142);
      expect(wrapped.amount, 1136);
    });

    test('ยังไม่จดเลขปัจจุบัน คิดเป็นศูนย์หน่วย', () {
      final record = ElectricityRecord(
        roomDbId: 1,
        roomNumber: '301',
        billingMonth: 8,
        billingYear: 2026,
        previousReading: 1200,
        unitRate: 8,
      );

      expect(record.unitsUsed, 0);
      expect(record.amount, 0);
    });
  });
}
```

- [ ] **Step 3: รันเทสต์ให้เห็นว่าล้ม**

```bash
flutter test test/invoice_calculator_unit_test.dart
```
Expected: FAIL — `Target of URI doesn't exist: 'package:horplug/services/invoice_calculator.dart'`

- [ ] **Step 4: เขียน `lib/services/invoice_calculator.dart`**

```dart
/// ตรรกะการประกอบร่างบิล — Dart ล้วน ไม่ import supabase หรือ flutter
///
/// เดิมตรรกะนี้ฝังอยู่กลาง SupabaseService.fetchInvoices ซึ่งเปิดด้วยการเรียก
/// เครือข่าย จึงเขียน unit test ไม่ได้เลย ทั้งที่เป็นส่วนที่เกี่ยวกับเงิน
library;

import '../models/models.dart';

/// ประกอบร่างบิลของห้องหนึ่งในงวดหนึ่ง
///
/// [alreadyIssued] ให้ผู้เรียกเป็นคนบอก ฟังก์ชันนี้จึงไม่ต้องแตะฐานข้อมูล
/// ลำดับการตัดสินเหตุผลที่ข้าม: ไม่มีผู้เช่า → ออกบิลไปแล้ว → ไม่มีข้อมูลคิดเงิน
InvoiceDraft buildDraft({
  required Room room,
  required int billingMonth,
  required int billingYear,
  MeterCharge? electricity,
  double? waterAmount,
  double cleaningFee = 0,
  bool alreadyIssued = false,
}) {
  final electricityCost = electricity?.amount ?? 0;
  final waterCost = waterAmount ?? 0;

  SkipReason? skipReason;
  if (room.currentTenantId == null) {
    // ห้องภายใต้การซ่อมยังมีผู้เช่าและยังต้องออกบิล — เฉพาะห้องที่ไม่มีคนอยู่
    // เท่านั้นที่ข้าม เงื่อนไขเดิมใน fetchInvoices ก็ใช้เกณฑ์นี้
    skipReason = SkipReason.noTenant;
  } else if (alreadyIssued) {
    skipReason = SkipReason.alreadyIssued;
  } else if (electricity == null && waterAmount == null && cleaningFee <= 0) {
    skipReason = SkipReason.noMeterReading;
  }

  return InvoiceDraft(
    roomDbId: room.dbId,
    roomNumber: room.id,
    tenantId: room.currentTenantId,
    tenantName: room.tenantName ?? '-',
    billingMonth: billingMonth,
    billingYear: billingYear,
    roomPrice: room.price,
    electricityUnits: electricity?.units ?? 0,
    electricityCost: electricityCost,
    waterCost: waterCost,
    cleaningFee: cleaningFee,
    skipReason: skipReason,
  );
}

/// ครบกำหนดชำระวันที่ 5 ของเดือนถัดจากงวด
///
/// DateTime รับ month = 13 แล้วขึ้นปีใหม่ให้เอง งวดธันวาคมจึงได้ 5 มกราคม
/// ปีถัดไปโดยไม่ต้องเขียนเงื่อนไขแยก
/// (ตรรกะเดียวกับ MockPaymentLedger.dueDateFor ที่จะถูกลบใน Task 3)
DateTime dueDateFor(int year, int month) => DateTime(year, month + 1, 5);

/// เลขที่บิล — `INV-{YYYYMM}-{เลขห้อง}` และต่อท้าย `-R{n}` เมื่อเป็นใบที่ออกใหม่
String invoiceNoFor({
  required int year,
  required int month,
  required String roomNumber,
  int revision = 1,
}) {
  final period = '$year${month.toString().padLeft(2, '0')}';
  final base = 'INV-$period-$roomNumber';
  return revision > 1 ? '$base-R$revision' : base;
}

/// ข้อความที่แสดงในรายการ "ข้าม N ห้อง" ของกล่องตรวจก่อนออกบิล
String skipReasonLabel(SkipReason reason) {
  switch (reason) {
    case SkipReason.noTenant:
      return 'ห้องว่าง ไม่มีผู้เช่า';
    case SkipReason.noMeterReading:
      return 'ยังไม่จดมิเตอร์';
    case SkipReason.alreadyIssued:
      return 'ออกบิลงวดนี้ไปแล้ว';
  }
}
```

- [ ] **Step 5: รันเทสต์ให้ผ่าน**

```bash
flutter test test/invoice_calculator_unit_test.dart
```
Expected: PASS ทั้ง 14 เทสต์

- [ ] **Step 6: เขียนเทสต์ที่ยังล้ม `test/invoice_lifecycle_unit_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_lifecycle.dart';

void main() {
  group('canTransition — เส้นทางที่อนุญาต', () {
    test('อัปสลิป: unpaid → pending', () {
      expect(canTransition(InvoiceStatus.unpaid, InvoiceStatus.pending), isTrue);
    });

    test('อนุมัติ: pending → paid', () {
      expect(canTransition(InvoiceStatus.pending, InvoiceStatus.paid), isTrue);
    });

    test('ปฏิเสธสลิปพากลับไป unpaid ไม่ใช่สถานะที่ห้า', () {
      expect(canTransition(InvoiceStatus.pending, InvoiceStatus.unpaid), isTrue);
    });

    test('ยกเลิกได้จากทุกสถานะที่ยังไม่ถูกยกเลิก รวมทั้ง paid', () {
      expect(canTransition(InvoiceStatus.unpaid, InvoiceStatus.voided), isTrue);
      expect(canTransition(InvoiceStatus.pending, InvoiceStatus.voided), isTrue);
      expect(canTransition(InvoiceStatus.paid, InvoiceStatus.voided), isTrue);
    });
  });

  group('canTransition — เส้นทางที่ต้องปฏิเสธ', () {
    test('ถอยจาก paid กลับไป pending ไม่ได้', () {
      expect(canTransition(InvoiceStatus.paid, InvoiceStatus.pending), isFalse);
    });

    test('ข้ามขั้นจาก unpaid ไป paid ไม่ได้ ต้องผ่านการตรวจสลิป', () {
      expect(canTransition(InvoiceStatus.unpaid, InvoiceStatus.paid), isFalse);
    });

    test('voided เป็นสถานะสุดท้าย ออกไปไหนไม่ได้เลย', () {
      for (final to in InvoiceStatus.values) {
        expect(canTransition(InvoiceStatus.voided, to), isFalse,
            reason: 'voided → ${to.name} ต้องถูกปฏิเสธ');
      }
    });

    test('เปลี่ยนเป็นสถานะเดิมไม่นับเป็นการเปลี่ยน', () {
      for (final status in InvoiceStatus.values) {
        expect(canTransition(status, status), isFalse,
            reason: '${status.name} → ${status.name} ต้องถูกปฏิเสธ');
      }
    });
  });
}
```

- [ ] **Step 7: รันเทสต์ให้เห็นว่าล้ม แล้วเขียน `lib/services/invoice_lifecycle.dart`**

```bash
flutter test test/invoice_lifecycle_unit_test.dart
```
Expected: FAIL — ไฟล์ยังไม่มี

```dart
/// การเปลี่ยนสถานะบิลที่อนุญาต — Dart ล้วน ไม่ import supabase หรือ flutter
///
/// แยกจาก invoice_calculator เพราะเป็นคนละคำถาม ตัวหนึ่งตอบว่าบิลควรมียอด
/// เท่าไร อีกตัวตอบว่าบิลเดินไปทางไหนได้ InvoiceService เรียกตรวจก่อนทุกครั้ง
/// ที่จะ UPDATE เป็นด่านคู่กับที่ฐานข้อมูลบังคับไว้
library;

import '../models/models.dart';

bool canTransition(InvoiceStatus from, InvoiceStatus to) {
  if (from == to) return false;
  // ยกเลิกแล้วคือจบ ต่อให้อนุมัติผิดก็ต้องออกใบใหม่ ไม่ใช่ปลุกใบเดิม
  if (from == InvoiceStatus.voided) return false;
  if (to == InvoiceStatus.voided) return true;

  switch (from) {
    case InvoiceStatus.unpaid:
      return to == InvoiceStatus.pending;
    case InvoiceStatus.pending:
      return to == InvoiceStatus.paid || to == InvoiceStatus.unpaid;
    case InvoiceStatus.paid:
      return false;
    case InvoiceStatus.voided:
      return false;
  }
}
```

```bash
flutter test test/invoice_lifecycle_unit_test.dart
```
Expected: PASS ทั้ง 8 เทสต์

- [ ] **Step 8: รองรับสถานะ `voided` ในจุดที่ switch แบบครบทุกกรณี**

การเพิ่มค่าใน `InvoiceStatus` ทำให้ switch ที่ไม่มี default ทั้งหมดคอมไพล์ไม่ผ่าน ซึ่งเป็นสิ่งที่ต้องการ — มันชี้จุดที่ต้องตัดสินใจให้ครบ

`lib/viewmodels/tenant_dashboard_view_model.dart` เพิ่มสองกรณี

```dart
String billStatusLabel(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.unpaid:
      return 'ค้างชำระ';
    case InvoiceStatus.pending:
      return 'รอตรวจสลิป';
    case InvoiceStatus.paid:
      return 'ชำระแล้ว';
    case InvoiceStatus.voided:
      return 'ยกเลิกแล้ว';
  }
}

BadgeVariant billStatusVariant(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.unpaid:
      return BadgeVariant.destructive;
    case InvoiceStatus.pending:
      return BadgeVariant.warning;
    case InvoiceStatus.paid:
      return BadgeVariant.success;
    case InvoiceStatus.voided:
      return BadgeVariant.muted;
  }
}
```

`lib/widgets/tenant_bill_card.dart` เพิ่มกรณีใน `_buildAction` ต่อจาก `case InvoiceStatus.paid`

```dart
      case InvoiceStatus.voided:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 16, color: AppColors.mutedForeground),
            const SizedBox(width: 6),
            Text(
              'ยกเลิกแล้ว',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        );
```

- [ ] **Step 9: ให้ `fetchInvoices` เดิมใช้ calculator โดยผลลัพธ์ไม่เปลี่ยน**

ใน `lib/services/supabase_service.dart` แทนที่ลูปประกอบบิลใน `fetchInvoices` (บรรทัด 266-294) ด้วยการเรียก `buildDraft` แล้วแปลงร่างเป็น `Invoice` แบบเดิม ส่วนอื่นของเมธอดคงไว้ทั้งหมด

```dart
    final invoices = <Invoice>[];
    for (final room in rooms) {
      final e = elecData.firstWhere((r) => r['room_id'] == room.dbId,
          orElse: () => {});
      final w = waterData.firstWhere((r) => r['room_id'] == room.dbId,
          orElse: () => {});

      final draft = buildDraft(
        room: room,
        billingMonth: month,
        billingYear: year,
        electricity: e.isEmpty
            ? null
            : MeterCharge(
                units: _parseDouble(e['current_reading']) -
                    _parseDouble(e['previous_reading']),
                amount: _parseDouble(e['amount']),
              ),
        waterAmount: w.isEmpty ? null : _parseDouble(w['amount']),
        cleaningFee: cleaningFeeByRoom[room.dbId] ?? 0.0,
      );

      if (!draft.canIssue) continue;

      invoices.add(Invoice(
        id: 'INV-${room.dbId}-$month-$year',
        roomNumber: draft.roomNumber,
        tenantName: draft.tenantName,
        // คงนิพจน์เดิมไว้เป๊ะ — draft ไม่ได้ถือ "มีแถวค่าน้ำหรือไม่" และ Task นี้
        // สัญญาว่าไม่มีตัวเลขไหนเปลี่ยน (ฟิลด์นี้ถูกลบทิ้งใน Task 3 อยู่แล้ว)
        waterUnits: w.isNotEmpty ? 1.0 : 0.0,
        electricityUnits: draft.electricityUnits,
        roomPrice: draft.roomPrice,
        waterCost: draft.waterCost,
        electricityCost: draft.electricityCost,
        cleaningFee: draft.cleaningFee,
        status: InvoiceStatus.unpaid,
        date: DateTime(year, month, 1),
      ));
    }
    return invoices;
```

เพิ่ม import ที่หัวไฟล์

```dart
import 'invoice_calculator.dart';
```

- [ ] **Step 10: ตรวจว่าไม่มีอะไรเปลี่ยนพฤติกรรม**

```bash
flutter analyze
flutter test
```
Expected: analyze สะอาด · เทสต์เดิม 131 ตัวผ่านครบเหมือนเดิม บวกเทสต์ใหม่ 22 ตัว

ถ้าเทสต์เดิมตัวใดล้ม แปลว่า refactor เปลี่ยนพฤติกรรมจริง ห้ามแก้เทสต์ให้ผ่าน ให้กลับไปแก้ `buildDraft` ให้ตรงกับตรรกะเดิม

- [ ] **Step 11: ตรวจด้วยตาบนเครื่องจริง**

```bash
flutter run
```
เปิดหน้า "บิล" ฝั่งเจ้าของหอ เลือกงวดที่มีข้อมูล แล้วเทียบกับก่อนเริ่ม Task — รายการห้อง ยอดแต่ละรายการ และยอดรวมต้องเหมือนเดิมทุกตัว

- [ ] **Step 12: หยุดและรายงานผู้ใช้**

รายงานจำนวนเทสต์ที่เพิ่มขึ้น ผล analyze และผลการเทียบหน้าจอ แล้วบอกว่าพร้อม commit ด้วยข้อความหัวข้อ **2** ในไฟล์ commit messages — **อย่ารัน `git commit` เอง**

---

## Task 3: อ่านบิลที่ออกแล้วจากฐานข้อมูลแทนการคำนวณสด

Task ที่ใหญ่ที่สุดในแผน เพราะการเปลี่ยนรูปร่างของ `Invoice` แตะทั้งสองฝั่งพร้อมกันโดยเลี่ยงไม่ได้ ทำเป็นสองคอมมิทได้ก็ต่อเมื่อยอมเขียนอะแดปเตอร์ที่จะถูกลบทิ้งอยู่ดี

**ขอบเขตที่ขยับจากไฟล์ commit messages** — `submitPaymentSlip` ที่อัปโหลดจริงย้ายมาอยู่ที่นี่ เพราะการลบ `MockTenantBillingSource` บังคับให้ต้องมีของจริงมาแทนครบทุกเมธอด Task 5 จึงเหลือเฉพาะหน้าตาของแผ่นชำระเงิน

**Files:**
- Modify: `lib/models/models.dart` — เขียน `Invoice` ใหม่ · ลบ `TenantBill` · ขยาย `PaymentChannel`
- Create: `lib/services/invoice_service.dart`
- Modify: `lib/services/supabase_service.dart` — ลบ `fetchInvoices`, `_fetchCleaningFeesByRoom`, `fetchInvoiceForRoom`, `fetchInvoiceHistoryForRoom`, `_fetchCleaningFeesByPeriod`
- Modify: `lib/services/tenant_billing_source.dart` — ลบทั้งไฟล์แล้วเขียนใหม่
- Modify: `lib/viewmodels/billing_view_model.dart`
- Modify: `lib/viewmodels/tenant_bills_view_model.dart`
- Modify: `lib/viewmodels/tenant_dashboard_view_model.dart`
- Modify: `lib/screens/admin/billing_screen.dart`
- Modify: `lib/screens/tenant/tenant_bills_screen.dart` · `tenant_dashboard_screen.dart` · `tenant_shell.dart`
- Modify: `lib/widgets/tenant_bill_card.dart` · `lib/widgets/payment_sheet.dart`
- Test: `test/tenant_dashboard_unit_test.dart`

**Interfaces:**
- Consumes: `buildDraft`, `dueDateFor`, `invoiceNoFor`, `skipReasonLabel` จาก Task 2 · ตาราง `invoices` จาก Task 1
- Produces:
  - `class Invoice` — `dbId`, `invoiceNo`, `roomDbId`, `roomNumber`, `tenantId`, `tenantName`, `billingMonth`, `billingYear`, `roomPrice`, `electricityUnits`, `electricityCost`, `waterCost`, `cleaningFee`, `total`, `status`, `dueDate`, `issuedAt`, `slipUrl`, `slipSubmittedAt`, `rejectionReason`, `paidAt`, `revision`, `voidReason` · getter `period`, `hasSlip`, `isVoided`
  - `class InvoiceService` — `fetchInvoices({dormitoryId, month, year})`, `fetchForRoom({roomDbId, monthCount})`, `fetchCurrentForRoom({roomDbId, month, year})`, `previewDrafts({dormitoryId, month, year})`, `uploadSlip({invoice, file})`, `submitSlip({invoiceId, slipPath})`, `signedSlipUrl(path)`
  - `class InvoicePreview` — `drafts` (ออกได้) · `skipped` (ข้าม)
  - `PaymentChannel` เพิ่ม `bankName`, `accountNo`, `qrAssetPath`

- [ ] **Step 1: เขียน `Invoice` ใหม่และลบ `TenantBill` ใน `lib/models/models.dart`**

แทนที่ `class Invoice` เดิมทั้งก้อน (บรรทัด 125-155) ด้วย

```dart
/// บิลหนึ่งใบที่ออกแล้ว — หนึ่งแถวในตาราง invoices
///
/// ตัวเลขทุกตัวถูกตรึงไว้ ณ วันออกบิล การแก้มิเตอร์ย้อนหลังจึงไม่กระทบบิลที่
/// ออกไปแล้ว ร่างที่ยังไม่ออกใช้ [InvoiceDraft] คนละชนิดกัน
class Invoice {
  final int dbId;
  final String invoiceNo;
  final int roomDbId;
  final String roomNumber;
  final String? tenantId;
  final String tenantName;
  final int billingMonth;
  final int billingYear;

  final double roomPrice;
  final double electricityUnits;
  final double electricityCost;
  final double waterCost;
  final double cleaningFee;
  final double total;

  final InvoiceStatus status;
  final DateTime dueDate;
  final DateTime issuedAt;
  final String? slipUrl;
  final DateTime? slipSubmittedAt;
  final String? rejectionReason;
  final DateTime? paidAt;
  final int revision;
  final String? voidReason;

  const Invoice({
    required this.dbId,
    required this.invoiceNo,
    required this.roomDbId,
    required this.roomNumber,
    this.tenantId,
    required this.tenantName,
    required this.billingMonth,
    required this.billingYear,
    this.roomPrice = 0,
    this.electricityUnits = 0,
    this.electricityCost = 0,
    this.waterCost = 0,
    this.cleaningFee = 0,
    required this.total,
    required this.status,
    required this.dueDate,
    required this.issuedAt,
    this.slipUrl,
    this.slipSubmittedAt,
    this.rejectionReason,
    this.paidAt,
    this.revision = 1,
    this.voidReason,
  });

  /// งวดของบิล (วันที่ 1 ของเดือนนั้น) — ใช้เรียงและแสดงชื่อเดือน
  DateTime get period => DateTime(billingYear, billingMonth, 1);

  bool get hasSlip => slipUrl != null;
  bool get isVoided => status == InvoiceStatus.voided;

  Invoice copyWith({
    InvoiceStatus? status,
    String? slipUrl,
    DateTime? slipSubmittedAt,
    String? rejectionReason,
    DateTime? paidAt,
    String? voidReason,
  }) {
    return Invoice(
      dbId: dbId,
      invoiceNo: invoiceNo,
      roomDbId: roomDbId,
      roomNumber: roomNumber,
      tenantId: tenantId,
      tenantName: tenantName,
      billingMonth: billingMonth,
      billingYear: billingYear,
      roomPrice: roomPrice,
      electricityUnits: electricityUnits,
      electricityCost: electricityCost,
      waterCost: waterCost,
      cleaningFee: cleaningFee,
      total: total,
      status: status ?? this.status,
      dueDate: dueDate,
      issuedAt: issuedAt,
      slipUrl: slipUrl ?? this.slipUrl,
      slipSubmittedAt: slipSubmittedAt ?? this.slipSubmittedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      paidAt: paidAt ?? this.paidAt,
      revision: revision,
      voidReason: voidReason ?? this.voidReason,
    );
  }
}
```

ลบ `class TenantBill` ทั้งก้อน (บรรทัด 346-385 รวมคอมเมนต์นำหน้า) และแทน `class PaymentChannel` ด้วย

```dart
/// ช่องทางรับชำระเงินของหอพัก
///
/// เฟสนี้ QR เป็นภาพนิ่งใน assets จึงไม่มีจำนวนเงินฝังอยู่ เมื่อเปลี่ยนไปใช้
/// QR ที่สร้างสดพร้อมจำนวนเงิน ให้เปลี่ยนเฉพาะที่มาของ [qrAssetPath]
/// ผู้เรียกทั้งหมดไม่ต้องแก้
class PaymentChannel {
  final String bankName;
  final String accountNo;
  final String accountName;
  final String qrAssetPath;

  const PaymentChannel({
    required this.bankName,
    required this.accountNo,
    required this.accountName,
    required this.qrAssetPath,
  });
}
```

- [ ] **Step 2: เขียน `lib/services/invoice_service.dart`**

```dart
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'invoice_calculator.dart';
import 'supabase_service.dart';

const _slipBucket = 'payment-slip';

/// ผลของการตรวจก่อนออกบิล — แยกห้องที่ออกได้ออกจากห้องที่ข้าม
class InvoicePreview {
  final List<InvoiceDraft> drafts;
  final List<InvoiceDraft> skipped;

  const InvoicePreview({required this.drafts, required this.skipped});

  double get total =>
      drafts.fold<double>(0, (sum, draft) => sum + draft.total);
}

/// ทุกอย่างที่คุยกับตาราง invoices และ bucket payment-slip
///
/// แยกจาก SupabaseService เพราะไฟล์นั้นถือหกโดเมนอยู่แล้วและยาว 972 บรรทัด
/// การย้ายโค้ด billing ออกมาทำให้ไฟล์เดิมเล็กลง ไม่ใช่ใหญ่ขึ้น
class InvoiceService {
  InvoiceService({SupabaseService? service})
      : _service = service ?? SupabaseService();

  final SupabaseService _service;

  SupabaseClient get _client => Supabase.instance.client;

  static const _columns = '''
    id, invoice_no, room_id, tenant_id, billing_month, billing_year,
    room_price, electricity_units, electricity_cost, water_cost, cleaning_fee,
    total, status, due_date, issued_at, slip_url, slip_submitted_at,
    rejection_reason, paid_at, revision, void_reason,
    rooms(room_number), tenant_profiles(first_name, last_name)
  ''';

  // ── อ่าน ────────────────────────────────────────────────────────────────

  /// บิลทุกใบของหอในงวดที่ระบุ รวมใบที่ยกเลิกแล้ว
  ///
  /// การกรอง "ยกเลิกแล้ว" ออกจากรายการปกติเป็นหน้าที่ของ ViewModel ไม่ใช่ของ
  /// ที่นี่ เพราะหน้าจอมีชิปให้ดูใบที่ยกเลิกด้วย
  Future<List<Invoice>> fetchInvoices({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    final data = await _client
        .from('invoices')
        .select(_columns)
        .eq('dorm_id', dormitoryId)
        .eq('billing_month', month)
        .eq('billing_year', year)
        .order('invoice_no');

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(_invoiceFromRow)
        .toList();
  }

  /// ประวัติบิลของห้องเดียว เรียงจากงวดล่าสุดไปเก่า
  Future<List<Invoice>> fetchForRoom({
    required int roomDbId,
    int monthCount = 6,
  }) async {
    final data = await _client
        .from('invoices')
        .select(_columns)
        .eq('room_id', roomDbId)
        .order('billing_year', ascending: false)
        .order('billing_month', ascending: false)
        .limit(monthCount);

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(_invoiceFromRow)
        .toList();
  }

  /// บิลของห้องในงวดที่ระบุ — null แปลว่ายังไม่ออกบิล ไม่ใช่ error
  Future<Invoice?> fetchCurrentForRoom({
    required int roomDbId,
    required int month,
    required int year,
  }) async {
    final data = await _client
        .from('invoices')
        .select(_columns)
        .eq('room_id', roomDbId)
        .eq('billing_month', month)
        .eq('billing_year', year)
        .neq('status', InvoiceStatus.voided.name)
        .maybeSingle();

    return data == null ? null : _invoiceFromRow(data);
  }

  // ── ตรวจก่อนออกบิล ──────────────────────────────────────────────────────

  /// ประกอบร่างบิลของทุกห้องในหอสำหรับงวดที่ระบุ
  ///
  /// รวมทุกห้อง ไม่กรองทิ้ง เพราะหน้าจอต้องบอกได้ว่าห้องไหนข้ามเพราะอะไร
  Future<InvoicePreview> previewDrafts({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    final rooms = await _service.fetchRooms(dormitoryId: dormitoryId);
    final roomIds = rooms.map((room) => room.dbId).toList();
    if (roomIds.isEmpty) {
      return const InvoicePreview(drafts: [], skipped: []);
    }

    final elecs = await _client
        .from('electricity_record')
        .select()
        .inFilter('room_id', roomIds)
        .eq('billing_month', month)
        .eq('billing_year', year);
    final waters = await _client
        .from('water_meter')
        .select()
        .inFilter('room_id', roomIds)
        .eq('billing_month', month)
        .eq('billing_year', year);
    final issued = await _client
        .from('invoices')
        .select('room_id')
        .inFilter('room_id', roomIds)
        .eq('billing_month', month)
        .eq('billing_year', year)
        .neq('status', InvoiceStatus.voided.name);

    final elecData = (elecs as List).cast<Map<String, dynamic>>();
    final waterData = (waters as List).cast<Map<String, dynamic>>();
    final issuedRoomIds = (issued as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['room_id'] as int)
        .toSet();
    final cleaningByRoom = await _fetchCleaningFeesByRoom(
      roomIds: roomIds,
      month: month,
      year: year,
    );

    final drafts = <InvoiceDraft>[];
    final skipped = <InvoiceDraft>[];

    for (final room in rooms) {
      final e = elecData.firstWhere((r) => r['room_id'] == room.dbId,
          orElse: () => {});
      final w = waterData.firstWhere((r) => r['room_id'] == room.dbId,
          orElse: () => {});

      final draft = buildDraft(
        room: room,
        billingMonth: month,
        billingYear: year,
        electricity: e.isEmpty
            ? null
            : MeterCharge(
                units: _toDouble(e['current_reading']) -
                    _toDouble(e['previous_reading']),
                amount: _toDouble(e['amount']),
              ),
        waterAmount: w.isEmpty ? null : _toDouble(w['amount']),
        cleaningFee: cleaningByRoom[room.dbId] ?? 0,
        alreadyIssued: issuedRoomIds.contains(room.dbId),
      );

      (draft.canIssue ? drafts : skipped).add(draft);
    }

    return InvoicePreview(drafts: drafts, skipped: skipped);
  }

  /// ค่าทำความสะอาดจากคำขอที่เสร็จสิ้นในงวดนั้น แยกตามห้อง
  Future<Map<int, double>> _fetchCleaningFeesByRoom({
    required List<int> roomIds,
    required int month,
    required int year,
  }) async {
    final periodStart = DateTime(year, month, 1);
    final periodEnd = DateTime(month == 12 ? year + 1 : year,
        month == 12 ? 1 : month + 1, 1);

    final data = await _client
        .from('maintenance_requests')
        .select('room_id, cleaning_fee')
        .inFilter('room_id', roomIds)
        .eq('request_type', 'Cleaning')
        .eq('status', 'Completed')
        .gte('completed_at', periodStart.toIso8601String())
        .lt('completed_at', periodEnd.toIso8601String());

    final feeByRoom = <int, double>{};
    for (final row in (data as List).cast<Map<String, dynamic>>()) {
      final roomId = row['room_id'] as int;
      feeByRoom[roomId] =
          (feeByRoom[roomId] ?? 0) + _toDouble(row['cleaning_fee']);
    }
    return feeByRoom;
  }

  // ── สลิป ────────────────────────────────────────────────────────────────

  /// อัปโหลดสลิปแล้วคืน storage path
  Future<String> uploadSlip({
    required Invoice invoice,
    required File file,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${invoice.roomDbId}/${invoice.invoiceNo}-$stamp.jpg';
    await _client.storage.from(_slipBucket).upload(path, file);
    return path;
  }

  /// บันทึกสลิปเข้าบิลผ่าน RPC ที่ตรวจสิทธิ์และสถานะเองในฐานข้อมูล
  ///
  /// ไม่ UPDATE ตรงเพราะ RLS policy จำกัดไม่ได้ว่าคอลัมน์ไหนแก้ได้
  Future<void> submitSlip({
    required int invoiceId,
    required String slipPath,
  }) async {
    await _client.rpc('submit_payment_slip', params: {
      'p_invoice_id': invoiceId,
      'p_slip_url': slipPath,
    });
  }

  /// ลบสลิปที่เพิ่งอัปโหลดเมื่อขั้นตอนถัดไปล้ม — best effort
  Future<void> discardSlip(String path) async {
    try {
      await _client.storage.from(_slipBucket).remove([path]);
    } catch (_) {
      // ปล่อยผ่าน: ไฟล์กำพร้าหนึ่งไฟล์ไม่ควรกลบข้อความ error ตัวจริง
    }
  }

  /// signed URL อายุ 1 ชั่วโมง สร้างใหม่ทุกครั้งที่เปิดดู ไม่ cache ข้าม session
  Future<String> signedSlipUrl(String path) =>
      _client.storage.from(_slipBucket).createSignedUrl(path, 3600);
}

// ── แปลงแถว ───────────────────────────────────────────────────────────────

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

InvoiceStatus _statusFromName(String? name) {
  return InvoiceStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => InvoiceStatus.unpaid,
  );
}

/// PostgREST คืน Map สำหรับ many-to-one และ List สำหรับ one-to-many
/// จึงรองรับทั้งสองแบบเหมือนที่ fetchDormitoryInfo ทำอยู่แล้ว
Map<String, dynamic>? _embedded(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return (value.first as Map).cast<String, dynamic>();
  }
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

Invoice _invoiceFromRow(Map<String, dynamic> row) {
  final room = _embedded(row['rooms']);
  final tenant = _embedded(row['tenant_profiles']);
  final tenantName = [
    tenant?['first_name'] as String?,
    tenant?['last_name'] as String?,
  ].where((part) => part != null && part.trim().isNotEmpty).join(' ').trim();

  return Invoice(
    dbId: row['id'] as int,
    invoiceNo: row['invoice_no'] as String,
    roomDbId: row['room_id'] as int,
    roomNumber: room?['room_number'] as String? ?? '-',
    tenantId: row['tenant_id'] as String?,
    tenantName: tenantName.isEmpty ? '-' : tenantName,
    billingMonth: row['billing_month'] as int,
    billingYear: row['billing_year'] as int,
    roomPrice: _toDouble(row['room_price']),
    electricityUnits: _toDouble(row['electricity_units']),
    electricityCost: _toDouble(row['electricity_cost']),
    waterCost: _toDouble(row['water_cost']),
    cleaningFee: _toDouble(row['cleaning_fee']),
    total: _toDouble(row['total']),
    status: _statusFromName(row['status'] as String?),
    dueDate: DateTime.parse(row['due_date'] as String),
    issuedAt: DateTime.parse(row['issued_at'] as String),
    slipUrl: row['slip_url'] as String?,
    slipSubmittedAt: row['slip_submitted_at'] == null
        ? null
        : DateTime.parse(row['slip_submitted_at'] as String),
    rejectionReason: row['rejection_reason'] as String?,
    paidAt: row['paid_at'] == null
        ? null
        : DateTime.parse(row['paid_at'] as String),
    revision: row['revision'] as int? ?? 1,
    voidReason: row['void_reason'] as String?,
  );
}
```

- [ ] **Step 3: ลบโค้ด billing ออกจาก `lib/services/supabase_service.dart`**

ลบทั้งหมดในหัวข้อ `// --- ระบบ Billing ---` และ `// --- ระบบ Billing ฝั่งผู้เช่า ---` ได้แก่ `fetchInvoices`, `_fetchCleaningFeesByRoom`, `fetchInvoiceForRoom`, `fetchInvoiceHistoryForRoom` และ `_fetchCleaningFeesByPeriod` พร้อม import `invoice_calculator.dart` ที่เพิ่มไว้ใน Task 2 (ย้ายไปอยู่ที่ `invoice_service.dart` แล้ว)

ตรวจว่าไม่มีอะไรอ้างถึงอีก

```bash
grep -rn "fetchInvoice\|_fetchCleaningFees" lib test
```
Expected: เจอเฉพาะใน `lib/services/invoice_service.dart`

- [ ] **Step 4: เขียน `lib/services/tenant_billing_source.dart` ใหม่ทั้งไฟล์**

```dart
import 'dart:io';

import '../models/models.dart';
import '../viewmodels/action_result.dart';
import 'invoice_service.dart';
import 'supabase_service.dart';

/// ช่องทางที่ฝั่งผู้เช่าใช้เข้าถึงบิลของตัวเอง
///
/// คงไว้เป็น abstract เพื่อให้ ViewModel ทดสอบได้ด้วย fake โดยไม่ต้องมี
/// Supabase client — เหตุผลเดียวกับที่ formatters.dart อธิบายไว้
abstract class TenantBillingSource {
  Future<Invoice?> fetchCurrentBill({
    required int roomDbId,
    required int month,
    required int year,
  });

  Future<List<Invoice>> fetchBillHistory({
    required int roomDbId,
    int monthCount,
  });

  Future<PaymentChannel> fetchPaymentChannel({required int dormitoryId});

  Future<ActionResult> submitPaymentSlip({
    required Invoice bill,
    required File slip,
  });
}

class SupabaseTenantBillingSource implements TenantBillingSource {
  SupabaseTenantBillingSource({
    InvoiceService? invoiceService,
    SupabaseService? service,
  })  : _injectedInvoices = invoiceService,
        _injectedService = service;

  final InvoiceService? _injectedInvoices;
  final SupabaseService? _injectedService;
  InvoiceService? _resolvedInvoices;
  SupabaseService? _resolvedService;

  /// สร้างแบบ lazy: constructor ของทั้งสองตัวอ่าน Supabase.instance ทันที
  /// ซึ่ง assert ใน unit test การหน่วงไว้ทำให้ทดสอบส่วนที่ไม่แตะเครือข่ายได้
  InvoiceService get _invoices =>
      _resolvedInvoices ??= (_injectedInvoices ?? InvoiceService());
  SupabaseService get _service =>
      _resolvedService ??= (_injectedService ?? SupabaseService());

  @override
  Future<Invoice?> fetchCurrentBill({
    required int roomDbId,
    required int month,
    required int year,
  }) =>
      _invoices.fetchCurrentForRoom(
        roomDbId: roomDbId,
        month: month,
        year: year,
      );

  @override
  Future<List<Invoice>> fetchBillHistory({
    required int roomDbId,
    int monthCount = 6,
  }) =>
      _invoices.fetchForRoom(roomDbId: roomDbId, monthCount: monthCount);

  @override
  Future<PaymentChannel> fetchPaymentChannel({required int dormitoryId}) async {
    final dorm = await _service.fetchDormitoryInfo(dormitoryId: dormitoryId);
    return PaymentChannel(
      bankName: 'ธนาคารกสิกรไทย',
      accountNo: '1438323216',
      accountName: dorm?.landlordName ?? dorm?.name ?? 'เจ้าของหอ',
      qrAssetPath: 'lib/assets/sample_paymant_qrcode.jpg',
    );
  }

  /// อัปโหลดก่อนแล้วค่อยบันทึก ถ้าบันทึกล้มให้ลบไฟล์ที่เพิ่งอัปทิ้ง
  /// ไม่งั้นจะเหลือไฟล์ที่ไม่มีแถวไหนอ้างถึงค้างอยู่ใน storage
  @override
  Future<ActionResult> submitPaymentSlip({
    required Invoice bill,
    required File slip,
  }) async {
    final path = await _invoices.uploadSlip(invoice: bill, file: slip);
    try {
      await _invoices.submitSlip(invoiceId: bill.dbId, slipPath: path);
    } catch (error) {
      await _invoices.discardSlip(path);
      rethrow;
    }

    return const ActionResult(
      success: true,
      message: 'ส่งสลิปแล้ว รอเจ้าของหอตรวจสอบ',
    );
  }
}
```

- [ ] **Step 5: ปรับ ViewModel ฝั่งผู้เช่า**

`lib/viewmodels/tenant_bills_view_model.dart` — เปลี่ยนชนิดจาก `TenantBill` เป็น `Invoice` ทุกจุด เปลี่ยน source เริ่มต้นเป็น `SupabaseTenantBillingSource()` และปรับสามฟังก์ชันระดับไฟล์

```dart
List<Invoice> filterBills(List<Invoice> bills, String filter) {
  if (filter == 'ทั้งหมด') return bills;
  return bills.where((bill) => billStatusLabel(bill.status) == filter).toList();
}

double totalOutstanding(List<Invoice> bills) => bills
    .where((bill) => bill.status == InvoiceStatus.unpaid)
    .fold<double>(0, (sum, bill) => sum + bill.total);

double totalPaidInYear(List<Invoice> bills, int year) => bills
    .where((bill) => bill.status == InvoiceStatus.paid && bill.period.year == year)
    .fold<double>(0, (sum, bill) => sum + bill.total);
```

`totalOutstanding` กรอง `unpaid` อยู่แล้ว บิลที่ `voided` จึงไม่ถูกนับโดยอัตโนมัติ — เทสต์ใน Step 8 ล็อกพฤติกรรมนี้ไว้

`submitSlip` เปลี่ยน signature เป็นรับ `Invoice`

```dart
  Future<ActionResult> submitSlip({
    required Invoice bill,
    required File slip,
  }) async {
    isSubmittingSlip = true;
    notifyListeners();

    try {
      final result = await _source.submitPaymentSlip(bill: bill, slip: slip);
      if (result.success) await load();
      return result;
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ส่งสลิปไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isSubmittingSlip = false;
      notifyListeners();
    }
  }
```

`lib/viewmodels/tenant_dashboard_view_model.dart` — เปลี่ยนชนิด `TenantBill` เป็น `Invoice` ทุกจุด และเปลี่ยน source เริ่มต้นเป็น `SupabaseTenantBillingSource()` เช่นกัน

- [ ] **Step 6: ปรับหน้าจอและวิดเจ็ตฝั่งผู้เช่า**

`lib/widgets/tenant_bill_card.dart` — เปลี่ยน `final TenantBill bill;` เป็น `final Invoice bill;` ลบ `final invoice = bill.invoice;` แล้วอ่านตรงจาก `bill` และเพิ่มสามอย่าง

```dart
    // ใต้หัวการ์ด ถัดจากชื่อเดือน
    Text(
      bill.revision > 1
          ? '${bill.invoiceNo} · แก้ไขครั้งที่ ${bill.revision}'
          : bill.invoiceNo,
      style: Theme.of(context).textTheme.labelSmall,
    ),
```

```dart
    // ท้ายการ์ด ก่อนบรรทัดครบกำหนด — ผู้เช่าต้องอ่านก่อนจ่ายรอบสอง
    if (bill.rejectionReason != null && bill.status == InvoiceStatus.unpaid) ...[
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.destructiveBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'สลิปถูกปฏิเสธ: ${bill.rejectionReason}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.destructive),
        ),
      ),
    ],
```

บรรทัดครบกำหนดเดิมเช็ค `bill.dueDate != null` ซึ่งไม่จำเป็นแล้วเพราะ `dueDate` เป็น non-nullable

```dart
    if (bill.status == InvoiceStatus.unpaid) ...[
      const SizedBox(height: 8),
      Text(
        'ครบกำหนด ${bill.dueDate.day} ${thaiMonthName(bill.dueDate.month)} ${bill.dueDate.year}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
```

`lib/widgets/payment_sheet.dart` · `lib/screens/tenant/tenant_bills_screen.dart` · `tenant_dashboard_screen.dart` · `tenant_shell.dart` — เปลี่ยนชนิด `TenantBill` เป็น `Invoice` และแก้จุดเรียก `submitSlip` ให้ส่ง `bill:` แทน `billId:` หน้าตายังเป็นแบบเดิม (แผ่นชำระเงินจะทำใน Task 5)

- [ ] **Step 7: ปรับฝั่งเจ้าของหอ**

`lib/viewmodels/billing_view_model.dart` — อ่านจาก `InvoiceService` เพิ่มจำนวนร่างที่พร้อมออกไว้ให้ empty state ใช้ และให้ตัวกรอง `ทั้งหมด` ไม่รวมใบที่ยกเลิก

```dart
class BillingViewModel extends ChangeNotifier {
  BillingViewModel({required this.dormitoryId, InvoiceService? service})
      : _service = service ?? InvoiceService();

  final int dormitoryId;
  final InvoiceService _service;

  bool isLoading = true;
  List<Invoice> invoices = [];
  /// จำนวนห้องที่มิเตอร์พร้อมแล้วแต่ยังไม่ได้ออกบิล — ใช้แยกสาเหตุรายการว่าง
  int readyToIssueCount = 0;
  String selectedFilter = 'ทั้งหมด';
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  String? _pendingError;

  List<Invoice> get filteredInvoices {
    switch (selectedFilter) {
      case 'ค้างชำระ':
        return invoices.where((i) => i.status == InvoiceStatus.unpaid).toList();
      case 'รอตรวจสลิป':
        return invoices.where((i) => i.status == InvoiceStatus.pending).toList();
      case 'ชำระแล้ว':
        return invoices.where((i) => i.status == InvoiceStatus.paid).toList();
      case 'ยกเลิกแล้ว':
        return invoices.where((i) => i.isVoided).toList();
      default:
        // ใบที่ยกเลิกไม่โผล่ในรายการปกติ ไม่งั้นงวดที่ออกใบแทนจะดูเหมือน
        // ค้างชำระสองใบ
        return invoices.where((i) => !i.isVoided).toList();
    }
  }

  Future<void> loadInvoices() async {
    isLoading = true;
    notifyListeners();
    try {
      invoices = await _service.fetchInvoices(
        dormitoryId: dormitoryId,
        month: selectedMonth,
        year: selectedYear,
      );
      final preview = await _service.previewDrafts(
        dormitoryId: dormitoryId,
        month: selectedMonth,
        year: selectedYear,
      );
      readyToIssueCount = preview.drafts.length;
    } catch (e) {
      _pendingError = 'โหลดข้อมูลบิลไม่สำเร็จ: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
```

`setFilter`, `setPeriod`, `consumeError` คงเดิม

`lib/screens/admin/billing_screen.dart` — สี่จุด

1. เพิ่ม `'ยกเลิกแล้ว'` เข้าลิสต์ชิปกรอง
2. ใน `_InvoiceCard` เปลี่ยน `invoice.date` เป็น `invoice.period` และเพิ่มเลขที่บิลใต้ชื่อห้อง

```dart
              Text(
                invoice.revision > 1
                    ? '${invoice.invoiceNo} · แก้ไขครั้งที่ ${invoice.revision}'
                    : invoice.invoiceNo,
                style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground),
              ),
```

3. เพิ่มกรณี `voided` ในการเลือกป้ายสถานะ

```dart
    if (invoice.status == InvoiceStatus.paid) {
      variant = BadgeVariant.success;
      statusText = 'ชำระแล้ว';
    } else if (invoice.status == InvoiceStatus.pending) {
      variant = BadgeVariant.warning;
      statusText = 'รอตรวจสลิป';
    } else if (invoice.isVoided) {
      variant = BadgeVariant.muted;
      statusText = 'ยกเลิกแล้ว';
    }
```

4. แทน `_buildEmptyState` ด้วยเวอร์ชันที่แยกสองสาเหตุ

```dart
  Widget _buildEmptyState(BillingViewModel viewModel) {
    final hasDrafts = viewModel.readyToIssueCount > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasDrafts ? Icons.playlist_add_check : Icons.speed_outlined,
                size: 64, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              hasDrafts
                  ? 'มิเตอร์พร้อมแล้ว ${viewModel.readyToIssueCount} ห้อง ยังไม่ได้ออกบิลงวดนี้'
                  : 'ยังไม่ได้จดมิเตอร์งวดนี้',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: viewModel.loadInvoices,
              child: const Text('โหลดใหม่อีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
```

ปุ่ม "ออกบิลใหม่" ยังเรียก `loadInvoices` อยู่ใน Task นี้ — Task 4 จะต่อให้ออกบิลจริง

- [ ] **Step 8: แก้เทสต์เดิมและเพิ่มกรณีบิลยกเลิก**

ใน `test/tenant_dashboard_unit_test.dart` ลบการใช้ `MockTenantBillingSource` และ `MockPaymentLedger` (บรรทัดราว 400-430) แล้วเพิ่ม helper สร้าง `Invoice` กับเทสต์ที่ล็อกพฤติกรรมสถานะที่สี่

```dart
Invoice _bill({
  required int month,
  required int year,
  required InvoiceStatus status,
  double total = 5240,
}) {
  return Invoice(
    dbId: month,
    invoiceNo: 'INV-$year${month.toString().padLeft(2, '0')}-301',
    roomDbId: 1,
    roomNumber: '301',
    tenantName: 'สมชาย ใจดี',
    billingMonth: month,
    billingYear: year,
    roomPrice: 3500,
    electricityCost: 1136,
    waterCost: 404,
    cleaningFee: 200,
    total: total,
    status: status,
    dueDate: DateTime(year, month + 1, 5),
    issuedAt: DateTime(year, month + 1, 1),
  );
}

void main() {
  group('ยอดค้างชำระ', () {
    test('บิลที่ยกเลิกแล้วไม่ถูกนับเป็นยอดค้างชำระ', () {
      final bills = [
        _bill(month: 7, year: 2026, status: InvoiceStatus.voided),
        _bill(month: 8, year: 2026, status: InvoiceStatus.unpaid),
      ];

      expect(totalOutstanding(bills), 5240);
    });

    test('บิลที่รอตรวจสลิปไม่ถูกนับเป็นยอดค้าง เพราะจ่ายไปแล้ว', () {
      final bills = [
        _bill(month: 8, year: 2026, status: InvoiceStatus.pending),
      ];

      expect(totalOutstanding(bills), 0);
    });

    test('บิลที่ยกเลิกแล้วไม่ถูกนับเป็นยอดชำระสะสมของปี', () {
      final bills = [
        _bill(month: 7, year: 2026, status: InvoiceStatus.voided),
        _bill(month: 8, year: 2026, status: InvoiceStatus.paid),
      ];

      expect(totalPaidInYear(bills, 2026), 5240);
    });
  });
}
```

เทสต์นี้ต้อง import `package:horplug/viewmodels/tenant_bills_view_model.dart` เพื่อใช้ `totalOutstanding` และ `totalPaidInYear`

- [ ] **Step 9: ตรวจว่าไม่มีร่องรอยของตัวจำลองเหลืออยู่**

```bash
grep -rn "TenantBill\b\|MockPaymentLedger\|MockTenantBillingSource\|โหมดตัวอย่าง" lib test
```
Expected: ไม่พบอะไรเลย ยกเว้น `โหมดตัวอย่าง` ใน `payment_sheet.dart` ที่จะลบใน Task 5

```bash
flutter analyze
flutter test
```
Expected: analyze สะอาด · เทสต์ผ่านทั้งหมด

- [ ] **Step 10: ตรวจบนเครื่องจริงทั้งสองบทบาท**

```bash
flutter run
```

ฝั่งเจ้าของหอ — หน้าบิลแสดงบิลที่ backfill สร้างไว้ เลขที่บิลขึ้นครบ ชิป "ยกเลิกแล้ว" กดได้แล้วรายการว่าง เลือกงวดที่ไม่มีบิลแล้วเห็น empty state ที่ถูกกรณี

ฝั่งผู้เช่า — แท็บบิลแสดงประวัติเท่าเดิมกับก่อนเริ่ม Task ยอดค้างบนแดชบอร์ดตรงกับบิลงวดปัจจุบัน และที่สำคัญคือ **ปิดแอปแล้วเปิดใหม่ สถานะต้องไม่รีเซ็ต** ซึ่งเป็นสิ่งที่ตัวจำลองทำไม่ได้

- [ ] **Step 11: หยุดและรายงานผู้ใช้**

รายงานผล analyze เทสต์ และผลการตรวจทั้งสองบทบาท โดยระบุชัดว่าสถานะอยู่รอดข้ามการปิดแอปแล้ว จากนั้นบอกว่าพร้อม commit ด้วยข้อความหัวข้อ **3** ในไฟล์ commit messages — **อย่ารัน `git commit` เอง**

---

## Task 4: ออกบิลทั้งหอจากกล่องตรวจก่อนออก

**Files:**
- Modify: `lib/services/invoice_service.dart` (เพิ่ม `issueInvoices`)
- Create: `lib/viewmodels/invoice_issue_view_model.dart`
- Create: `lib/widgets/issue_invoices_dialog.dart`
- Modify: `lib/screens/admin/billing_screen.dart` (ต่อปุ่ม "ออกบิลใหม่")

**Interfaces:**
- Consumes: `InvoicePreview`, `InvoiceDraft`, `previewDrafts`, `invoiceNoFor`, `dueDateFor`, `skipReasonLabel`
- Produces:
  - `Future<int> InvoiceService.issueInvoices({required int dormitoryId, required List<InvoiceDraft> drafts})`
  - `class InvoiceIssueViewModel` — `isLoading`, `isIssuing`, `preview`, `errorMessage`, `load()`, `issue()` คืน `ActionResult`
  - `Future<bool> showIssueInvoicesDialog(BuildContext, {required int dormitoryId, required int month, required int year})` — คืน `true` เมื่อออกบิลสำเร็จ

- [ ] **Step 1: เพิ่ม `issueInvoices` ใน `lib/services/invoice_service.dart`**

```dart
  /// ออกบิลทั้งชุดใน insert เดียว
  ///
  /// Postgres รับประกัน all-or-nothing ให้เอง จึงไม่มีสภาพ "ออกไป 7 จาก 12
  /// ห้องแล้วค้าง" และการกดซ้อนกันจะชนที่ partial unique index เป็น 23505
  /// แทนที่จะสร้างบิลซ้ำเงียบๆ
  Future<int> issueInvoices({
    required int dormitoryId,
    required List<InvoiceDraft> drafts,
  }) async {
    if (drafts.isEmpty) return 0;

    final issuedBy = _client.auth.currentUser?.id;
    if (issuedBy == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final rows = drafts.map((draft) {
      final due = dueDateFor(draft.billingYear, draft.billingMonth);
      return {
        'invoice_no': invoiceNoFor(
          year: draft.billingYear,
          month: draft.billingMonth,
          roomNumber: draft.roomNumber,
        ),
        'dorm_id': dormitoryId,
        'room_id': draft.roomDbId,
        'tenant_id': draft.tenantId,
        'billing_month': draft.billingMonth,
        'billing_year': draft.billingYear,
        'room_price': draft.roomPrice,
        'electricity_units': draft.electricityUnits,
        'electricity_cost': draft.electricityCost,
        'water_cost': draft.waterCost,
        'cleaning_fee': draft.cleaningFee,
        'due_date':
            '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
        'issued_by': issuedBy,
      };
    }).toList();

    await _client.from('invoices').insert(rows);
    return rows.length;
  }
```

- [ ] **Step 2: เขียน `lib/viewmodels/invoice_issue_view_model.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/invoice_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'safe_notifier.dart';

/// แปลง error ตอนออกบิลให้เป็นข้อความที่บอกทางออกได้
///
/// 23505 คือชนกับ partial unique index แปลว่ามีคนออกบิลงวดนี้ไปก่อนแล้ว
/// ซึ่งต่างจากเน็ตหลุดโดยสิ้นเชิง ผู้ใช้ต้องโหลดใหม่ ไม่ใช่ลองใหม่
String describeIssueError(Object error) {
  if (error is PostgrestException && error.code == '23505') {
    return 'บางห้องถูกออกบิลงวดนี้ไปแล้ว กรุณาโหลดใหม่';
  }
  return formatErrorMessage(error);
}

class InvoiceIssueViewModel extends ChangeNotifier with SafeNotifier {
  InvoiceIssueViewModel({
    required this.dormitoryId,
    required this.month,
    required this.year,
    InvoiceService? service,
  }) : _service = service ?? InvoiceService();

  final int dormitoryId;
  final int month;
  final int year;
  final InvoiceService _service;

  bool isLoading = true;
  bool isIssuing = false;
  String? errorMessage;
  InvoicePreview? preview;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      preview = await _service.previewDrafts(
        dormitoryId: dormitoryId,
        month: month,
        year: year,
      );
    } catch (error) {
      errorMessage = describeIssueError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ActionResult> issue() async {
    final drafts = preview?.drafts ?? const [];
    if (drafts.isEmpty) {
      return const ActionResult(
        success: false,
        message: 'ไม่มีห้องที่ออกบิลได้ในงวดนี้',
      );
    }

    isIssuing = true;
    notifyListeners();

    try {
      final count = await _service.issueInvoices(
        dormitoryId: dormitoryId,
        drafts: drafts,
      );
      return ActionResult(success: true, message: 'ออกบิลแล้ว $count ห้อง');
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ออกบิลไม่สำเร็จ: ${describeIssueError(error)}',
      );
    } finally {
      isIssuing = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 3: เขียน `lib/widgets/issue_invoices_dialog.dart`**

โครงสร้างตามภาพในสเปก — สองรายการแยกกันชัดเจน รายการที่จะออกด้านบน รายการที่ข้ามพร้อมเหตุผลด้านล่าง

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/invoice_calculator.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/invoice_issue_view_model.dart';
import '../viewmodels/tenant_dashboard_view_model.dart' show thaiMonthName;
import 'reusable_widgets.dart';

/// เปิดกล่องตรวจก่อนออกบิล — คืน true เมื่อออกบิลสำเร็จ
Future<bool> showIssueInvoicesDialog(
  BuildContext context, {
  required int dormitoryId,
  required int month,
  required int year,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => InvoiceIssueViewModel(
        dormitoryId: dormitoryId,
        month: month,
        year: year,
      )..load(),
      child: const _IssueInvoicesDialog(),
    ),
  );
  return result ?? false;
}

class _IssueInvoicesDialog extends StatelessWidget {
  const _IssueInvoicesDialog();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<InvoiceIssueViewModel>();
    final preview = viewModel.preview;

    return AlertDialog(
      title: Text('ออกบิลเดือน${thaiMonthName(viewModel.month)} ${viewModel.year}'),
      content: SizedBox(
        width: 400,
        child: viewModel.isLoading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : viewModel.errorMessage != null
                ? SectionErrorNote(message: viewModel.errorMessage!)
                : _buildBody(context, preview!),
      ),
      actions: [
        TextButton(
          onPressed: viewModel.isIssuing ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        PrimaryButton(
          label: 'ออกบิล ${preview?.drafts.length ?? 0} ห้อง',
          isLoading: viewModel.isIssuing,
          onPressed: (preview?.drafts.isEmpty ?? true)
              ? null
              : () async {
                  final result = await viewModel.issue();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(result.message)));
                  if (result.success) Navigator.pop(context, true);
                },
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, InvoicePreview preview) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'จะออกบิล ${preview.drafts.length} ห้อง · ยอดรวม ${formatBaht(preview.total)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...preview.drafts.map((draft) => _DraftRow(draft: draft)),
          if (preview.skipped.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Text('ข้าม ${preview.skipped.length} ห้อง',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            // ต้องเห็นเหตุผลทุกห้อง ถ้าเงียบไปเจ้าของหอจะไม่รู้ว่าลืมจดมิเตอร์
            // จนกระทั่งผู้เช่าทักมาถามว่าทำไมไม่ได้บิล
            ...preview.skipped.map((draft) => _SkippedRow(draft: draft)),
          ],
        ],
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.draft});
  final InvoiceDraft draft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(draft.roomNumber)),
          Expanded(
            child: Text(draft.tenantName,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(formatBaht(draft.total),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SkippedRow extends StatelessWidget {
  const _SkippedRow({required this.draft});
  final InvoiceDraft draft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(draft.roomNumber)),
          Expanded(
            child: Text(
              skipReasonLabel(draft.skipReason!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: ต่อปุ่มใน `lib/screens/admin/billing_screen.dart`**

```dart
              PrimaryButton(
                label: 'ออกบิลใหม่',
                icon: Icons.add_chart,
                onPressed: () async {
                  final issued = await showIssueInvoicesDialog(
                    context,
                    dormitoryId: viewModel.dormitoryId,
                    month: viewModel.selectedMonth,
                    year: viewModel.selectedYear,
                  );
                  if (issued) await viewModel.loadInvoices();
                },
              ),
```

เพิ่ม `import '../../widgets/issue_invoices_dialog.dart';` และเพิ่มปุ่มออกบิลใน empty state กรณี `hasDrafts` ให้กดจากตรงนั้นได้ด้วย

- [ ] **Step 5: ตรวจ**

```bash
flutter analyze
flutter test
```
Expected: analyze สะอาด · เทสต์ผ่านทั้งหมด (Task นี้ไม่เพิ่มเทสต์ เพราะตรรกะการข้ามถูกทดสอบไว้แล้วใน Task 2 ส่วนที่เหลือเป็นการต่อสาย)

- [ ] **Step 6: ตรวจบนเครื่องจริง**

เลือกงวดที่ยังไม่ออกบิล กด "ออกบิลใหม่" ตรวจว่า

- รายการที่จะออกกับที่ข้ามแยกกันชัด และเหตุผลตรงกับความจริง (ลองลบมิเตอร์ห้องหนึ่งออกก่อนแล้วเปิดใหม่ ต้องขึ้น "ยังไม่จดมิเตอร์")
- กดออกบิลแล้วรายการบิลขึ้นครบ
- **กด "ออกบิลใหม่" ซ้ำอีกครั้งทันที** ต้องเห็นทุกห้องอยู่ในรายการข้ามด้วยเหตุผล "ออกบิลงวดนี้ไปแล้ว" และปุ่มออกบิลถูกปิด
- ฝั่งผู้เช่าเห็นบิลใหม่ในแท็บบิล

- [ ] **Step 7: หยุดและรายงานผู้ใช้**

รายงานว่าออกบิลได้กี่ห้อง ข้ามกี่ห้องด้วยเหตุผลอะไร และผลของการกดซ้ำ แล้วบอกว่าพร้อม commit ด้วยข้อความหัวข้อ **4** — **อย่ารัน `git commit` เอง**

---

## Task 5: แสดงช่องทางชำระเงินจริงในแผ่นชำระเงิน

**Files:**
- Modify: `pubspec.yaml` (ประกาศ asset รูป QR)
- Modify: `lib/widgets/payment_sheet.dart`

**Interfaces:**
- Consumes: `PaymentChannel` (`bankName`, `accountNo`, `accountName`, `qrAssetPath`) จาก Task 3
- Produces: ไม่มี API ใหม่

- [ ] **Step 1: ประกาศ asset ใน `pubspec.yaml`**

```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
    - lib/assets/sample_paymant_qrcode.jpg
```

```bash
flutter pub get
```

- [ ] **Step 2: แก้ `lib/widgets/payment_sheet.dart`**

ลบแบนเนอร์ `โหมดตัวอย่าง` ทั้งก้อน แล้วแทนส่วนช่องทางชำระด้วย

```dart
  Widget _buildChannel(BuildContext context, PaymentChannel channel) {
    return Column(
      children: [
        Text('ยอดที่ต้องชำระ',
            style: Theme.of(context).textTheme.labelSmall),
        Text(formatBaht(widget.bill.total),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(channel.qrAssetPath, width: 200, height: 200),
        ),
        const SizedBox(height: 8),
        // QR เฟสนี้เป็นภาพนิ่งจึงไม่มีจำนวนเงินฝังอยู่ ถ้าไม่บอกตรงนี้ ผู้เช่า
        // จะสแกนแล้วเจอช่องจำนวนเงินว่าง กรอกผิด แล้วสลิปถูกปฏิเสธ
        Text(
          'กรุณากรอกจำนวนเงินเอง',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.warning),
        ),
        const SizedBox(height: 12),
        Text(channel.bankName, style: Theme.of(context).textTheme.bodyMedium),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SelectableText(
              channel.accountNo,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(letterSpacing: 1.2),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'คัดลอกเลขบัญชี',
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: channel.accountNo));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('คัดลอกเลขบัญชีแล้ว')),
                );
              },
            ),
          ],
        ),
        Text(channel.accountName,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
```

`Clipboard` มาจาก `package:flutter/services.dart` ซึ่งไฟล์นี้ import ไว้อยู่แล้ว

เมื่อ `channel == null` (โหลดช่องทางไม่สำเร็จ) ให้แสดง `SectionErrorNote` ว่า "โหลดช่องทางชำระเงินไม่สำเร็จ" แทนที่จะซ่อนทั้งแผ่น — ผู้เช่ายังต้องแนบสลิปได้ถ้าเขาจ่ายผ่านช่องทางอื่นไปแล้ว

- [ ] **Step 3: ตรวจ**

```bash
flutter analyze
flutter test
flutter run
```

เปิดแท็บบิลฝั่งผู้เช่า กด "ชำระเงิน" ตรวจว่า QR ขึ้นจริงไม่ใช่กรอบว่าง (ถ้าว่างแปลว่า asset ไม่ได้ถูกประกาศ) เลขบัญชีคัดลอกได้ ข้อความเตือนเรื่องกรอกจำนวนเงินอ่านออก และไม่มีคำว่า "โหมดตัวอย่าง" เหลืออยู่

แนบสลิปจริงหนึ่งใบ แล้วตรวจใน Supabase ว่ามีไฟล์ใน bucket `payment-slip` และแถวบิลเปลี่ยนเป็น `pending`

- [ ] **Step 4: หยุดและรายงานผู้ใช้**

พร้อม commit ด้วยข้อความหัวข้อ **5** ในไฟล์ commit messages — **อย่ารัน `git commit` เอง**

---

## Task 6: โพสต์การ์ดบิลเข้าห้องแชทเมื่อออกบิล

**Files:**
- Create: `database/invoices_chat_message.sql`
- Modify: `lib/models/models.dart` (`MessageType.invoice`, `ChatMessage.invoiceId`)
- Modify: `lib/services/supabase_service.dart` (`sendMessage` และ `_mapMessageRow` รับ `invoiceId`)
- Modify: `lib/services/invoice_service.dart` (`postIssueNotices`)
- Create: `lib/widgets/invoice_chat_card.dart`
- Modify: `lib/widgets/chat_conversation_view.dart`
- Modify: `lib/viewmodels/chat_view_model.dart` · `lib/viewmodels/tenant_chat_view_model.dart`

**Interfaces:**
- Consumes: `Invoice`, `InvoiceService.fetchForRoom`, `issueInvoices`
- Produces:
  - `Future<int> InvoiceService.postIssueNotices({required List<Invoice> invoices})` — คืนจำนวนข้อความที่โพสต์จริง (ข้ามใบที่เคยแจ้งแล้ว)
  - `InvoiceService.issueInvoices` เปลี่ยน return type จาก `Future<int>` ที่ประกาศไว้ใน Task 4 เป็น `Future<List<Invoice>>` เพื่อให้ผู้เรียกเอาบิลที่เพิ่งสร้างไปโพสต์แชทต่อได้
  - `Future<Map<int, Invoice>> InvoiceService.invoicesByIdForRoom({required int roomDbId})`
  - `class InvoiceChatCard` — `Invoice? invoice`, `String fallbackText`, `VoidCallback? onOpen`

- [ ] **Step 1: เขียนและรัน `database/invoices_chat_message.sql`**

```sql
-- ข้อความบิลอ้างถึงบิลใบไหน — คู่ขนานกับ maintenance_request_id ที่มีอยู่แล้ว
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS invoice_id BIGINT REFERENCES invoices(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS messages_invoice ON messages (invoice_id);
```

รันใน Supabase SQL Editor

- [ ] **Step 2: เพิ่มชนิดข้อความใน `lib/models/models.dart`**

```dart
enum MessageType {
  text,
  maintenanceRequest,
  parcelNotification,
  maintenanceUpdate,
  image,
  cleaningRequest,
  cleaningUpdate,
  invoice,
}
```

เพิ่มฟิลด์ใน `ChatMessage` ต่อจาก `maintenanceRequestId`

```dart
  final int? invoiceId;
```
พร้อมพารามิเตอร์ `this.invoiceId,` ใน constructor

- [ ] **Step 3: ให้ `sendMessage` และ `_mapMessageRow` รู้จัก `invoice_id`**

ใน `lib/services/supabase_service.dart`

```dart
  Future<void> sendMessage({
    required int roomId,
    required String senderId,
    required bool isFromOwner,
    required String body,
    MessageType type = MessageType.text,
    String? attachmentUrl,
    int? maintenanceRequestId,
    int? invoiceId,
  }) async {
    await client.from('messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'is_from_owner': isFromOwner,
      'body': body,
      'message_type': type.name,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (maintenanceRequestId != null)
        'maintenance_request_id': maintenanceRequestId,
      if (invoiceId != null) 'invoice_id': invoiceId,
    });
  }
```

ใน `_mapMessageRow` เพิ่ม `invoiceId: row['invoice_id'] as int?,` ตอนสร้าง `ChatMessage`

- [ ] **Step 4: โพสต์ข้อความหลังออกบิล ใน `lib/services/invoice_service.dart`**

`issueInvoices` เปลี่ยนให้คืนบิลที่เพิ่งสร้างแทนจำนวน เพื่อให้ผู้เรียกเอาไปโพสต์ต่อได้

```dart
    final inserted = await _client.from('invoices').insert(rows).select(_columns);
    return (inserted as List)
        .cast<Map<String, dynamic>>()
        .map(_invoiceFromRow)
        .toList();
```
(เปลี่ยน return type เป็น `Future<List<Invoice>>` และแก้ `InvoiceIssueViewModel.issue()` ให้ใช้ `.length`)

เพิ่มสองเมธอด

```dart
  /// โพสต์การ์ดบิลเข้าห้องแชทของแต่ละบิล
  ///
  /// เป็น batch insert เดียวเช่นกัน ถ้าล้มก็ล้มทั้งชุด — บิลยังอยู่ ผู้เรียก
  /// รายงานว่าแจ้งเตือนไม่สำเร็จแล้วให้กดส่งซ้ำ ไม่ rollback บิล เพราะบิลคือ
  /// ของจริง ข้อความคือการแจ้งเตือนเกี่ยวกับมัน
  Future<int> postIssueNotices({required List<Invoice> invoices}) async {
    if (invoices.isEmpty) return 0;

    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    // ข้ามใบที่เคยแจ้งไปแล้ว เพื่อให้ปุ่มส่งซ้ำไม่สร้างข้อความซ้อน
    final existing = await _client
        .from('messages')
        .select('invoice_id')
        .inFilter('invoice_id', invoices.map((i) => i.dbId).toList())
        .eq('message_type', MessageType.invoice.name);
    final notified = (existing as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['invoice_id'] as int)
        .toSet();

    final rows = invoices
        .where((invoice) => !notified.contains(invoice.dbId))
        .map((invoice) => {
              'room_id': invoice.roomDbId,
              'sender_id': senderId,
              'is_from_owner': true,
              'body': 'ออกบิลค่าเช่างวด '
                  '${invoice.billingMonth}/${invoice.billingYear} แล้ว',
              'message_type': MessageType.invoice.name,
              'invoice_id': invoice.dbId,
            })
        .toList();

    if (rows.isEmpty) return 0;
    await _client.from('messages').insert(rows);
    return rows.length;
  }

  /// บิลของห้องหนึ่ง map ด้วย id — ให้การ์ดในแชทแสดงสถานะสด ไม่ใช่สถานะตอนส่ง
  Future<Map<int, Invoice>> invoicesByIdForRoom({
    required int roomDbId,
    int monthCount = 24,
  }) async {
    final invoices =
        await fetchForRoom(roomDbId: roomDbId, monthCount: monthCount);
    return {for (final invoice in invoices) invoice.dbId: invoice};
  }
```

ใน `InvoiceIssueViewModel.issue()` เรียกโพสต์ต่อจากออกบิล และแยกความล้มเหลวสองแบบออกจากกัน

```dart
      final issued = await _service.issueInvoices(
        dormitoryId: dormitoryId,
        drafts: drafts,
      );

      try {
        await _service.postIssueNotices(invoices: issued);
      } catch (_) {
        return ActionResult(
          success: true,
          message: 'ออกบิลแล้ว ${issued.length} ห้อง '
              'แต่แจ้งเตือนในแชทไม่สำเร็จ กดออกบิลอีกครั้งเพื่อส่งแจ้งเตือนซ้ำ',
        );
      }

      return ActionResult(
          success: true, message: 'ออกบิลแล้ว ${issued.length} ห้อง');
```

- [ ] **Step 5: เขียน `lib/widgets/invoice_chat_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/tenant_dashboard_view_model.dart'
    show billStatusLabel, thaiMonthName;

/// การ์ดบิลในฟองแชท — งวด ยอด ครบกำหนด และสถานะสด
///
/// [invoice] เป็น null ได้เมื่อโหลดสถานะไม่สำเร็จ กรณีนั้นแสดงข้อความสำรอง
/// แทนที่จะทำให้ทั้งแชทพัง
class InvoiceChatCard extends StatelessWidget {
  const InvoiceChatCard({
    super.key,
    required this.invoice,
    required this.fallbackText,
    required this.textColor,
    this.onOpen,
  });

  final Invoice? invoice;
  final String fallbackText;
  final Color textColor;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final bill = invoice;
    if (bill == null) {
      return Text(fallbackText, style: TextStyle(color: textColor));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long, size: 16, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'บิลค่าเช่าเดือน${thaiMonthName(bill.billingMonth)} ${bill.billingYear}',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(bill.invoiceNo,
            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 10)),
        const SizedBox(height: 8),
        Text('ยอดรวม ${formatBaht(bill.total)}',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(
          'ครบกำหนด ${bill.dueDate.day} ${thaiMonthName(bill.dueDate.month)} ${bill.dueDate.year}',
          style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(billStatusLabel(bill.status),
            style: TextStyle(color: textColor, fontSize: 11)),
        if (onOpen != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('แตะเพื่อเปิดบิล ›',
                style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 10)),
          ),
        ],
      ],
    );
  }
}
```

`AppColors` ถูก import ไว้เผื่อการปรับสีในอนาคต ถ้า analyze เตือน unused ให้ลบบรรทัด import นั้นออก

- [ ] **Step 6: เรนเดอร์การ์ดใน `lib/widgets/chat_conversation_view.dart`**

เพิ่มพารามิเตอร์สองตัวใน widget

```dart
  final Map<int, Invoice> invoicesById;
  final void Function(Invoice invoice)? onOpenInvoice;
```

ใน `_buildMessageContent` เพิ่มสาขาก่อน `return Text(...)` ตัวสุดท้าย

```dart
    if (message.type == MessageType.invoice) {
      return InvoiceChatCard(
        invoice: widget.invoicesById[message.invoiceId],
        fallbackText: message.text,
        textColor: textColor,
        onOpen: widget.onOpenInvoice == null ? null : () {},
      );
    }
```

ใน `_buildChatBubble` ให้ฟองข้อความชนิดบิลกดได้ ทำนองเดียวกับที่คำขอซ่อมทำอยู่

```dart
    final invoiceOfMessage = message.type == MessageType.invoice
        ? widget.invoicesById[message.invoiceId]
        : null;
    final canOpenInvoice =
        invoiceOfMessage != null && widget.onOpenInvoice != null;
```
แล้วห่อ `bubble` ด้วย `GestureDetector(onTap: () => widget.onOpenInvoice!(invoiceOfMessage!), child: bubble)` เมื่อ `canOpenInvoice`

- [ ] **Step 7: ให้ ViewModel ของแชททั้งสองฝั่งโหลดบิลของห้อง**

ใน `lib/viewmodels/chat_view_model.dart` เพิ่มฟิลด์และโหลดตอน `openChat`

```dart
  Map<int, Invoice> invoicesById = {};

  // โหลดครั้งเดียวตอนเปิดแชท แล้ว resolve ตาม invoiceId — เพิ่ม query เดียว
  // แลกกับการไม่มีการ์ดค้างที่ยังบอกว่าค้างชำระทั้งที่จ่ายไปแล้วเมื่อวาน
  Future<void> _loadInvoices(int roomId) async {
    try {
      invoicesById = await _invoiceService.invoicesByIdForRoom(roomDbId: roomId);
    } catch (_) {
      // การ์ดจะ fallback ไปแสดงข้อความสำรอง แชทต้องไม่พังเพราะบิลโหลดไม่ได้
      invoicesById = {};
    }
    notifyListeners();
  }
```
เรียก `_loadInvoices(chat.roomDbId)` ใน `openChat` และล้าง `invoicesById = {}` ใน `closeChat`

ทำแบบเดียวกันใน `lib/viewmodels/tenant_chat_view_model.dart` โดยใช้ `roomId` ที่ ViewModel ถืออยู่แล้ว

ส่งลงไปที่หน้าจอทั้งสองฝั่งผ่าน `ChatConversationView(invoicesById: viewModel.invoicesById, onOpenInvoice: ...)` — ฝั่งผู้เช่าเปิด `showPaymentSheet` ฝั่งเจ้าของหอเปิด `showInvoiceDetailSheet` ที่จะสร้างใน Task 7 ระหว่างนี้ให้ส่ง `null` ไปก่อนสำหรับฝั่งเจ้าของหอ

- [ ] **Step 8: ตรวจ**

```bash
flutter analyze
flutter test
flutter run
```

ออกบิลหนึ่งงวด แล้วตรวจ

- ฝั่งผู้เช่าเห็นการ์ดบิลในแชท กดแล้วเปิดแผ่นชำระเงินของบิลใบนั้น
- ฝั่งเจ้าของหอเห็นการ์ดเดียวกันในห้องแชทของห้องนั้น
- **จ่ายบิลจนสถานะเปลี่ยน แล้วปิดเปิดแชทใหม่** ป้ายสถานะบนการ์ดต้องเปลี่ยนตาม ไม่ค้างที่ "ค้างชำระ"
- กด "ออกบิลใหม่" ซ้ำ ต้องไม่มีข้อความบิลซ้ำในแชท

- [ ] **Step 9: หยุดและรายงานผู้ใช้**

พร้อม commit ด้วยข้อความหัวข้อ **6** — **อย่ารัน `git commit` เอง** และอย่าลืมให้ผู้ใช้ stage `database/invoices_chat_message.sql` ด้วย

---

## Task 7: เจ้าของหออนุมัติหรือปฏิเสธสลิป

**Files:**
- Modify: `lib/services/invoice_service.dart` (`approveSlip`, `rejectSlip`, `_postInvoiceNotice`)
- Create: `lib/widgets/slip_review_sheet.dart`
- Create: `lib/widgets/invoice_detail_sheet.dart`
- Modify: `lib/viewmodels/billing_view_model.dart`
- Modify: `lib/screens/admin/billing_screen.dart` (ต่อปุ่ม "ดูสลิป")
- Modify: `lib/screens/admin/chat_screen.dart` (ต่อ `onOpenInvoice`)

**Interfaces:**
- Consumes: `canTransition` จาก Task 2 · `signedSlipUrl` จาก Task 3 · `MessageType.invoice` จาก Task 6
- Produces:
  - `Future<void> InvoiceService.approveSlip({required Invoice invoice})`
  - `Future<void> InvoiceService.rejectSlip({required Invoice invoice, required String reason})`
  - `Future<bool> showSlipReviewSheet(BuildContext, {required Invoice invoice})`
  - `Future<bool> showInvoiceDetailSheet(BuildContext, {required Invoice invoice})`

- [ ] **Step 1: เพิ่มการเปลี่ยนสถานะใน `lib/services/invoice_service.dart`**

```dart
  Future<void> approveSlip({required Invoice invoice}) async {
    _assertTransition(invoice.status, InvoiceStatus.paid);

    final approvedBy = _client.auth.currentUser?.id;
    await _client.from('invoices').update({
      'status': InvoiceStatus.paid.name,
      // toUtc ก่อนเสมอ — DateTime ที่ไม่ใช่ UTC จะไม่มี offset ในสตริง
      // แล้ว Postgres ตีความเป็น UTC ทำให้เวลาเพี้ยนไปเท่ากับ timezone เครื่อง
      'paid_at': DateTime.now().toUtc().toIso8601String(),
      'approved_by': approvedBy,
    }).eq('id', invoice.dbId);

    await _postInvoiceNotice(
      invoice: invoice,
      body: 'รับชำระบิล ${invoice.invoiceNo} เรียบร้อยแล้ว ขอบคุณครับ',
    );
  }

  /// ปฏิเสธพากลับไป unpaid ไม่ใช่สถานะที่ห้า เพราะสิ่งที่ผู้เช่าต้องทำ
  /// เหมือนเดิมคือจ่ายใหม่ ต่างแค่มีเหตุผลให้อ่าน
  Future<void> rejectSlip({
    required Invoice invoice,
    required String reason,
  }) async {
    _assertTransition(invoice.status, InvoiceStatus.unpaid);

    await _client.from('invoices').update({
      'status': InvoiceStatus.unpaid.name,
      'rejection_reason': reason,
      'slip_url': null,
      'slip_submitted_at': null,
    }).eq('id', invoice.dbId);

    await _postInvoiceNotice(
      invoice: invoice,
      body: 'สลิปของบิล ${invoice.invoiceNo} ไม่ผ่านการตรวจสอบ: $reason',
    );
  }

  void _assertTransition(InvoiceStatus from, InvoiceStatus to) {
    if (!canTransition(from, to)) {
      throw Exception('บิลใบนี้เปลี่ยนสถานะแบบนั้นไม่ได้');
    }
  }

  /// ข้อความธรรมดาที่ผูกกับบิล — ต่างจากการ์ดตอนออกบิลตรงที่ไม่ต้องเปิดดูอะไร
  Future<void> _postInvoiceNotice({
    required Invoice invoice,
    required String body,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) return;

    await _client.from('messages').insert({
      'room_id': invoice.roomDbId,
      'sender_id': senderId,
      'is_from_owner': true,
      'body': body,
      'message_type': MessageType.text.name,
      'invoice_id': invoice.dbId,
    });
  }
```

เพิ่ม `import 'invoice_lifecycle.dart';` ที่หัวไฟล์

- [ ] **Step 2: เขียน `lib/widgets/slip_review_sheet.dart`**

แผ่นเต็มจอที่แสดงสลิปพร้อมสองปุ่ม คืน `true` เมื่อสถานะถูกเปลี่ยนสำเร็จ

โครงสร้าง

1. `FutureBuilder` เรียก `InvoiceService.signedSlipUrl(invoice.slipUrl!)` — สร้างใหม่ทุกครั้งที่เปิด ไม่ cache
2. `Image.network` เต็มความกว้าง มี `errorBuilder` แสดง "โหลดสลิปไม่สำเร็จ"
3. หัวแผ่นแสดง `invoice.invoiceNo` ห้อง ชื่อผู้เช่า และ `formatBaht(invoice.total)` เพื่อให้เทียบยอดกับสลิปได้โดยไม่ต้องปิดแผ่น
4. ปุ่ม **ปฏิเสธ** เปิด `AlertDialog` ที่มี `TextField` บังคับกรอกเหตุผล ปุ่มยืนยันถูกปิดจนกว่าข้อความจะไม่ว่าง
5. ปุ่ม **อนุมัติ** เรียก `approveSlip` ตรง

ทั้งสองปุ่มต้อง disable ระหว่างรอผลและแสดง `SnackBar` ผลลัพธ์ผ่าน `formatErrorMessage`

`TextEditingController` ของกล่องเหตุผลต้องเป็นของ `StatefulWidget` และ dispose ใน `State.dispose()` — **ห้าม dispose ใน `finally` หลัง `showDialog`** เพราะ dialog ยังเล่นแอนิเมชันปิดอยู่และยังอ่าน controller อยู่ ซึ่งเป็นบั๊กเดียวกับที่ commit `64bb83e` เคยแก้ไปแล้วในกล่องแจ้งซ่อม

- [ ] **Step 3: เขียน `lib/widgets/invoice_detail_sheet.dart`**

แผ่นรายละเอียดบิลฝั่งเจ้าของหอ ใช้เมื่อกดการ์ดบิลในแชทหรือกดจากรายการ แสดง

- หัวบิล เลขที่ งวด ห้อง ผู้เช่า และป้ายสถานะ
- รายการค่าใช้จ่ายสี่บรรทัดผ่าน `formatBaht` และยอดรวม
- ปุ่มตามสถานะ: `pending` → ปุ่ม "ตรวจสลิป" เปิด `showSlipReviewSheet` · ทุกสถานะที่ยังไม่ยกเลิก → ปุ่ม "ยกเลิกบิล" (ต่อใน Task 8) · ทุกสถานะ → ปุ่ม "บันทึก PDF" (ต่อใน Task 9)
- เมื่อ `isVoided` แสดงกล่องเหตุผลการยกเลิกและซ่อนปุ่มที่เปลี่ยนสถานะทั้งหมด

- [ ] **Step 4: เพิ่ม action ใน `lib/viewmodels/billing_view_model.dart`**

```dart
  Future<ActionResult> approve(Invoice invoice) async {
    try {
      await _service.approveSlip(invoice: invoice);
      await loadInvoices();
      return const ActionResult(success: true, message: 'อนุมัติการชำระแล้ว');
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'อนุมัติไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    }
  }

  Future<ActionResult> reject(Invoice invoice, String reason) async {
    try {
      await _service.rejectSlip(invoice: invoice, reason: reason);
      await loadInvoices();
      return const ActionResult(success: true, message: 'ปฏิเสธสลิปแล้ว');
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ปฏิเสธไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    }
  }
```

- [ ] **Step 5: ต่อปุ่มใน `lib/screens/admin/billing_screen.dart`**

`onPressed: () {}` ที่บรรทัด 249 เปลี่ยนเป็นเปิด `showSlipReviewSheet` แล้ว `loadInvoices()` เมื่อคืน `true` และให้ทั้งการ์ดกดเปิด `showInvoiceDetailSheet` ได้

`_InvoiceCard` ต้องเข้าถึง `BillingViewModel` — ใช้ `context.read<BillingViewModel>()` ตามรูปแบบที่ไฟล์นี้ใช้อยู่แล้ว

ใน `lib/screens/admin/chat_screen.dart` ส่ง `onOpenInvoice: (invoice) => showInvoiceDetailSheet(context, invoice: invoice)` เข้า `ChatConversationView` แทน `null` ที่ใส่ไว้ชั่วคราวใน Task 6

- [ ] **Step 6: ตรวจบนเครื่องจริง — เส้นทางเต็ม**

```bash
flutter analyze
flutter test
flutter run
```

เดินเส้นทางนี้ให้ครบ

1. ผู้เช่าอัปสลิป → บิลเป็น "รอตรวจสลิป" ทั้งสองฝั่ง
2. เจ้าของหอกด "ดูสลิป" → เห็นรูปจริง ไม่ใช่กรอบว่าง
3. กดปฏิเสธพร้อมเหตุผล → บิลกลับเป็น "ค้างชำระ" · ผู้เช่าเห็นกล่องเหตุผลบนการ์ดบิล · มีข้อความในแชท
4. **กดยกเลิกกล่องกรอกเหตุผลแทนที่จะยืนยัน** → ต้องไม่มี exception เรื่อง `TextEditingController was used after being disposed`
5. ผู้เช่าอัปสลิปใหม่ → เหตุผลเดิมหายไป
6. เจ้าของหอกดอนุมัติ → บิลเป็น "ชำระแล้ว" ทั้งสองฝั่ง · มีข้อความยืนยันในแชท

- [ ] **Step 7: หยุดและรายงานผู้ใช้**

รายงานผลทั้งหกข้อ แล้วบอกว่าพร้อม commit ด้วยข้อความหัวข้อ **7** — **อย่ารัน `git commit` เอง**

---

## Task 8: ยกเลิกบิลแล้วออกใบแทน

**Files:**
- Modify: `lib/services/invoice_service.dart` (`voidInvoice`, `reissueInvoice`)
- Modify: `lib/widgets/invoice_detail_sheet.dart` (ปุ่มยกเลิก + กล่องเหตุผล)
- Modify: `lib/viewmodels/billing_view_model.dart` (`voidBill`)
- Modify: `lib/screens/admin/billing_screen.dart` (เมนู ⋮)

**Interfaces:**
- Consumes: `canTransition`, `invoiceNoFor`, `previewDrafts`, `issueInvoices`
- Produces:
  - `Future<void> InvoiceService.voidInvoice({required Invoice invoice, required String reason})`
  - `Future<Invoice?> InvoiceService.reissueInvoice({required Invoice voided, required int dormitoryId})`

- [ ] **Step 1: เพิ่ม `voidInvoice` และ `reissueInvoice`**

```dart
  Future<void> voidInvoice({
    required Invoice invoice,
    required String reason,
  }) async {
    _assertTransition(invoice.status, InvoiceStatus.voided);

    await _client.from('invoices').update({
      'status': InvoiceStatus.voided.name,
      'voided_at': DateTime.now().toUtc().toIso8601String(),
      'void_reason': reason,
    }).eq('id', invoice.dbId);

    await _postInvoiceNotice(
      invoice: invoice,
      body: 'บิล ${invoice.invoiceNo} ถูกยกเลิก: $reason',
    );
  }

  /// ออกใบแทนจากมิเตอร์ปัจจุบัน — เรียกหลัง voidInvoice เท่านั้น
  ///
  /// partial unique index ปล่อยให้ใบใหม่เกิดได้เพราะใบเดิมไม่นับเป็น active
  /// แล้ว revision + 1 ทำให้เลขที่บิลไม่ชนกัน และ replaces_invoice_id ทำให้
  /// สลิปที่จ่ายใบเดิมไปแล้วยังตามรอยได้
  Future<Invoice?> reissueInvoice({
    required Invoice voided,
    required int dormitoryId,
  }) async {
    final preview = await previewDrafts(
      dormitoryId: dormitoryId,
      month: voided.billingMonth,
      year: voided.billingYear,
    );

    final draft = preview.drafts
        .where((d) => d.roomDbId == voided.roomDbId)
        .firstOrNull;
    if (draft == null) return null;

    final issuedBy = _client.auth.currentUser?.id;
    if (issuedBy == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final revision = voided.revision + 1;
    final due = dueDateFor(draft.billingYear, draft.billingMonth);

    final inserted = await _client.from('invoices').insert({
      'invoice_no': invoiceNoFor(
        year: draft.billingYear,
        month: draft.billingMonth,
        roomNumber: draft.roomNumber,
        revision: revision,
      ),
      'dorm_id': dormitoryId,
      'room_id': draft.roomDbId,
      'tenant_id': draft.tenantId,
      'billing_month': draft.billingMonth,
      'billing_year': draft.billingYear,
      'room_price': draft.roomPrice,
      'electricity_units': draft.electricityUnits,
      'electricity_cost': draft.electricityCost,
      'water_cost': draft.waterCost,
      'cleaning_fee': draft.cleaningFee,
      'due_date':
          '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
      'issued_by': issuedBy,
      'revision': revision,
      'replaces_invoice_id': voided.dbId,
    }).select(_columns).single();

    final invoice = _invoiceFromRow(inserted);
    await postIssueNotices(invoices: [invoice]);
    return invoice;
  }
```

ต้องเพิ่ม `import 'package:collection/collection.dart';` สำหรับ `firstOrNull` หรือเขียนเป็นลูปหา index เองถ้าไม่อยากเพิ่ม dependency — **เลือกเขียนเอง** เพื่อไม่เพิ่ม dependency ให้ฟีเจอร์เดียว

```dart
    InvoiceDraft? draft;
    for (final candidate in preview.drafts) {
      if (candidate.roomDbId == voided.roomDbId) {
        draft = candidate;
        break;
      }
    }
    if (draft == null) return null;
```

- [ ] **Step 2: ต่อ UI ยกเลิก**

ใน `invoice_detail_sheet.dart` เพิ่มปุ่ม "ยกเลิกบิล" ที่เปิดกล่องกรอกเหตุผล (บังคับกรอก ใช้ `StatefulWidget` + dispose ใน `State.dispose()` เหมือน Task 7) เมื่อยืนยันแล้วถามต่อว่า **"ออกบิลใบใหม่แทนเลยไหม"** ถ้าตอบใช่จึงเรียก `reissueInvoice`

แยกสองคำถามเพราะบางกรณีเจ้าของหอต้องการยกเลิกอย่างเดียว เช่นผู้เช่าย้ายออกกลางคัน

ใน `billing_screen.dart` เพิ่ม `PopupMenuButton` ที่มุมการ์ด มีสองรายการ: **ยกเลิกบิล** และ **บันทึก PDF** (รายการหลังต่อใน Task 9) ซ่อนทั้งเมนูเมื่อ `invoice.isVoided`

- [ ] **Step 3: ตรวจบนเครื่องจริง**

```bash
flutter analyze
flutter test
flutter run
```

1. ยกเลิกบิลที่ยัง "ค้างชำระ" พร้อมเหตุผล → หายจากรายการ "ทั้งหมด" แต่โผล่ในชิป "ยกเลิกแล้ว" · ผู้เช่าเห็นป้าย "ยกเลิกแล้ว" และข้อความในแชท
2. ตอบว่าออกใบใหม่ → ได้ใบที่ลงท้าย `-R2` และมีป้าย "แก้ไขครั้งที่ 2" · ผู้เช่าได้การ์ดบิลใหม่ในแชท
3. ลอง**ยกเลิกบิลที่ "ชำระแล้ว"** → ต้องทำได้ และใบใหม่ต้องเกิดได้โดยไม่ชน unique index
4. เปิดใบที่ยกเลิกแล้ว → ปุ่มที่เปลี่ยนสถานะทั้งหมดต้องหายไป เหลือแค่ดูข้อมูล

- [ ] **Step 4: หยุดและรายงานผู้ใช้**

พร้อม commit ด้วยข้อความหัวข้อ **8** — **อย่ารัน `git commit` เอง**

---

## Task 9: Export บิลเป็น PDF

**Files:**
- Modify: `pubspec.yaml` (dependency `pdf` `printing` · asset ฟอนต์)
- Add: `lib/assets/fonts/Sarabun-Regular.ttf` · `lib/assets/fonts/Sarabun-Bold.ttf`
- Create: `lib/services/invoice_pdf.dart`
- Modify: `lib/widgets/invoice_detail_sheet.dart` · `lib/widgets/payment_sheet.dart` · `lib/screens/admin/billing_screen.dart`
- Test: `test/invoice_pdf_unit_test.dart`

**Interfaces:**
- Consumes: `Invoice` (ชนิดที่ตรึงแล้วเท่านั้น) · `DormitoryInfo` · `PaymentChannel`
- Produces:
  - `Future<Uint8List> buildInvoicePdf({required Invoice invoice, required String dormitoryName, PaymentChannel? channel})`
  - `Future<void> shareInvoicePdf({required Invoice invoice, required String dormitoryName, PaymentChannel? channel})`

- [ ] **Step 1: เพิ่ม dependency และฟอนต์**

ดาวน์โหลด Sarabun จาก Google Fonts (ใบอนุญาต SIL Open Font แจกจ่ายพร้อมแอปได้) วางที่ `lib/assets/fonts/Sarabun-Regular.ttf` และ `lib/assets/fonts/Sarabun-Bold.ttf`

```yaml
dependencies:
  pdf: ^3.11.0
  printing: ^5.13.0

flutter:
  assets:
    - .env
    - lib/assets/sample_paymant_qrcode.jpg
    - lib/assets/fonts/Sarabun-Regular.ttf
    - lib/assets/fonts/Sarabun-Bold.ttf
```

```bash
flutter pub get
```

ประกาศฟอนต์เป็น **asset ไม่ใช่ `fonts:`** เพราะ `pdf` โหลดผ่าน `rootBundle` เอง ไม่ได้ใช้ระบบฟอนต์ของ Flutter

- [ ] **Step 2: เขียนเทสต์ที่ยังล้ม `test/invoice_pdf_unit_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_pdf.dart';

Invoice _invoice(InvoiceStatus status) => Invoice(
      dbId: 1,
      invoiceNo: 'INV-202608-301',
      roomDbId: 1,
      roomNumber: '301',
      tenantName: 'สมชาย ใจดี',
      billingMonth: 8,
      billingYear: 2026,
      roomPrice: 3500,
      electricityUnits: 142,
      electricityCost: 1136,
      waterCost: 404,
      cleaningFee: 200,
      total: 5240,
      status: status,
      dueDate: DateTime(2026, 9, 5),
      issuedAt: DateTime(2026, 9, 1),
      voidReason: status == InvoiceStatus.voided ? 'จดมิเตอร์ผิด' : null,
    );

void main() {
  // rootBundle ต้องพร้อมก่อนโหลดฟอนต์
  TestWidgetsFlutterBinding.ensureInitialized();

  test('บิลค้างชำระสร้าง PDF ได้และไม่ว่าง', () async {
    final bytes = await buildInvoicePdf(
      invoice: _invoice(InvoiceStatus.unpaid),
      dormitoryName: 'หอพักสุขสบาย',
    );

    expect(bytes.lengthInBytes, greaterThan(0));
  });

  test('บิลชำระแล้วสร้าง PDF ได้', () async {
    final bytes = await buildInvoicePdf(
      invoice: _invoice(InvoiceStatus.paid),
      dormitoryName: 'หอพักสุขสบาย',
    );

    expect(bytes.lengthInBytes, greaterThan(0));
  });

  test('บิลที่ยกเลิกแล้วสร้าง PDF ได้', () async {
    final bytes = await buildInvoicePdf(
      invoice: _invoice(InvoiceStatus.voided),
      dormitoryName: 'หอพักสุขสบาย',
    );

    expect(bytes.lengthInBytes, greaterThan(0));
  });
}
```

```bash
flutter test test/invoice_pdf_unit_test.dart
```
Expected: FAIL — ไฟล์ `invoice_pdf.dart` ยังไม่มี

- [ ] **Step 3: เขียน `lib/services/invoice_pdf.dart`**

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../utils/formatters.dart';
import '../viewmodels/tenant_dashboard_view_model.dart' show thaiMonthName;

/// สร้างเอกสารบิลจากบิลที่ **ตรึงแล้ว** เท่านั้น
///
/// พารามิเตอร์เป็น [Invoice] ไม่ใช่ [InvoiceDraft] จึงเป็นไปไม่ได้ที่จะเผลอ
/// พิมพ์ตัวเลขที่คำนวณสดลงเอกสารที่ผู้เช่าจะเก็บไว้เป็นหลักฐาน
Future<Uint8List> buildInvoicePdf({
  required Invoice invoice,
  required String dormitoryName,
  PaymentChannel? channel,
}) async {
  // pdf ใช้ Helvetica เป็นค่าเริ่มต้นซึ่งไม่มี glyph ภาษาไทย ถ้าไม่ฝังฟอนต์เอง
  // เอกสารจะออกมาเป็นกล่องว่างทั้งใบโดยไม่มีอะไรเตือนตอน compile
  final regular = pw.Font.ttf(
      await rootBundle.load('lib/assets/fonts/Sarabun-Regular.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('lib/assets/fonts/Sarabun-Bold.ttf'));

  Uint8List? qr;
  if (channel != null) {
    final data = await rootBundle.load(channel.qrAssetPath);
    qr = data.buffer.asUint8List();
  }

  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (context) => pw.Stack(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(dormitoryName,
                      style: pw.TextStyle(font: bold, fontSize: 14)),
                  pw.Text('ใบแจ้งค่าเช่า',
                      style: pw.TextStyle(font: bold, fontSize: 14)),
                ],
              ),
              pw.Divider(),
              _row('เลขที่', invoice.invoiceNo),
              _row('งวด',
                  '${thaiMonthName(invoice.billingMonth)} ${invoice.billingYear}'),
              _row('ห้อง', '${invoice.roomNumber}   ${invoice.tenantName}'),
              _row('ออกเมื่อ', _thaiDate(invoice.issuedAt)),
              pw.Divider(),
              _amount('ค่าห้อง', invoice.roomPrice),
              _amount(
                  'ค่าไฟ ${formatUnits(invoice.electricityUnits)} หน่วย',
                  invoice.electricityCost),
              _amount('ค่าน้ำ', invoice.waterCost),
              if (invoice.cleaningFee > 0)
                _amount('ค่าทำความสะอาด', invoice.cleaningFee),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ยอดรวมสุทธิ',
                      style: pw.TextStyle(font: bold, fontSize: 13)),
                  pw.Text(formatBaht(invoice.total),
                      style: pw.TextStyle(font: bold, fontSize: 16)),
                ],
              ),
              _row('ครบกำหนดชำระ', _thaiDate(invoice.dueDate)),
              if (channel != null) ...[
                pw.Divider(),
                _row('ชำระผ่าน', channel.bankName),
                _row('เลขบัญชี', channel.accountNo),
                if (qr != null)
                  pw.Center(
                    child: pw.Image(pw.MemoryImage(qr), width: 120, height: 120),
                  ),
              ],
            ],
          ),
          // PDF ที่แชร์ออกไปแล้วเรียกคืนไม่ได้ ใบที่ยกเลิกจึงต้องบอกตัวเองได้
          if (invoice.status == InvoiceStatus.paid)
            _watermark('ชำระแล้ว', PdfColors.green300, bold),
          if (invoice.isVoided) _watermark('ยกเลิก', PdfColors.red300, bold),
        ],
      ),
    ),
  );

  return document.save();
}

/// เปิดแผ่นแชร์ของระบบพร้อมไฟล์ที่ตั้งชื่อตามเลขที่บิล
Future<void> shareInvoicePdf({
  required Invoice invoice,
  required String dormitoryName,
  PaymentChannel? channel,
}) async {
  final bytes = await buildInvoicePdf(
    invoice: invoice,
    dormitoryName: dormitoryName,
    channel: channel,
  );
  await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNo}.pdf');
}

pw.Widget _row(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label), pw.Text(value)],
      ),
    );

pw.Widget _amount(String label, double value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label), pw.Text(formatBaht(value))],
      ),
    );

pw.Widget _watermark(String text, PdfColor color, pw.Font font) => pw.Center(
      child: pw.Transform.rotate(
        angle: 0.6,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: 60, color: color),
        ),
      ),
    );

String _thaiDate(DateTime date) =>
    '${date.day} ${thaiMonthName(date.month)} ${date.year}';
```

- [ ] **Step 4: รันเทสต์ให้ผ่าน**

```bash
flutter test test/invoice_pdf_unit_test.dart
```
Expected: PASS ทั้ง 3 เทสต์

ถ้าล้มด้วย `Unable to load asset` แปลว่าไฟล์ฟอนต์ยังไม่อยู่ในตำแหน่งที่ประกาศไว้ ตรวจ Step 1 ก่อน

- [ ] **Step 5: ต่อปุ่มทั้งสามจุด**

- `invoice_detail_sheet.dart` — รายการ "บันทึก PDF"
- `payment_sheet.dart` — ปุ่ม 📄 PDF ข้างปุ่มแนบสลิป
- `billing_screen.dart` — รายการ "บันทึก PDF" ในเมนู ⋮ ที่สร้างไว้ใน Task 8

ทั้งสามจุดเรียก `shareInvoicePdf` และแสดง `SnackBar` เมื่อ throw ผ่าน `formatErrorMessage` ชื่อหอมาจาก `DormitoryInfo.name` ที่ ViewModel โหลดไว้แล้ว

- [ ] **Step 6: ตรวจ**

```bash
flutter analyze
flutter test
flutter run
```

เปิด PDF จากทั้งสามจุด แล้วตรวจว่า

- **ภาษาไทยอ่านออก ไม่ใช่กล่องว่าง** — ถ้าเป็นกล่องแปลว่าฟอนต์ไม่ได้ถูกฝัง
- ตัวเลขทุกตัวตรงกับที่แสดงบนหน้าจอ
- บิลที่ชำระแล้วมีลายน้ำ "ชำระแล้ว" · บิลที่ยกเลิกมีลายน้ำ "ยกเลิก"
- QR ขึ้นในเอกสารเมื่อเปิดจากฝั่งผู้เช่า
- ชื่อไฟล์ตอนแชร์เป็น `INV-…​.pdf`

- [ ] **Step 7: หยุดและรายงานผู้ใช้**

รายงานผลทั้งหมด แล้วบอกว่าพร้อม commit ด้วยข้อความหัวข้อ **9** และเตือนให้ stage ไฟล์ฟอนต์สองไฟล์ด้วย — **อย่ารัน `git commit` เอง**

---

## ตรวจครบทั้งฟีเจอร์ก่อนปิดงาน

หลัง Task 9 ผ่าน ให้เดินเส้นทางเต็มหนึ่งรอบบนเครื่องจริงตามที่สเปกหัวข้อ 6 กำหนด

```
ออกบิล → ผู้เช่าเห็นการ์ดในแชท → อัปสลิป → เจ้าของหอปฏิเสธ
→ ผู้เช่าเห็นเหตุผล → อัปใหม่ → อนุมัติ → เปิด PDF
```

แล้วตรวจสามข้อที่ตัวจำลองเดิมทำไม่ได้

1. ปิดแอปแล้วเปิดใหม่ สถานะบิลไม่รีเซ็ต
2. แก้มิเตอร์ย้อนหลังของงวดที่ออกบิลไปแล้ว → ตัวเลขบนบิลต้องไม่ขยับ
3. เข้าด้วยบัญชีผู้เช่าอีกห้อง → ไม่เห็นบิลของห้องอื่นเลย
