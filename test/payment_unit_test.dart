import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/models/picked_image.dart';
import 'package:horplug/services/invoice_service.dart';
import 'package:horplug/services/payment_channel_service.dart';
import 'package:horplug/services/promptpay.dart';
import 'package:horplug/services/tenant_billing_source.dart';
import 'package:horplug/viewmodels/tenant_bills_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
// ignore: implementation_imports
import 'package:promptpay_qrcode_generate/src/crc16.dart';

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

Invoice buildInvoice({
  int dbId = 1,
  String invoiceNo = 'INV-202609-101',
  int roomDbId = 101,
  InvoiceStatus status = InvoiceStatus.unpaid,
  double total = 4000,
}) =>
    Invoice(
      dbId: dbId,
      invoiceNo: invoiceNo,
      roomDbId: roomDbId,
      roomNumber: '101',
      tenantId: 'tenant-uuid',
      tenantName: 'สมชาย ใจดี',
      billingMonth: 9,
      billingYear: 2026,
      roomPrice: 3000,
      electricityUnits: 90,
      electricityCost: total - 3000 - 100,
      waterCost: 100,
      total: total,
      status: status,
      revision: 1,
      dueDate: DateTime(2026, 10, 5),
      issuedAt: DateTime(2026, 9, 28),
    );

PickedImage buildSlip({String extension = 'jpg'}) => PickedImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      extension: extension,
      contentType: 'image/jpeg',
    );

