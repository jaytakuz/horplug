-- ─ Payment Slip Storage Policies ──────────────────────────────────────────────
-- รันหลังสร้าง bucket "payment-slip" (แบบ private) ใน Supabase Storage
--
-- path ของไฟล์คือ {room_id}/{invoice_no}-{timestamp}.jpg (ดู InvoiceService
-- .uploadSlip) โฟลเดอร์ชั้นแรกจึงเป็น room_id ที่ใช้ผูกสิทธิ์ได้
--
-- policy ชุดเดิมเป็น USING (bucket_id = 'payment-slip') เฉยๆ ซึ่งเปิดให้ผู้ใช้
-- ที่ล็อกอินแล้ว **ทุกคน** อ่านและลบสลิปของทุกห้องในทุกหอ ผู้เช่าคนหนึ่งลบสลิป
-- ของอีกคนได้ แล้วคนนั้นถูกปฏิเสธการชำระโดยไม่รู้สาเหตุ
--
-- คอมเมนต์เดิมอ้างว่า "ควบคุมสิทธิ์จริงที่ตาราง invoices เพราะผู้เช่าอ่าน path
-- มาจากแถวที่ตัวเองอ่านได้" — ไม่จริง Storage API list ไฟล์ในบัคเก็ตได้ตรงๆ
-- โดยไม่ต้องผ่านตาราง invoices เลย การซ่อน path ไม่ใช่การควบคุมสิทธิ์

DROP POLICY IF EXISTS "payment_slip_authenticated_write"  ON storage.objects;
DROP POLICY IF EXISTS "payment_slip_authenticated_read"   ON storage.objects;
DROP POLICY IF EXISTS "payment_slip_authenticated_delete" ON storage.objects;
DROP POLICY IF EXISTS "payment_slip_tenant_write"   ON storage.objects;
DROP POLICY IF EXISTS "payment_slip_tenant_read"    ON storage.objects;
DROP POLICY IF EXISTS "payment_slip_tenant_delete"  ON storage.objects;
DROP POLICY IF EXISTS "payment_slip_landlord_read"  ON storage.objects;

-- ── ผู้เช่า: เฉพาะโฟลเดอร์ของห้องตัวเอง ────────────────────────────────────
-- รูปแบบ subquery เดียวกับที่ rls_tenant_access.sql ใช้กับ electricity_record

CREATE POLICY "payment_slip_tenant_write" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'payment-slip'
    AND (storage.foldername(name))[1] IN (
      SELECT room_id::text FROM tenant_profiles
      WHERE id = auth.uid() AND room_id IS NOT NULL
    )
  );

CREATE POLICY "payment_slip_tenant_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'payment-slip'
    AND (storage.foldername(name))[1] IN (
      SELECT room_id::text FROM tenant_profiles
      WHERE id = auth.uid() AND room_id IS NOT NULL
    )
  );

-- ลบได้เฉพาะของห้องตัวเอง — discardSlip ใช้เก็บกวาดไฟล์กำพร้าเมื่อบันทึกล้ม
-- ถ้าไม่มี policy นี้ RLS จะปฏิเสธเงียบๆ แล้วเหลือไฟล์ค้างทุกครั้งที่ส่งไม่สำเร็จ
CREATE POLICY "payment_slip_tenant_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'payment-slip'
    AND (storage.foldername(name))[1] IN (
      SELECT room_id::text FROM tenant_profiles
      WHERE id = auth.uid() AND room_id IS NOT NULL
    )
  );

-- ── เจ้าของหอ: อ่านและลบสลิปของห้องในหอตัวเอง ──────────────────────────────
-- ต้องมีสิทธิ์ลบด้วย เพราะ InvoiceService.rejectSlip เรียก discardSlip ต่อจาก
-- การอัปเดตแถว เพื่อไม่ให้ไฟล์ที่ไม่มีบิลใบไหนอ้างถึงค้างในบัคเก็ต — ถ้าให้แต่
-- สิทธิ์อ่าน การปฏิเสธสลิปจะยังสำเร็จแต่ทิ้งไฟล์กำพร้าไว้ทุกครั้งโดยเงียบสนิท

CREATE POLICY "payment_slip_landlord_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'payment-slip'
    AND (storage.foldername(name))[1] IN (
      SELECT r.id::text FROM rooms r
      JOIN dormitories d ON d.id = r.dorm_id
      WHERE d.landlord_id = auth.uid()
    )
  );

CREATE POLICY "payment_slip_landlord_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'payment-slip'
    AND (storage.foldername(name))[1] IN (
      SELECT r.id::text FROM rooms r
      JOIN dormitories d ON d.id = r.dorm_id
      WHERE d.landlord_id = auth.uid()
    )
  );
