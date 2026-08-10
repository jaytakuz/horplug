import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/viewmodels/payment_channel_view_model.dart';

void main() {
  // validate ทั้งสองตัวสะท้อน CHECK ในฐานข้อมูล (dpc_has_a_channel และ
  // dpc_promptpay_format) ถ้าฝั่งแอปหลวมกว่า เจ้าของหอจะเจอข้อความดิบจาก
  // Postgres แทนคำอธิบายว่าต้องกรอกอะไรเพิ่ม
  group('validateHasAnyChannel', () {
    test('มีแต่พร้อมเพย์ก็พอ', () {
      expect(
        validateHasAnyChannel(
            promptPayId: '0812345678', bankName: '', accountNo: ''),
        isNull,
      );
    });

    test('มีแต่ธนาคารครบคู่ก็พอ', () {
      expect(
        validateHasAnyChannel(
            promptPayId: '', bankName: 'กสิกรไทย', accountNo: '1438323216'),
        isNull,
      );
    });

    test('ไม่มีอะไรเลยถูกปฏิเสธ', () {
      expect(
        validateHasAnyChannel(promptPayId: '', bankName: '', accountNo: ''),
        isNotNull,
      );
    });

    test('ธนาคารกรอกครึ่งเดียวไม่นับเป็นช่องทาง', () {
      expect(
        validateHasAnyChannel(
            promptPayId: '', bankName: 'กสิกรไทย', accountNo: ''),
        isNotNull,
      );
    });

    test('ช่องว่างล้วนไม่นับว่ากรอก', () {
      expect(
        validateHasAnyChannel(
            promptPayId: '   ', bankName: '  ', accountNo: '  '),
        isNotNull,
      );
    });
  });

  group('validateBankPair', () {
    test('เว้นว่างทั้งคู่ผ่าน — หอที่ใช้แต่พร้อมเพย์', () {
      expect(validateBankPair(bankName: '', accountNo: ''), isNull);
    });

    test('กรอกครบทั้งคู่ผ่าน', () {
      expect(
        validateBankPair(bankName: 'กสิกรไทย', accountNo: '1438323216'),
        isNull,
      );
    });

    // แถวที่มีชื่อธนาคารแต่ไม่มีเลขบัญชีคือแถวที่โอนตามไม่ได้จริง
    test('มีชื่อธนาคารแต่ไม่มีเลขบัญชีถูกปฏิเสธ', () {
      expect(
        validateBankPair(bankName: 'กสิกรไทย', accountNo: ''),
        contains('เลขบัญชี'),
      );
    });

    test('มีเลขบัญชีแต่ไม่มีชื่อธนาคารถูกปฏิเสธ', () {
      expect(
        validateBankPair(bankName: '', accountNo: '1438323216'),
        contains('ชื่อธนาคาร'),
      );
    });
  });
}
