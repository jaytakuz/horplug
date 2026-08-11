# Deploy HorPlug ขึ้น Vercel

เอกสารนี้ครอบทุกอย่างที่ต้องทำเพื่อให้เว็บใช้งานได้จริง ตั้งแต่ตั้งค่า Vercel
ไปจนถึงสิ่งที่ต้องตั้งฝั่ง Supabase ซึ่งถ้าลืมจะทำให้ล็อกอินไม่ได้

---

## 1. ตั้งค่าใน Vercel

**Import โปรเจกต์** จาก GitHub แล้วตั้งค่าดังนี้ (ส่วนใหญ่ `vercel.json` ตั้งให้
อัตโนมัติแล้ว ไม่ต้องแก้ใน UI)

| ช่อง | ค่า | มาจากไหน |
|---|---|---|
| Framework Preset | Other | `vercel.json` |
| Build Command | `bash scripts/build_web.sh` | `vercel.json` |
| Output Directory | `build/web` | `vercel.json` |
| Install Command | (ว่าง — สคริปต์จัดการเอง) | `vercel.json` |
| Production Branch | `main` | ต้องตั้งเองใน Settings → Git |

Production Branch สำคัญ — Vercel ตั้งค่าเริ่มต้นเป็น default branch ของ repo
ซึ่งอาจไม่ใช่ `main` · branch อื่นทุกอันจะได้ preview deployment แยก URL ของ
ตัวเองอัตโนมัติ ซึ่งเป็นสิ่งที่ใช้ทดสอบก่อน merge เข้า main

**Build แรกใช้เวลาราว 4–6 นาที** เพราะต้องดาวน์โหลด Flutter SDK · รอบถัดไปเร็วขึ้น
ถ้า Vercel ยัง cache โฟลเดอร์ `~/flutter` ไว้

**Environment Variables** — ต้องตั้งเองใน Settings → Environment Variables
ให้ครบทั้งสาม environment (Production / Preview / Development)

| ชื่อ | ค่า | หมายเหตุ |
|---|---|---|
| `SUPABASE_URL` | `https://xxxx.supabase.co` | จาก Supabase → Project Settings → API |
| `SUPABASE_ANON_KEY` | anon / publishable key | **ห้ามใช้ service role key เด็ดขาด** |

> โค้ดเว็บทั้งก้อนดาวน์โหลดได้จากเบราว์เซอร์ ทุกอย่างที่ compile เข้าไปถือว่า
> เปิดเผยต่อสาธารณะ · anon key ถูกออกแบบมาให้เปิดเผยอยู่แล้ว ด่านกันข้อมูลจริง
> คือ RLS ที่ฝั่งฐานข้อมูล ส่วน service role key ข้าม RLS ได้ทั้งหมด ถ้าหลุด
> ขึ้นเว็บเท่ากับเปิดฐานข้อมูลทั้งใบให้ใครก็ได้

ถ้ายังไม่ได้ตั้งสองตัวนี้ สคริปต์จะหยุด build พร้อมบอกว่าขาดอะไร — ดีกว่าปล่อยให้
deploy ผ่านแล้วได้หน้าขาว

---

## 2. ตั้งค่าฝั่ง Supabase (ลืมแล้วล็อกอินไม่ได้)

Supabase → Authentication → URL Configuration

| ช่อง | ค่าที่ต้องใส่ |
|---|---|
| Site URL | `https://<โดเมนจริง>` |
| Redirect URLs | `https://<โดเมนจริง>/**` และ `https://<โปรเจกต์>-*.vercel.app/**` |

ตัวที่สองครอบ preview deployment ซึ่ง Vercel สร้าง URL ใหม่ทุกครั้งที่ push
ไม่ใส่ไว้ก็ทดสอบ preview ไม่ได้เลย

---

## 3. เรื่องที่ต้องรู้ก่อน deploy

### `.env` ไม่ได้อยู่ใน git — และนั่นถูกแล้ว

`pubspec.yaml` ประกาศ `.env` เป็น asset ไว้สำหรับตอนพัฒนา แต่ไฟล์นี้เป็นความลับ
จึงถูกกันไม่ให้เข้า git · Flutter จะหยุด build ทันทีเมื่อหา asset ไม่เจอ
`scripts/build_web.sh` จึง `touch .env` สร้างไฟล์เปล่าไว้ก่อน แล้วส่งค่าจริงผ่าน
`--dart-define`

[`AppConfig`](../lib/config/app_config.dart) อ่าน `--dart-define` ก่อน `.env`
เสมอ ลำดับนี้กลับกันไม่ได้ — ถ้า `.env` ชนะ นักพัฒนาที่เผลอมีไฟล์ค้างอยู่จะ build
เอาค่าของเครื่องตัวเองขึ้น production โดยไม่รู้ตัว

### URL ไม่มี `#`

