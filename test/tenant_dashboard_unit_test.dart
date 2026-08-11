import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/viewmodels/action_result.dart';
import 'package:horplug/viewmodels/error_message.dart';
import 'package:horplug/viewmodels/tenant_bills_view_model.dart';
import 'package:horplug/viewmodels/tenant_dashboard_view_model.dart';

/// Fake ของชั้นข้อมูลฝั่งผู้เช่า
///
/// สร้าง ViewModel จริงใน test ไม่ได้ เพราะ SupabaseService สร้าง client ตอน
/// field initializer — จึงทดสอบ repository fake + top-level function แทน
/// (ตามแบบเดียวกับ test ไฟล์อื่นในโปรเจกต์)
class FakeTenantDashboardRepository {
  FakeTenantDashboardRepository({
    List<Invoice>? invoices,
    List<Map<String, dynamic>>? messages,
    String? lastReadAt,
    this.shouldThrowOnFetchInvoice = false,
    this.shouldThrowOnFetchHistory = false,
    this.shouldThrowOnCountUnread = false,
    this.shouldThrowOnCreateRequest = false,
  })  : _invoices = List<Invoice>.from(invoices ?? const []),
        _messages =
            List<Map<String, dynamic>>.from(messages ?? const []),
        _lastReadAt = lastReadAt;

  final List<Invoice> _invoices;
  final List<Map<String, dynamic>> _messages;
  final String? _lastReadAt;

  final bool shouldThrowOnFetchInvoice;
  final bool shouldThrowOnFetchHistory;
  final bool shouldThrowOnCountUnread;
  final bool shouldThrowOnCreateRequest;

  int createRequestCallCount = 0;
  int loadRequestsCallCount = 0;

  Future<Invoice?> fetchInvoiceForRoom({
    required int roomDbId,
    required int month,
    required int year,
  }) async {
    if (shouldThrowOnFetchInvoice) {
      throw const SocketException('Failed host lookup');
    }
    final matches = _invoices.where(
      (invoice) => invoice.billingMonth == month && invoice.billingYear == year,
    );
    return matches.isEmpty ? null : matches.first;
  }

  Future<List<Invoice>> fetchInvoiceHistoryForRoom({
    required int roomDbId,
    int monthCount = 6,
  }) async {
    if (shouldThrowOnFetchHistory) {
      throw const SocketException('Failed host lookup');
    }
    final sorted = List<Invoice>.from(_invoices)
      ..sort((a, b) => b.period.compareTo(a.period));
    return sorted.take(monthCount).toList();
  }

  /// จำลอง countUnreadMessagesForRoom: นับเฉพาะข้อความจากเจ้าของหอ
  /// ที่เกิดหลัง last_read_at
  Future<int> countUnreadMessagesForRoom({
    required int roomId,
    required String userId,
  }) async {
    if (shouldThrowOnCountUnread) {
      throw const SocketException('Failed host lookup');
    }

    final lastReadAt = _lastReadAt;
    final cutoff = lastReadAt == null ? null : DateTime.parse(lastReadAt);

    return _messages.where((message) {
      if (message['is_from_owner'] != true) return false;
      if (cutoff == null) return true;
      return DateTime.parse(message['created_at'] as String).isAfter(cutoff);
    }).length;
  }

