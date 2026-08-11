-- ข้อความบิลอ้างถึงบิลใบไหน — คู่ขนานกับ maintenance_request_id ที่มีอยู่แล้ว
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS invoice_id BIGINT REFERENCES invoices(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS messages_invoice ON messages (invoice_id);

-- ── ชนิดข้อความ 'invoice' ────────────────────────────────────────────────────
--
-- คอลัมน์ invoice_id อย่างเดียวไม่พอ · messages.message_type มี CHECK constraint
-- ที่ไล่ชื่อชนิดข้อความไว้ตายตัว และเวอร์ชันแรกของไฟล์นี้ลืมเติม 'invoice' เข้าไป
-- ผลคือทุก INSERT ของการ์ดบิลตกด้วย 23514 (messages_message_type_check) —
-- การ์ดบิลในแชทจึงไม่เคยโพสต์ได้เลยบนฐานข้อมูลที่รันไฟล์นี้ ทั้งตอนออกบิล
-- ตอนออกใบแทน และตอนกดส่งเข้าแชทเอง
--
-- ค่าที่อนุญาตต้องสะกดตรงกับ `MessageType.<ชื่อ>.name` ฝั่ง Dart ทุกตัว เพราะ
-- SupabaseService.sendMessage เขียน `type.name` ลงคอลัมน์นี้ตรงๆ
--
-- ADD CONSTRAINT ตรวจแถวที่มีอยู่ทั้งหมดด้วย ถ้ามีแถวที่ใช้ชนิดนอกรายการนี้
-- คำสั่งจะล้มทั้งชุดแทนที่จะปล่อยผ่านเงียบๆ ซึ่งเป็นสิ่งที่ต้องการ — ตรวจก่อนรัน
-- ได้ด้วย
--
--   SELECT DISTINCT message_type FROM messages;
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_message_type_check;

ALTER TABLE messages
  ADD CONSTRAINT messages_message_type_check
  CHECK (message_type IN (
    'text',
    'maintenanceRequest',
    'parcelNotification',
    'maintenanceUpdate',
    'image',
    'cleaningRequest',
    'cleaningUpdate',
    'invoice'
  ));
