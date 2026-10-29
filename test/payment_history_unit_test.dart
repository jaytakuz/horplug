import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/models/picked_image.dart';
import 'package:horplug/services/invoice_pdf.dart';
import 'package:horplug/services/promptpay.dart';
import 'package:horplug/services/tenant_billing_source.dart';
import 'package:horplug/viewmodels/action_result.dart';
import 'package:horplug/viewmodels/tenant_bills_view_model.dart';

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

Invoice buildBill({
  int dbId = 6,
  String invoiceNo = 'INV-202609-104',
  int billingMonth = 9,
  int billingYear = 2026,
  double total = 3820,
  InvoiceStatus status = InvoiceStatus.unpaid,
  PaymentMethod? paymentMethod,
  DateTime? paidAt,
}) =>
    Invoice(
      dbId: dbId,
      invoiceNo: invoiceNo,
      roomDbId: 104,
      roomNumber: '104',
      tenantName: 'สมใจ ใฝ่ดี',
      billingMonth: billingMonth,
      billingYear: billingYear,
      roomPrice: 3000,
      electricityUnits: 90,
      electricityCost: 720,
      waterCost: 100,
      total: total,
      status: status,
      paymentMethod: paymentMethod,
      paidAt: paidAt,
      dueDate: DateTime(billingYear, billingMonth + 1, 5),
      issuedAt: DateTime(billingYear, billingMonth, 28),
    );

const promptPayChannel = PaymentChannel(
  accountName: 'สมหญิง เจ้าของหอ',
  promptPayId: '0898765432',
  bankName: 'ธนาคารกสิกรไทย',
  accountNo: '1234567890',
);

/// ประวัติบิลของห้อง 104 ตามที่ MD-44 คืนมา: 6 งวดล่าสุด เรียงใหม่ไปเก่า
/// ไม่มีใบที่ถูกยกเลิก (INV-202607-104 ถูกแทนด้วย -R2 แล้ว)
List<Invoice> room104History() => [
      buildBill(dbId: 6, invoiceNo: 'INV-202609-104', billingMonth: 9),
      buildBill(
        dbId: 7,
        invoiceNo: 'INV-202608-104',
        billingMonth: 8,
        total: 3880,
        status: InvoiceStatus.paid,
      ),
      buildBill(
        dbId: 9,
        invoiceNo: 'INV-202607-104-R2',
        billingMonth: 7,
        total: 3660,
        status: InvoiceStatus.paid,
      ),
      buildBill(
        dbId: 10,
        invoiceNo: 'INV-202606-104',
        billingMonth: 6,
        total: 3620,
        status: InvoiceStatus.pending,
        paymentMethod: PaymentMethod.cash,
      ),
      buildBill(
        dbId: 11,
        invoiceNo: 'INV-202605-104',
        billingMonth: 5,
        total: 3540,
        status: InvoiceStatus.pending,
        paymentMethod: PaymentMethod.transfer,
      ),
      buildBill(
        dbId: 12,
        invoiceNo: 'INV-202604-104',
        billingMonth: 4,
        total: 3500,
      ),
    ];

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// แหล่งข้อมูลบิลปลอมของแท็บบิล — นับจำนวนครั้งที่ถูกเรียก และหน่วงคำตอบไว้ได้
/// เพื่อตรวจสภาพระหว่างที่กำลังรีเฟรช
class _FakeHistorySource implements TenantBillingSource {
  _FakeHistorySource({
    this.throwOnHistory = false,
    this.throwOnChannel = false,
  });

  final List<Invoice> history = room104History();
  final bool throwOnHistory;
  final bool throwOnChannel;

  /// ตั้งค่าไว้เมื่อต้องการให้การโหลดค้างจนกว่าเทสต์จะปล่อย
  Completer<void>? gate;

  int historyCallCount = 0;
  int channelCallCount = 0;
  int? requestedMonthCount;

  @override
  Future<List<Invoice>> fetchBillHistory({
    required int roomDbId,
    int monthCount = 6,
  }) async {
    historyCallCount++;
    requestedMonthCount = monthCount;
    if (gate != null) await gate!.future;
    if (throwOnHistory) throw const SocketException('Failed host lookup');
    return history;
  }

  @override
  Future<PaymentChannel?> fetchPaymentChannel({required int dormitoryId}) async {
    channelCallCount++;
    if (throwOnChannel) throw const SocketException('Failed host lookup');
    return promptPayChannel;
  }

  @override
  Future<Invoice?> fetchCurrentBill({
    required int roomDbId,
    required int month,
    required int year,
  }) async =>
      null;

  @override
  Future<ActionResult> submitPaymentSlip({
    required Invoice bill,
    required PickedImage slip,
  }) async =>
      const ActionResult(success: true, message: 'ส่งสลิปแล้ว');

