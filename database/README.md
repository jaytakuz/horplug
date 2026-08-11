# ฐานข้อมูล HorPlug — ลำดับการติดตั้ง

ไฟล์ในโฟลเดอร์นี้คือ schema และ policy ทั้งหมดของระบบ **ลำดับการรันสำคัญ**
เพราะแต่ละไฟล์อ้างถึงตารางที่ไฟล์ก่อนหน้าสร้าง

เอกสารนี้มีเพราะเคยไม่มี — ไฟล์ `invoices_schema.sql` ไม่เคยถูกรันบนฐานข้อมูลจริง
อยู่หลายสัปดาห์ ทุกหน้าที่แตะบิลจึงพังด้วย `PGRST205 Could not find the table
'public.invoices'` โดยไม่มีใครรู้ว่าต้องไปรันอะไร

## รันตามลำดับนี้ใน Supabase → SQL Editor

| # | ไฟล์ | สร้างอะไร | ต้องมีก่อน |
|---|---|---|---|
| 1 | `rls_setup.sql` | policy พื้นฐานของ dormitories, rooms, profiles | — |
| 2 | `rls_tenant_access.sql` | สิทธิ์อ่านฝั่งผู้เช่า (มิเตอร์, โปรไฟล์เจ้าของหอ) | 1 |
| 3 | `invoices_schema.sql` | ตาราง `invoices` + index + trigger | 1 |
| 4 | `invoices_rls.sql` | policy ของบิล + ฟังก์ชัน `submit_payment_slip` | 3 |
| 5 | `invoices_backfill.sql` | ประวัติบิลย้อนหลังจากมิเตอร์ที่จดไว้ (ไม่บังคับ) | 4 |
| 6 | `invoices_chat_message.sql` | `messages.invoice_id` สำหรับการ์ดบิลในแชท | 3 |
| 7 | `payment_slip_bucket.sql` | policy ของบัคเก็ตสลิป | 3 · **สร้าง bucket ก่อน** |
| 8 | `dormitory_payment_channel.sql` | ตารางช่องทางชำระเงินต่อหอ | 1 |
| 9 | `invoices_cash_payment.sql` | คอลัมน์ `payment_method` + RPC แจ้ง/ยกเลิกการจ่ายเงินสด | 4 |

ไฟล์ทุกไฟล์ **รันซ้ำได้** (`IF NOT EXISTS` / `DROP POLICY IF EXISTS`)

### ก่อนรันข้อ 7

สร้าง bucket ชื่อ `payment-slip` แบบ **private** ในหน้า Storage ก่อน ไม่งั้น policy
จะผูกกับบัคเก็ตที่ไม่มีอยู่

### หลังรันข้อ 5 (backfill)

ตรวจว่าตัวเลขสมเหตุสมผล โดยเฉพาะหน่วยไฟ

```sql
SELECT invoice_no, billing_month, electricity_units, electricity_cost, status
  FROM invoices ORDER BY billing_year DESC, billing_month DESC;
```

`electricity_units` เป็น 0 ขณะที่ `electricity_cost` มีตัวเลข = รันไฟล์เวอร์ชันเก่า
ที่ยังไม่รองรับมิเตอร์วนรอบ 9999→0000 ให้ลบแถวนั้นแล้วรันใหม่

**ข้อจำกัดของ backfill:** บิลย้อนหลังถูกผูกกับผู้เช่า *ปัจจุบัน* ของห้อง เพราะระบบ
ไม่ได้เก็บประวัติว่าใครอยู่ห้องไหนช่วงไหน ถ้าห้องเคยเปลี่ยนผู้เช่ามาก่อน ผู้เช่า
คนปัจจุบันจะเห็นบิลของคนก่อนหน้า — ให้ลบบิลของงวดก่อนที่เขาเข้าอยู่ทิ้งด้วยมือ

## ตรวจว่าติดตั้งครบ

```sql
SELECT tablename FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN ('invoices', 'dormitory_payment_channels')
 ORDER BY tablename;
```

ต้องได้ 2 แถว · ได้ไม่ครบแปลว่าข้ามไฟล์ไป

```sql
-- คอลัมน์และฟังก์ชันที่เพิ่มทีหลัง ต้องมีครบทั้งหมด
SELECT column_name FROM information_schema.columns
 WHERE table_name = 'invoices' AND column_name = 'payment_method';
SELECT proname FROM pg_proc
 WHERE proname IN ('submit_payment_slip', 'submit_cash_payment',
                   'cancel_cash_payment')
 ORDER BY proname;
```

ต้องได้ 1 แถว และ 3 แถวตามลำดับ

```sql
-- policy ของบิลต้องมี 4 อัน และของบัคเก็ตสลิปต้องมี 5 อัน
SELECT tablename, COUNT(*) FROM pg_policies
 WHERE tablename IN ('invoices', 'dormitory_payment_channels')
 GROUP BY tablename;
```

## เมื่อแอปขึ้น PGRST205 ทั้งที่ตารางมีอยู่

PostgREST แคช schema ไว้ สั่งให้โหลดใหม่แล้วเปิดแอปอีกครั้ง

```sql
NOTIFY pgrst, 'reload schema';
```

## ไฟล์ที่ไม่เกี่ยวกับการติดตั้ง

`seed_*.sql` และ `csv/` เป็นข้อมูลทดสอบ · `fix_id_sequences.sql` กับ
`utility_records_normalization.sql` เป็นงานซ่อมเฉพาะกิจที่รันไปแล้ว
ไม่ต้องรันบนฐานข้อมูลใหม่
