import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_service.dart';
import 'package:horplug/viewmodels/invoice_actions_view_model.dart';

Invoice _invoice({
  InvoiceStatus status = InvoiceStatus.pending,
  String invoiceNo = 'INV-202608-301',
}) =>
    Invoice(
      dbId: 1,
      invoiceNo: invoiceNo,
      roomDbId: 7,
      roomNumber: '301',
      tenantName: 'สมชาย ใจดี',
      billingMonth: 8,
      billingYear: 2026,
      roomPrice: 3500,
      electricityUnits: 142,
      electricityCost: 1136,
      waterCost: 404,
      cleaningFee: 200,
      total: 5240,
      status: status,
      dueDate: DateTime(2026, 9, 5),
      issuedAt: DateTime(2026, 9, 1),
      slipUrl: 'slips/301.jpg',
    );

/// InvoiceService ปลอมที่ไม่แตะเครือข่ายเลย
///
/// สืบทอดได้เพราะ `SupabaseService.client` เป็น getter แล้ว — ตอนเป็น field
/// initializer การสร้าง InvoiceService ในเทสต์จะ assert ทันทีที่ Supabase ยัง
/// ไม่ได้ initialize ซึ่งเป็นเหตุผลที่ชั้น service ไม่เคยถูกทดสอบมาก่อน
class _FakeInvoiceService extends InvoiceService {
  _FakeInvoiceService({this.error, this.reissued, this.cardError});

  /// error ที่จะโยนออกมาจากทุกเมธอด — null แปลว่าสำเร็จ
  final Object? error;

  /// error เฉพาะของ [sendInvoiceCard] — แยกจาก [error] เพราะเคสจริงคือบิลออก
  /// สำเร็จแต่การ์ดในแชทล้ม (ฐานข้อมูลยังไม่รู้จัก message_type 'invoice')
  final Object? cardError;

  /// ผลของ reissueInvoice — null แปลว่าไม่มีร่างบิลให้ออกใบแทน
  final Invoice? reissued;

  final List<String> calls = [];

  @override
  Future<void> approveSlip({required Invoice invoice}) async {
    calls.add('approveSlip');
    if (error != null) throw error!;
  }

  @override
  Future<void> rejectSlip({
    required Invoice invoice,
    required String reason,
  }) async {
    calls.add('rejectSlip:$reason');
    if (error != null) throw error!;
  }

  @override
  Future<void> markPaidByLandlord({
    required Invoice invoice,
    required PaymentMethod method,
  }) async {
    calls.add('markPaidByLandlord:${method.name}');
    if (error != null) throw error!;
  }

  @override
  Future<void> voidInvoice({
    required Invoice invoice,
    required String reason,
  }) async {
    calls.add('voidInvoice:$reason');
    if (error != null) throw error!;
  }

  @override
  Future<Invoice?> reissueInvoice({
    required Invoice voided,
    required int dormitoryId,
  }) async {
    calls.add('reissueInvoice');
    if (error != null) throw error!;
    return reissued;
  }

  @override
  Future<void> sendInvoiceCard({required Invoice invoice}) async {
    calls.add('sendInvoiceCard:${invoice.invoiceNo}');
    if (cardError != null) throw cardError!;
    if (error != null) throw error!;
  }
}

InvoiceActionsViewModel _viewModel(
  _FakeInvoiceService service, {
  Invoice? invoice,
}) =>
    InvoiceActionsViewModel(
      invoice: invoice ?? _invoice(),
      dormitoryId: 1,
      service: service,
    );

