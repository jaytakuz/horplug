-- Migration: Normalize utility records to one row per utility per month
-- This script transforms the utility_records table from snapshot format to 
-- a monthly billing format with composite unique key (room_id, utility_type, billing_month, billing_year)
-- Preserves old data by renaming the original table to utility_records_archive

BEGIN;

-- 1. Create a new normalized table structure for utility billing
-- One row per utility per month allows for:
-- - Historical tracking of meter readings and charges
-- - Accurate monthly billing calculations
-- - Composite unique constraint prevents duplicate entries
CREATE TABLE IF NOT EXISTS utility_records_new (
  id BIGSERIAL PRIMARY KEY,
  room_id INT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  utility_type TEXT NOT NULL CHECK (utility_type IN ('electricity', 'water')),
  billing_month INT NOT NULL CHECK (billing_month BETWEEN 1 AND 12),
  billing_year INT NOT NULL,
  
  -- Meter readings (electricity) or charges (water)
  previous_value NUMERIC,                    -- Previous month meter reading (electricity only)
  current_value NUMERIC,                     -- Current month meter reading or charge amount
  
  -- Rate and calculated amount
  unit_rate NUMERIC NOT NULL DEFAULT 0,      -- Rate per unit or fixed charge
  amount NUMERIC NOT NULL DEFAULT 0,         -- Calculated: (current - previous) * rate OR fixed charge
  
  -- Timestamps
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE (room_id, utility_type, billing_month, billing_year)
);

-- Create indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_utility_records_room_month 
  ON utility_records_new (room_id, billing_year, billing_month DESC);
CREATE INDEX IF NOT EXISTS idx_utility_records_type_month 
  ON utility_records_new (utility_type, billing_year, billing_month DESC);

-- 2. Migrate electricity records from the old snapshot table
-- Uses window functions to calculate previous meter readings for cost calculation
-- Base electricity rate comes from dormitories table (default: 8 per unit)
INSERT INTO utility_records_new (
  room_id,
  utility_type,
  billing_month,
  billing_year,
  previous_value,
  current_value,
  unit_rate,
  amount,
  recorded_at,
  created_at,
  updated_at
)
SELECT
  u.room_id,
  'electricity' AS utility_type,
  u.billing_month,
  u.billing_year,
  -- Calculate previous month's meter reading using window function
  lag(u.electricity_meter::numeric) OVER (
    PARTITION BY u.room_id ORDER BY u.billing_year, u.billing_month
  ) AS previous_value,
  u.electricity_meter::numeric AS current_value,
  -- Use dormitory base rate or default to 8 baht per unit
  COALESCE(d.base_electricity_rate, 8)::numeric AS unit_rate,
  -- Calculate consumed units and multiply by rate
  -- GREATEST ensures no negative consumption values
  COALESCE(
    GREATEST(
      u.electricity_meter::numeric - lag(u.electricity_meter::numeric) OVER (
        PARTITION BY u.room_id ORDER BY u.billing_year, u.billing_month
      ),
      0
    ),
    0
  ) * COALESCE(d.base_electricity_rate, 8)::numeric AS amount,
  u.recorded_at,
  NOW(),
  NOW()
FROM utility_records u
LEFT JOIN rooms r ON r.id = u.room_id
LEFT JOIN dormitories d ON d.id = r.dorm_id
WHERE u.electricity_meter IS NOT NULL;

-- 3. Migrate water records from the old snapshot table
-- Water charges are fixed monthly rates (not meter-based)
-- Fallback hierarchy: water_rate > dormitory base_water_rate > 100 baht
INSERT INTO utility_records_new (
  room_id,
  utility_type,
  billing_month,
  billing_year,
  previous_value,
  current_value,
  unit_rate,
  amount,
  recorded_at,
  created_at,
  updated_at
)
SELECT
  u.room_id,
  'water' AS utility_type,
  u.billing_month,
  u.billing_year,
  NULL AS previous_value,
  -- Use water_rate from record, fallback to dormitory rate, fallback to 100
  COALESCE(u.water_rate::numeric, d.base_water_rate::numeric, 100) AS current_value,
  -- Unit rate is the fixed monthly charge (same as current_value for water)
  COALESCE(u.water_rate::numeric, d.base_water_rate::numeric, 100)::numeric AS unit_rate,
  -- Amount is the fixed monthly charge
  COALESCE(u.water_rate::numeric, d.base_water_rate::numeric, 100)::numeric AS amount,
  u.recorded_at,
  NOW(),
  NOW()
FROM utility_records u
LEFT JOIN rooms r ON r.id = u.room_id
LEFT JOIN dormitories d ON d.id = r.dorm_id
WHERE u.water_rate IS NOT NULL;

-- 4. Atomic table swap: keep original as archive, move new table into production
ALTER TABLE utility_records RENAME TO utility_records_archive;
ALTER TABLE utility_records_new RENAME TO utility_records;

-- 5. Create trigger to auto-update updated_at timestamp on record changes
CREATE OR REPLACE FUNCTION update_utility_records_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER utility_records_updated_at_trigger
BEFORE UPDATE ON utility_records
FOR EACH ROW
EXECUTE FUNCTION update_utility_records_timestamp();

COMMIT;