  @override
  Future<ActionResult> submitCashPayment({required Invoice bill}) async =>
      const ActionResult(success: true, message: 'แจ้งชำระเงินสดแล้ว');

  @override
  Future<ActionResult> cancelCashPayment({required Invoice bill}) async =>
      const ActionResult(success: true, message: 'ยกเลิกแล้ว');
}

TenantBillsViewModel buildBills({
  int? roomId = 104,
  int? dormitoryId = 1,
  TenantBillingSource? source,
}) =>
    TenantBillsViewModel(
      roomId: roomId,
      dormitoryId: dormitoryId,
      source: source ?? _FakeHistorySource(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugPrint = (String? message, {int? wrapWidth}) {};

  group('Feature 11: Payment History', () {
    // -----------------------------------------------------------------------
    group('UTC-81 loadBillHistory', () {
      test('UTC-81-TC-01 loads the room bills and the payment channel',
          () async {
        final viewModel = buildBills();

        await viewModel.load();

        expect(viewModel.bills.map((b) => b.invoiceNo), [
          'INV-202609-104',
          'INV-202608-104',
          'INV-202607-104-R2',
          'INV-202606-104',
          'INV-202605-104',
          'INV-202604-104',
        ]);
        expect(viewModel.paymentChannel?.promptPayId, '0898765432');
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.isLoading, isFalse);
      });

      test('UTC-81-TC-02 asks for the six most recent periods', () async {
        final source = _FakeHistorySource();
        final viewModel = buildBills(source: source);

        await viewModel.load();

        expect(source.requestedMonthCount, 6);
      });

      test('UTC-81-TC-03 a tenant without a room finishes without a query',
          () async {
        final source = _FakeHistorySource();
        final viewModel = buildBills(roomId: null, source: source);

        await viewModel.load();

        expect(viewModel.bills, isEmpty);
        expect(source.historyCallCount, 0);
        expect(viewModel.isLoading, isFalse);
      });

      test('UTC-81-TC-04 records a bill load failure instead of throwing',
          () async {
        final viewModel =
            buildBills(source: _FakeHistorySource(throwOnHistory: true));

        await viewModel.load();

        expect(viewModel.errorMessage, 'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่');
        expect(viewModel.bills, isEmpty);
        expect(viewModel.isLoading, isFalse);
      });

      test('UTC-81-TC-05 a payment channel failure still lists the bills',
          () async {
        final viewModel =
            buildBills(source: _FakeHistorySource(throwOnChannel: true));

        await viewModel.load();

        expect(viewModel.bills, hasLength(6));
        expect(viewModel.paymentChannel, isNull);
        expect(viewModel.errorMessage, isNull);
      });

      test('UTC-81-TC-06 a later load keeps the bills on screen while refreshing',
          () async {
        final source = _FakeHistorySource();
        final viewModel = buildBills(source: source);
        await viewModel.load();

        source.gate = Completer<void>();
        final refreshing = viewModel.load();

        expect(viewModel.isRefreshing, isTrue);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.bills, hasLength(6));

        source.gate!.complete();
        await refreshing;

        expect(viewModel.isRefreshing, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-82 filterBills', () {
      final bills = room104History();

      test('UTC-82-TC-01 the default filter returns every bill in order', () {
        expect(filterBills(bills, 'ทั้งหมด').map((b) => b.dbId),
            [6, 7, 9, 10, 11, 12]);
      });

      test('UTC-82-TC-02 returns only the outstanding bills', () {
        expect(filterBills(bills, 'ค้างชำระ').map((b) => b.dbId), [6, 12]);
      });

      test('UTC-82-TC-03 returns every bill awaiting verification, slip or cash',
          () {
        expect(filterBills(bills, 'รอตรวจสลิป').map((b) => b.dbId), [10, 11]);
      });

      test('UTC-82-TC-04 returns only the paid bills', () {
        expect(filterBills(bills, 'ชำระแล้ว').map((b) => b.dbId), [7, 9]);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-83 totalOutstanding', () {
      test('UTC-83-TC-01 sums only the unpaid bills', () {
        expect(totalOutstanding(room104History()), 7320);
      });

      test('UTC-83-TC-02 leaves out bills awaiting verification', () {
        final bills = [
          buildBill(
            status: InvoiceStatus.pending,
            paymentMethod: PaymentMethod.cash,
            total: 3620,
          ),
        ];

        expect(totalOutstanding(bills), 0);
      });

      test('UTC-83-TC-03 returns 0 when no bill is loaded', () {
        expect(totalOutstanding(const []), 0);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-84 totalPaidInYear', () {
      test('UTC-84-TC-01 sums the paid bills of the year', () {
        expect(totalPaidInYear(room104History(), 2026), 7540);
      });

      test('UTC-84-TC-02 leaves out a paid bill of another year', () {
        final bills = [
          buildBill(
            billingMonth: 8,
            status: InvoiceStatus.paid,
            total: 3580,
          ),
          buildBill(
            billingMonth: 11,
            billingYear: 2025,
            status: InvoiceStatus.paid,
            total: 3400,
          ),
        ];

        expect(totalPaidInYear(bills, 2026), 3580);
      });

      test('UTC-84-TC-03 counts a bill by its billing period, not its payment date',
          () {
        final bills = [
          buildBill(
            billingMonth: 12,
            billingYear: 2025,
            status: InvoiceStatus.paid,
            total: 3450,
            paidAt: DateTime(2026, 1, 3),
          ),
        ];

        expect(totalPaidInYear(bills, 2026), 0);
        expect(totalPaidInYear(bills, 2025), 3450);
      });

      test('UTC-84-TC-04 returns 0 when no bill of the year is paid', () {
        expect(totalPaidInYear([buildBill()], 2026), 0);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-85 invoiceQrPayload', () {
      test('UTC-85-TC-01 an unpaid bill gets the PromptPay payload of its total',
          () {
        final payload = invoiceQrPayload(
          invoice: buildBill(total: 3820),
          channel: promptPayChannel,
        );

        expect(payload, isNotNull);
        expect(
          payload,
          promptPayPayload(promptPayId: '0898765432', amount: 3820),
        );
      });

      test('UTC-85-TC-02 a paid bill gets no QR code', () {
        expect(
          invoiceQrPayload(
            invoice: buildBill(status: InvoiceStatus.paid),
            channel: promptPayChannel,
          ),
          isNull,
        );
      });

      test('UTC-85-TC-03 a bill awaiting verification gets no QR code', () {
        expect(
          invoiceQrPayload(
            invoice: buildBill(
              status: InvoiceStatus.pending,
              paymentMethod: PaymentMethod.transfer,
            ),
            channel: promptPayChannel,
          ),
          isNull,
        );
      });

      test('UTC-85-TC-04 a voided bill gets no QR code', () {
        expect(
          invoiceQrPayload(
            invoice: buildBill(status: InvoiceStatus.voided),
            channel: promptPayChannel,
          ),
          isNull,
        );
      });

      test('UTC-85-TC-05 no QR code when the dormitory has no payment channel',
          () {
        expect(invoiceQrPayload(invoice: buildBill()), isNull);
      });

      test('UTC-85-TC-06 no QR code when the channel has a bank account only',
          () {
        const bankOnly = PaymentChannel(
          accountName: 'สมหญิง เจ้าของหอ',
          bankName: 'ธนาคารกสิกรไทย',
          accountNo: '1234567890',
        );

        expect(invoiceQrPayload(invoice: buildBill(), channel: bankOnly),
            isNull);
      });

      test('UTC-85-TC-07 no QR code when the PromptPay ID is malformed', () {
        const malformed = PaymentChannel(
          accountName: 'สมหญิง เจ้าของหอ',
          promptPayId: '089876543',
        );

        expect(invoiceQrPayload(invoice: buildBill(), channel: malformed),
            isNull);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-86 refreshWhen', () {
      test('UTC-86-TC-01 a refresh signal reloads the bills', () async {
        final source = _FakeHistorySource();
        final viewModel = buildBills(source: source);
        final signal = StreamController<void>.broadcast();

        viewModel.refreshWhen(signal.stream);
        signal.add(null);
        await pumpEventQueue();

        expect(source.historyCallCount, 1);
        await signal.close();
      });

      test('UTC-86-TC-02 subscribing again replaces the previous signal',
          () async {
        final source = _FakeHistorySource();
        final viewModel = buildBills(source: source);
        final first = StreamController<void>.broadcast();
        final second = StreamController<void>.broadcast();

        viewModel.refreshWhen(first.stream);
        viewModel.refreshWhen(second.stream);
        first.add(null);
        await pumpEventQueue();
        expect(source.historyCallCount, 0);

        second.add(null);
        await pumpEventQueue();
        expect(source.historyCallCount, 1);

        await first.close();
        await second.close();
      });

      test('UTC-86-TC-03 a disposed view model ignores the signal', () async {
        final source = _FakeHistorySource();
        final viewModel = buildBills(source: source);
        final signal = StreamController<void>.broadcast();

        viewModel.refreshWhen(signal.stream);
        viewModel.dispose();
        signal.add(null);
        await pumpEventQueue();

        expect(source.historyCallCount, 0);
        await signal.close();
      });
    });
  });
}