void main() {
  group('การกระทำที่สำเร็จ', () {
    test('อนุมัติสลิปคืนข้อความที่มีเลขที่บิลอยู่ด้วย', () async {
      final service = _FakeInvoiceService();
      final result = await _viewModel(service).approve();

      expect(result.success, isTrue);
      expect(result.message, contains('INV-202608-301'));
      expect(service.calls, ['approveSlip']);
    });

    test('ปฏิเสธสลิปตัดช่องว่างหัวท้ายของเหตุผลก่อนส่งให้ service', () async {
      final service = _FakeInvoiceService();
      final result = await _viewModel(service).reject('  สลิปเบลอ  ');

      expect(result.success, isTrue);
      expect(service.calls, ['rejectSlip:สลิปเบลอ']);
    });

    test('ยกเลิกบิลคืนข้อความที่มีเลขที่บิล', () async {
      final service = _FakeInvoiceService();
      final result = await _viewModel(service).voidBill('จดมิเตอร์ผิด');

      expect(result.success, isTrue);
      expect(result.message, contains('INV-202608-301'));
      expect(service.calls, ['voidInvoice:จดมิเตอร์ผิด']);
    });

    test('ส่งบิลเข้าแชทเรียก sendInvoiceCard ไม่ใช่ postIssueNotices',
        () async {
      // postIssueNotices ข้ามใบที่เคยแจ้งแล้ว การทวงจึงต้องไปทางอื่น ไม่งั้น
      // ปุ่มนี้จะกดแล้วไม่มีอะไรเกิดขึ้นกับบิลทุกใบที่ถูกแจ้งตอนออกไปแล้ว
      // ซึ่งก็คือบิลทุกใบที่มีอยู่
      final service = _FakeInvoiceService();
      final result = await _viewModel(service).sendCardToChat();

      expect(result.success, isTrue);
      expect(service.calls, ['sendInvoiceCard:INV-202608-301']);
    });

    // เจ้าของหอบันทึกเองสำหรับเงินที่จ่ายกันนอกแอป โดยผู้เช่าไม่ได้แจ้งมาก่อน
    test('บันทึกว่าชำระแล้วส่งวิธีรับเงินไปด้วย ไม่ใช่แค่เปลี่ยนสถานะ',
        () async {
      final service = _FakeInvoiceService();
      final result = await _viewModel(
        service,
        invoice: _invoice(status: InvoiceStatus.unpaid),
      ).markPaid(PaymentMethod.cash);

      expect(result.success, isTrue);
      expect(service.calls, ['markPaidByLandlord:cash']);
      expect(result.message, contains('INV-202608-301'));
      expect(result.message, contains('เงินสด'));
    });

    test('บันทึกว่าชำระแล้วแบบเงินโอน บอกวิธีที่ถูกในข้อความ', () async {
      final service = _FakeInvoiceService();
      final result = await _viewModel(
        service,
        invoice: _invoice(status: InvoiceStatus.unpaid),
      ).markPaid(PaymentMethod.transfer);

      expect(service.calls, ['markPaidByLandlord:transfer']);
      expect(result.message, contains('เงินโอน'));
    });

    test('ส่งบิลเข้าแชทไม่แตะสถานะบิล', () async {
      final service = _FakeInvoiceService();
      final viewModel = _viewModel(service);

      await viewModel.sendCardToChat();

      expect(viewModel.invoice.status, InvoiceStatus.pending);
      expect(viewModel.isBusy, isFalse);
    });
  });

  group('service โยน error', () {
    test('คืน ActionResult ที่ล้มเหลว ไม่ปล่อย exception ทะลุขึ้นไปถึง widget',
        () async {
      final service = _FakeInvoiceService(error: Exception('เน็ตหลุด'));
      final result = await _viewModel(service).approve();

      expect(result.success, isFalse);
      expect(result.message, contains('อนุมัติไม่สำเร็จ'));
      expect(result.message, contains('เน็ตหลุด'));
    });

    test('isBusy ถูกปลดแม้การเรียกจะล้มเหลว ไม่ค้างปุ่มไว้ตลอดกาล', () async {
      final service = _FakeInvoiceService(error: Exception('เน็ตหลุด'));
      final viewModel = _viewModel(service);

      await viewModel.voidBill('จดมิเตอร์ผิด');

      expect(viewModel.isBusy, isFalse);
    });
  });

  group('ออกใบแทนหลังยกเลิก', () {
    test('สำเร็จ — ข้อความเล่าทั้งการยกเลิกและเลขที่ใบใหม่', () async {
      final service = _FakeInvoiceService(
        reissued: _invoice(invoiceNo: 'INV-202608-301-R2'),
      );
      final result = await _viewModel(service).reissue();

      expect(result.success, isTrue);
      expect(result.message, contains('INV-202608-301'));
      expect(result.message, contains('INV-202608-301-R2'));
    });

    // reissueInvoice คืน null แทนที่จะ throw เมื่อห้องไม่มีในร่างบิลงวดนี้
    // ถ้าไม่แยกเคสนี้ออกมา แผ่นจะปิดไปเงียบๆ โดยไม่มีอะไรบอกว่าทำไมใบใหม่
    // ไม่โผล่ — ซึ่งเป็นสิ่งที่รีวิว Task 7+8 ชี้ไว้
    test('คืน null — บอกว่ายกเลิกสำเร็จแล้ว แต่ออกใบแทนไม่ได้ พร้อมเหตุผล',
        () async {
      final service = _FakeInvoiceService();
      final result = await _viewModel(service).reissue();

      expect(result.success, isFalse);
      expect(result.message, contains('ยกเลิกบิล INV-202608-301 แล้ว'));
      expect(result.message, contains('ออกใบแทนไม่ได้'));
      expect(result.message, contains('ยังไม่ได้จดมิเตอร์'));
    });

    test('โยน error — ยังต้องบอกว่าการยกเลิกสำเร็จไปแล้ว', () async {
      final service = _FakeInvoiceService(error: Exception('ชนคีย์ซ้ำ'));
      final result = await _viewModel(service).reissue();

      expect(result.success, isFalse);
      expect(result.message, contains('ยกเลิกบิล INV-202608-301 แล้ว'));
      expect(result.message, contains('ออกใบแทนไม่สำเร็จ'));
      expect(result.message, contains('ชนคีย์ซ้ำ'));
    });

    test('ใบแทนออกแล้ว ต้องส่งการ์ดเข้าแชทต่อเสมอ', () async {
      final service = _FakeInvoiceService(
        reissued: _invoice(invoiceNo: 'INV-202608-301-R2'),
      );

      await _viewModel(service).reissue();

      expect(service.calls,
          ['reissueInvoice', 'sendInvoiceCard:INV-202608-301-R2']);
    });

    // เคสจริงที่เจอบนฐานข้อมูลที่ยังไม่รู้จัก message_type 'invoice': ใบแทนออก
    // สำเร็จ การ์ดในแชทตกด้วย 23514 แล้วเดิมถูกกลืนหายทั้งก้อน เจ้าของหอจึงเชื่อ
    // ว่าผู้เช่าได้รับการ์ดแล้วทั้งที่ไม่มีอะไรถูกส่งเลย
    test('การ์ดในแชทล้ม — ยังนับว่าออกใบแทนสำเร็จ แต่ต้องบอกว่าการ์ดไม่ได้ส่ง',
        () async {
      final service = _FakeInvoiceService(
        reissued: _invoice(invoiceNo: 'INV-202608-301-R2'),
        cardError: Exception('ส่งข้อความไม่ได้'),
      );

      final result = await _viewModel(service).reissue();

      expect(result.success, isTrue);
      expect(result.message, contains('INV-202608-301-R2'));
      expect(result.message, contains('ส่งการ์ดเข้าแชทไม่สำเร็จ'));
      expect(result.message, contains('ส่งบิลเข้าแชท'));
    });
  });
}
