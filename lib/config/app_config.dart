import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ค่าตั้งต้นที่แอปต้องมีก่อนจะต่อกับ Supabase ได้
///
/// อ่านจากสองที่ตามลำดับ:
///
/// 1. `--dart-define` ตอน build — ใช้บน CI และตอน deploy ขึ้น Vercel ซึ่งไม่มี
///    ไฟล์ `.env` เพราะไฟล์นั้นถูกกันไม่ให้เข้า git
/// 2. ไฟล์ `.env` ที่ bundle มาเป็น asset — ใช้ตอนพัฒนาบนเครื่องตัวเอง
///
/// ลำดับนี้กลับกันไม่ได้ · ถ้า `.env` ชนะ นักพัฒนาที่เผลอมีไฟล์ค้างอยู่จะ build
/// เอาค่าของเครื่องตัวเองขึ้น production โดยไม่รู้ตัว
///
/// **คีย์ที่ใส่ตรงนี้ต้องเป็น anon/publishable key เท่านั้น** ไม่ใช่ service role
/// — โค้ดเว็บทั้งก้อนดาวน์โหลดได้จากเบราว์เซอร์ ทุกอย่างที่ compile เข้าไปถือว่า
/// เปิดเผยต่อสาธารณะ · anon key ถูกออกแบบมาให้เปิดเผยอยู่แล้ว ด่านกันข้อมูลจริง
/// คือ RLS ที่ฝั่งฐานข้อมูล
abstract final class AppConfig {
  static const _urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  static const _anonKeyFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// โหลด `.env` ถ้ามี · ไม่มีก็ไม่เป็นไร
  ///
  /// `dotenv.load` โยนเมื่อหาไฟล์ไม่เจอ ซึ่งบน Vercel เป็นเรื่องปกติ ไม่ใช่
  /// ความผิดพลาด · ปล่อยให้โยนจะทำให้แอปตายตั้งแต่ยังไม่ทันวาดอะไร แล้วผู้ใช้
  /// เห็นแค่หน้าขาวโดยไม่มีอะไรบอกสาเหตุ
  static Future<void> loadDotEnvIfPresent() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (error) {
      debugPrint('ไม่พบ .env — ใช้ค่าจาก --dart-define แทน ($error)');
    }
  }

  static String _read(String fromDefine, String key) {
    if (fromDefine.isNotEmpty) return fromDefine;
    // isInitialized ต้องเช็คก่อน · dotenv.env โยน NotInitializedError เมื่อ
    // load() ไม่เคยสำเร็จ ซึ่งเป็นกรณีปกติบน Vercel
    if (!dotenv.isInitialized) return '';
    return dotenv.env[key] ?? '';
  }

  static String get supabaseUrl => _read(_urlFromDefine, 'SUPABASE_URL');

  static String get supabaseAnonKey =>
      _read(_anonKeyFromDefine, 'SUPABASE_ANON_KEY');

  /// true เมื่อมีค่าครบพอจะต่อกับ Supabase ได้
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// ข้อความบอกวิธีแก้ · ใช้ทั้งใน log และบนหน้าจอที่แสดงแทนแอปเมื่อค่าไม่ครบ
  static const missingConfigMessage =
      'ยังไม่ได้ตั้งค่า SUPABASE_URL และ SUPABASE_ANON_KEY\n\n'
      'ตอนพัฒนา: สร้างไฟล์ .env ที่รากโปรเจกต์\n'
      'ตอน deploy: ส่งผ่าน --dart-define ตอน flutter build';
}
