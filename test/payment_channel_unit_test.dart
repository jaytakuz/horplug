import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/models/thai_bank.dart';
import 'package:horplug/services/payment_channel_service.dart';
import 'package:horplug/viewmodels/payment_channel_view_model.dart';

/// PaymentChannelService ปลอมที่ไม่แตะเครือข่าย
class _FakeChannelService implements PaymentChannelService {
  _FakeChannelService({this.stored});

  final PaymentChannel? stored;
  PaymentChannel? saved;

  @override
  Future<PaymentChannel?> fetch({required int dormitoryId}) async => stored;

  @override
  Future<void> save({
    required int dormitoryId,
    required PaymentChannel channel,
  }) async {
    saved = channel;
  }
}

Future<PaymentChannelViewModel> _viewModel({PaymentChannel? stored}) async {
  final viewModel = PaymentChannelViewModel(
    dormitoryId: 1,
    service: _FakeChannelService(stored: stored),
  );
  await viewModel.load();
  return viewModel;
}

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

  group('เลือกธนาคารจากรายการ', () {
    test('เลือกแล้วเก็บเป็นชื่อเต็ม', () async {
      final viewModel = await _viewModel();

      viewModel.selectBank(ThaiBank.kbank);

      expect(viewModel.bankName, 'ธนาคารกสิกรไทย');
      expect(viewModel.selectedBank, ThaiBank.kbank);
    });

    test('เลือก "ไม่ระบุ" ล้างค่าออก', () async {
      final viewModel = await _viewModel();
      viewModel.selectBank(ThaiBank.scb);

      viewModel.selectBank(null);

      expect(viewModel.bankName, isEmpty);
      expect(viewModel.selectedBank, isNull);
    });

    test('ค่าที่เก็บไว้แล้วถูกจับคู่กับรายการตอนโหลด', () async {
      final viewModel = await _viewModel(
        stored: const PaymentChannel(
          accountName: 'สมหญิง เจ้าของหอ',
          bankName: 'ธนาคารกรุงไทย',
          accountNo: '1234567890',
        ),
      );

      expect(viewModel.selectedBank, ThaiBank.ktb);
      expect(viewModel.hasUnlistedBank, isFalse);
    });

    // หอที่ตั้งค่าไว้ตอนช่องนี้ยังพิมพ์เองได้ ต้องเห็นค่าเดิมของตัวเอง
    // ไม่ใช่ช่องว่างที่ทำเหมือนไม่เคยกรอกอะไรไว้
    test('ค่าเดิมที่ไม่อยู่ในรายการถูกทำเครื่องหมายไว้ ไม่ถูกกลืนหาย', () async {
      final viewModel = await _viewModel(
        stored: const PaymentChannel(
          accountName: 'สมหญิง เจ้าของหอ',
          bankName: 'กสิกร',
          accountNo: '1234567890',
        ),
      );

      expect(viewModel.selectedBank, isNull);
      expect(viewModel.hasUnlistedBank, isTrue);
      expect(viewModel.bankName, 'กสิกร');
    });

    test('หอที่ไม่ได้ตั้งชื่อธนาคารไว้ ไม่ถือว่าเป็นค่านอกรายการ', () async {
      final viewModel = await _viewModel();

      expect(viewModel.hasUnlistedBank, isFalse);
    });
  });

  group('ยอดในคิวอาร์ตัวอย่าง', () {
    test('ปรับเป็นยอดที่กรอกได้', () async {
      final viewModel = await _viewModel();

      viewModel.setPreviewAmount('1');

      expect(viewModel.previewAmount, 1);
    });

    test('รับทศนิยมและตัวคั่นหลักพัน', () async {
      final viewModel = await _viewModel();

      viewModel.setPreviewAmount('1,250.75');

      expect(viewModel.previewAmount, 1250.75);
    });

    // ยอด 0 หรือติดลบสร้าง payload ที่ไม่มี tag 54 ซึ่งเป็นคิวอาร์คนละแบบกับที่
    // ผู้เช่าจะเห็นจริง — การทดสอบด้วยของที่ไม่เหมือนของจริงไม่ได้พิสูจน์อะไร
    // คิวอาร์ตัวอย่างโอนได้จริง · ยอดที่ใช้ไม่ได้ต้องทำให้ไม่มีคิวอาร์ ไม่ใช่
    // เงียบๆ กลับไปใช้ ฿1,234.56 ซึ่งจะทำให้ช่องกรอกกับคิวอาร์บอกยอดคนละอย่าง
    // แล้วคนที่สแกนระหว่างพิมพ์ก็โอนยอดที่ไม่ได้ตั้งใจ
    test('ยอดที่ใช้ไม่ได้ทำให้ไม่มีคิวอาร์ ไม่ใช่คิวอาร์ยอดอื่น', () async {
      final viewModel = await _viewModel();
      viewModel.update(promptPayId: '0812345678');

      for (final input in ['0', '-5', '', 'abc']) {
        viewModel.setPreviewAmount(input);
        expect(viewModel.previewAmount, isNull,
            reason: 'ยอด "$input" ไม่ควรถูกใช้');
        expect(viewModel.previewPayload, isNull,
            reason: 'ยอด "$input" ไม่ควรมีคิวอาร์ให้สแกน');
      }

      // เบอร์ยังถูกต้องอยู่ ช่องกรอกยอดจึงต้องอยู่ต่อให้พิมพ์ใหม่ได้
      expect(viewModel.canPreviewQr, isTrue);
    });

    test('คิวอาร์ตัวอย่างฝังยอดที่ปรับไว้จริง', () async {
      final viewModel = await _viewModel();
      viewModel.update(promptPayId: '0812345678');

      viewModel.setPreviewAmount('1');

      expect(viewModel.previewPayload, contains('54041.00'));
    });

    test('ยังไม่กรอกเบอร์พร้อมเพย์ก็ยังไม่มีคิวอาร์', () async {
      final viewModel = await _viewModel();

      viewModel.setPreviewAmount('100');

      expect(viewModel.previewPayload, isNull);
    });
  });
}
