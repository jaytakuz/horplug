#!/usr/bin/env python3
"""สร้างไอคอนเว็บทุกขนาดจากโลโก้ต้นฉบับ

รันเมื่อโลโก้เปลี่ยน:

    python3 scripts/generate_web_icons.py

**ย่อจากต้นฉบับ 4000×4000 เสมอ ไม่ใช่จาก lib/assets/horplug_logo.png** ซึ่งเป็น
ฉบับย่อ 256px สำหรับใช้ใน UI · ทั้งสองไฟล์เป็นภาพเดียวกัน แต่การขยาย 256 → 512
ให้ขอบฟุ้ง ขณะที่ย่อ 4000 → 512 ให้ขอบคม และไอคอน PWA ขนาด 512 คือสิ่งที่ระบบ
ปฏิบัติการหยิบไปแสดงตอนติดตั้งเป็นแอป

ใช้ `sips` (มากับ macOS) ย่อภาพ เพราะเร็วและคุณภาพดีกว่าการเขียน resampler เอง
ส่วนการแบนพื้นโปร่งเขียนด้วย stdlib ล้วน — sips ทำไม่ได้ และการเพิ่ม Pillow
เข้ามาเพื่องานที่รันปีละครั้งไม่คุ้ม

เป็นเครื่องมือฝั่งนักพัฒนา ไม่ได้อยู่ในเส้นทาง build ของ Vercel — ไฟล์ที่ได้ถูก
คอมมิทเข้า git ไปเลย
"""

import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / 'lib/assets/horplug_icon1.png'

# สีพื้นของตัวโลโก้เอง ไม่ใช่สีพื้นของธีม — ใช้เติมมุมโค้งที่โปร่งใส ถ้าใช้สีอื่น
# จะเห็นเป็นวงแหวนรอบไอคอนบนหน้าจอโฮมของ iOS
BACKGROUND = (0xFE, 0xF6, 0xE9)

# สัดส่วนของภาพในไอคอนแบบ maskable · ระบบปฏิบัติการครอปไอคอนเป็นวงกลมหรือ
# สี่เหลี่ยมมนตามธีมของเครื่อง สเปกจึงกำหนดให้เนื้อหาสำคัญอยู่ในวงกลมกลางภาพ
# ขนาด 80% ของด้าน · 78% เผื่อไว้อีกนิดให้ขอบบ้านไม่แตะเส้นครอบพอดีเป๊ะ
MASKABLE_SCALE = 0.78


def read_png(path):
    """คืน (กว้าง, สูง, bytearray ของ RGBA) — รองรับ 8-bit RGB/RGBA ไม่ interlace

    เขียนเองเพราะ stdlib ไม่มีตัวอ่าน PNG และภาพที่ต้องอ่านคือผลลัพธ์ของ sips
    ซึ่งเล็ก (≤512²) การถอดรหัสด้วย Python ล้วนจึงเร็วพอ
    """
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'{path} ไม่ใช่ไฟล์ PNG')

    pos, idat, header = 8, bytearray(), None
    while pos < len(data):
        (length,) = struct.unpack('>I', data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        if ctype == b'IHDR':
            header = struct.unpack('>IIBBBBB', chunk)
        elif ctype == b'IDAT':
            idat += chunk
        pos += 12 + length

    width, height, depth, color, _, _, interlace = header
    if depth != 8 or color not in (2, 6) or interlace != 0:
        raise ValueError(
            f'{path}: รองรับเฉพาะ 8-bit RGB/RGBA ที่ไม่ interlace '
            f'(เจอ depth={depth} color={color} interlace={interlace})'
        )

    channels = 4 if color == 6 else 3
    stride = width * channels
    raw = zlib.decompress(bytes(idat))

    out = bytearray()
    previous = bytearray(stride)
    pos = 0
    for _ in range(height):
        filter_type = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride

        # ย้อนตัวกรองตามสเปก PNG — แต่ละแถวเลือกตัวกรองของตัวเองได้
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up = previous[i]
            up_left = previous[i - channels] if i >= channels else 0
            if filter_type == 1:
                line[i] = (line[i] + left) & 0xFF
            elif filter_type == 2:
                line[i] = (line[i] + up) & 0xFF
            elif filter_type == 3:
                line[i] = (line[i] + (left + up) // 2) & 0xFF
            elif filter_type == 4:
                p = left + up - up_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - up_left)
                nearest = left if (pa <= pb and pa <= pc) else (up if pb <= pc else up_left)
                line[i] = (line[i] + nearest) & 0xFF
            elif filter_type != 0:
                raise ValueError(f'ตัวกรองแถวไม่รู้จัก: {filter_type}')

        previous = line
        if channels == 4:
            out += line
        else:
            for i in range(0, stride, 3):
                out += line[i:i + 3] + b'\xff'

    return width, height, out


def write_png(path, width, height, rgba):
    """เขียน PNG แบบ 8-bit RGBA ตัวกรองแถวเป็น 0 ทั้งหมด"""
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += rgba[y * width * 4:(y + 1) * width * 4]

    def chunk(tag, payload):
        return (struct.pack('>I', len(payload)) + tag + payload
                + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF))

    path.write_bytes(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
        + chunk(b'IEND', b'')
    )


