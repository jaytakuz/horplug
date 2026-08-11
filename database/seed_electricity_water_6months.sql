-- Seed: ข้อมูลค่าไฟ 5 เดือน (มกราคม - พฤษภาคม 2026) และค่าน้ำ 6 เดือน (มกราคม - มิถุนายน 2026)
-- ครอบคลุมทุกห้องพักไม่ว่าสถานะจะเป็นอะไร (occupied / vacant / maintenance)
-- ค่ามิเตอร์ไฟจะเพิ่มขึ้น 50 หน่วย/เดือน อ้างอิงจาก room_id เพื่อให้แต่ละห้องมีเลขต่างกัน
-- วิธีใช้: รัน fix_id_sequences.sql ก่อน แล้วค่อยรัน seed นี้

BEGIN;

-- ─── electricity_record ───────────────────────────────────────────────────────
INSERT INTO electricity_record (
  room_id, billing_month, billing_year,
  previous_reading, current_reading, unit_rate, amount
)
WITH months AS (
  SELECT m AS billing_month, 2026 AS billing_year
  FROM generate_series(1, 5) AS m
),
rooms_with_rate AS (
  SELECT
    r.id AS room_id,
    COALESCE(d.base_electricity_rate, 8)::numeric AS unit_rate
  FROM rooms r
  LEFT JOIN dormitories d ON d.id = r.dorm_id
),
base AS (
  -- เลขเริ่มต้นมิเตอร์ = 3000 + room_id * 200 เพื่อให้แต่ละห้องมีค่าต่างกัน
  SELECT
    r.room_id,
    r.unit_rate,
    m.billing_month,
    m.billing_year,
    (3000 + r.room_id * 200 + (m.billing_month - 1) * 50)::numeric AS previous_reading,
    (3000 + r.room_id * 200 + m.billing_month * 50)::numeric AS current_reading
  FROM rooms_with_rate r
  CROSS JOIN months m
)
SELECT
  room_id,
  billing_month,
  billing_year,
  previous_reading,
  current_reading,
  unit_rate,
  (50 * unit_rate)::numeric AS amount
FROM base
ON CONFLICT (room_id, billing_month, billing_year) DO NOTHING;

-- ─── water_meter ──────────────────────────────────────────────────────────────
INSERT INTO water_meter (
  room_id, billing_month, billing_year, amount
)
WITH months AS (
  SELECT m AS billing_month, 2026 AS billing_year
  FROM generate_series(1, 6) AS m
),
rooms_with_rate AS (
  SELECT
    r.id AS room_id,
    COALESCE(d.base_water_rate, 100)::numeric AS amount
  FROM rooms r
  LEFT JOIN dormitories d ON d.id = r.dorm_id
)
SELECT
  r.room_id,
  m.billing_month,
  m.billing_year,
  r.amount
FROM rooms_with_rate r
CROSS JOIN months m
ON CONFLICT (room_id, billing_month, billing_year) DO NOTHING;

COMMIT;