`main.dart` เรียก `usePathUrlStrategy()` ทำให้ได้ `/{path}` แทน `/#/{path}`
ไม่ใช่แค่ความสวยงาม — Supabase ส่งลิงก์รีเซ็ตรหัสผ่านกลับมาพร้อม token ใน
fragment (`#access_token=...`) ถ้า go_router ใช้ fragment เป็นเส้นทางด้วย
สองอย่างจะแย่ง `#` กันเอง แล้วลิงก์รีเซ็ตพังทั้งหมด

แลกกับการที่เซิร์ฟเวอร์ต้อง rewrite ทุก path มาที่ `index.html` — `vercel.json`
ทำไว้แล้ว ถ้าย้ายไป host อื่นต้องตั้งเองไม่งั้นรีเฟรชหน้าใดก็ตามที่ไม่ใช่ `/`
จะได้ 404

### สิ่งที่ยังไม่รองรับบนเว็บ

| ฟีเจอร์ | สถานะบนเว็บ | หมายเหตุ |
|---|---|---|
| เลือกรูปจากเครื่อง (`image_picker`) | ใช้ได้ | เปิด file picker ของเบราว์เซอร์ |
| ถ่ายรูปด้วยกล้อง | จำกัด | เบราว์เซอร์บนเดสก์ท็อปไม่มีกล้อง ผู้ใช้ต้องเลือกไฟล์แทน |
| บันทึก/แชร์ PDF (`printing`) | ใช้ได้ | เปิดหน้าต่างพิมพ์ของเบราว์เซอร์ ไม่ใช่แผ่นแชร์ของ OS |
| ฟอนต์ไทยใน PDF | ใช้ได้ | Sarabun ถูก bundle เป็น asset จึงไปด้วยกันกับ build |

---

## 4. ตรวจหลัง deploy

ไล่ทีละข้อบนโดเมนจริง ถ้าข้อไหนไม่ผ่านให้หยุดแล้วแก้ก่อน

1. เปิดหน้าแรก → เห็นหน้าเข้าสู่ระบบ **ไม่ใช่หน้าขาวและไม่ใช่ "ตั้งค่าไม่ครบ"**
   - เจอ "ตั้งค่าไม่ครบ" = environment variables ไม่ถึงตัว build → ตรวจข้อ 1
2. ล็อกอิน → เข้าได้ · ถ้าค้างที่หน้าเดิม ให้เปิด console ดู error เรื่อง redirect → ตรวจข้อ 2
3. อยู่หน้าใดก็ได้ที่ไม่ใช่ `/` แล้วกด **รีเฟรช** → ต้องได้หน้าเดิม ไม่ใช่ 404
   - ได้ 404 = rewrite ไม่ทำงาน → ตรวจว่า `vercel.json` ถูก deploy ไปด้วย
4. ย่อหน้าต่างให้แคบกว่า 600px → แถบนำทางย้ายลงล่าง · ขยายเกิน 600px → ย้ายไปข้างซ้าย
5. ขยายเต็มจอกว้าง → เนื้อหาอยู่กลาง ไม่ทอดยาวจนสุดขอบทั้งสองด้าน
6. ลากแถวชิปตัวกรองในหน้าบิลด้วยเมาส์ → เลื่อนได้
7. เปิดบิลสักใบ → กด "บันทึก PDF" → **ภาษาไทยอ่านออก ไม่ใช่กล่องว่าง**
8. ลืมรหัสผ่าน → กดลิงก์ในอีเมล → เข้าหน้าตั้งรหัสใหม่ได้ (ข้อนี้พิสูจน์เรื่อง `#`)

---

## 5. ลำดับการ merge

```
feature-invoice-generation  →  dev  →  main
```

**ก่อน merge เข้า dev**

- [ ] `flutter analyze` — 14 issues, 0 errors
- [ ] `flutter test` — ผ่านทั้งหมด
- [ ] `flutter build web --release` ผ่าน
- [ ] `flutter build ios --simulator` ผ่าน
- [ ] รัน `database/invoices_cash_payment.sql` บน Supabase แล้ว
- [ ] ทดสอบบนเครื่องจริงตามเช็คลิสต์ใน `docs/superpowers/plans/`

**ก่อน merge เข้า main**

- [ ] ผ่านเช็คลิสต์ข้อ 4 ทั้งแปดข้อบน preview deployment ของ Vercel
- [ ] ตั้ง Redirect URLs ของ Supabase ให้ครอบโดเมน production แล้ว
- [ ] ตรวจว่า `database/csv/` และ `sample_documents/` ยังไม่เข้า git
      (`git ls-files database/csv/ sample_documents/` ต้องไม่คืนอะไรเลย)

---

## 6. ทดสอบ build แบบเดียวกับ Vercel บนเครื่องตัวเอง

```bash
mv .env .env.bak && touch .env
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
rm .env && mv .env.bak .env

# เสิร์ฟแบบมี rewrite เหมือน Vercel
npx serve build/web -s
```

`-s` คือ single-page mode ซึ่ง rewrite ทุก path มาที่ `index.html` เหมือนที่
`vercel.json` ทำ · ไม่ใส่แล้วรีเฟรชหน้าในจะได้ 404 ซึ่งเป็นอาการเดียวกับที่จะ
เจอบน production ถ้า rewrite ไม่ทำงาน
