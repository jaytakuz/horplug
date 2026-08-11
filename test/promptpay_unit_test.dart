import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/services/promptpay.dart';
// ignore: implementation_imports
import 'package:promptpay_qrcode_generate/src/generate_qrcode.dart';

/// checksum ของ payload ที่ซ่อมแล้ว — 4 ตัวท้ายเสมอ
///
/// ห้ามใช้ lastIndexOf('6304') หา tag เพราะ checksum เองมีค่าเป็น "6304" ได้
/// (payload จะลงท้าย "...63046304") แล้วจะไปเจอตัวหลังซึ่งเป็น checksum ไม่ใช่
/// tag — เป็นบั๊กเดียวกับที่ promptPayPayload ต้องแก้ ถ้า helper ของเทสต์มีบั๊ก
/// เดียวกัน เทสต์จะมองไม่เห็นเคสนั้นเลย
String _checksumOf(String payload) =>
    payload.substring(payload.length - 4);

/// tag ที่นำหน้า checksum · payload ที่ถูกต้องต้องเป็น "6304" เสมอ
String _tagBeforeChecksum(String payload) =>
    payload.substring(payload.length - 8, payload.length - 4);

void main() {
  const phone = '0812345678';

  group('บั๊ก checksum ของ package ที่ promptPayPayload ต้องซ่อม', () {
    // เหตุผลทั้งหมดอยู่ใน doc ของ promptPayPayload — เทสต์คู่นี้คือหลักฐานที่
    // อ้างถึง ถ้าวันหนึ่ง package ออกเวอร์ชันที่แก้แล้ว เทสต์แรกจะล้ม ซึ่งเป็น
    // สัญญาณให้กลับมาลบ wrapper ทิ้งได้ ไม่ใช่ความล้มเหลว
    test('package สร้าง payload ที่สั้นกว่าที่ควรจริง', () {
      final broken = <double>[];

      for (var satang = 0; satang < 5000; satang++) {
        final amount = satang / 100;
        final raw = generateQRCode(promptPayID: phone, amount: amount);
        final fixed = promptPayPayload(promptPayId: phone, amount: amount);
        if (raw.isEmpty || fixed == null) continue;
        // payload ที่ซ่อมแล้วยาวกว่าของเดิม = ของเดิม checksum ไม่ครบ 4 หลัก
        if (fixed.length > raw.length) broken.add(amount);
      }

      expect(broken, isNotEmpty,
          reason: 'ถ้าว่างแปลว่า package แก้บั๊กแล้ว — ลบ wrapper ได้');
    });

    // invariant ที่แข็งแรงกว่าการนับความยาว checksum: payload EMVCo ที่ถูกต้อง
    // ต้องจบด้วย tag 63 · length 04 · ข้อมูล 4 ตัว รวม 8 ตัวท้ายเสมอ
    test('promptPayPayload ปิดท้ายด้วย tag 6304 + checksum 4 หลักเสมอ', () {
      for (var satang = 0; satang < 5000; satang++) {
        final amount = satang / 100;
        final payload = promptPayPayload(promptPayId: phone, amount: amount);

        expect(payload, isNotNull);
        expect(_tagBeforeChecksum(payload!), '6304',
            reason: 'ยอด $amount ตัดตำแหน่ง tag ผิด');
        expect(_checksumOf(payload), hasLength(4));
      }
    });

    // lastIndexOf('6304') พังเมื่อ checksum เองเป็น "6304" พอดี เพราะ payload
    // ลงท้าย "...63046304" แล้วไปเจอตัวหลังซึ่งเป็น checksum ไม่ใช่ tag
    test('checksum ที่บังเอิญเป็น "6304" ไม่ทำให้ตัด payload ผิดตำแหน่ง', () {
      var covered = false;

      for (var satang = 0; satang < 400000; satang++) {
        final amount = satang / 100;
        final raw = generateQRCode(promptPayID: phone, amount: amount);
        // body จบด้วย tag "6304" เสมอ ถ้า checksum เป็น "6304" ด้วย
        // payload จะลงท้ายด้วยแปดตัวนี้พอดี
        if (!raw.endsWith('63046304')) continue;

        covered = true;
        final payload = promptPayPayload(promptPayId: phone, amount: amount)!;

        // checksum ครบ 4 อยู่แล้ว จึงต้องไม่มีอะไรถูกต่อท้ายเพิ่ม
        expect(payload, raw);
        expect(_tagBeforeChecksum(payload), '6304');
        break;
      }

      expect(covered, isTrue,
          reason: 'ไม่เจอยอดที่ทำให้ checksum เป็น 6304 ในช่วงที่กวาด '
              'ขยายช่วงหรือเปลี่ยนเบอร์ทดสอบ');
    });

    test('ซ่อมด้วยการเติมศูนย์ข้างหน้า ไม่ใช่ตัดหรือคำนวณใหม่', () {
      // 0.10 เป็นยอดที่ package คืน "15D" (3 หลัก) — ดูเทสต์พิสูจน์ด้านบน
      final raw = generateQRCode(promptPayID: phone, amount: 0.1);
      final fixed = promptPayPayload(promptPayId: phone, amount: 0.1)!;

      expect(fixed.length, raw.length + 1);
      expect(fixed, '${raw.substring(0, raw.length - 3)}0'
          '${raw.substring(raw.length - 3)}');
    });
  });

  group('รูปร่างของ payload', () {
    test('ขึ้นต้นด้วย payload format indicator ตามสเปก EMVCo', () {
      final payload = promptPayPayload(promptPayId: phone, amount: 5240)!;
      expect(payload.startsWith('000201'), isTrue);
    });

    test('ฝังจำนวนเงินไว้ใน tag 54 — นี่คือเหตุผลทั้งหมดของฟีเจอร์นี้', () {
      final payload = promptPayPayload(promptPayId: phone, amount: 5240)!;
      expect(payload, contains('54075240.00'));
    });

    test('ยอดต่างกันให้ payload ต่างกัน', () {
      final a = promptPayPayload(promptPayId: phone, amount: 5240)!;
      final b = promptPayPayload(promptPayId: phone, amount: 5180)!;
      expect(a, isNot(b));
    });

    test('เบอร์ 10 หลักถูกแปลงเป็นรูปแบบสากล 0066 โดยตัดศูนย์นำหน้า', () {
      final payload = promptPayPayload(promptPayId: phone, amount: 1)!;
      expect(payload, contains('0066812345678'));
    });
  });

  group('เลขที่รับไม่ได้', () {
    // package คืนสตริงว่างเงียบๆ ซึ่งกลายเป็นกล่อง QR เปล่าบนหน้าจอ
    // wrapper คืน null เพื่อให้ผู้เรียกต้องจัดการกรณีนี้
    test('เบอร์ 9 หลักได้ null', () {
      expect(promptPayPayload(promptPayId: '081234567', amount: 1), isNull);
    });

    test('เบอร์ 11 หลักได้ null', () {
      expect(promptPayPayload(promptPayId: '08123456789', amount: 1), isNull);
    });

    test('มีขีดคั่นแม้ความยาวจะครบ 10 ก็ยังได้ null', () {
      expect(promptPayPayload(promptPayId: '081-234-56', amount: 1), isNull);
    });

    test('เลขบัตรประชาชน 13 หลักใช้ได้', () {
      expect(
        promptPayPayload(promptPayId: '1234567890123', amount: 1),
        isNotNull,
      );
    });
  });

  group('validatePromptPayId', () {
    test('เบอร์ 10 หลักผ่าน', () {
      expect(validatePromptPayId(phone), isNull);
    });

    test('ว่างได้เมื่อไม่บังคับ เพราะหอที่ใช้แต่เลขบัญชีก็ตั้งค่าได้', () {
      expect(validatePromptPayId(''), isNull);
      expect(validatePromptPayId(null), isNull);
    });

    test('ว่างไม่ได้เมื่อบังคับ', () {
      expect(validatePromptPayId('', required: true), isNotNull);
    });

    test('ตัวอักษรปนถูกปฏิเสธพร้อมบอกว่าต้องเป็นตัวเลขล้วน', () {
      expect(validatePromptPayId('081-234-5678'), contains('เฉพาะตัวเลข'));
    });

    test('ความยาวผิดถูกปฏิเสธพร้อมบอกความยาวที่ถูก', () {
      expect(validatePromptPayId('081234567'), contains('10 หลัก'));
    });

    test('ตัดช่องว่างหัวท้ายก่อนตรวจ', () {
      expect(validatePromptPayId('  $phone  '), isNull);
    });
  });
}
