-- ═══════════════════════════════════════════════════════════════════════════════
-- HorPlug — Tenant Read Access (Feature 7: Dashboard for Tenant)
-- รันไฟล์นี้ใน Supabase → SQL Editor "หลังจาก" rls_setup.sql
--
-- ปัญหา:
--   policy เดิม elec_select / water_select / lp_select_own ให้สิทธิ์อ่านเฉพาะ
--   landlord (ผ่าน dormitories.landlord_id = auth.uid()) → ผู้เช่า SELECT ได้
--   0 แถว หน้าแดชบอร์ดผู้เช่าจึงว่างเปล่าทั้งที่มีข้อมูลอยู่จริง
--
-- แนวทาง:
--   "เพิ่ม" policy ใหม่ ไม่แก้ของเดิม — PostgreSQL รวม permissive policy หลายอัน
--   ด้วย OR อยู่แล้ว ฝั่ง landlord จึงไม่กระทบเลย
--
-- Recursion check (ธีมหลักของ rls_setup.sql — ห้าม policy อ้างวนกลับหากัน):
--   electricity_record → tenant_profiles → (จบ)                        ✔
--   water_meter        → tenant_profiles → (จบ)                        ✔
--   landlord_profiles  → dormitories → tenant_profiles → (จบ)          ✔
--   หมายเหตุ: tenant_profiles policy (tp_select) อ้าง dormitories ได้
--   เพราะ dorm_select ไม่ย้อนกลับมาหา tenant_profiles
--
-- ไฟล์นี้ idempotent: DROP POLICY IF EXISTS ก่อน CREATE เสมอ → รันซ้ำได้
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── STEP 1: electricity_record — ผู้เช่าอ่านมิเตอร์ไฟของห้องตัวเอง ─────────────

DROP POLICY IF EXISTS "elec_select_tenant" ON electricity_record;

CREATE POLICY "elec_select_tenant"
  ON electricity_record FOR SELECT
  USING (
    room_id IN (
      SELECT room_id FROM tenant_profiles
      WHERE id = auth.uid() AND room_id IS NOT NULL
    )
  );

-- ─── STEP 2: water_meter — ผู้เช่าอ่านค่าน้ำของห้องตัวเอง ──────────────────────

DROP POLICY IF EXISTS "water_select_tenant" ON water_meter;

CREATE POLICY "water_select_tenant"
  ON water_meter FOR SELECT
  USING (
    room_id IN (
      SELECT room_id FROM tenant_profiles
      WHERE id = auth.uid() AND room_id IS NOT NULL
    )
  );

-- ─── STEP 3: landlord_profiles — ผู้เช่าอ่านข้อมูลติดต่อเจ้าของหอ "ของหอตัวเอง" ──
-- ใช้กับการ์ด "ติดต่อเจ้าของหอ" ในหน้าโปรไฟล์ผู้เช่า
-- policy เดิม lp_select_own คือ id = auth.uid() เท่านั้น ผู้เช่าจึงอ่านไม่ได้เลย

DROP POLICY IF EXISTS "lp_select_by_tenant" ON landlord_profiles;

CREATE POLICY "lp_select_by_tenant"
  ON landlord_profiles FOR SELECT
  USING (
    id IN (
      SELECT d.landlord_id FROM dormitories d
      WHERE d.id IN (
        SELECT dorm_id FROM tenant_profiles
        WHERE id = auth.uid() AND dorm_id IS NOT NULL
      )
    )
  );

