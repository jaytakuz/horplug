-- ═══════════════════════════════════════════════════════════════════════════════
-- HorPlug — RLS Setup v3 (No Circular Dependency)
-- Run this in Supabase → SQL Editor
--
-- Root cause of infinite recursion:
--   dormitories policy → queries tenant_profiles
--   tenant_profiles policy → queries dormitories  ← loop!
--
-- Fix: dormitories policy NEVER references tenant_profiles (and vice versa for
--      the table that starts the chain). Break the cycle at the dormitories level.
--
-- NOTE: ตรวจสอบ column ที่ dormitories ใช้ link กลับ landlord ก่อนรัน
--       ไปที่ Supabase > Table Editor > dormitories > columns
--       ถ้าไม่ใช่ "landlord_id" ให้ Replace All คำว่า landlord_id ด้วยชื่อจริง
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── STEP 0: Drop policies เดิม + Disable RLS ทั้งหมดก่อน ───────────────────

ALTER TABLE landlord_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE dormitories        DISABLE ROW LEVEL SECURITY;
ALTER TABLE rooms              DISABLE ROW LEVEL SECURITY;
ALTER TABLE electricity_record DISABLE ROW LEVEL SECURITY;
ALTER TABLE water_meter        DISABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_profiles    DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "landlord_can_read_own_profile"          ON landlord_profiles;
DROP POLICY IF EXISTS "landlord_can_read_own_dormitory"        ON dormitories;
DROP POLICY IF EXISTS "landlord_can_update_own_dormitory"      ON dormitories;
DROP POLICY IF EXISTS "landlord_can_read_rooms"                ON rooms;
DROP POLICY IF EXISTS "landlord_can_update_rooms"              ON rooms;
DROP POLICY IF EXISTS "landlord_can_read_electricity_records"  ON electricity_record;
DROP POLICY IF EXISTS "landlord_can_write_electricity_records" ON electricity_record;
DROP POLICY IF EXISTS "landlord_can_read_water_meter"          ON water_meter;
DROP POLICY IF EXISTS "landlord_can_write_water_meter"         ON water_meter;
DROP POLICY IF EXISTS "landlord_can_read_tenants"              ON tenant_profiles;
DROP POLICY IF EXISTS "lp_select_own"    ON landlord_profiles;
DROP POLICY IF EXISTS "lp_insert_own"    ON landlord_profiles;
DROP POLICY IF EXISTS "lp_update_own"    ON landlord_profiles;
DROP POLICY IF EXISTS "tp_select"        ON tenant_profiles;
DROP POLICY IF EXISTS "tp_insert_own"    ON tenant_profiles;
DROP POLICY IF EXISTS "tp_update_own"    ON tenant_profiles;
DROP POLICY IF EXISTS "dorm_select"      ON dormitories;
DROP POLICY IF EXISTS "dorm_insert"      ON dormitories;
DROP POLICY IF EXISTS "dorm_update"      ON dormitories;
DROP POLICY IF EXISTS "dorm_delete"      ON dormitories;
DROP POLICY IF EXISTS "rooms_select"     ON rooms;
DROP POLICY IF EXISTS "rooms_insert"     ON rooms;
DROP POLICY IF EXISTS "rooms_update"     ON rooms;
DROP POLICY IF EXISTS "rooms_delete"     ON rooms;
DROP POLICY IF EXISTS "elec_select"      ON electricity_record;
DROP POLICY IF EXISTS "elec_insert"      ON electricity_record;
DROP POLICY IF EXISTS "elec_update"      ON electricity_record;
DROP POLICY IF EXISTS "water_select"     ON water_meter;
DROP POLICY IF EXISTS "water_insert"     ON water_meter;
DROP POLICY IF EXISTS "water_update"     ON water_meter;

-- ─── STEP 1: landlord_profiles ───────────────────────────────────────────────
-- ไม่อ้างอิงตารางอื่น → ปลอดภัยจาก recursion

ALTER TABLE landlord_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "lp_select_own"
  ON landlord_profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "lp_insert_own"
  ON landlord_profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "lp_update_own"
  ON landlord_profiles FOR UPDATE
  USING (id = auth.uid());

-- ─── STEP 2: dormitories ─────────────────────────────────────────────────────
-- KEY FIX: policy นี้ต้องไม่อ้างอิง tenant_profiles เด็ดขาด
-- - Landlord: เห็นเฉพาะหอของตัวเอง (landlord_id = auth.uid())
-- - Tenant: อนุญาตให้ authenticated user ทุกคนอ่านได้
--   (ข้อมูล dorm เช่น ชื่อหอ ไม่ใช่ข้อมูลลับ + tenant ต้องอ่านได้ใน enrichTenantProfile)

