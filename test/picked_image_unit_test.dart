import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/picked_image.dart';
import 'package:image_picker/image_picker.dart';

/// รูปที่ผู้ใช้เลือกต้องเดินทางเป็น "ไบต์" ตลอดสาย ไม่ใช่ dart:io File
///
/// บนเว็บ `dart:io` คอมไพล์ผ่านแต่พังตอนรัน — `File(...).readAsBytes()` โยน
/// `UnsupportedError: _Namespace` ทันที และ `XFile.path` ที่ image_picker คืนมา
/// เป็น `blob:` URL ซึ่งไม่มีไฟล์จริงอยู่ปลายทาง การอ่านไบต์จาก XFile โดยตรง
/// จึงเป็นทางเดียวที่ใช้ได้ทั้งเว็บและมือถือ
///
/// ทุกเทสต์ส่งทั้ง `name` และ `path` ค่าเดียวกัน เพราะ XFile คนละแพลตฟอร์มอ่าน
/// ชื่อคนละทาง — ฝั่ง dart:io (ที่เทสต์นี้รันอยู่) ละเลย `name` แล้วตัดชื่อจาก
/// `path` ส่วนฝั่งเว็บใช้ `name` ตรงๆ
XFile _picked(Uint8List bytes, {String? name, String? mimeType}) =>
    XFile.fromData(bytes, name: name, path: name, mimeType: mimeType);

void main() {
  final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);

  group('PickedImage.fromXFile', () {
    test('อ่านไบต์จาก XFile ได้ตรงตัว โดยไม่แตะระบบไฟล์', () async {
      final image = await PickedImage.fromXFile(
        _picked(bytes, name: 'slip.png', mimeType: 'image/png'),
      );

      expect(image.bytes, bytes);
      expect(image.extension, 'png');
      expect(image.contentType, 'image/png');
    });

    test('นามสกุลถูกทำเป็นตัวเล็ก', () async {
      final image = await PickedImage.fromXFile(
        _picked(bytes, name: 'สลิป.JPEG', mimeType: 'image/jpeg'),
      );

      expect(image.extension, 'jpeg');
    });

    // เดิมโค้ดหานามสกุลด้วย `path.split('.').last` ซึ่งบนเว็บ path คือ blob URL
    // จุดในชื่อโฮสต์ทำให้ได้ "app/8f2c-..." มาเป็นนามสกุล
    test('blob URL ไม่ถูกตีความเป็นนามสกุล', () async {
      final image = await PickedImage.fromXFile(
        _picked(
          bytes,
          name: 'blob:https://horplug.vercel.app/8f2c-4d1a-9b77',
          mimeType: 'image/jpeg',
        ),
      );

      expect(image.extension, 'jpg');
      expect(image.extension, isNot(contains('/')));
    });

    // ชื่อที่กล้องมือถือตั้งเองมีจุดคั่นวันที่ได้ — "12" ไม่ใช่นามสกุลรูป
    test('จุดในชื่อไฟล์ที่ไม่ใช่นามสกุลถูกมองข้าม', () async {
      final image = await PickedImage.fromXFile(
        _picked(bytes, name: 'IMG_2026.08.12', mimeType: 'image/png'),
      );

      expect(image.extension, 'png');
    });

    test('ไม่มีนามสกุลและไม่มี mime type ก็ยังได้ค่าที่ใช้ได้', () async {
      final image = await PickedImage.fromXFile(XFile.fromData(bytes));

      expect(image.extension, 'jpg');
      expect(image.contentType, 'image/jpeg');
    });

    test('mime type ที่ผิดรูปไม่ถูกส่งต่อไปยัง storage', () async {
      final image = await PickedImage.fromXFile(
        _picked(bytes, name: 'photo.webp', mimeType: 'ไม่ใช่ mime'),
      );

      expect(image.extension, 'webp');
      expect(image.contentType, 'image/webp');
    });
  });
}
