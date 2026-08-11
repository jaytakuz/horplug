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
-- ต้องระบุ pg_temp ต่อท้ายเสมอ ไม่งั้น Postgres ค้น pg_temp ก่อน public อยู่ดี
-- ผู้เรียกที่สร้างตาราง temp ชื่อ invoices ขึ้นมาเองจะทำให้ทั้งฟังก์ชันไปอ่าน
-- เขียนตารางปลอมของตัวเอง แล้ว RPC กลายเป็น no-op ที่ไม่มีใครรู้
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status  TEXT;
  v_room_id INT;
BEGIN
  SELECT status, room_id INTO v_status, v_room_id
  FROM invoices
  WHERE id = p_invoice_id AND tenant_id = auth.uid();

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'ไม่พบบิลใบนี้';
  END IF;

  IF v_status <> 'unpaid' THEN
    RAISE EXCEPTION 'บิลใบนี้ส่งสลิปไม่ได้ในสถานะปัจจุบัน';
  END IF;

  -- path ต้องอยู่ในโฟลเดอร์ของห้องที่บิลใบนี้เป็นของ (ดู InvoiceService
  -- .uploadSlip ที่สร้าง path เป็น {room_id}/...) ถ้าไม่ตรวจ ผู้เช่าจะชี้บิล
  -- ตัวเองไปที่ไฟล์สลิปของห้องอื่น หรือชี้ไปยัง path ที่ไม่มีไฟล์อยู่จริง
  -- แล้วบิลค้างอยู่ที่ pending โดยเจ้าของหอเปิดดูสลิปไม่ได้เลย
  IF p_slip_url IS NULL
     OR split_part(p_slip_url, '/', 1) <> v_room_id::text THEN
    RAISE EXCEPTION 'path ของสลิปไม่ถูกต้อง';
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
