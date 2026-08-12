import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/models/picked_image.dart';
import 'package:horplug/services/tenant_billing_source.dart';
import 'package:horplug/viewmodels/action_result.dart';
import 'package:horplug/viewmodels/tenant_slip_submission.dart';

Invoice _bill() => Invoice(
      dbId: 1,
      invoiceNo: 'INV-202608-301',
      roomDbId: 7,
      roomNumber: '301',
      tenantName: 'สมชาย ใจดี',
      billingMonth: 8,
      billingYear: 2026,
      total: 5240,
      status: InvoiceStatus.unpaid,
      dueDate: DateTime(2026, 9, 5),
      issuedAt: DateTime(2026, 9, 1),
    );

class _FakeBillingSource implements TenantBillingSource {
  _FakeBillingSource({this.result, this.error, this.channel});

  final ActionResult? result;
  final Object? error;
  final PaymentChannel? channel;

  int submitCalls = 0;

  @override
  Future<ActionResult> submitPaymentSlip({
    required Invoice bill,
    required PickedImage slip,
  }) async {
    submitCalls++;
    if (error != null) throw error!;
    return result ?? const ActionResult(success: true, message: 'ส่งสลิปแล้ว');
  }

  @override
  Future<PaymentChannel?> fetchPaymentChannel({
    required int dormitoryId,
  }) async {
    if (error != null) throw error!;
    return channel;
  }

  @override
  Future<ActionResult> submitCashPayment({required Invoice bill}) async {
    submitCalls++;
    if (error != null) throw error!;
    return result ??
        const ActionResult(success: true, message: 'แจ้งชำระเงินสดแล้ว');
  }

  @override
  Future<ActionResult> cancelCashPayment({required Invoice bill}) async {
    if (error != null) throw error!;
    return const ActionResult(success: true, message: 'ยกเลิกแล้ว');
  }

  @override
  Future<Invoice?> fetchCurrentBill({
    required int roomDbId,
    required int month,
    required int year,
  }) async =>
      null;

  @override
  Future<List<Invoice>> fetchBillHistory({
    required int roomDbId,
    int monthCount = 6,
  }) async =>
      const [];
}

/// ตัวแทนของ ViewModel ทั้งสามตัวที่ผสม mixin นี้ — แท็บบิล แดชบอร์ด และแชท
class _Host extends ChangeNotifier with TenantSlipSubmission {
  _Host(this._source);

  final TenantBillingSource _source;
  int reloads = 0;

  @override
  TenantBillingSource get billingSource => _source;

  @override
  Future<void> reloadAfterSlip() async => reloads++;
}

void main() {
  final slip = PickedImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    extension: 'jpg',
    contentType: 'image/jpeg',
  );

  group('submitSlip', () {
    test('สำเร็จแล้วรีเฟรชหน้าจอที่ผสม mixin นี้', () async {
      final host = _Host(_FakeBillingSource());
      final result = await host.submitSlip(bill: _bill(), slip: slip);

      expect(result.success, isTrue);
      expect(host.reloads, 1);
    });

    test('ล้มแล้วไม่รีเฟรช — สถานะเดิมบนจอยังตรงกับความจริง', () async {
      final host = _Host(_FakeBillingSource(
        result: const ActionResult(success: false, message: 'ไฟล์ใหญ่เกินไป'),
      ));
      final result = await host.submitSlip(bill: _bill(), slip: slip);

      expect(result.success, isFalse);
      expect(host.reloads, 0);
    });

    test('source โยน error แล้วได้ ActionResult ไม่ใช่ exception', () async {
      final host = _Host(_FakeBillingSource(error: Exception('เน็ตหลุด')));
      final result = await host.submitSlip(bill: _bill(), slip: slip);

      expect(result.success, isFalse);
      expect(result.message, contains('ส่งสลิปไม่สำเร็จ'));
      expect(result.message, contains('เน็ตหลุด'));
    });

    // ก่อนรวมเป็น mixin สำเนาของแดชบอร์ดไม่เคยตั้ง isSubmittingSlip เลย และ
    // ไม่ได้ประกาศฟิลด์นั้นด้วยซ้ำ ทั้งที่อีกสองหน้าจอมี
    test('isSubmittingSlip ถูกปลดทั้งตอนสำเร็จและตอนล้ม', () async {
      final ok = _Host(_FakeBillingSource());
      await ok.submitSlip(bill: _bill(), slip: slip);
      expect(ok.isSubmittingSlip, isFalse);

      final failed = _Host(_FakeBillingSource(error: Exception('เน็ตหลุด')));
      await failed.submitSlip(bill: _bill(), slip: slip);
      expect(failed.isSubmittingSlip, isFalse);
    });
  });

  group('loadPaymentChannel', () {
    test('หอที่ตั้งค่าไว้แล้วได้ช่องทางกลับมา', () async {
      final host = _Host(_FakeBillingSource(
        channel: const PaymentChannel(
          promptPayId: '0812345678',
          bankName: 'ธนาคารกสิกรไทย',
          accountNo: '1234567890',
          accountName: 'สมหญิง เจ้าของหอ',
        ),
      ));

      await host.loadPaymentChannel(1);

      expect(host.paymentChannel?.accountNo, '1234567890');
      expect(host.paymentChannel?.hasPromptPay, isTrue);
      expect(host.paymentChannel?.hasBankAccount, isTrue);
    });

    test('หอที่ตั้งแต่พร้อมเพย์ ไม่มีเลขบัญชี ก็ยังใช้งานได้', () async {
      final host = _Host(_FakeBillingSource(
        channel: const PaymentChannel(
          promptPayId: '0812345678',
          accountName: 'สมหญิง เจ้าของหอ',
        ),
      ));

      await host.loadPaymentChannel(1);

      expect(host.paymentChannel?.hasPromptPay, isTrue);
      expect(host.paymentChannel?.hasBankAccount, isFalse);
    });

    // เดิม fetchPaymentChannel คืนเลขบัญชี hardcode ให้ทุกหอ ตอนนี้หอที่ยังไม่ได้
    // ตั้งค่าต้องได้ null เพื่อให้แผ่นชำระเงินบอกตรงๆ ว่ายังไม่มีข้อมูล
    // ไม่ใช่แสดงเลขบัญชีของคนอื่น
    test('หอที่ยังไม่ได้ตั้งค่าได้ null ไม่ใช่ค่าตั้งต้นของใครสักคน', () async {
      final host = _Host(_FakeBillingSource());

      await host.loadPaymentChannel(1);

      expect(host.paymentChannel, isNull);
    });

    test('โหลดล้มไม่พาทั้งหน้าจอล้ม แค่ไม่มีช่องทางให้ดู', () async {
      final host = _Host(_FakeBillingSource(error: Exception('เน็ตหลุด')));

      await host.loadPaymentChannel(1);

      expect(host.paymentChannel, isNull);
    });

    test('ผู้เช่าที่ยังไม่มีหอ ไม่ยิง query เลย', () async {
      final source = _FakeBillingSource(error: Exception('ต้องไม่ถูกเรียก'));
      final host = _Host(source);

      await host.loadPaymentChannel(null);

      expect(host.paymentChannel, isNull);
    });
  });
}
