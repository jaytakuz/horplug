#!/usr/bin/env python3
"""สร้างไอคอนแอปของ Android · iOS · macOS จากโลโก้ต้นฉบับ

รันเมื่อโลโก้เปลี่ยน (คู่กับ generate_web_icons.py ซึ่งทำฝั่งเว็บ):

    python3 scripts/generate_app_icons.py

ใช้ต้นฉบับ 4000px ตัวเดียวกับไอคอนเว็บ เพื่อให้ favicon บนแท็บกับไอคอนบน
หน้าจอโฮมเป็นภาพเดียวกันทุกแพลตฟอร์ม · ยืม read_png / write_png / resize /
flatten มาจากสคริปต์เว็บ ไม่เขียนซ้ำ

ต้นฉบับเป็นกระเบื้องมุมมนที่เต็มกรอบเกือบพอดี (ขอบโปร่งราว 0.5%) แต่ละแพลตฟอร์ม
ต้องการกระเบื้องนั้นคนละแบบ:

- iOS ห้ามมี alpha และระบบครอปมุมมนเอง → แบนพื้นครีมลงไปเต็มกรอบ
- macOS ไอคอนต้องมีรูปทรงมุมมนของตัวเอง และกินที่ 824/1024 ตามกริดของ Apple
  ถ้าเต็มกรอบจะดูใหญ่กว่าแอปอื่นบน Dock → ย่อลงแล้ววางบนพื้นโปร่ง
- Android 8+ ใช้ adaptive icon ซึ่งลอนเชอร์ครอปเป็นวงกลม/สี่เหลี่ยมมนเอง
  ถ้าไม่มี ระบบจะย่อไอคอนเดิมไปใส่ในวงกลมขาว → foreground ใช้สัดส่วน 78%
  เดียวกับไอคอน maskable ของเว็บ ส่วน Android รุ่นเก่ากว่านั้นได้กระเบื้องตรงๆ
"""

import json
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_web_icons import (  # noqa: E402
    BACKGROUND, MASKABLE_SCALE, MASTER, ROOT, flatten, read_png, resize,
    write_png,
)

# iOS ต้องการภาพเต็มกรอบ จึงดันขอบกระเบื้องให้พ้นกรอบไป (ดู ios())
IOS_ZOOM = 1.03

# ความกว้างของตัวไอคอนในกริด macOS: 824 จาก 1024 · ที่เหลือเป็นระยะเผื่อเงา
MACOS_BODY = 824 / 1024

# adaptive icon ของ Android มีผืนผ้าใบ 108dp ต่อความหนาแน่น
ANDROID_DENSITIES = {
    'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4,
}


def pad(source, canvas_size, destination):
    """วางภาพไว้กลางผืนผ้าใบโปร่งใส โดยคง alpha เดิมไว้

    sips เติมขอบได้แต่ใส่สีทึบ ซึ่งจะทำให้มุมรอบไอคอน macOS และ foreground
    ของ Android กลายเป็นกรอบสี่เหลี่ยม
    """
    width, height, rgba = read_png(source)
    canvas = bytearray(canvas_size * canvas_size * 4)
    offset_x = (canvas_size - width) // 2
    offset_y = (canvas_size - height) // 2
    for y in range(height):
        start = ((offset_y + y) * canvas_size + offset_x) * 4
        canvas[start:start + width * 4] = rgba[y * width * 4:(y + 1) * width * 4]
    write_png(destination, canvas_size, canvas_size, canvas)


def strip_alpha(path):
    """เขียนไฟล์ใหม่เป็น PNG แบบ RGB ที่ไม่มีช่อง alpha เลย

    flatten ทำให้ทุกพิกเซลทึบแล้ว แต่ไฟล์ยังเป็น RGBA · App Store ปฏิเสธไอคอน
    1024 ที่ "มี" ช่อง alpha แม้ทุกค่าจะเป็น 255 ก็ตาม
    """
    width, height, rgba = read_png(path)
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        row = rgba[y * width * 4:(y + 1) * width * 4]
        for i in range(0, len(row), 4):
            raw += row[i:i + 3]

    def chunk(tag, payload):
        return (struct.pack('>I', len(payload)) + tag + payload
                + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF))

    path.write_bytes(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
        + chunk(b'IEND', b'')
    )


