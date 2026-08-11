-- Seed: Historical utility data for 5 months back from today (June 1, 2026)
-- This script generates monthly utility records for testing billing calculations.
-- Months: January (1) to May (5) 2026, plus current month June (6) 2026

BEGIN;

WITH month_data AS (
  -- Generate months from January to May 2026, plus June 2026
  SELECT 1 AS billing_month, 2026 AS billing_year
  UNION ALL SELECT 2, 2026
  UNION ALL SELECT 3, 2026
  UNION ALL SELECT 4, 2026
  UNION ALL SELECT 5, 2026
  UNION ALL SELECT 6, 2026
),
room_data AS (
  -- Get all rooms to seed data for
  SELECT DISTINCT r.id, d.id AS dorm_id, d.base_electricity_rate, d.base_water_rate
  FROM rooms r
  LEFT JOIN dormitories d ON d.id = r.dorm_id
  WHERE r.status = 'occupied'
),
electricity_seed AS (
  -- Generate electricity records with incremental meter readings
  SELECT
    r.id AS room_id,
    'electricity' AS utility_type,
    m.billing_month,
    m.billing_year,
    -- Previous value: meter reading from previous month
    (3000 + (r.id * 100) + (m.billing_month * 50) - 100)::numeric AS previous_value,
    -- Current value: meter reading for current month
    (3000 + (r.id * 100) + (m.billing_month * 50))::numeric AS current_value,
    COALESCE(r.base_electricity_rate, 8)::numeric AS unit_rate,
    -- Amount: (current - previous) * rate
    (50::numeric * COALESCE(r.base_electricity_rate, 8)::numeric) AS amount,
    NOW() - INTERVAL '1 day' * (6 - m.billing_month) AS recorded_at,
    NOW() AS created_at,
    NOW() AS updated_at
  FROM room_data r
  CROSS JOIN month_data m
  WHERE m.billing_month BETWEEN 1 AND 6
),
water_seed AS (
  -- Generate water charge records (fixed monthly charge)
  SELECT
    r.id AS room_id,
    'water' AS utility_type,
    m.billing_month,
    m.billing_year,
    NULL::numeric AS previous_value,
    COALESCE(r.base_water_rate, 100)::numeric AS current_value,
    COALESCE(r.base_water_rate, 100)::numeric AS unit_rate,
    COALESCE(r.base_water_rate, 100)::numeric AS amount,
    NOW() - INTERVAL '1 day' * (6 - m.billing_month) AS recorded_at,
    NOW() AS created_at,
    NOW() AS updated_at
  FROM room_data r
  CROSS JOIN month_data m
  WHERE m.billing_month BETWEEN 1 AND 6
)
-- Insert all electricity records
INSERT INTO utility_records (
  room_id, utility_type, billing_month, billing_year,
  previous_value, current_value, unit_rate, amount,
  recorded_at, created_at, updated_at
)
SELECT * FROM electricity_seed
ON CONFLICT (room_id, utility_type, billing_month, billing_year) 
DO UPDATE SET
  previous_value = EXCLUDED.previous_value,
  current_value = EXCLUDED.current_value,
  unit_rate = EXCLUDED.unit_rate,
  amount = EXCLUDED.amount,
  recorded_at = EXCLUDED.recorded_at,
  updated_at = NOW();

-- Insert all water charge records
INSERT INTO utility_records (
  room_id, utility_type, billing_month, billing_year,
  previous_value, current_value, unit_rate, amount,
  recorded_at, created_at, updated_at
)
SELECT * FROM water_seed
ON CONFLICT (room_id, utility_type, billing_month, billing_year) 
DO UPDATE SET
  previous_value = EXCLUDED.previous_value,
  current_value = EXCLUDED.current_value,
  unit_rate = EXCLUDED.unit_rate,
  amount = EXCLUDED.amount,
  recorded_at = EXCLUDED.recorded_at,
  updated_at = NOW();

COMMIT;