-- ═══════════════════════════════════════════════════════════════════════════════
-- ตรวจสอบผลลัพธ์ — ล็อกอินเป็นผู้เช่าแล้วรัน:
--   SELECT * FROM electricity_record;   -- ควรเห็นเฉพาะแถวของห้องตัวเอง
--   SELECT * FROM water_meter;          -- ควรเห็นเฉพาะแถวของห้องตัวเอง
--   SELECT * FROM landlord_profiles;    -- ควรเห็นเจ้าของหอของหอตัวเอง 1 แถว
-- ═══════════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════════
-- STEP 4 (ทางเลือก — ยังไม่ต้องรันตอนนี้)
--
-- ⚠️  ตอนนี้ messages / message_reads / maintenance_requests ยัง "ปิด" RLS อยู่
--     (ไม่มี policy ใน rls_setup.sql) แชทและแจ้งซ่อมจึงทำงานได้ทั้งสองฝั่ง
--
-- การเปิด RLS บน messages กระทบสองจุดที่ต้องทดสอบก่อน:
--   1. realtime subscription ใน watchMessages() — stream จะถูกกรองตาม policy
--   2. RPC fetch_chat_previews — ถ้าไม่ใช่ SECURITY DEFINER จะคืน 0 แถวให้ landlord
--
-- จึงแยกเป็น hardening pass ต่างหาก ไม่รวมกับ Feature 7
-- ถ้าจะเปิด ให้รัน "ทั้งบล็อก" พร้อมกัน — รันไม่ครบแล้วฝั่ง landlord จะพัง
-- ═══════════════════════════════════════════════════════════════════════════════

-- ALTER TABLE maintenance_requests ENABLE ROW LEVEL SECURITY;
--
-- DROP POLICY IF EXISTS "mr_select" ON maintenance_requests;
-- CREATE POLICY "mr_select"
--   ON maintenance_requests FOR SELECT
--   USING (
--     tenant_id = auth.uid()
--     OR room_id IN (
--       SELECT r.id FROM rooms r
--       WHERE r.dorm_id IN (SELECT id FROM dormitories WHERE landlord_id = auth.uid())
--     )
--   );
--
-- DROP POLICY IF EXISTS "mr_insert_tenant" ON maintenance_requests;
-- CREATE POLICY "mr_insert_tenant"
--   ON maintenance_requests FOR INSERT
--   WITH CHECK (
--     tenant_id = auth.uid()
--     AND room_id IN (SELECT room_id FROM tenant_profiles WHERE id = auth.uid())
--   );
--
-- DROP POLICY IF EXISTS "mr_update_landlord" ON maintenance_requests;
-- CREATE POLICY "mr_update_landlord"
--   ON maintenance_requests FOR UPDATE
--   USING (
--     room_id IN (
--       SELECT r.id FROM rooms r
--       WHERE r.dorm_id IN (SELECT id FROM dormitories WHERE landlord_id = auth.uid())
--     )
--   );
--
-- ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
--
-- DROP POLICY IF EXISTS "msg_select" ON messages;
-- CREATE POLICY "msg_select"
--   ON messages FOR SELECT
--   USING (
--     room_id IN (SELECT room_id FROM tenant_profiles WHERE id = auth.uid())
--     OR room_id IN (
--       SELECT r.id FROM rooms r
--       WHERE r.dorm_id IN (SELECT id FROM dormitories WHERE landlord_id = auth.uid())
--     )
--   );
--
-- DROP POLICY IF EXISTS "msg_insert" ON messages;
-- CREATE POLICY "msg_insert"
--   ON messages FOR INSERT
--   WITH CHECK (
--     sender_id = auth.uid()
--     AND (
--       room_id IN (SELECT room_id FROM tenant_profiles WHERE id = auth.uid())
--       OR room_id IN (
--         SELECT r.id FROM rooms r
--         WHERE r.dorm_id IN (SELECT id FROM dormitories WHERE landlord_id = auth.uid())
--       )
--     )
--   );
--
-- ALTER TABLE message_reads ENABLE ROW LEVEL SECURITY;
--
-- DROP POLICY IF EXISTS "mrd_all_own" ON message_reads;
-- CREATE POLICY "mrd_all_own"
--   ON message_reads FOR ALL
--   USING (user_id = auth.uid())
--   WITH CHECK (user_id = auth.uid());
