-- ═══════════════════════════════════════════════════════════════════════════
-- HorPlug — Invoice Generation: schema
-- รันใน Supabase → SQL Editor เป็นไฟล์แรกของชุด
-- ลำดับ: invoices_schema.sql → invoices_rls.sql → invoices_backfill.sql
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS invoices (
  id                  BIGSERIAL PRIMARY KEY,
  invoice_no          TEXT NOT NULL,
  dorm_id             INT  NOT NULL REFERENCES dormitories(id) ON DELETE CASCADE,
  -- RESTRICT ไม่ใช่ CASCADE — การลบห้องหนึ่งห้องต้องไม่ทำลายประวัติการเงินของ
  -- ห้องนั้นทิ้งเงียบๆ ซึ่งขัดกับทั้งฟีเจอร์ที่ออกแบบให้ "ยกเลิกบิล" เก็บใบเดิม
  -- ไว้เป็นหลักฐานแทนการลบ · ห้องที่มีบิลอยู่จะลบไม่ได้จนกว่าจะจัดการบิลก่อน
  -- (dorm_id ยังเป็น CASCADE เพราะการลบทั้งหอคือการปิดกิจการ ไม่ใช่การจัดห้อง)
  room_id             INT  NOT NULL REFERENCES rooms(id)       ON DELETE RESTRICT,
  tenant_id           UUID REFERENCES tenant_profiles(id),
  billing_month       INT  NOT NULL CHECK (billing_month BETWEEN 1 AND 12),
  billing_year        INT  NOT NULL,

  -- ตัวเลขที่ตรึงไว้ ณ วันออกบิล ห้ามคำนวณใหม่จากมิเตอร์อีก
  room_price          NUMERIC NOT NULL DEFAULT 0,
  electricity_units   NUMERIC NOT NULL DEFAULT 0,
  electricity_cost    NUMERIC NOT NULL DEFAULT 0,
  water_cost          NUMERIC NOT NULL DEFAULT 0,
  cleaning_fee        NUMERIC NOT NULL DEFAULT 0,
  -- ยอดรวมคำนวณในฐานข้อมูล จึงเป็นไปไม่ได้ที่จะไม่ตรงกับผลบวกของรายการ
  total               NUMERIC GENERATED ALWAYS AS
                        (room_price + electricity_cost + water_cost + cleaning_fee) STORED,

  -- ค่าสะกดตรงกับ InvoiceStatus.<ชื่อ>.name ฝั่ง Dart จึงไม่ต้องมีตารางแปลงชื่อ
  status              TEXT NOT NULL DEFAULT 'unpaid'
                        CHECK (status IN ('unpaid','pending','paid','voided')),
  due_date            DATE NOT NULL,
  issued_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  issued_by           UUID NOT NULL,
  slip_url            TEXT,
  slip_submitted_at   TIMESTAMPTZ,
  rejection_reason    TEXT,
  paid_at             TIMESTAMPTZ,
  approved_by         UUID,

  voided_at           TIMESTAMPTZ,
  void_reason         TEXT,
  replaces_invoice_id BIGINT REFERENCES invoices(id),
  revision            INT NOT NULL DEFAULT 1,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- หนึ่งห้อง หนึ่งงวด มีบิลที่ยังไม่ถูกยกเลิกได้ใบเดียว
-- partial เพื่อให้ใบที่ยกเลิกยังอยู่เป็นประวัติ และให้ใบแทนที่เกิดได้
CREATE UNIQUE INDEX IF NOT EXISTS invoices_one_active_per_period
  ON invoices (room_id, billing_year, billing_month) WHERE status <> 'voided';

CREATE INDEX IF NOT EXISTS invoices_room_period
  ON invoices (room_id, billing_year DESC, billing_month DESC);
CREATE INDEX IF NOT EXISTS invoices_dorm_period
  ON invoices (dorm_id, billing_year DESC, billing_month DESC);
CREATE INDEX IF NOT EXISTS invoices_tenant
  ON invoices (tenant_id);

-- เลขที่บิลไม่มีส่วนที่บอกหอ และเลขห้องซ้ำกันข้ามหอได้ ความไม่ซ้ำจึงต้อง
-- ผูกกับหอ ไม่ใช่ทั้งตาราง — เลขที่เอกสารมีความหมายในขอบเขตของกิจการที่ออกมัน
CREATE UNIQUE INDEX IF NOT EXISTS invoices_no_per_dorm
  ON invoices (dorm_id, invoice_no);

CREATE OR REPLACE FUNCTION set_invoice_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS invoices_set_updated_at ON invoices;
CREATE TRIGGER invoices_set_updated_at
  BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION set_invoice_updated_at();

COMMIT;
