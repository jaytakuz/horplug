import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/viewmodels/error_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException _postgrest(String code, {String message = 'boom'}) =>
    PostgrestException(message: message, code: code);

void main() {
  // เหตุผลของเทสต์ชุดนี้: ผู้เช่าเคยเห็นข้อความนี้เต็มหน้าจอบนแอปจริง
  //
  //   PostgrestException(message: {"code":"PGRST205","details":null,
  //   "hint":"Perhaps you meant the table 'public.tenant_profiles'", ...
  //
  // อ่านไม่รู้เรื่อง และบอกโครงสร้างฐานข้อมูลให้คนนอกรู้ไปด้วย
  group('ไม่มีรายละเอียดทางเทคนิครั่วออกไปถึงผู้ใช้', () {
    const leaks = ['PostgrestException', 'PGRST', 'StorageException', 'public.'];

    void expectNoLeak(String message) {
      for (final leak in leaks) {
        expect(message.contains(leak), isFalse,
            reason: '"$message" มีคำว่า "$leak" ซึ่งไม่ควรถึงตาผู้ใช้');
      }
    }

    test('ทุก error code ของ Postgres ที่รู้จัก', () {
      for (final code in [
        'PGRST205',
        '42P01',
        '42703',
        '42883',
        '42501',
        'PGRST301',
        '23505',
        '23514',
        '23503',
        '23502',
        'PGRST116',
      ]) {
        expectNoLeak(formatErrorMessage(_postgrest(code)));
      }
    });

    test('code ที่ไม่รู้จัก พร้อมข้อความอังกฤษจาก Postgres', () {
      expectNoLeak(formatErrorMessage(_postgrest(
        '99999',
        message: 'relation "public.invoices" does not exist',
      )));
    });

    test('เคสจริงที่เจอบนแอป — ตาราง invoices ไม่มี', () {
      final message = formatErrorMessage(PostgrestException(
        message: "Could not find the table 'public.invoices' in the schema "
            "cache",
        code: 'PGRST205',
        hint: "Perhaps you meant the table 'public.tenant_profiles'",
      ));

      expectNoLeak(message);
      expect(message, contains('ผู้ดูแลระบบ'));
    });

    test('StorageException ทุกสถานะที่จัดการไว้', () {
      for (final status in ['413', '403', '401', '404', '500']) {
        expectNoLeak(formatErrorMessage(
          StorageException('Payload too large', statusCode: status),
        ));
      }
    });
  });

  group('แปลงตาม code ให้ตรงกับสิ่งที่ผู้ใช้ทำต่อได้', () {
    test('ตารางหายบอกให้แจ้งผู้ดูแล ไม่ใช่ให้ลองใหม่', () {
      expect(formatErrorMessage(_postgrest('PGRST205')), contains('ผู้ดูแล'));
    });

    // เคสจริงที่เจอ: เพิ่มคอลัมน์ payment_method ในโค้ดแล้วยังไม่ได้รัน
    // migration · ผู้ใช้ต้องรู้ว่าเป็นเรื่องการติดตั้ง ไม่ใช่ให้กดลองใหม่ไปเรื่อยๆ
    test('คอลัมน์หายบอกให้แจ้งผู้ดูแลเหมือนตารางหาย', () {
      expect(
        formatErrorMessage(_postgrest(
          '42703',
          message: 'column invoices.payment_method does not exist',
        )),
        contains('ผู้ดูแล'),
      );
    });

    test('ฟังก์ชันหายบอกให้แจ้งผู้ดูแล', () {
      expect(formatErrorMessage(_postgrest('42883')), contains('ผู้ดูแล'));
    });

    test('RLS ปฏิเสธบอกว่าไม่มีสิทธิ์', () {
      expect(formatErrorMessage(_postgrest('42501')), contains('ไม่มีสิทธิ์'));
    });

    test('ค่าซ้ำบอกให้โหลดใหม่', () {
      expect(formatErrorMessage(_postgrest('23505')), contains('โหลดใหม่'));
    });

    test('ไฟล์ใหญ่เกินบอกให้เลือกรูปเล็กลง', () {
      expect(
        formatErrorMessage(StorageException('too big', statusCode: '413')),
        contains('เล็กลง'),
      );
    });
  });

  group('ข้อความที่ตั้งใจให้ผู้ใช้อ่าน ต้องผ่านไปได้', () {
    // ฟังก์ชันใน SQL ของเราเอง (เช่น submit_payment_slip) RAISE EXCEPTION
    // เป็นภาษาไทยที่เขียนมาเพื่อผู้ใช้โดยเฉพาะ
    test('ข้อความไทยจาก RAISE EXCEPTION ส่งต่อตามเดิม', () {
      expect(
        formatErrorMessage(_postgrest('P0001', message: 'บิลใบนี้ส่งสลิปไม่ได้')),
        'บิลใบนี้ส่งสลิปไม่ได้',
      );
    });

    test('Exception ที่โค้ด Dart โยนเองถูกตัด prefix ออก', () {
      expect(
        formatErrorMessage(Exception('ยังไม่ได้เข้าสู่ระบบ')),
        'ยังไม่ได้เข้าสู่ระบบ',
      );
    });
  });

  group('error เครือข่าย', () {
    test('เน็ตหลุดบอกให้ตรวจอินเทอร์เน็ต', () {
      expect(
        formatErrorMessage(const SocketException('Failed host lookup')),
        contains('อินเทอร์เน็ต'),
      );
    });
  });
}
