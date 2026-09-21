#!/usr/bin/env bash
#
# สร้างไฟล์เว็บสำหรับ deploy — ใช้เป็น Build Command ของ Vercel
#
# ติดตั้ง Flutter เองเพราะ Vercel ไม่มีให้ · ใช้ tarball ที่ build มาแล้วแทนการ
# clone จาก git เพราะเร็วกว่ามาก (ไม่ต้องดึงประวัติทั้งหมด) และไม่เจอปัญหาที่
# shallow clone ทำให้ Flutter หาเวอร์ชันของตัวเองไม่เจอ
#
# ค่าที่ต้องตั้งใน Vercel → Settings → Environment Variables:
#   SUPABASE_URL       เช่น https://xxxx.supabase.co
#   SUPABASE_ANON_KEY  anon / publishable key เท่านั้น ห้ามใช้ service role
#
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.1}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "✗ ยังไม่ได้ตั้ง SUPABASE_URL หรือ SUPABASE_ANON_KEY" >&2
  echo "  ตั้งที่ Vercel → Settings → Environment Variables แล้ว redeploy" >&2
  exit 1
fi

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "→ ติดตั้ง Flutter $FLUTTER_VERSION"
  ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/$ARCHIVE"

  mkdir -p "$(dirname "$FLUTTER_DIR")"
  curl -fsSL "$URL" -o "/tmp/$ARCHIVE"
  tar -xf "/tmp/$ARCHIVE" -C "$(dirname "$FLUTTER_DIR")"
  rm -f "/tmp/$ARCHIVE"
else
  echo "→ ใช้ Flutter ที่ cache ไว้แล้ว"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Flutter ปฏิเสธที่จะรันเมื่อโฟลเดอร์ของตัวเองเป็นของผู้ใช้คนอื่น ซึ่งเกิดได้บน
# build container บางแบบ · บอกให้ git ไว้ใจ path นี้ไปเลย
git config --global --add safe.directory "$FLUTTER_DIR" || true

# pubspec ประกาศ .env เป็น asset ไว้สำหรับตอนพัฒนา · ไฟล์นี้ถูกกันไม่ให้เข้า git
# (มันคือความลับ) บน CI จึงไม่มี และ Flutter จะหยุด build ทันทีเมื่อหา asset
# ไม่เจอ · สร้างไฟล์เปล่าไว้ให้ผ่านด่านนั้น ค่าจริงส่งผ่าน --dart-define ซึ่ง
# AppConfig ให้ความสำคัญก่อน .env อยู่แล้ว
touch .env

flutter --version
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "✓ เสร็จแล้ว — ไฟล์อยู่ที่ build/web"
