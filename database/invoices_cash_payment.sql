-- ═══════════════════════════════════════════════════════════════════════════
-- HorPlug — ชำระด้วยเงินสด
-- รันหลัง invoices_rls.sql · idempotent รันซ้ำได้
--
-- เดิมมีทางเดียวคือโอนแล้วอัปสลิป ผู้เช่าที่จ่ายสดให้เจ้าของหอกับมือจึงไม่มีที่
-- บันทึกในระบบเลย บิลค้างอยู่ที่ unpaid ทั้งที่จ่ายไปแล้ว
--
-- **ไม่เพิ่มสถานะที่ห้า** — เงินสดใช้ pending เหมือนกับการอัปสลิป เพราะสิ่งที่
-- เกิดขึ้นเหมือนกันทุกประการ: ผู้เช่าบอกว่าจ่ายแล้ว เจ้าของหอยังไม่รับรอง
-- ต่างกันแค่ "หลักฐานคืออะไร" ซึ่งเป็นคนละคำถามกับ "บิลอยู่ขั้นไหน" เก็บไว้ที่
-- payment_method แทน · การเพิ่มสถานะจะทำให้ทุก exhaustive switch ในแอปพัง
-- และทำให้ canTransition ต้องรู้เรื่องวิธีจ่าย ซึ่งไม่ใช่เรื่องของมัน
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS payment_method TEXT;

-- ตั้งค่าแยกจาก ADD COLUMN เพื่อให้รันซ้ำได้เมื่อคอลัมน์มีอยู่แล้ว
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'invoices_payment_method_check'
  ) THEN
    ALTER TABLE invoices ADD CONSTRAINT invoices_payment_method_check
      CHECK (payment_method IS NULL OR payment_method IN ('transfer', 'cash'));
  END IF;
END $$;

COMMENT ON COLUMN invoices.payment_method IS
  'วิธีที่ผู้เช่าแจ้งว่าชำระ · transfer = โอนแล้วแนบสลิป · cash = จ่ายสดรอเจ้าของหอยืนยัน · NULL = ยังไม่ได้แจ้ง';

-- ─── ผู้เช่าแจ้งว่าจ่ายเงินสดแล้ว ────────────────────────────────────────────
-- SECURITY DEFINER ด้วยเหตุผลเดียวกับ submit_payment_slip: RLS จำกัดไม่ได้ว่า
-- UPDATE แตะคอลัมน์ไหน ผู้เช่าที่เรียก API ตรงจึงต้องแก้ยอดหรือกดตัวเองเป็น
-- paid ไม่ได้
CREATE OR REPLACE FUNCTION submit_cash_payment(p_invoice_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
    RAISE EXCEPTION 'บิลใบนี้แจ้งชำระไม่ได้ในสถานะปัจจุบัน';
  END IF;

  UPDATE invoices
  SET status            = 'pending',
      payment_method    = 'cash',
      slip_submitted_at = NOW(),
      -- ล้างสลิปเดิมทิ้ง เผื่อผู้เช่าเคยอัปสลิปแล้วถูกปฏิเสธ แล้วรอบนี้เลือก
      -- จ่ายสดแทน — สลิปที่ค้างอยู่จะทำให้เจ้าของหอเห็นหลักฐานผิดวิธี
      slip_url          = NULL,
      rejection_reason  = NULL
  WHERE id = p_invoice_id;
END;
$$;

REVOKE ALL ON FUNCTION submit_cash_payment(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION submit_cash_payment(BIGINT) TO authenticated;

-- ─── ผู้เช่ายกเลิกการแจ้งจ่ายสด ──────────────────────────────────────────────
-- กดผิดได้ และการรอเจ้าของหอปฏิเสธให้เป็นการบังคับให้คนสองคนต้องคุยกันเพราะ
-- ปุ่มเดียว · ยกเลิกได้เฉพาะที่ตัวเองแจ้งไว้และยังไม่ถูกยืนยัน
CREATE OR REPLACE FUNCTION cancel_cash_payment(p_invoice_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status TEXT;
  v_method TEXT;
BEGIN
  SELECT status, payment_method INTO v_status, v_method
  FROM invoices
  WHERE id = p_invoice_id AND tenant_id = auth.uid();

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'ไม่พบบิลใบนี้';
  END IF;

  -- เฉพาะที่แจ้งด้วยเงินสดเท่านั้น การถอนสลิปที่อัปไปแล้วเป็นคนละเรื่อง
  -- (ไฟล์อยู่ใน storage แล้ว ต้องลบด้วย ซึ่งฟังก์ชันนี้ทำไม่ได้)
  IF v_status <> 'pending' OR v_method <> 'cash' THEN
    RAISE EXCEPTION 'ยกเลิกได้เฉพาะการแจ้งชำระเงินสดที่ยังรอยืนยัน';
  END IF;

  UPDATE invoices
  SET status            = 'unpaid',
      payment_method    = NULL,
      slip_submitted_at = NULL
  WHERE id = p_invoice_id;
END;
$$;

REVOKE ALL ON FUNCTION cancel_cash_payment(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cancel_cash_payment(BIGINT) TO authenticated;

COMMIT;

-- ─── หมายเหตุ ───────────────────────────────────────────────────────────────
-- ฝั่งเจ้าของหอไม่ต้องมี RPC ใหม่ · การยืนยันรับเงินสดคือการเปลี่ยนสถานะเป็น
-- paid ซึ่ง approveSlip ทำอยู่แล้วผ่าน policy invoices_landlord_update
-- ปกติ แอปเรียกเมธอดเดียวกันแต่แสดงข้อความคนละแบบตาม payment_method
