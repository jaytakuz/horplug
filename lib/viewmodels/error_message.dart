import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// แปลง error จาก service ให้เป็นข้อความภาษาไทยที่ผู้ใช้อ่านเข้าใจ
///
/// เดิมฟังก์ชันนี้ถูกคัดลอกซ้ำอยู่ใน ViewModel หลายตัว (dashboard, rooms,
/// tenant_home) — ย้ายมารวมไว้ที่เดียวเพื่อให้ข้อความสอดคล้องกันทั้งแอป
///
/// **ห้ามคืน `error.toString()` ของ error จากฐานข้อมูลออกไปตรงๆ** ก่อนหน้านี้
/// ทำแบบนั้น ผู้เช่าจึงเห็นข้อความแบบนี้เต็มหน้าจอ
///
/// ```
/// PostgrestException(message: {"code":"PGRST205","details":null,"hint":
/// "Perhaps you meant the table 'public.tenant_profiles'", ...
/// ```
///
/// นอกจากอ่านไม่รู้เรื่องแล้ว มันยังบอกชื่อตารางกับโครงสร้างฐานข้อมูลให้คนนอก
/// รู้ด้วย รายละเอียดจริงยังจำเป็นตอนแก้บั๊ก จึงส่งลง log ผ่าน [debugPrint]
/// แทนที่จะส่งขึ้นหน้าจอ
String formatErrorMessage(Object error) {
  // เก็บของจริงไว้ให้คนแก้บั๊กเสมอ ไม่ว่าจะแปลงเป็นข้อความไหนก็ตาม
  debugPrint('[error] $error');

  if (error is PostgrestException) return _describePostgrest(error);
  if (error is StorageException) return _describeStorage(error);
  if (error is AuthException) {
    return 'เซสชันหมดอายุหรือเข้าสู่ระบบไม่สำเร็จ กรุณาเข้าสู่ระบบใหม่';
  }

  final message = error.toString().trim();
  final normalized = message.startsWith('Exception: ')
      ? message.substring('Exception: '.length).trim()
      : message;

  if (_looksLikeNetworkFailure(normalized.toLowerCase())) {
    return 'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
  }

  // ข้อความที่โค้ดของเราโยนเองด้วย `throw Exception('...')` เป็นภาษาไทยและ
  // เขียนมาเพื่อให้ผู้ใช้อ่านอยู่แล้ว จึงส่งต่อได้ตามเดิม
  return normalized;
}

/// error จาก PostgREST/Postgres — แปลงตาม code ไม่ใช่ตามข้อความ
///
/// ยึดหลัก "บอกสิ่งที่ผู้ใช้ทำต่อได้" ไม่ใช่ "บอกสิ่งที่ระบบเจอ" เพราะคนอ่าน
/// คือผู้เช่ากับเจ้าของหอ ไม่ใช่คนเขียนโปรแกรม
String _describePostgrest(PostgrestException error) {
  switch (error.code) {
    // ตาราง คอลัมน์ หรือฟังก์ชันหายไปจากฐานข้อมูล — แปลว่ายังไม่ได้รัน
    // migration ให้ครบ ผู้ใช้ทำอะไรไม่ได้เลยนอกจากแจ้งคนดูแล
    // (42703 undefined_column · 42883 undefined_function)
    case 'PGRST205':
    case '42P01':
    case '42703':
    case '42883':
      return 'ระบบยังติดตั้งไม่ครบ กรุณาแจ้งผู้ดูแลระบบ';

    // RLS ปฏิเสธ หรือไม่มีสิทธิ์บนตาราง
    case '42501':
    case 'PGRST301':
      return 'ไม่มีสิทธิ์เข้าถึงข้อมูลนี้';

    case '23505': // unique_violation
      return 'มีข้อมูลนี้อยู่แล้ว กรุณาโหลดใหม่อีกครั้ง';

    case '23514': // check_violation
      return 'ข้อมูลไม่ถูกต้องตามเงื่อนไขที่กำหนด';

    case '23503': // foreign_key_violation
      return 'ลบหรือแก้ไม่ได้ เพราะยังมีข้อมูลอื่นอ้างอิงอยู่';

    case '23502': // not_null_violation
      return 'กรอกข้อมูลไม่ครบ';

    case 'PGRST116': // ไม่พบแถวที่ตรงเงื่อนไข
      return 'ไม่พบข้อมูลที่ต้องการ';

    default:
      // ข้อความจาก RAISE EXCEPTION ในฟังก์ชันของเราเองเป็นภาษาไทยและเขียนมา
      // ให้ผู้ใช้อ่าน (เช่น submit_payment_slip) ส่งต่อได้ · ส่วนข้อความ
      // ภาษาอังกฤษจาก Postgres ไม่มีประโยชน์กับผู้ใช้
      final message = error.message.trim();
      return _isThai(message) ? message : 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
  }
}

String _describeStorage(StorageException error) {
  if (error.statusCode == '413') return 'ไฟล์ใหญ่เกินไป กรุณาเลือกรูปที่เล็กลง';
  if (error.statusCode == '403' || error.statusCode == '401') {
    return 'ไม่มีสิทธิ์เข้าถึงไฟล์นี้';
  }
  if (error.statusCode == '404') return 'ไม่พบไฟล์ที่ต้องการ';

  final message = error.message.trim();
  return _isThai(message) ? message : 'จัดการไฟล์ไม่สำเร็จ กรุณาลองใหม่';
}

bool _looksLikeNetworkFailure(String message) =>
    message.contains('failed host lookup') ||
    message.contains('socketexception') ||
    message.contains('clientexception') ||
    message.contains('connection refused') ||
    message.contains('network is unreachable') ||
    message.contains('connection timed out') ||
    message.contains('timed out');

/// true เมื่อข้อความมีอักษรไทย — ใช้แยกข้อความที่เราเขียนเองเพื่อผู้ใช้
/// ออกจากข้อความของ Postgres ที่ไม่ได้ตั้งใจให้ใครนอกจากคนเขียนโปรแกรมอ่าน
bool _isThai(String message) => RegExp(r'[฀-๿]').hasMatch(message);