ALTER TABLE dormitories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "dorm_select"
  ON dormitories FOR SELECT
  USING (auth.uid() IS NOT NULL);   -- authenticated user ทุกคนอ่านได้

CREATE POLICY "dorm_insert"
  ON dormitories FOR INSERT
  WITH CHECK (landlord_id = auth.uid());

CREATE POLICY "dorm_update"
  ON dormitories FOR UPDATE
  USING (landlord_id = auth.uid());

CREATE POLICY "dorm_delete"
  ON dormitories FOR DELETE
  USING (landlord_id = auth.uid());

-- ─── STEP 3: tenant_profiles ─────────────────────────────────────────────────
-- ตอนนี้ tenant_profiles policy อ้าง dormitories ได้โดย dormitories policy
-- ไม่วนกลับมาหา tenant_profiles อีก → ไม่มี recursion

ALTER TABLE tenant_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tp_select"
  ON tenant_profiles FOR SELECT
  USING (
    -- เจ้าของโปรไฟล์อ่านได้เสมอ
    id = auth.uid()
    -- Landlord อ่าน tenant ในหอตัวเองได้
    OR dorm_id IN (
      SELECT id FROM dormitories WHERE landlord_id = auth.uid()
    )
  );

CREATE POLICY "tp_insert_own"
  ON tenant_profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "tp_update_own"
  ON tenant_profiles FOR UPDATE
  USING (id = auth.uid());

-- ─── STEP 4: rooms ───────────────────────────────────────────────────────────
-- dormitories policy ไม่ loopกลับมาที่ rooms → ปลอดภัย

ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rooms_select"
  ON rooms FOR SELECT
  USING (
    -- Landlord เห็นทุกห้องในหอตัวเอง
    dorm_id IN (
      SELECT id FROM dormitories WHERE landlord_id = auth.uid()
    )
    -- Tenant เห็นเฉพาะห้องของตัวเอง
    OR id IN (
      SELECT room_id FROM tenant_profiles WHERE id = auth.uid()
    )
  );

CREATE POLICY "rooms_insert"
  ON rooms FOR INSERT
  WITH CHECK (
    dorm_id IN (
      SELECT id FROM dormitories WHERE landlord_id = auth.uid()
    )
  );

CREATE POLICY "rooms_update"
  ON rooms FOR UPDATE
  USING (
    dorm_id IN (
      SELECT id FROM dormitories WHERE landlord_id = auth.uid()
    )
  );

CREATE POLICY "rooms_delete"
  ON rooms FOR DELETE
  USING (
    dorm_id IN (
      SELECT id FROM dormitories WHERE landlord_id = auth.uid()
    )
  );

-- ─── STEP 5: electricity_record ──────────────────────────────────────────────

ALTER TABLE electricity_record ENABLE ROW LEVEL SECURITY;

CREATE POLICY "elec_select"
  ON electricity_record FOR SELECT
  USING (
    room_id IN (
      SELECT r.id FROM rooms r
      WHERE r.dorm_id IN (
        SELECT id FROM dormitories WHERE landlord_id = auth.uid()
      )
    )
  );

CREATE POLICY "elec_insert"
  ON electricity_record FOR INSERT
  WITH CHECK (
    room_id IN (
      SELECT r.id FROM rooms r
      WHERE r.dorm_id IN (
        SELECT id FROM dormitories WHERE landlord_id = auth.uid()
      )
    )
  );

CREATE POLICY "elec_update"
  ON electricity_record FOR UPDATE
  USING (
    room_id IN (
      SELECT r.id FROM rooms r
      WHERE r.dorm_id IN (
        SELECT id FROM dormitories WHERE landlord_id = auth.uid()
      )
    )
  );

-- ─── STEP 6: water_meter ─────────────────────────────────────────────────────

ALTER TABLE water_meter ENABLE ROW LEVEL SECURITY;

CREATE POLICY "water_select"
  ON water_meter FOR SELECT
  USING (
    room_id IN (
      SELECT r.id FROM rooms r
      WHERE r.dorm_id IN (
        SELECT id FROM dormitories WHERE landlord_id = auth.uid()
      )
    )
  );

CREATE POLICY "water_insert"
  ON water_meter FOR INSERT
  WITH CHECK (
    room_id IN (
      SELECT r.id FROM rooms r
      WHERE r.dorm_id IN (
        SELECT id FROM dormitories WHERE landlord_id = auth.uid()
      )
    )
  );

CREATE POLICY "water_update"
  ON water_meter FOR UPDATE
  USING (
    room_id IN (
      SELECT r.id FROM rooms r
      WHERE r.dorm_id IN (
        SELECT id FROM dormitories WHERE landlord_id = auth.uid()
      )
    )
  );
