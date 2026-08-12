import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// รูปหนึ่งใบที่ผู้ใช้เพิ่งเลือก — เก็บเป็น "ไบต์" ไม่ใช่ตำแหน่งไฟล์
///
/// ทั้งแอปเคยส่งต่อรูปเป็น `dart:io File` ที่สร้างจาก `XFile.path` ซึ่งใช้ได้
/// เฉพาะบนมือถือ · บนเว็บ `dart:io` คอมไพล์ผ่าน (เป็น stub) แต่ทุกคำสั่งที่แตะ
/// ไฟล์จริงโยน `UnsupportedError: _Namespace` ตอนรัน และ path ที่ได้จากเบราว์เซอร์
/// เป็น `blob:` URL ที่ไม่มีไฟล์อยู่ปลายทางอยู่แล้ว ผู้ใช้บนเว็บจึงแนบสลิปและ
/// ส่งรูปในแชทไม่ได้เลย
///
/// การอ่านไบต์จาก [XFile] ตั้งแต่ต้นทางใช้ได้เหมือนกันทุกแพลตฟอร์ม และทำให้
/// ชั้นล่างอัปโหลดด้วย `uploadBinary` ได้โดยไม่ต้องรู้ว่ารูปมาจากที่ไหน
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;

  /// นามสกุลตัวเล็กไม่มีจุดนำหน้า เช่น `jpg` — ใช้ตั้งชื่อไฟล์ใน storage
  final String extension;

  /// MIME type ที่ส่งให้ storage · ถ้าไม่ตั้ง Supabase จะเดาเป็น
  /// `application/octet-stream` ทำให้เบราว์เซอร์ดาวน์โหลดแทนที่จะแสดงรูป
  final String contentType;

  static Future<PickedImage> fromXFile(XFile file) async {
    // อ่านชื่อก่อน path เพราะบนเว็บ path เป็น blob URL ส่วน name คือชื่อไฟล์จริง
    // ที่ผู้ใช้เลือก · บนมือถือทั้งสองค่ามาจากไฟล์เดียวกันอยู่แล้ว
    final extension = _extensionOf(
      file.name.isNotEmpty ? file.name : file.path,
      file.mimeType,
    );
    return PickedImage(
      bytes: await file.readAsBytes(),
      extension: extension,
      contentType: _contentTypeOf(file.mimeType, extension),
    );
  }
}

const String _fallbackExtension = 'jpg';

const Map<String, String> _extensionByMimeType = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
  'image/heic': 'heic',
  'image/heif': 'heif',
};

/// ยอมรับเฉพาะนามสกุลรูปที่รู้จัก ไม่ใช่ "อะไรก็ตามที่อยู่หลังจุดสุดท้าย"
///
/// กันสองกรณีที่เจอจริง: บนเว็บชื่ออาจเป็น blob URL เช่น
/// `blob:https://horplug.vercel.app/8f2c-...` ซึ่ง `split('.').last` คืน
/// `app/8f2c-...` มาเป็นนามสกุล กลายเป็นโฟลเดอร์ซ้อนใน storage path · และชื่อที่
/// กล้องมือถือตั้งเองอย่าง `IMG_2026.08.12` จะได้ `12` มาเป็นนามสกุล
const Set<String> _knownExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'heic',
  'heif',
  'bmp',
};

String _extensionOf(String name, String? mimeType) {
  final dot = name.lastIndexOf('.');
  if (dot != -1 && dot < name.length - 1) {
    final candidate = name.substring(dot + 1).toLowerCase();
    if (_knownExtensions.contains(candidate)) return candidate;
  }
  return _extensionByMimeType[mimeType?.toLowerCase()] ?? _fallbackExtension;
}

String _contentTypeOf(String? mimeType, String extension) {
  final declared = mimeType?.toLowerCase();
  if (declared != null && _extensionByMimeType.containsKey(declared)) {
    return declared;
  }
  // ชนิดที่เบราว์เซอร์บอกมาใช้ไม่ได้ (ว่าง ผิดรูป หรือไม่ใช่รูปภาพ) — เดาจาก
  // นามสกุลแทน เพราะนามสกุลผ่านการตรวจมาแล้วว่าอยู่ในรูปที่ใช้ได้
  return extension == 'jpg' ? 'image/jpeg' : 'image/$extension';
}
