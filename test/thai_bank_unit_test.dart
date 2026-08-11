import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/thai_bank.dart';

void main() {
  group('ThaiBank.fromName', () {
    test('ชื่อที่ตรงกับรายการหาเจอ', () {
      expect(ThaiBank.fromName('ธนาคารกสิกรไทย'), ThaiBank.kbank);
      expect(ThaiBank.fromName('ธนาคารไทยพาณิชย์'), ThaiBank.scb);
      expect(ThaiBank.fromName('ธนาคารออมสิน'), ThaiBank.gsb);
    });

    test('ตัดช่องว่างหัวท้ายก่อนเทียบ', () {
      expect(ThaiBank.fromName('  ธนาคารกรุงเทพ  '), ThaiBank.bbl);
    });

    // หอที่ตั้งค่าไว้ตอนช่องนี้ยังพิมพ์เองได้ อาจมีค่าที่ไม่ตรงรายการ · การเดา
    // ธนาคารที่ใกล้เคียงที่สุดให้แปลว่าเงินอาจถูกโอนผิดที่ คืน null แล้วให้
    // หน้าจอบอกว่าค่าเดิมคืออะไรปลอดภัยกว่า
    test('ชื่อที่ไม่ตรงรายการคืน null ไม่เดาให้', () {
      expect(ThaiBank.fromName('กสิกร'), isNull);
      expect(ThaiBank.fromName('KBank'), isNull);
      expect(ThaiBank.fromName('ธนาคารกสิกร'), isNull);
    });

    test('ค่าว่างคืน null', () {
      expect(ThaiBank.fromName(null), isNull);
      expect(ThaiBank.fromName(''), isNull);
      expect(ThaiBank.fromName('   '), isNull);
    });
  });

  group('รายการธนาคาร', () {
    test('ทุกตัวมีชื่อแสดงผลที่ไม่ว่าง', () {
      for (final bank in ThaiBank.values) {
        expect(bank.displayName.trim(), isNotEmpty,
            reason: '${bank.name} ไม่มีชื่อแสดงผล');
      }
    });

    // ชื่อซ้ำทำให้ fromName คืนตัวแรกเสมอ แล้ว dropdown จะเลือกผิดตัวเงียบๆ
    test('ไม่มีชื่อซ้ำกัน', () {
      final names = ThaiBank.values.map((bank) => bank.displayName).toSet();
      expect(names, hasLength(ThaiBank.values.length));
    });

    test('ทุกชื่อขึ้นต้นด้วยคำว่าธนาคาร เพื่อให้ผู้เช่าอ่านแล้วรู้ทันที', () {
      for (final bank in ThaiBank.values) {
        expect(bank.displayName.startsWith('ธนาคาร'), isTrue,
            reason: '${bank.displayName} ไม่ขึ้นต้นด้วย "ธนาคาร"');
      }
    });

    test('ชื่อที่แสดงผลวนกลับมาเป็นตัวเดิมได้ทุกตัว', () {
      for (final bank in ThaiBank.values) {
        expect(ThaiBank.fromName(bank.displayName), bank);
      }
    });
  });
}
