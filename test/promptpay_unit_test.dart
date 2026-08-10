import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/services/promptpay.dart';
// ignore: implementation_imports
import 'package:promptpay_qrcode_generate/src/generate_qrcode.dart';

/// ดึง checksum (ข้อมูลของ tag 63) ออกจาก payload
String _checksumOf(String payload) {
  final marker = payload.lastIndexOf('6304');
  return payload.substring(marker + 4);
}

void main() {
  const phone = '0812345678';

  group('บั๊ก checksum ของ package ที่ promptPayPayload ต้องซ่อม', () {
    // เหตุผลทั้งหมดอยู่ใน doc ของ promptPayPayload — เทสต์คู่นี้คือหลักฐานที่
    // อ้างถึง ถ้าวันหนึ่ง package ออกเวอร์ชันที่แก้แล้ว เทสต์แรกจะล้ม ซึ่งเป็น
    // สัญญาณให้กลับมาลบ wrapper ทิ้งได้ ไม่ใช่ความล้มเหลว
    test('package สร้าง checksum สั้นกว่า 4 หลักจริง', () {
      final broken = <double>[];

      for (var satang = 0; satang < 5000; satang++) {
        final amount = satang / 100;
        final payload = generateQRCode(promptPayID: phone, amount: amount);
        if (payload.isEmpty) continue;
        if (_checksumOf(payload).length != 4) broken.add(amount);
      }

      expect(broken, isNotEmpty,
          reason: 'ถ้าว่างแปลว่า package แก้บั๊กแล้ว — ลบ wrapper ได้');
    });

    test('promptPayPayload คืน checksum 4 หลักเสมอทุกยอด', () {
      for (var satang = 0; satang < 5000; satang++) {
        final amount = satang / 100;
        final payload =
            promptPayPayload(promptPayId: phone, amount: amount);

        expect(payload, isNotNull);
        expect(_checksumOf(payload!).length, 4,
            reason: 'ยอด $amount ให้ checksum ที่ยาวไม่ครบ');
      }
    });

    test('ซ่อมด้วยการเติมศูนย์ข้างหน้า ไม่ใช่ตัดหรือคำนวณใหม่', () {
      // 0.10 เป็นยอดที่ package คืน "15D" (3 หลัก) — ดูเทสต์พิสูจน์ด้านบน
      final raw = generateQRCode(promptPayID: phone, amount: 0.1);
      final fixed = promptPayPayload(promptPayId: phone, amount: 0.1)!;

      expect(_checksumOf(raw).length, lessThan(4));
      expect(_checksumOf(fixed), '0${_checksumOf(raw)}');
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
