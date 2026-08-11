-- ═══════════════════════════════════════════════════════════════════════════
-- HorPlug — ช่องทางชำระเงินต่อหอ (PromptPay + เลขบัญชีธนาคาร)
-- รันใน Supabase SQL Editor · idempotent รันซ้ำได้
--
-- ก่อนหน้านี้ fetchPaymentChannel คืนเลขบัญชีกสิกร 1438323216 กับ QR ตัวอย่าง
-- ให้ทุกหอเหมือนกันหมด โดยดึงชื่อเจ้าของหอ "ของจริง" มาแสดงคู่กัน และ Task 5
-- ก็ลบแบนเนอร์ "โหมดตัวอย่าง" ที่เคยกำกับไว้ออกไป ผู้เช่าของหออื่นจึงเห็นชื่อ
-- เจ้าของหอที่ถูกต้องข้างเลขบัญชีของคนอื่น ซึ่งอ่านแล้วเหมือนข้อมูลที่ยืนยันแล้ว
--
-- เป็นตารางแยก ไม่ใช่คอลัมน์บน dormitories เพราะ policy dorm_select เปิดให้
-- ผู้ใช้ที่ล็อกอินแล้ว "ทุกคน" อ่าน dormitories ได้ (ชื่อหอไม่ใช่ความลับ)
-- เลขบัญชีธนาคารไม่ควรกว้างขนาดนั้น — ที่นี่จำกัดไว้ที่เจ้าของหอกับผู้เช่าของหอ
-- นั้นเท่านั้น
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS dormitory_payment_channels (
  dorm_id       BIGINT PRIMARY KEY REFERENCES dormitories(id) ON DELETE CASCADE,

  -- เลขพร้อมเพย์ · ใช้สร้าง QR ที่ฝังจำนวนเงินของบิลไว้แล้ว ผู้เช่าจึงไม่ต้อง
  -- พิมพ์ยอดเอง ซึ่งเป็นสาเหตุอันดับต้นๆ ที่สลิปถูกปฏิเสธ
  promptpay_id  TEXT,

  -- ช่องทางสำรองสำหรับคนที่โอนด้วยเลขบัญชี หรือกรณีสแกน QR ไม่ผ่าน
  bank_name     TEXT,
  account_no    TEXT,

  -- ผู้เช่าต้องเห็นชื่อปลายทางเพื่อเทียบก่อนกดโอน จึงบังคับเสมอ
  account_name  TEXT NOT NULL,

  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- ต้องมีอย่างน้อยหนึ่งช่องทาง ไม่งั้นแถวนี้ไม่มีประโยชน์ และผู้เช่าจะเห็น
  -- ชื่อบัญชีลอยๆ โดยไม่มีอะไรให้โอนไป
  CONSTRAINT dpc_has_a_channel CHECK (
    promptpay_id IS NOT NULL
    OR (bank_name IS NOT NULL AND account_no IS NOT NULL)
  ),

  -- ตัวสร้าง QR รองรับแค่ 10 หลัก (เบอร์โทร) กับ 13 หลัก (บัตรประชาชน) เลขนอก
  -- นี้จะได้ payload ว่างกลับมา แล้วหน้าจอขึ้นกล่องเปล่าโดยไม่มี error ให้ตามรอย
  -- กันไว้ที่ฐานข้อมูลด้วย เพราะหน้าตั้งค่าไม่ใช่ทางเข้าเดียวของตารางนี้
  CONSTRAINT dpc_promptpay_format CHECK (
    promptpay_id IS NULL OR promptpay_id ~ '^[0-9]{10}$|^[0-9]{13}$'
  )
);

ALTER TABLE dormitory_payment_channels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dpc_landlord_all"    ON dormitory_payment_channels;
DROP POLICY IF EXISTS "dpc_tenant_select"   ON dormitory_payment_channels;

-- เจ้าของหอ: จัดการช่องทางของหอตัวเองได้ทั้งหมด (หน้าตั้งค่าใช้ทั้ง INSERT
-- และ UPDATE ผ่าน upsert จึงต้องเป็น FOR ALL)
CREATE POLICY "dpc_landlord_all" ON dormitory_payment_channels
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM dormitories d
    WHERE d.id = dormitory_payment_channels.dorm_id
      AND d.landlord_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM dormitories d
    WHERE d.id = dormitory_payment_channels.dorm_id
      AND d.landlord_id = auth.uid()
  ));

-- ผู้เช่า: อ่านช่องทางของหอที่ตัวเองอยู่เท่านั้น ไม่มีสิทธิ์เขียน
CREATE POLICY "dpc_tenant_select" ON dormitory_payment_channels
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM tenant_profiles t
    WHERE t.id = auth.uid()
      AND t.dorm_id = dormitory_payment_channels.dorm_id
  ));

COMMIT;

-- ─── ตั้งค่าช่องทางของหอที่ใช้งานอยู่ ────────────────────────────────────────
-- ปกติตั้งค่าผ่านหน้า "ช่องทางชำระเงิน" ในแอป (หน้าบิล → ปุ่มตั้งค่า) ซึ่ง
-- validate ให้ตรงกับ CHECK ข้างบนแล้ว บล็อกนี้มีไว้เผื่ออยากตั้งค่าล่วงหน้า
-- โดยไม่ต้องเปิดแอป
--
-- ถ้าไม่ตั้งค่า แผ่นชำระเงินจะบอกผู้เช่าว่ายังไม่มีข้อมูลช่องทางชำระเงิน
-- ซึ่งตั้งใจให้เป็นแบบนั้น — เงียบแล้วโชว์เลขบัญชีมั่วอันตรายกว่า

-- INSERT INTO dormitory_payment_channels
--   (dorm_id, promptpay_id, bank_name, account_no, account_name)
-- SELECT d.id,
--        '0812345678',              -- เบอร์ที่ผูกพร้อมเพย์ไว้แล้ว 10 หลัก
--        'ธนาคารกสิกรไทย',
--        '1438323216',
--        'ชื่อบัญชีตามสมุดบัญชี'
--   FROM dormitories d
--   JOIN landlord_profiles lp ON lp.id = d.landlord_id
--  WHERE lp.email = 'อีเมลเจ้าของหอ@example.com'
-- ON CONFLICT (dorm_id) DO UPDATE
--   SET promptpay_id = EXCLUDED.promptpay_id,
--       bank_name    = EXCLUDED.bank_name,
--       account_no   = EXCLUDED.account_no,
--       account_name = EXCLUDED.account_name,
--       updated_at   = NOW();
