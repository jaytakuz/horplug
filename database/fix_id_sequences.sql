-- Fix: เพิ่ม auto-increment ให้กับ id column ของตาราง electricity_record และ water_meter
-- สาเหตุ: เมื่อ app ทำ upsert โดยไม่ส่ง id (record ใหม่), PostgreSQL ต้องการ DEFAULT แต่ไม่มี
-- วิธีใช้: รัน SQL นี้บน Supabase SQL Editor ครั้งเดียว

-- ─── electricity_record ───────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_sequences WHERE sequencename = 'electricity_record_id_seq'
  ) THEN
    CREATE SEQUENCE electricity_record_id_seq;
    PERFORM setval(
      'electricity_record_id_seq',
      COALESCE((SELECT MAX(id) FROM electricity_record), 0)
    );
  END IF;
END $$;

ALTER TABLE electricity_record
  ALTER COLUMN id SET DEFAULT nextval('electricity_record_id_seq');

-- ─── water_meter ──────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_sequences WHERE sequencename = 'water_meter_id_seq'
  ) THEN
    CREATE SEQUENCE water_meter_id_seq;
    PERFORM setval(
      'water_meter_id_seq',
      COALESCE((SELECT MAX(id) FROM water_meter), 0)
    );
  END IF;
END $$;

ALTER TABLE water_meter
  ALTER COLUMN id SET DEFAULT nextval('water_meter_id_seq');