def appiconset_sizes(appiconset):
    """คืน {ชื่อไฟล์: ขนาดพิกเซล} ตาม Contents.json ที่ Xcode ใช้จริง

    อ่านจากไฟล์แทนการเขียนรายการเอง — ถ้า Flutter หรือ Xcode เพิ่มช่องใหม่
    สคริปต์จะตามทัน และไม่มีวันเขียนไฟล์ที่ไม่มีใครอ้างถึง
    """
    contents = json.loads((appiconset / 'Contents.json').read_text())
    sizes = {}
    for image in contents['images']:
        if 'filename' not in image:
            continue
        points = float(image['size'].split('x')[0])
        scale = int(image['scale'].rstrip('x'))
        sizes[image['filename']] = round(points * scale)
    return sizes


def ios(scratch):
    appiconset = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for filename, size in appiconset_sizes(appiconset).items():
        staged = scratch / f'ios-{size}.png'
        # ขยายเกินกรอบแล้วครอปกลาง — ขอบกระเบื้องของต้นฉบับมีเส้นจางๆ ห่างขอบ
        # ราว 0.5% ซึ่งหน้ากากมุมมนของ iOS ตัดเฉพาะที่มุม ด้านตรงทั้งสี่จะยังเห็น
        # เป็นกรอบบางๆ รอบไอคอน
        resize(MASTER, round(size * IOS_ZOOM), staged)
        subprocess.run(
            ['sips', '-c', str(size), str(size), str(staged)],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        flatten(staged, size, appiconset / filename)
        strip_alpha(appiconset / filename)
    print('✓ iOS AppIcon (แบนพื้นครีม ไม่มี alpha)')


def macos(scratch):
    appiconset = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for filename, size in appiconset_sizes(appiconset).items():
        staged = scratch / f'macos-{size}.png'
        resize(MASTER, round(size * MACOS_BODY), staged)
        pad(staged, size, appiconset / filename)
    print('✓ macOS AppIcon (824/1024 บนพื้นโปร่ง)')


def android(scratch):
    res = ROOT / 'android/app/src/main/res'
    for density, factor in ANDROID_DENSITIES.items():
        folder = res / f'mipmap-{density}'
        folder.mkdir(exist_ok=True)

        # ไอคอนแบบเดิม (48dp) สำหรับ Android ก่อน 8.0
        resize(MASTER, round(48 * factor), folder / 'ic_launcher.png')

        # foreground ของ adaptive icon (108dp) · มุมของกระเบื้องที่ 78% อยู่นอก
        # พื้นที่ที่ลอนเชอร์แสดง (66dp กลางภาพ) จึงไม่มีทางเห็นขอบกระเบื้อง
        canvas = round(108 * factor)
        staged = scratch / f'android-{density}.png'
        resize(MASTER, round(canvas * MASKABLE_SCALE), staged)
        pad(staged, canvas, folder / 'ic_launcher_foreground.png')

    anydpi = res / 'mipmap-anydpi-v26'
    anydpi.mkdir(exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    # สีพื้นเดียวกับที่แบนลงไอคอน iOS — สีของตัวโลโก้เอง ไม่ใช่สีของธีม
    (res / 'values/ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
        '</resources>\n' % BACKGROUND
    )
    print('✓ Android ic_launcher + adaptive icon')


def main():
    if not MASTER.exists():
        sys.exit(f'✗ ไม่พบโลโก้ต้นฉบับที่ {MASTER}')

    with tempfile.TemporaryDirectory() as tmp:
        scratch = Path(tmp)
        ios(scratch)
        macos(scratch)
        android(scratch)


if __name__ == '__main__':
    main()