def resize(source, size, destination):
    """ย่อด้วย sips — คุณภาพดีกว่าและเร็วกว่าการ resample เองใน Python"""
    subprocess.run(
        ['sips', '-s', 'format', 'png', '-z', str(size), str(size),
         str(source), '--out', str(destination)],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def flatten(source, canvas_size, destination):
    """วางภาพไว้กลางพื้นทึบ แล้วผสม alpha ลงไปจนไม่เหลือความโปร่งใส

    จำเป็นสำหรับไอคอนของ iOS ซึ่งไม่รองรับ alpha — พิกเซลโปร่งกลายเป็นสีดำ
    ทำให้ไอคอนที่มีมุมโค้งได้กรอบดำรอบตัวบนหน้าจอโฮม · และจำเป็นกับ maskable
    ซึ่งสเปกกำหนดให้เต็มกรอบทึบ เพราะระบบจะครอปมันเป็นรูปทรงของตัวเอง
    """
    width, height, rgba = read_png(source)
    # สี่ช่องต่อพิกเซล — พื้นทึบ alpha เต็มตั้งแต่ต้น
    canvas = bytearray((*BACKGROUND, 0xFF) * canvas_size * canvas_size)

    offset_x = (canvas_size - width) // 2
    offset_y = (canvas_size - height) // 2

    for y in range(height):
        row = (offset_y + y) * canvas_size
        for x in range(width):
            i = (y * width + x) * 4
            alpha = rgba[i + 3]
            if alpha == 0:
                continue
            j = (row + offset_x + x) * 4
            if alpha == 255:
                canvas[j:j + 3] = rgba[i:i + 3]
            else:
                for c in range(3):
                    canvas[j + c] = (rgba[i + c] * alpha
                                     + canvas[j + c] * (255 - alpha) + 127) // 255

    write_png(destination, canvas_size, canvas_size, canvas)


def main():
    if not MASTER.exists():
        sys.exit(f'✗ ไม่พบโลโก้ต้นฉบับที่ {MASTER}')

    web = ROOT / 'web'
    icons = web / 'icons'
    icons.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        scratch = Path(tmp)

        # favicon — เรนเดอร์ทุกขนาดที่เบราว์เซอร์ใช้จริง แทนที่จะส่งไปขนาดเดียว
        # แล้วให้เบราว์เซอร์ย่อเอง ซึ่งได้ขอบฟุ้งบนแท็บ
        resize(MASTER, 16, web / 'favicon-16.png')
        resize(MASTER, 32, web / 'favicon.png')
        resize(MASTER, 48, web / 'favicon-48.png')
        print('✓ favicon 16 · 32 · 48')

        # ไอคอน PWA แบบ any — คงพื้นโปร่งไว้ ระบบวางบนพื้นหลังของตัวเอง
        for size in (192, 512):
            resize(MASTER, size, icons / f'Icon-{size}.png')
        print('✓ Icon-192 · Icon-512')

        for size in (192, 512):
            inner = round(size * MASKABLE_SCALE)
            staged = scratch / f'maskable-{size}.png'
            resize(MASTER, inner, staged)
            flatten(staged, size, icons / f'Icon-maskable-{size}.png')
        print('✓ Icon-maskable-192 · Icon-maskable-512')

        staged = scratch / 'apple.png'
        resize(MASTER, 180, staged)
        flatten(staged, 180, icons / 'apple-touch-icon-180.png')
        print('✓ apple-touch-icon-180')


if __name__ == '__main__':
    main()