  Future<ActionResult> submitRequest({
    required String description,
    required MaintenanceRequestType requestType,
  }) async {
    try {
      if (shouldThrowOnCreateRequest) {
        throw const SocketException('Failed host lookup');
      }
      createRequestCallCount++;
      loadRequestsCallCount++;
      return const ActionResult(
        success: true,
        message: 'ส่งคำขอแล้ว เจ้าของหอจะติดต่อกลับ',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ส่งคำขอไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    }
  }
}

/// บิลหนึ่งใบแบบที่ InvoiceService คืนออกมา
///
/// [total] คำนวณจากผลบวกของรายการเหมือน generated column ในฐานข้อมูล เพื่อให้
/// fixture ในเทสต์เป็นไปไม่ได้ที่จะมียอดรวมไม่ตรงกับรายการย่อย
Invoice buildInvoice({
  required int roomDbId,
  required int month,
  required int year,
  double roomPrice = 2500,
  double electricityCost = 0,
  double electricityUnits = 0,
  double waterCost = 0,
  double cleaningFee = 0,
  InvoiceStatus status = InvoiceStatus.unpaid,
  PaymentMethod? paymentMethod,
}) {
  return Invoice(
    paymentMethod: paymentMethod,
    dbId: roomDbId * 10000 + year * 100 + month,
    invoiceNo: 'INV-$year${month.toString().padLeft(2, '0')}-101',
    roomDbId: roomDbId,
    roomNumber: '101',
    tenantName: 'Somchai Jaidee',
    billingMonth: month,
    billingYear: year,
    roomPrice: roomPrice,
    electricityUnits: electricityUnits,
    electricityCost: electricityCost,
    waterCost: waterCost,
    cleaningFee: cleaningFee,
    total: roomPrice + electricityCost + waterCost + cleaningFee,
    status: status,
    dueDate: DateTime(year, month + 1, 5),
    issuedAt: DateTime(year, month + 1, 1),
  );
}

void main() {
  group('Feature 7: Dashboard for Tenant', () {
    group('UTC-36 fetchInvoiceForRoom', () {
      test('UTC-36-TC-01 returns an invoice totalling every line item',
          () async {
        final repository = FakeTenantDashboardRepository(
          invoices: [
            buildInvoice(
              roomDbId: 10,
              month: 6,
              year: 2026,
              roomPrice: 2500,
              electricityCost: 1240,
              electricityUnits: 155,
              waterCost: 100,
              cleaningFee: 300,
            ),
          ],
        );

        final invoice = await repository.fetchInvoiceForRoom(
          roomDbId: 10,
          month: 6,
          year: 2026,
        );

        expect(invoice, isNotNull);
        expect(invoice!.total, 2500 + 1240 + 100 + 300);
      });

      test('UTC-36-TC-02 returns null when the period has no meter record',
          () async {
        final repository = FakeTenantDashboardRepository(
          invoices: [buildInvoice(roomDbId: 10, month: 5, year: 2026)],
        );

        final invoice = await repository.fetchInvoiceForRoom(
          roomDbId: 10,
          month: 6,
          year: 2026,
        );

        expect(invoice, isNull);
      });

      test('UTC-36-TC-03 throws SocketException on network failure', () {
        final repository = FakeTenantDashboardRepository(
          shouldThrowOnFetchInvoice: true,
        );

        expect(
          () => repository.fetchInvoiceForRoom(
              roomDbId: 10, month: 6, year: 2026),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-37 fetchInvoiceHistoryForRoom', () {
      test('UTC-37-TC-01 returns invoices newest-first, capped at monthCount',
          () async {
        final repository = FakeTenantDashboardRepository(
          invoices: [
            buildInvoice(roomDbId: 10, month: 4, year: 2026),
            buildInvoice(roomDbId: 10, month: 6, year: 2026),
            buildInvoice(roomDbId: 10, month: 5, year: 2026),
          ],
        );

        final history = await repository.fetchInvoiceHistoryForRoom(
          roomDbId: 10,
          monthCount: 2,
        );

        expect(history, hasLength(2));
        expect(history[0].billingMonth, 6);
        expect(history[1].billingMonth, 5);
      });

      test('UTC-37-TC-02 returns an empty list for a room with no history',
          () async {
        final repository = FakeTenantDashboardRepository(invoices: []);

        final history =
            await repository.fetchInvoiceHistoryForRoom(roomDbId: 10);

        expect(history, isEmpty);
      });

      test('UTC-37-TC-03 includes the cleaning fee in the period total',
          () async {
        final repository = FakeTenantDashboardRepository(
          invoices: [
            buildInvoice(
              roomDbId: 10,
              month: 6,
              year: 2026,
              roomPrice: 2500,
              cleaningFee: 500,
            ),
          ],
        );

        final history =
            await repository.fetchInvoiceHistoryForRoom(roomDbId: 10);

        expect(history.first.cleaningFee, 500);
        expect(history.first.total, 3000);
      });

      test('UTC-37-TC-04 throws SocketException on network failure', () {
        final repository = FakeTenantDashboardRepository(
          shouldThrowOnFetchHistory: true,
        );

        expect(
          () => repository.fetchInvoiceHistoryForRoom(roomDbId: 10),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-38 countUnreadMessagesForRoom', () {
      test(
          'UTC-38-TC-01 counts only owner messages newer than last_read_at',
          () async {
        final repository = FakeTenantDashboardRepository(
          lastReadAt: '2026-06-21T10:00:00Z',
          messages: [
            {'is_from_owner': true, 'created_at': '2026-06-21T09:00:00Z'},
            {'is_from_owner': true, 'created_at': '2026-06-21T11:00:00Z'},
            {'is_from_owner': true, 'created_at': '2026-06-21T12:00:00Z'},
            {'is_from_owner': false, 'created_at': '2026-06-21T13:00:00Z'},
          ],
        );

        final count = await repository.countUnreadMessagesForRoom(
          roomId: 10,
          userId: 'tenant-1',
        );

        expect(count, 2);
      });

      test(
          'UTC-38-TC-02 counts every owner message when no read record exists',
          () async {
        final repository = FakeTenantDashboardRepository(
          messages: [
            {'is_from_owner': true, 'created_at': '2026-06-21T09:00:00Z'},
            {'is_from_owner': true, 'created_at': '2026-06-21T11:00:00Z'},
          ],
        );

        final count = await repository.countUnreadMessagesForRoom(
          roomId: 10,
          userId: 'tenant-1',
        );

        expect(count, 2);
      });

      test('UTC-38-TC-03 returns 0 when only the tenant has sent messages',
          () async {
        final repository = FakeTenantDashboardRepository(
          messages: [
            {'is_from_owner': false, 'created_at': '2026-06-21T09:00:00Z'},
            {'is_from_owner': false, 'created_at': '2026-06-21T11:00:00Z'},
          ],
        );

        final count = await repository.countUnreadMessagesForRoom(
          roomId: 10,
          userId: 'tenant-1',
        );

        expect(count, 0);
      });

      test('UTC-38-TC-04 throws SocketException on network failure', () {
        final repository = FakeTenantDashboardRepository(
          shouldThrowOnCountUnread: true,
        );

        expect(
          () => repository.countUnreadMessagesForRoom(
              roomId: 10, userId: 'tenant-1'),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-39 utilityTrend', () {
      test('UTC-39-TC-01 reports an increase with a positive percentage', () {
        final trend = utilityTrend(current: 162, previous: 150);

        expect(trend.direction, TrendDirection.up);
        expect(trend.delta, 12);
        expect(trend.percent, closeTo(8, 0.01));
      });

      test('UTC-39-TC-02 reports a decrease with a negative percentage', () {
        final trend = utilityTrend(current: 120, previous: 150);

        expect(trend.direction, TrendDirection.down);
        expect(trend.delta, -30);
        expect(trend.percent, closeTo(-20, 0.01));
      });

      test('UTC-39-TC-03 leaves percent null when the previous month is zero',
          () {
        final trend = utilityTrend(current: 150, previous: 0);

        expect(trend.direction, TrendDirection.up);
        expect(trend.delta, 150);
        expect(trend.percent, isNull);
      });

      test('UTC-39-TC-04 reports flat when usage is unchanged', () {
        final trend = utilityTrend(current: 150, previous: 150);

        expect(trend.direction, TrendDirection.flat);
        expect(trend.delta, 0);
        expect(trend.percent, 0);
      });
    });

    group('UTC-40 ยอดค้างชำระ', () {
      test('UTC-40-TC-01 บิลที่ยกเลิกแล้วไม่ถูกนับเป็นยอดค้างชำระ', () {
        final bills = [
          buildInvoice(
              roomDbId: 10, month: 7, year: 2026,
              status: InvoiceStatus.voided),
          buildInvoice(
              roomDbId: 10, month: 8, year: 2026,
              status: InvoiceStatus.unpaid),
        ];

        expect(totalOutstanding(bills), 2500);
      });

      test('UTC-40-TC-02 บิลที่รอตรวจสลิปไม่ถูกนับเป็นยอดค้าง เพราะจ่ายไปแล้ว',
          () {
        final bills = [
          buildInvoice(
              roomDbId: 10, month: 8, year: 2026,
              status: InvoiceStatus.pending),
        ];

        expect(totalOutstanding(bills), 0);
      });

      test('UTC-40-TC-03 บิลที่ยกเลิกแล้วไม่ถูกนับเป็นยอดชำระสะสมของปี', () {
        final bills = [
          buildInvoice(
              roomDbId: 10, month: 7, year: 2026,
              status: InvoiceStatus.voided),
          buildInvoice(
              roomDbId: 10, month: 8, year: 2026,
              status: InvoiceStatus.paid),
        ];

        expect(totalPaidInYear(bills, 2026), 2500);
      });
    });

    group('UTC-42 tenant maintenance submitRequest', () {
      test('UTC-42-TC-01 succeeds and reloads the request list', () async {
        final repository = FakeTenantDashboardRepository();

        final result = await repository.submitRequest(
          description: 'ไฟห้องน้ำเสีย',
          requestType: MaintenanceRequestType.repair,
        );

        expect(result.success, isTrue);
        expect(result.message, 'ส่งคำขอแล้ว เจ้าของหอจะติดต่อกลับ');
        expect(repository.createRequestCallCount, 1);
        expect(repository.loadRequestsCallCount, 1);
      });

      test(
          'UTC-42-TC-02 maps a network failure to the Thai connectivity message',
          () async {
        final repository = FakeTenantDashboardRepository(
          shouldThrowOnCreateRequest: true,
        );

        final result = await repository.submitRequest(
          description: 'ไฟห้องน้ำเสีย',
          requestType: MaintenanceRequestType.repair,
        );

        expect(result.success, isFalse);
        expect(
          result.message,
          'ส่งคำขอไม่สำเร็จ: กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
        );
        expect(repository.createRequestCallCount, 0);
      });
    });

    group('UTC-43 bill presentation helpers', () {
      test('UTC-43-TC-01 maps each invoice status to its Thai label', () {
        expect(billStatusLabel(InvoiceStatus.unpaid), 'ค้างชำระ');
        // pending ใช้คำกลางๆ เพราะครอบทั้งบิลที่แนบสลิปและบิลที่แจ้งจ่ายสด
        // และเพราะข้อความนี้ถูกใช้เป็นชิปตัวกรองรายการด้วย
        expect(billStatusLabel(InvoiceStatus.pending), 'รอยืนยัน');
        expect(billStatusLabel(InvoiceStatus.paid), 'ชำระแล้ว');
        expect(billStatusLabel(InvoiceStatus.voided), 'ยกเลิกแล้ว');
      });

      test('UTC-43-TC-03 บิลที่รอยืนยันบอกได้ว่ารออะไรอยู่', () {
        Invoice pending({PaymentMethod? method}) => buildInvoice(
              roomDbId: 10,
              month: 5,
              year: 2026,
              status: InvoiceStatus.pending,
              paymentMethod: method,
            );

        // เจ้าของหอต้องทำคนละอย่างกับสองใบนี้ — ตรวจสลิป กับ ยืนยันรับเงินสด
        // ป้าย "รอตรวจสลิป" บนบิลที่จ่ายสดทำให้ทั้งสองฝ่ายไปตามหาสลิปที่ไม่มี
        expect(billStatusLabelOf(pending()), 'รอตรวจสลิป');
        expect(billStatusLabelOf(pending(method: PaymentMethod.transfer)),
            'รอตรวจสลิป');
        expect(billStatusLabelOf(pending(method: PaymentMethod.cash)),
            'รอยืนยันรับเงินสด');

        // สถานะอื่นไม่สนใจวิธีจ่าย — จ่ายสดที่ยืนยันแล้วก็คือ "ชำระแล้ว"
        expect(
          billStatusLabelOf(buildInvoice(
            roomDbId: 10,
            month: 5,
            year: 2026,
            status: InvoiceStatus.paid,
            paymentMethod: PaymentMethod.cash,
          )),
          'ชำระแล้ว',
        );
      });

      test('UTC-43-TC-02 returns Thai month names and guards bad input', () {
        expect(thaiMonthName(1), 'มกราคม');
        expect(thaiMonthName(7), 'กรกฎาคม');
        expect(thaiMonthName(12), 'ธันวาคม');
        expect(thaiMonthName(0), '-');
        expect(thaiMonthName(13), '-');
      });
    });
  });
}
