-- ข้อความบิลอ้างถึงบิลใบไหน — คู่ขนานกับ maintenance_request_id ที่มีอยู่แล้ว
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS invoice_id BIGINT REFERENCES invoices(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS messages_invoice ON messages (invoice_id);