/// true เมื่อ checksum 4 ตัวท้ายของ payload คำนวณซ้ำจากส่วนหน้าแล้วตรงกัน —
/// ตรวจแบบเดียวกับที่ promptPayPayload ยืนยันตัวเองก่อนคืนค่า
bool _hasValidChecksum(String payload) {
  final body = payload.substring(0, payload.length - 4);
  final checksum = payload.substring(payload.length - 4);
  return crc16(body).toRadixString(16).toUpperCase().padLeft(4, '0') ==
      checksum;
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// InvoiceService ปลอมของ Feature 10
///
/// uploadSlip/submitSlip/discardSlip/submitCashPayment/cancelCashPayment ไม่มี
/// ตรรกะของตัวเองให้ทดสอบ (เป็นแค่ storage/RPC call ตรงๆ) จึงถูกแทนทั้งก้อน
/// — บันทึกอาร์กิวเมนต์ที่ถูกเรียกไว้เป็น spy แทน ตรรกะจริงที่ทดสอบในไฟล์นี้คือ
/// [SupabaseTenantBillingSource.submitPaymentSlip] (MD-78) ที่เรียกเมธอดเหล่านี้
/// ตามลำดับ — ตัว uploadSlip/submitSlip เองไม่มีเลข MD ของตัวเอง
class _FakeInvoiceService extends InvoiceService {
  _FakeInvoiceService({
    this.throwOnUpload = false,
    this.throwOnSubmitSlip = false,
    this.throwOnSubmitCash = false,
    this.throwOnCancelCash = false,
  });

  final bool throwOnUpload;
  final bool throwOnSubmitSlip;
  final bool throwOnSubmitCash;
  final bool throwOnCancelCash;

  Invoice? uploadedInvoice;
  PickedImage? uploadedFile;
  int? submittedInvoiceId;
  String? submittedSlipPath;
  String? discardedPath;
  int? cashSubmittedInvoiceId;
  int? cashCancelledInvoiceId;

  @override
  Future<String> uploadSlip({
    required Invoice invoice,
    required PickedImage file,
  }) async {
    if (throwOnUpload) throw const SocketException('Failed host lookup');
    uploadedInvoice = invoice;
    uploadedFile = file;
    return '${invoice.roomDbId}/${invoice.invoiceNo}-1700000000.${file.extension}';
  }

  @override
  Future<void> submitSlip({
    required int invoiceId,
    required String slipPath,
  }) async {
    if (throwOnSubmitSlip) {
      throw PostgrestException(
        message: 'บิลใบนี้ส่งสลิปไม่ได้ในสถานะปัจจุบัน',
      );
    }
    submittedInvoiceId = invoiceId;
    submittedSlipPath = slipPath;
  }

  @override
  Future<void> discardSlip(String path) async {
    discardedPath = path;
  }

  @override
  Future<void> submitCashPayment({required int invoiceId}) async {
    if (throwOnSubmitCash) {
      throw PostgrestException(
        message: 'บิลใบนี้แจ้งชำระไม่ได้ในสถานะปัจจุบัน',
      );
    }
    cashSubmittedInvoiceId = invoiceId;
  }

  @override
  Future<void> cancelCashPayment({required int invoiceId}) async {
    if (throwOnCancelCash) {
      throw PostgrestException(
        message: 'ยกเลิกได้เฉพาะการแจ้งชำระเงินสดที่ยังรอยืนยัน',
      );
    }
    cashCancelledInvoiceId = invoiceId;
  }
}

/// PaymentChannelService ปลอม — รูปแบบเดียวกับ FakePaymentChannelService ใน
/// landlord_profile_unit_test.dart
class _FakePaymentChannelService extends PaymentChannelService {
  _FakePaymentChannelService({this.channel, this.shouldThrow = false});

  final PaymentChannel? channel;
  final bool shouldThrow;

  @override
  Future<PaymentChannel?> fetch({required int dormitoryId}) async {
    if (shouldThrow) throw const SocketException('Failed host lookup');
    return channel;
  }
}

TenantBillsViewModel buildViewModel({
  InvoiceService? invoices,
  PaymentChannelService? channels,
  int? dormitoryId,
}) =>
    TenantBillsViewModel(
      // roomId: null ทำให้ reloadAfterSlip() -> load() จบตั้งแต่ต้นโดยไม่แตะ
      // fetchBillHistory — การทดสอบไฟล์นี้อยู่ที่การส่งชำระ ไม่ใช่การโหลดบิล
      roomId: null,
      dormitoryId: dormitoryId,
      source: SupabaseTenantBillingSource(
        invoiceService: invoices ?? _FakeInvoiceService(),
        paymentChannelService: channels ?? _FakePaymentChannelService(),
      ),
    );

void main() {
  group('Feature 10: Payment', () {
    // -------------------------------------------------------------------
    // promptPayPayload (lib/services/promptpay.dart) is not its own MD entry
    // in the document, so these cases carry no UTC-xx prefix — still real,
    // still run, just not traced through the TCR/TR numbering.
    group('promptPayPayload', () {
      test('builds a valid payload for a 10-digit phone number', () {
        final payload =
            promptPayPayload(promptPayId: '0812345678', amount: 100);

        expect(payload, isNotNull);
        expect(_hasValidChecksum(payload!), isTrue);
      });

      test('builds a valid payload for a 13-digit citizen ID', () {
        final payload =
            promptPayPayload(promptPayId: '1234567890123', amount: 2500);

        expect(payload, isNotNull);
        expect(_hasValidChecksum(payload!), isTrue);
      });

      test('returns null for an ID that is not 10 or 13 digits', () {
        expect(
            promptPayPayload(promptPayId: '12345', amount: 100), isNull);
      });

      test('returns null for an ID containing non-digit characters', () {
        expect(
            promptPayPayload(promptPayId: '081-234-5678', amount: 100),
            isNull);
      });

      test(
          'repairs the checksum for amounts that break the underlying '
          'package (฿0.10–฿0.14)', () {
        for (final amount in [0.10, 0.11, 0.12, 0.13, 0.14]) {
          final payload =
              promptPayPayload(promptPayId: '0812345678', amount: amount);

          expect(payload, isNotNull, reason: 'amount=$amount');
          expect(_hasValidChecksum(payload!), isTrue, reason: 'amount=$amount');
        }
      });

      test('trims surrounding whitespace from the ID', () {
        final payload =
            promptPayPayload(promptPayId: '  0812345678  ', amount: 100);

        expect(payload, isNotNull);
      });
    });

    // -------------------------------------------------------------------
    group('UTC-77 fetchPaymentChannel', () {
      test('UTC-77-TC-01 returns the dormitory\'s configured channel',
          () async {
        final channel = const PaymentChannel(
          accountName: 'พงษ์พิพัฒน์ กาละสุข',
          promptPayId: '0812345678',
          bankName: 'ธนาคารกรุงไทย',
          accountNo: '6794352508',
        );
        final viewModel = buildViewModel(
          channels: _FakePaymentChannelService(channel: channel),
          dormitoryId: 1,
        );

        await viewModel.loadPaymentChannel(1);

        expect(viewModel.paymentChannel, same(channel));
      });

      test('UTC-77-TC-02 leaves paymentChannel null when not configured',
          () async {
        final viewModel = buildViewModel(dormitoryId: 1);

        await viewModel.loadPaymentChannel(1);

        expect(viewModel.paymentChannel, isNull);
      });

      test(
          'UTC-77-TC-03 swallows a network failure instead of crashing the '
          'screen', () async {
        final viewModel = buildViewModel(
          channels: _FakePaymentChannelService(shouldThrow: true),
          dormitoryId: 1,
        );

        await viewModel.loadPaymentChannel(1);

        expect(viewModel.paymentChannel, isNull);
      });
    });

    // -------------------------------------------------------------------
    // uploadSlip and submitSlip (the raw RPC call) are not their own MD
    // entries — MD-78 is submitPaymentSlip, the real orchestration that
    // sequences them with rollback on failure, so their call contracts are
    // verified here instead of independently.
    group('UTC-78 submitPaymentSlip', () {
      test(
          'UTC-78-TC-01 uploads the slip, attaches it, and reports success',
          () async {
        final invoices = _FakeInvoiceService();
        final viewModel = buildViewModel(invoices: invoices);
        final bill = buildInvoice(dbId: 7, invoiceNo: 'INV-202609-101');
        final slip = buildSlip();

        final result = await viewModel.submitSlip(bill: bill, slip: slip);

        expect(result.success, isTrue);
        expect(result.message, 'ส่งสลิปแล้ว รอเจ้าของหอตรวจสอบ');
        expect(invoices.uploadedInvoice, same(bill));
        expect(invoices.uploadedFile, same(slip));
        expect(invoices.submittedInvoiceId, 7);
        expect(invoices.submittedSlipPath,
            '101/INV-202609-101-1700000000.jpg');
        expect(invoices.discardedPath, isNull);
      });

      test(
          'UTC-78-TC-02 discards the uploaded file and rethrows when '
          'attaching fails', () async {
        final invoices = _FakeInvoiceService(throwOnSubmitSlip: true);
        final viewModel = buildViewModel(invoices: invoices);
        final bill = buildInvoice(dbId: 7, invoiceNo: 'INV-202609-101');

        final result =
            await viewModel.submitSlip(bill: bill, slip: buildSlip());

        expect(result.success, isFalse);
        expect(result.message,
            'ส่งสลิปไม่สำเร็จ: บิลใบนี้ส่งสลิปไม่ได้ในสถานะปัจจุบัน');
        expect(invoices.discardedPath,
            '101/INV-202609-101-1700000000.jpg');
      });

      test(
          'UTC-78-TC-03 never attempts to attach or discard when the upload '
          'itself fails', () async {
        final invoices = _FakeInvoiceService(throwOnUpload: true);
        final viewModel = buildViewModel(invoices: invoices);

        final result = await viewModel.submitSlip(
          bill: buildInvoice(),
          slip: buildSlip(),
        );

        expect(result.success, isFalse);
        expect(result.message, startsWith('ส่งสลิปไม่สำเร็จ:'));
        expect(invoices.submittedInvoiceId, isNull);
        expect(invoices.discardedPath, isNull);
      });
    });

    // -------------------------------------------------------------------
    group('UTC-79 discardSlip', () {
      test(
          'UTC-79-TC-01 is called with the exact path that was just '
          'uploaded, not a reconstructed one', () async {
        final invoices = _FakeInvoiceService(throwOnSubmitSlip: true);
        final viewModel = buildViewModel(invoices: invoices);

        await viewModel.submitSlip(
          bill: buildInvoice(dbId: 9, invoiceNo: 'INV-202609-205'),
          slip: buildSlip(extension: 'png'),
        );

        expect(invoices.discardedPath,
            '101/INV-202609-205-1700000000.png');
      });
    });

    // -------------------------------------------------------------------
    group('UTC-80 submitCashPayment', () {
      test('UTC-80-TC-01 records the declaration and reports success',
          () async {
        final invoices = _FakeInvoiceService();
        final viewModel = buildViewModel(invoices: invoices);
        final bill = buildInvoice(dbId: 12);

        final result = await viewModel.submitCash(bill: bill);

        expect(result.success, isTrue);
        expect(result.message,
            'แจ้งชำระเงินสดแล้ว รอเจ้าของหอยืนยันการรับเงิน');
        expect(invoices.cashSubmittedInvoiceId, 12);
      });

      test(
          'UTC-80-TC-02 reports the real reason when the bill is no longer '
          'ค้างชำระ', () async {
        final viewModel = buildViewModel(
          invoices: _FakeInvoiceService(throwOnSubmitCash: true),
        );

        final result = await viewModel.submitCash(bill: buildInvoice());

        expect(result.success, isFalse);
        expect(result.message,
            'แจ้งชำระเงินสดไม่สำเร็จ: บิลใบนี้แจ้งชำระไม่ได้ในสถานะปัจจุบัน');
      });
    });

    // -------------------------------------------------------------------
    group('UTC-81 cancelCashPayment', () {
      test('UTC-81-TC-01 withdraws the declaration and reports success',
          () async {
        final invoices = _FakeInvoiceService();
        final viewModel = buildViewModel(invoices: invoices);
        final bill = buildInvoice(dbId: 15);

        final result = await viewModel.cancelCash(bill: bill);

        expect(result.success, isTrue);
        expect(result.message, 'ยกเลิกการแจ้งชำระเงินสดแล้ว');
        expect(invoices.cashCancelledInvoiceId, 15);
      });

      test(
          'UTC-81-TC-02 reports the real reason when there is no pending '
          'cash declaration to cancel', () async {
        final viewModel = buildViewModel(
          invoices: _FakeInvoiceService(throwOnCancelCash: true),
        );

        final result = await viewModel.cancelCash(bill: buildInvoice());

        expect(result.success, isFalse);
        expect(result.message,
            'ยกเลิกไม่สำเร็จ: ยกเลิกได้เฉพาะการแจ้งชำระเงินสดที่ยังรอยืนยัน');
      });
    });
  });
}
