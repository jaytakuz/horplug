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
    -- ต้องใช้กฎเดียวกับ meterUnitsUsed() ฝั่ง Dart ที่รองรับมิเตอร์สี่หลักหมุน
    -- กลับ 9999 → 0000 · ของเดิมเป็น GREATEST(current - previous, 0) ซึ่งกลบ
    -- ค่าติดลบให้เป็นศูนย์ ขณะที่ electricity_cost ดึงจาก e.amount ที่คำนวณ
    -- ถูกต้องมาแล้ว บิลของงวดที่มิเตอร์หมุนกลับจึงกลายเป็น "0 หน่วย ฿1,136"
    -- ขัดแย้งกันเองอยู่ในแถวเดียว
    COALESCE(
      CASE
        WHEN e.current_reading IS NULL THEN 0
        WHEN e.current_reading::numeric >= e.previous_reading::numeric
          THEN e.current_reading::numeric - e.previous_reading::numeric
        ELSE (10000 - e.previous_reading::numeric) + e.current_reading::numeric
      END, 0)
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
  -- LATERAL + LIMIT 1 แทน LEFT JOIN ตรงๆ เพราะ electricity_record ไม่มี unique
  -- constraint บน (room_id, billing_month, billing_year) ถ้ามีแถวซ้ำ การ join
  -- จะขยายผลลัพธ์เป็นสองบิลของงวดเดียวกัน ซึ่งชน invoices_one_active_per_period
  -- แล้วพา transaction ทั้งก้อนตกไปด้วย — backfill ทั้งหอจะไม่ได้อะไรเลยเพราะ
  -- ข้อมูลซ้ำแถวเดียว
  LEFT JOIN LATERAL (
    SELECT * FROM electricity_record er
    WHERE er.room_id = p.room_id
      AND er.billing_month = p.billing_month
      AND er.billing_year  = p.billing_year
    ORDER BY er.id DESC LIMIT 1
  ) e ON TRUE
  LEFT JOIN LATERAL (
    SELECT * FROM water_meter wm
    WHERE wm.room_id = p.room_id
      AND wm.billing_month = p.billing_month
      AND wm.billing_year  = p.billing_year
    ORDER BY wm.id DESC LIMIT 1
  ) w ON TRUE
  -- ⚠️ ข้อจำกัดที่ต้องรู้: บิลย้อนหลังถูกผูกกับ current_tenant_id คือผู้เช่า
  -- "ปัจจุบัน" ของห้อง ไม่ใช่ผู้เช่า ณ งวดนั้น เพราะระบบไม่ได้เก็บประวัติว่าใคร
  -- อยู่ห้องไหนช่วงไหน ผลคือถ้าห้องเคยเปลี่ยนผู้เช่ามาก่อน ผู้เช่าคนปัจจุบันจะ
  -- เห็นบิลกับยอดใช้ไฟของคนก่อนหน้าผ่าน invoices_tenant_select
  --
  -- ยอมรับได้เมื่อ backfill ตอนที่ห้องยังไม่เคยเปลี่ยนมือ ซึ่งเป็นสถานการณ์ที่
  -- ไฟล์นี้ถูกออกแบบมาให้ใช้ (รันครั้งเดียวตอนเปิดระบบ) ถ้าหอมีการเปลี่ยนผู้เช่า
  -- มาแล้ว ให้ลบบิลของงวดก่อนที่ผู้เช่าปัจจุบันจะเข้าอยู่ทิ้งด้วยมือหลังรันเสร็จ
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
