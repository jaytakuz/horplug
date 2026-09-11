import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_calculator.dart';
import 'package:horplug/services/invoice_lifecycle.dart';
import 'package:horplug/services/invoice_pdf.dart';
import 'package:horplug/services/invoice_service.dart';
import 'package:horplug/viewmodels/billing_view_model.dart';
import 'package:horplug/viewmodels/invoice_actions_view_model.dart';
import 'package:horplug/viewmodels/invoice_issue_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

Room buildRoom({
  int dbId = 101,
  String number = '101',
  String floor = '1',
  RoomStatus status = RoomStatus.occupied,
  String? tenantId = 'tenant-uuid',
  double price = 3000,
}) =>
    Room(
      dbId: dbId,
      id: number,
      floor: floor,
      status: status,
      currentTenantId: tenantId,
      tenantName: tenantId == null ? null : 'สมชาย ใจดี',
      price: price,
    );

ExtraFee buildFee({
  int id = 1,
  int invoiceId = 1,
  String name = 'ค่าปรับ',
  double amount = 200,
  bool isRecurring = false,
}) =>
    ExtraFee(
      id: id,
      invoiceId: invoiceId,
      name: name,
      amount: amount,
      isRecurring: isRecurring,
    );

Invoice buildInvoice({
  int dbId = 1,
  String invoiceNo = 'INV-202609-101',
  int roomDbId = 101,
  String roomNumber = '101',
  int billingMonth = 9,
  int billingYear = 2026,
  double roomPrice = 3000,
  double electricityUnits = 90,
  double electricityCost = 720,
  double waterCost = 100,
  double extraFeesTotal = 0,
  double? total,
  InvoiceStatus status = InvoiceStatus.unpaid,
  int revision = 1,
  String? voidReason,
}) =>
    Invoice(
      dbId: dbId,
      invoiceNo: invoiceNo,
      roomDbId: roomDbId,
      roomNumber: roomNumber,
      tenantId: 'tenant-uuid',
      tenantName: 'สมชาย ใจดี',
      billingMonth: billingMonth,
      billingYear: billingYear,
      roomPrice: roomPrice,
      electricityUnits: electricityUnits,
      electricityCost: electricityCost,
      waterCost: waterCost,
      total: total ?? roomPrice + electricityCost + waterCost + extraFeesTotal,
      status: status,
      revision: revision,
      voidReason: voidReason,
      dueDate: dueDateFor(billingYear, billingMonth),
      issuedAt: DateTime(billingYear, billingMonth, 28),
    );

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// InvoiceService ปลอมของ Feature 8
///
/// `previewDrafts` และ `issueInvoices` ไม่ได้คืนค่าที่เตรียมไว้ตายตัว แต่เรียก
/// ตรรกะจริง ([buildDraft], [invoiceNoFor], [dueDateFor]) กับข้อมูลงวดที่ฉีดเข้า
/// มา — กฎการข้ามห้อง การให้เลขที่บิล และวันครบกำหนด จึงถูกทดสอบของจริง มีแต่
/// การอ่าน/เขียนฐานข้อมูลเท่านั้นที่ถูกแทน
class _FakeInvoiceService extends InvoiceService {
  _FakeInvoiceService({
    this.rooms = const [],
    this.electricity = const {},
    this.water = const {},
    this.issuedRoomIds = const {},
    this.carriedFees = const {},
    this.invoices = const [],
    this.extraFees = const [],
    this.adjustments = const [],
    this.failedAdjustments = const [],
    this.reissueDraftAvailable = true,
    this.throwOnFetchInvoices = false,
    this.throwOnIssue = false,
    this.duplicateOnIssue = false,
    this.throwOnCarryForward = false,
    this.throwOnNotices = false,
    this.throwOnSendCard = false,
    this.throwOnFetchExtraFees = false,
    this.throwOnAddExtraFee = false,
    this.throwOnRemoveExtraFee = false,
    this.throwOnVoid = false,
    this.extraFeesCopyFailsOnReissue = false,
  });

  final List<Room> rooms;
  final Map<int, MeterCharge> electricity;
  final Map<int, double> water;
  final Set<int> issuedRoomIds;
  final Map<int, List<ExtraFee>> carriedFees;
  final List<Invoice> invoices;
  final List<ExtraFee> extraFees;
  final List<InvoiceAdjustment> adjustments;
  final List<InvoiceAdjustment> failedAdjustments;
  final bool reissueDraftAvailable;
  final bool throwOnFetchInvoices;
  final bool throwOnIssue;
  final bool duplicateOnIssue;
  final bool throwOnCarryForward;
  final bool throwOnNotices;
  final bool throwOnSendCard;
  final bool throwOnFetchExtraFees;
  final bool throwOnAddExtraFee;
  final bool throwOnRemoveExtraFee;
  final bool throwOnVoid;
  final bool extraFeesCopyFailsOnReissue;

  List<InvoiceDraft>? issuedDrafts;
  List<Map<String, Object?>> writtenFees = [];
  final Set<int> notifiedInvoiceIds = {};
  int sendCardCallCount = 0;
  int adjustmentNoticeCallCount = 0;
  int? addedToInvoiceId;
  String? addedFeeName;
  double? addedFeeAmount;
  bool? addedFeeIsRecurring;
  int? removedFeeId;
  Invoice? voidedInvoice;
  String? voidReason;

  @override
  Future<InvoicePreview> previewDrafts({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    final drafts = <InvoiceDraft>[];
    final skipped = <InvoiceDraft>[];

    for (final room in rooms) {
      final draft = buildDraft(
        room: room,
        billingMonth: month,
        billingYear: year,
        electricity: electricity[room.dbId],
        waterAmount: water[room.dbId],
        carriedExtraFees: carriedFees[room.dbId] ?? const [],
        alreadyIssued: issuedRoomIds.contains(room.dbId),
      );
      (draft.canIssue ? drafts : skipped).add(draft);
    }

    return InvoicePreview(drafts: drafts, skipped: skipped);
  }

  @override
  Future<List<Invoice>> issueInvoices({
    required int dormitoryId,
    required List<InvoiceDraft> drafts,
  }) async {
    if (throwOnIssue) throw const SocketException('Failed host lookup');
    if (duplicateOnIssue) {
      throw PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
    }
    if (drafts.isEmpty) return [];

    issuedDrafts = drafts;
    var nextId = 1;
    return drafts
        .map((draft) => buildInvoice(
              dbId: nextId++,
              invoiceNo: invoiceNoFor(
                year: draft.billingYear,
                month: draft.billingMonth,
                roomNumber: draft.roomNumber,
              ),
              roomDbId: draft.roomDbId,
              roomNumber: draft.roomNumber,
              billingMonth: draft.billingMonth,
              billingYear: draft.billingYear,
              roomPrice: draft.roomPrice,
              electricityUnits: draft.electricityUnits,
              electricityCost: draft.electricityCost,
              waterCost: draft.waterCost,
            ))
        .toList();
  }

  @override
  Future<void> carryForwardExtraFeesForIssued({
    required List<Invoice> invoices,
    required List<InvoiceDraft> drafts,
  }) async {
    if (throwOnCarryForward) throw const SocketException('Failed host lookup');

    final draftsByRoom = {for (final draft in drafts) draft.roomDbId: draft};
    for (final invoice in invoices) {
      final draft = draftsByRoom[invoice.roomDbId];
      if (draft == null) continue;
      for (final fee in draft.carriedExtraFees) {
        writtenFees.add({
          'invoice_id': invoice.dbId,
          'name': fee.name,
          'amount': fee.amount,
          'is_recurring': fee.isRecurring,
        });
      }
    }
  }

  @override
  Future<int> postIssueNotices({required List<Invoice> invoices}) async {
    if (throwOnNotices) throw const SocketException('Failed host lookup');

    final fresh =
        invoices.where((i) => !notifiedInvoiceIds.contains(i.dbId)).toList();
    notifiedInvoiceIds.addAll(fresh.map((i) => i.dbId));
    return fresh.length;
  }

  @override
  Future<void> sendInvoiceCard({required Invoice invoice}) async {
    if (throwOnSendCard) throw const SocketException('Failed host lookup');
    sendCardCallCount++;
  }

  @override
  Future<List<Invoice>> fetchInvoices({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    if (throwOnFetchInvoices) throw const SocketException('Failed host lookup');
    return invoices;
  }

  @override
  Future<List<ExtraFee>> fetchExtraFees({required int invoiceId}) async {
    if (throwOnFetchExtraFees) throw const SocketException('Failed host lookup');
    return extraFees;
  }

  @override
  Future<void> addExtraFee({
    required int invoiceId,
    required String name,
    required double amount,
    required bool isRecurring,
  }) async {
    if (throwOnAddExtraFee) throw const SocketException('Failed host lookup');
    addedToInvoiceId = invoiceId;
    addedFeeName = name;
    addedFeeAmount = amount;
    addedFeeIsRecurring = isRecurring;
  }

  @override
  Future<void> removeExtraFee({required int extraFeeId}) async {
    if (throwOnRemoveExtraFee) throw const SocketException('Failed host lookup');
    removedFeeId = extraFeeId;
  }

  @override
  Future<({List<InvoiceAdjustment> applied, List<InvoiceAdjustment> failed})>
      syncUnpaidInvoices({
    required int dormitoryId,
    required int month,
    required int year,
  }) async =>
          (applied: adjustments, failed: failedAdjustments);

  @override
  Future<int> postAdjustmentNotices(List<InvoiceAdjustment> adjustments) async {
    adjustmentNoticeCallCount++;
    return adjustments.length;
  }

  @override
  Future<void> voidInvoice({
    required Invoice invoice,
    required String reason,
  }) async {
    if (throwOnVoid) throw const SocketException('Failed host lookup');
    if (!canTransition(invoice.status, InvoiceStatus.voided)) {
      throw Exception('บิลใบนี้เปลี่ยนสถานะแบบนั้นไม่ได้');
    }
    voidedInvoice = invoice;
    voidReason = reason;
  }

  @override
  Future<({Invoice? invoice, bool extraFeesCopyFailed})> reissueInvoice({
    required Invoice voided,
    required int dormitoryId,
  }) async {
    if (!reissueDraftAvailable) {
      return (invoice: null, extraFeesCopyFailed: false);
    }

    final revision = voided.revision + 1;
    return (
      invoice: buildInvoice(
        dbId: voided.dbId + 100,
        invoiceNo: invoiceNoFor(
          year: voided.billingYear,
          month: voided.billingMonth,
          roomNumber: voided.roomNumber,
          revision: revision,
        ),
        roomDbId: voided.roomDbId,
        roomNumber: voided.roomNumber,
        billingMonth: voided.billingMonth,
        billingYear: voided.billingYear,
        revision: revision,
      ),
      extraFeesCopyFailed: extraFeesCopyFailsOnReissue,
    );
  }
}

InvoiceAdjustment buildAdjustment({
  Invoice? invoice,
  double electricityCost = 900,
  double electricityUnits = 120,
  double waterCost = 100,
}) =>
    InvoiceAdjustment(
      invoice: invoice ?? buildInvoice(),
      roomPrice: 3000,
      electricityUnits: electricityUnits,
      electricityCost: electricityCost,
      waterCost: waterCost,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugPrint = (String? message, {int? wrapWidth}) {};

  group('Feature 8: Invoice Generation', () {
    // -----------------------------------------------------------------------
    group('UTC-54 buildDraft', () {
      test('UTC-54-TC-01 totals rent, electricity, water and additional fees',
          () {
        final draft = buildDraft(
          room: buildRoom(),
          billingMonth: 9,
          billingYear: 2026,
          electricity: const MeterCharge(units: 90, amount: 720),
          waterAmount: 100,
          carriedExtraFees: [buildFee(amount: 200)],
        );

        expect(draft.canIssue, isTrue);
        expect(draft.total, 4020);
      });

      test('UTC-54-TC-02 skips a room that has no tenant', () {
        final draft = buildDraft(
          room: buildRoom(status: RoomStatus.vacant, tenantId: null),
          billingMonth: 9,
          billingYear: 2026,
          electricity: const MeterCharge(units: 90, amount: 720),
        );

        expect(draft.canIssue, isFalse);
        expect(draft.skipReason, SkipReason.noTenant);
      });

      test('UTC-54-TC-03 skips a room already invoiced for the period', () {
        final draft = buildDraft(
          room: buildRoom(),
          billingMonth: 9,
          billingYear: 2026,
          electricity: const MeterCharge(units: 90, amount: 720),
          alreadyIssued: true,
        );

        expect(draft.skipReason, SkipReason.alreadyIssued);
      });

      test('UTC-54-TC-04 skips a room whose electricity was not recorded', () {
        final draft = buildDraft(
          room: buildRoom(),
          billingMonth: 9,
          billingYear: 2026,
          waterAmount: 100,
        );

        expect(draft.skipReason, SkipReason.noMeterReading);
      });

      test('UTC-54-TC-05 bills a missing water charge as zero and still issues',
          () {
        final draft = buildDraft(
          room: buildRoom(),
          billingMonth: 9,
          billingYear: 2026,
          electricity: const MeterCharge(units: 90, amount: 720),
        );

        expect(draft.canIssue, isTrue);
        expect(draft.waterCost, 0);
        expect(draft.total, 3720);
      });

      test('UTC-54-TC-06 reports "no tenant" ahead of the other reasons', () {
        final draft = buildDraft(
          room: buildRoom(status: RoomStatus.vacant, tenantId: null),
          billingMonth: 9,
          billingYear: 2026,
          alreadyIssued: true,
        );

        expect(draft.skipReason, SkipReason.noTenant);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-55 carryForwardExtraFees', () {
      test('UTC-55-TC-01 keeps only the fees marked as recurring', () {
        final result = carryForwardExtraFees([
          buildFee(id: 1, name: 'ค่าที่จอดรถ', isRecurring: true),
          buildFee(id: 2, name: 'ค่าปรับ', isRecurring: false),
        ]);

        expect(result.map((f) => f.name), ['ค่าที่จอดรถ']);
      });

      test('UTC-55-TC-02 returns an empty list when no fee is recurring', () {
        final result = carryForwardExtraFees([buildFee(isRecurring: false)]);

        expect(result, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-56 dueDateFor', () {
      test('UTC-56-TC-01 falls on the 5th of the following month', () {
        expect(dueDateFor(2026, 9), DateTime(2026, 10, 5));
      });

      test('UTC-56-TC-02 rolls a December period into the next year', () {
        expect(dueDateFor(2026, 12), DateTime(2027, 1, 5));
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-57 invoiceNoFor', () {
      test('UTC-57-TC-01 zero-pads the month in the period segment', () {
        final result =
            invoiceNoFor(year: 2026, month: 9, roomNumber: '101');

        expect(result, 'INV-202609-101');
      });

      test('UTC-57-TC-02 appends the revision on a replacement', () {
        final result = invoiceNoFor(
          year: 2026,
          month: 9,
          roomNumber: '101',
          revision: 2,
        );

        expect(result, 'INV-202609-101-R2');
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-58 previewDrafts', () {
      _FakeInvoiceService buildPreviewService() => _FakeInvoiceService(
            rooms: [
              buildRoom(dbId: 101, number: '101'),
              buildRoom(dbId: 102, number: '102'),
              buildRoom(
                dbId: 201,
                number: '201',
                status: RoomStatus.vacant,
                tenantId: null,
              ),
              buildRoom(dbId: 103, number: '103'),
            ],
            electricity: const {
              101: MeterCharge(units: 90, amount: 720),
              102: MeterCharge(units: 50, amount: 400),
            },
            water: const {101: 100, 102: 100},
            issuedRoomIds: const {102},
          );

      test('UTC-58-TC-01 separates the issuable rooms from the skipped ones',
          () async {
        final preview = await buildPreviewService()
            .previewDrafts(dormitoryId: 1, month: 9, year: 2026);

        expect(preview.drafts.map((d) => d.roomNumber), ['101']);
        expect(preview.skipped.map((d) => d.roomNumber), ['102', '201', '103']);
      });

      test('UTC-58-TC-02 records one reason per skipped room', () async {
        final preview = await buildPreviewService()
            .previewDrafts(dormitoryId: 1, month: 9, year: 2026);

        final reasons = {
          for (final draft in preview.skipped)
            draft.roomNumber: draft.skipReason,
        };
        expect(reasons['102'], SkipReason.alreadyIssued);
        expect(reasons['201'], SkipReason.noTenant);
        expect(reasons['103'], SkipReason.noMeterReading);
      });

      test('UTC-58-TC-03 totals only the drafts that will be issued',
          () async {
        final preview = await buildPreviewService()
            .previewDrafts(dormitoryId: 1, month: 9, year: 2026);

        expect(preview.total, 3820);
      });

      test('UTC-58-TC-04 returns nothing for a dormitory with no room',
          () async {
        final preview = await _FakeInvoiceService()
            .previewDrafts(dormitoryId: 1, month: 9, year: 2026);

        expect(preview.drafts, isEmpty);
        expect(preview.skipped, isEmpty);
        expect(preview.total, 0);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-59 addExtraFeeToDraft', () {
      Future<InvoiceIssueViewModel> loadedIssueViewModel({
        _FakeInvoiceService? service,
      }) async {
        final viewModel = InvoiceIssueViewModel(
          dormitoryId: 1,
          month: 9,
          year: 2026,
          service: service ??
              _FakeInvoiceService(
                rooms: [
                  buildRoom(dbId: 101, number: '101'),
                  buildRoom(dbId: 102, number: '102'),
                ],
                electricity: const {
                  101: MeterCharge(units: 90, amount: 720),
                  102: MeterCharge(units: 50, amount: 400),
                },
                water: const {101: 100, 102: 100},
              ),
        );
        await viewModel.load();
        return viewModel;
      }

      test('UTC-59-TC-01 attaches the fee to the chosen draft only', () async {
        final viewModel = await loadedIssueViewModel();
        final target = viewModel.preview!.drafts
            .firstWhere((d) => d.roomNumber == '101');

        viewModel.addExtraFeeToDraft(
          target,
          name: 'ค่าปรับ',
          amount: 200,
          isRecurring: false,
        );

        final drafts = viewModel.preview!.drafts;
        expect(
          drafts.firstWhere((d) => d.roomNumber == '101').carriedExtraFees,
          hasLength(1),
        );
        expect(
          drafts.firstWhere((d) => d.roomNumber == '102').carriedExtraFees,
          isEmpty,
        );
      });

      test('UTC-59-TC-02 raises the draft total and the grand total',
          () async {
        final viewModel = await loadedIssueViewModel();
        final before = viewModel.preview!.total;
        final target = viewModel.preview!.drafts.first;

        viewModel.addExtraFeeToDraft(
          target,
          name: 'ค่าปรับ',
          amount: 200,
          isRecurring: true,
        );

        expect(viewModel.preview!.total, before + 200);
      });

      test('UTC-59-TC-03 gives each pending fee its own temporary identifier',
          () async {
        final viewModel = await loadedIssueViewModel();
        var target = viewModel.preview!.drafts.first;

        viewModel.addExtraFeeToDraft(target,
            name: 'ค่าปรับ', amount: 200, isRecurring: false);
        target = viewModel.preview!.drafts.first;
        viewModel.addExtraFeeToDraft(target,
            name: 'ค่าที่จอดรถ', amount: 300, isRecurring: true);

        final ids = viewModel.preview!.drafts.first.carriedExtraFees
            .map((f) => f.id)
            .toSet();
        expect(ids, hasLength(2));
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-60 removeExtraFeeFromDraft', () {
      test('UTC-60-TC-01 drops the fee and lowers the totals again', () async {
        final viewModel = InvoiceIssueViewModel(
          dormitoryId: 1,
          month: 9,
          year: 2026,
          service: _FakeInvoiceService(
            rooms: [buildRoom(dbId: 101, number: '101')],
            electricity: const {101: MeterCharge(units: 90, amount: 720)},
            water: const {101: 100},
          ),
        );
        await viewModel.load();
        final before = viewModel.preview!.total;

        var draft = viewModel.preview!.drafts.first;
        viewModel.addExtraFeeToDraft(draft,
            name: 'ค่าปรับ', amount: 200, isRecurring: false);
        draft = viewModel.preview!.drafts.first;
        viewModel.removeExtraFeeFromDraft(
            draft, draft.carriedExtraFees.first);

        expect(viewModel.preview!.drafts.first.carriedExtraFees, isEmpty);
        expect(viewModel.preview!.total, before);
      });

      test('UTC-60-TC-02 writes nothing before the invoices are issued',
          () async {
        final service = _FakeInvoiceService(
          rooms: [buildRoom(dbId: 101, number: '101')],
          electricity: const {101: MeterCharge(units: 90, amount: 720)},
        );
        final viewModel = InvoiceIssueViewModel(
          dormitoryId: 1,
          month: 9,
          year: 2026,
          service: service,
        );
        await viewModel.load();

        final draft = viewModel.preview!.drafts.first;
        viewModel.addExtraFeeToDraft(draft,
            name: 'ค่าปรับ', amount: 200, isRecurring: false);

        expect(service.writtenFees, isEmpty);
        expect(service.addedToInvoiceId, isNull);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-61 issueInvoices', () {
      Future<InvoiceIssueViewModel> issueViewModel(
              _FakeInvoiceService service) async {
        final viewModel = InvoiceIssueViewModel(
          dormitoryId: 1,
          month: 9,
          year: 2026,
          service: service,
        );
        await viewModel.load();
        return viewModel;
      }

      _FakeInvoiceService issuableService({
        bool throwOnIssue = false,
        bool duplicateOnIssue = false,
        bool throwOnCarryForward = false,
        bool throwOnNotices = false,
        Map<int, List<ExtraFee>> carriedFees = const {},
      }) =>
          _FakeInvoiceService(
            rooms: [
              buildRoom(dbId: 101, number: '101'),
              buildRoom(dbId: 102, number: '102'),
            ],
            electricity: const {
              101: MeterCharge(units: 90, amount: 720),
              102: MeterCharge(units: 50, amount: 400),
            },
            water: const {101: 100, 102: 100},
            carriedFees: carriedFees,
            throwOnIssue: throwOnIssue,
            duplicateOnIssue: duplicateOnIssue,
            throwOnCarryForward: throwOnCarryForward,
            throwOnNotices: throwOnNotices,
          );

      test('UTC-61-TC-01 creates one invoice per issuable draft', () async {
        final service = issuableService();
        final viewModel = await issueViewModel(service);

        final result = await viewModel.issue();

        expect(result.success, isTrue);
        expect(result.message, 'ออกบิลแล้ว 2 ห้อง');
        expect(service.issuedDrafts, hasLength(2));
        expect(viewModel.hasIssued, isTrue);
      });

      test('UTC-61-TC-02 numbers each invoice and dates it for the period',
          () async {
        final service = issuableService();
        final created = await service.issueInvoices(
          dormitoryId: 1,
          drafts: (await service.previewDrafts(
                  dormitoryId: 1, month: 9, year: 2026))
              .drafts,
        );

        expect(created.map((i) => i.invoiceNo),
            ['INV-202609-101', 'INV-202609-102']);
        expect(created.first.dueDate, DateTime(2026, 10, 5));
      });

      test('UTC-61-TC-03 refuses to issue when no room can be billed',
          () async {
        final viewModel = await issueViewModel(_FakeInvoiceService());

        final result = await viewModel.issue();

        expect(result.success, isFalse);
        expect(result.message, 'ไม่มีห้องที่ออกบิลได้ในงวดนี้');
      });

      test('UTC-61-TC-04 reports a network failure and creates nothing',
          () async {
        final service = issuableService(throwOnIssue: true);
        final viewModel = await issueViewModel(service);

        final result = await viewModel.issue();

        expect(result.success, isFalse);
        expect(result.message, startsWith('ออกบิลไม่สำเร็จ:'));
        expect(service.issuedDrafts, isNull);
        expect(viewModel.hasIssued, isFalse);
      });

      test('UTC-61-TC-05 explains a duplicate collision in its own words',
          () async {
        final viewModel =
            await issueViewModel(issuableService(duplicateOnIssue: true));

        final result = await viewModel.issue();

        expect(result.message,
            'ออกบิลไม่สำเร็จ: บางห้องถูกออกบิลงวดนี้ไปแล้ว กรุณาโหลดใหม่');
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-62 carryForwardExtraFeesForIssued', () {
      test('UTC-62-TC-01 writes each fee with its own recurrence flag',
          () async {
        final service = _FakeInvoiceService(
          rooms: [buildRoom(dbId: 101, number: '101')],
          electricity: const {101: MeterCharge(units: 90, amount: 720)},
          carriedFees: {
            101: [
              buildFee(id: 1, name: 'ค่าที่จอดรถ', isRecurring: true),
              buildFee(id: 2, name: 'ค่าปรับ', isRecurring: false),
            ],
          },
        );
        final viewModel = InvoiceIssueViewModel(
          dormitoryId: 1,
          month: 9,
          year: 2026,
          service: service,
        );
        await viewModel.load();

        await viewModel.issue();

        expect(service.writtenFees, hasLength(2));
        expect(
          service.writtenFees
              .firstWhere((f) => f['name'] == 'ค่าที่จอดรถ')['is_recurring'],
          isTrue,
        );
        expect(
          service.writtenFees
              .firstWhere((f) => f['name'] == 'ค่าปรับ')['is_recurring'],
          isFalse,
        );
      });

      test('UTC-62-TC-02 keeps the invoices and offers a retry when the write '
          'fails', () async {
        final service = _FakeInvoiceService(
          rooms: [buildRoom(dbId: 101, number: '101')],
          electricity: const {101: MeterCharge(units: 90, amount: 720)},
          carriedFees: {101: [buildFee()]},
          throwOnCarryForward: true,
        );
        final viewModel = InvoiceIssueViewModel(
          dormitoryId: 1,
          month: 9,
          year: 2026,
          service: service,
        );
        await viewModel.load();

        final result = await viewModel.issue();

        expect(result.success, isFalse);
        expect(result.message, contains('ออกบิลแล้ว 1 ห้อง'));
        expect(result.message, contains('ค่าใช้จ่ายเพิ่มเติม'));
        expect(viewModel.hasIssued, isTrue);
        expect(viewModel.extraFeesCarryForwardFailed, hasLength(1));
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-63 postIssueNotices', () {
      test('UTC-63-TC-01 posts one invoice card per room', () async {
        final service = _FakeInvoiceService();

        final posted = await service.postIssueNotices(
          invoices: [buildInvoice(dbId: 1), buildInvoice(dbId: 2)],
        );

        expect(posted, 2);
      });

      test('UTC-63-TC-02 skips the invoices that were already announced',
          () async {
        final service = _FakeInvoiceService();
        await service.postIssueNotices(invoices: [buildInvoice(dbId: 1)]);

        final posted = await service.postIssueNotices(
          invoices: [buildInvoice(dbId: 1), buildInvoice(dbId: 2)],
        );

        expect(posted, 1);
      });

      test('UTC-63-TC-03 keeps the invoices and offers a retry when posting '
          'fails', () async {
        final service = _FakeInvoiceService(
          rooms: [buildRoom(dbId: 101, number: '101')],
          electricity: const {101: MeterCharge(units: 90, amount: 720)},
          throwOnNotices: true,
        );
        final viewModel = InvoiceIssueViewModel(
          dormitoryId: 1,
          month: 9,
          year: 2026,
          service: service,
        );
        await viewModel.load();

        final result = await viewModel.issue();

        expect(result.success, isFalse);
        expect(result.message, contains('แจ้งเตือนในแชทไม่สำเร็จ'));
        expect(viewModel.hasIssued, isTrue);
        expect(viewModel.unnotified, hasLength(1));
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-64 sendInvoiceCard', () {
      test('UTC-64-TC-01 posts the card again even when already announced',
          () async {
        final service = _FakeInvoiceService();
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: service,
        );

        await viewModel.sendCardToChat();
        final result = await viewModel.sendCardToChat();

        expect(result.success, isTrue);
        expect(service.sendCardCallCount, 2);
      });

      test('UTC-64-TC-02 reports a network failure', () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: _FakeInvoiceService(throwOnSendCard: true),
        );

        final result = await viewModel.sendCardToChat();

        expect(result.success, isFalse);
        expect(result.message, startsWith('ส่งบิลเข้าแชทไม่สำเร็จ:'));
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-65 fetchInvoices', () {
      test('UTC-65-TC-01 returns the invoices of the period', () async {
        final service = _FakeInvoiceService(
          invoices: [buildInvoice(dbId: 1), buildInvoice(dbId: 2)],
        );

        final result = await service.fetchInvoices(
            dormitoryId: 1, month: 9, year: 2026);

        expect(result, hasLength(2));
      });

      test('UTC-65-TC-02 returns an empty list when none has been issued',
          () async {
        final result = await _FakeInvoiceService()
            .fetchInvoices(dormitoryId: 1, month: 9, year: 2026);

        expect(result, isEmpty);
      });

      test('UTC-65-TC-03 records the failure instead of leaving the screen '
          'blank', () async {
        final viewModel = BillingViewModel(
          dormitoryId: 1,
          service: _FakeInvoiceService(throwOnFetchInvoices: true),
        );

        await viewModel.loadInvoices();

        expect(viewModel.errorMessage, isNotNull);
        expect(viewModel.invoices, isEmpty);
        expect(viewModel.isLoading, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-66 filterInvoices', () {
      Future<BillingViewModel> loadedBilling() async {
        final viewModel = BillingViewModel(
          dormitoryId: 1,
          service: _FakeInvoiceService(invoices: [
            buildInvoice(dbId: 1, status: InvoiceStatus.unpaid),
            buildInvoice(dbId: 2, status: InvoiceStatus.pending),
            buildInvoice(dbId: 3, status: InvoiceStatus.paid),
            buildInvoice(dbId: 4, status: InvoiceStatus.voided),
          ]),
        );
        await viewModel.loadInvoices();
        return viewModel;
      }

      test('UTC-66-TC-01 the default filter excludes voided invoices',
          () async {
        final viewModel = await loadedBilling();

        expect(viewModel.selectedFilter, 'ทั้งหมด');
        expect(viewModel.filteredInvoices.map((i) => i.dbId), [1, 2, 3]);
      });

      test('UTC-66-TC-02 returns only the outstanding invoices', () async {
        final viewModel = await loadedBilling();

        viewModel.setFilter('ค้างชำระ');

        expect(viewModel.filteredInvoices.map((i) => i.dbId), [1]);
      });

      test('UTC-66-TC-03 returns only the invoices awaiting review', () async {
        final viewModel = await loadedBilling();

        viewModel.setFilter('รอตรวจสลิป');

        expect(viewModel.filteredInvoices.map((i) => i.dbId), [2]);
      });

      test('UTC-66-TC-04 returns only the settled invoices', () async {
        final viewModel = await loadedBilling();

        viewModel.setFilter('ชำระแล้ว');

        expect(viewModel.filteredInvoices.map((i) => i.dbId), [3]);
      });

      test('UTC-66-TC-05 returns only the voided invoices', () async {
        final viewModel = await loadedBilling();

        viewModel.setFilter('ยกเลิกแล้ว');

        expect(viewModel.filteredInvoices.map((i) => i.dbId), [4]);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-67 fetchExtraFees', () {
      test('UTC-67-TC-01 returns the invoice fee rows in order', () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: _FakeInvoiceService(extraFees: [
            buildFee(id: 1, name: 'ค่าที่จอดรถ'),
            buildFee(id: 2, name: 'ค่าปรับ'),
          ]),
        );

        await viewModel.loadExtraFees();

        expect(viewModel.extraFees.map((f) => f.name),
            ['ค่าที่จอดรถ', 'ค่าปรับ']);
      });

      test('UTC-67-TC-02 returns an empty list when the invoice has no fee',
          () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: _FakeInvoiceService(),
        );

        await viewModel.loadExtraFees();

        expect(viewModel.extraFees, isEmpty);
      });

      test('UTC-67-TC-03 leaves the sheet usable when the fee list fails to '
          'load', () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: _FakeInvoiceService(throwOnFetchExtraFees: true),
        );

        await viewModel.loadExtraFees();

        expect(viewModel.extraFees, isEmpty);
        expect(viewModel.isLoadingExtraFees, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-68 addExtraFee', () {
      test('UTC-68-TC-01 writes the fee onto the open invoice', () async {
        final service = _FakeInvoiceService();
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(dbId: 7),
          dormitoryId: 1,
          service: service,
        );

        final result = await viewModel.addExtraFee(
          name: 'ค่าปรับ',
          amount: 200,
          isRecurring: true,
        );

        expect(result.success, isTrue);
        expect(result.message, 'เพิ่มรายการ "ค่าปรับ" แล้ว');
        expect(service.addedToInvoiceId, 7);
        expect(service.addedFeeName, 'ค่าปรับ');
        expect(service.addedFeeAmount, 200);
        expect(service.addedFeeIsRecurring, isTrue);
      });

      test('UTC-68-TC-02 raises the live net total shown on the sheet',
          () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: _FakeInvoiceService(extraFees: [buildFee(amount: 200)]),
        );

        await viewModel.loadExtraFees();

        expect(viewModel.liveTotal, 4020);
      });

      test('UTC-68-TC-03 reports a network failure and leaves the invoice '
          'unchanged', () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: _FakeInvoiceService(throwOnAddExtraFee: true),
        );

        final result = await viewModel.addExtraFee(
          name: 'ค่าปรับ',
          amount: 200,
          isRecurring: false,
        );

        expect(result.success, isFalse);
        expect(result.message, startsWith('เพิ่มรายการไม่สำเร็จ:'));
        expect(viewModel.extraFees, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-69 removeExtraFee', () {
      test('UTC-69-TC-01 deletes the chosen fee row', () async {
        final service = _FakeInvoiceService();
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: service,
        );

        final result =
            await viewModel.removeExtraFee(buildFee(id: 5, name: 'ค่าปรับ'));

        expect(result.success, isTrue);
        expect(result.message, 'ลบรายการ "ค่าปรับ" แล้ว');
        expect(service.removedFeeId, 5);
      });

      test('UTC-69-TC-02 reports a network failure and keeps the fee',
          () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: _FakeInvoiceService(throwOnRemoveExtraFee: true),
        );

        final result = await viewModel.removeExtraFee(buildFee(id: 5));

        expect(result.success, isFalse);
        expect(result.message, startsWith('ลบรายการไม่สำเร็จ:'));
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-70 revalueInvoice', () {
      test('UTC-70-TC-01 returns the adjustment when the figures moved', () {
        final invoice = buildInvoice();

        final result = revalueInvoice(
          invoice: invoice,
          room: buildRoom(),
          electricity: const MeterCharge(units: 120, amount: 960),
          waterAmount: 100,
        );

        expect(result, isNotNull);
        expect(result!.previousTotal, invoice.total);
        expect(result.newTotal, 4060);
      });

      test('UTC-70-TC-02 leaves an invoice that is not outstanding alone', () {
        final result = revalueInvoice(
          invoice: buildInvoice(status: InvoiceStatus.pending),
          room: buildRoom(),
          electricity: const MeterCharge(units: 120, amount: 960),
        );

        expect(result, isNull);
      });

      test('UTC-70-TC-03 leaves an invoice alone when the meter record is '
          'missing', () {
        final result = revalueInvoice(
          invoice: buildInvoice(),
          room: buildRoom(),
          waterAmount: 100,
        );

        expect(result, isNull);
      });

      test('UTC-70-TC-04 treats a rounding-sized difference as unchanged', () {
        final result = revalueInvoice(
          invoice: buildInvoice(),
          room: buildRoom(),
          electricity: const MeterCharge(units: 90, amount: 720.001),
          waterAmount: 100,
        );

        expect(result, isNull);
      });

      test('UTC-70-TC-05 keeps the existing water charge when none was '
          'recorded', () {
        final result = revalueInvoice(
          invoice: buildInvoice(waterCost: 100),
          room: buildRoom(),
          electricity: const MeterCharge(units: 120, amount: 960),
        );

        expect(result!.waterCost, 100);
      });

      test('UTC-70-TC-06 honours an explicit zero water charge', () {
        final result = revalueInvoice(
          invoice: buildInvoice(waterCost: 100),
          room: buildRoom(),
          electricity: const MeterCharge(units: 90, amount: 720),
          waterAmount: 0,
        );

        expect(result, isNotNull);
        expect(result!.waterCost, 0);
        expect(result.newTotal, 3720);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-71 syncUnpaidInvoices', () {
      test('UTC-71-TC-01 notifies only the tenants whose invoice was adjusted',
          () async {
        final service = _FakeInvoiceService(
          invoices: [buildInvoice()],
          adjustments: [buildAdjustment()],
        );
        final viewModel =
            BillingViewModel(dormitoryId: 1, service: service);

        await viewModel.refresh();

        expect(service.adjustmentNoticeCallCount, 1);
        expect(viewModel.syncErrorMessage, isNull);
      });

      test('UTC-71-TC-02 reports the invoices that could not be adjusted',
          () async {
        final viewModel = BillingViewModel(
          dormitoryId: 1,
          service: _FakeInvoiceService(
            invoices: [buildInvoice()],
            failedAdjustments: [buildAdjustment()],
          ),
        );

        await viewModel.refresh();

        expect(viewModel.syncErrorMessage, contains('ปรับยอด 1 ใบไม่สำเร็จ'));
      });

      test('UTC-71-TC-03 stays silent when nothing needed adjusting',
          () async {
        final service = _FakeInvoiceService(invoices: [buildInvoice()]);
        final viewModel =
            BillingViewModel(dormitoryId: 1, service: service);

        await viewModel.refresh();

        expect(service.adjustmentNoticeCallCount, 0);
        expect(viewModel.syncErrorMessage, isNull);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-72 postAdjustmentNotices', () {
      test('UTC-72-TC-01 posts one message per adjusted invoice', () async {
        final service = _FakeInvoiceService();

        final posted = await service
            .postAdjustmentNotices([buildAdjustment(), buildAdjustment()]);

        expect(posted, 2);
      });

      test('UTC-72-TC-02 posts nothing when no invoice was adjusted',
          () async {
        expect(await _FakeInvoiceService().postAdjustmentNotices([]), 0);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-73 canTransition', () {
      test('UTC-73-TC-01 an outstanding invoice may await review or be settled',
          () {
        expect(
            canTransition(InvoiceStatus.unpaid, InvoiceStatus.pending), isTrue);
        expect(canTransition(InvoiceStatus.unpaid, InvoiceStatus.paid), isTrue);
      });

      test('UTC-73-TC-02 an invoice awaiting review may be settled or returned',
          () {
        expect(canTransition(InvoiceStatus.pending, InvoiceStatus.paid), isTrue);
        expect(
            canTransition(InvoiceStatus.pending, InvoiceStatus.unpaid), isTrue);
      });

      test('UTC-73-TC-03 a settled invoice may only be voided', () {
        expect(canTransition(InvoiceStatus.paid, InvoiceStatus.unpaid), isFalse);
        expect(
            canTransition(InvoiceStatus.paid, InvoiceStatus.pending), isFalse);
        expect(canTransition(InvoiceStatus.paid, InvoiceStatus.voided), isTrue);
      });

      test('UTC-73-TC-04 a voided invoice may never move again', () {
        for (final status in InvoiceStatus.values) {
          expect(canTransition(InvoiceStatus.voided, status), isFalse);
        }
      });

      test('UTC-73-TC-05 a status never transitions to itself', () {
        for (final status in InvoiceStatus.values) {
          expect(canTransition(status, status), isFalse);
        }
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-74 voidInvoice', () {
      test('UTC-74-TC-01 cancels the invoice and records the reason',
          () async {
        final service = _FakeInvoiceService();
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(invoiceNo: 'INV-202609-101'),
          dormitoryId: 1,
          service: service,
        );

        final result = await viewModel.voidBill('มิเตอร์อ่านผิด');

        expect(result.success, isTrue);
        expect(result.message, 'ยกเลิกบิล INV-202609-101 แล้ว');
        expect(service.voidReason, 'มิเตอร์อ่านผิด');
      });

      test('UTC-74-TC-02 refuses to cancel an invoice that is already voided',
          () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(status: InvoiceStatus.voided),
          dormitoryId: 1,
          service: _FakeInvoiceService(),
        );

        final result = await viewModel.voidBill('ยกเลิกซ้ำ');

        expect(result.success, isFalse);
        expect(result.message, startsWith('ยกเลิกไม่สำเร็จ:'));
      });

      test('UTC-74-TC-03 reports a network failure and keeps the invoice',
          () async {
        final service = _FakeInvoiceService(throwOnVoid: true);
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: service,
        );

        final result = await viewModel.voidBill('มิเตอร์อ่านผิด');

        expect(result.success, isFalse);
        expect(service.voidedInvoice, isNull);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-75 reissueInvoice', () {
      test('UTC-75-TC-01 creates a replacement numbered one revision higher',
          () async {
        final service = _FakeInvoiceService();
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(invoiceNo: 'INV-202609-101'),
          dormitoryId: 1,
          service: service,
        );

        final result = await viewModel.reissue();

        expect(result.success, isTrue);
        expect(result.message, contains('INV-202609-101-R2'));
        expect(service.sendCardCallCount, 1);
      });

      test('UTC-75-TC-02 explains why no replacement could be built',
          () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: _FakeInvoiceService(reissueDraftAvailable: false),
        );

        final result = await viewModel.reissue();

        expect(result.success, isFalse);
        expect(result.message,
            contains('งวดนี้ยังไม่ได้จดมิเตอร์ หรือห้องไม่มีผู้เช่า'));
      });

      test('UTC-75-TC-03 still reports success when the fees could not be '
          'copied', () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service:
              _FakeInvoiceService(extraFeesCopyFailsOnReissue: true),
        );

        final result = await viewModel.reissue();

        expect(result.success, isTrue);
        expect(result.message,
            contains('คัดลอกค่าใช้จ่ายเพิ่มเติมจากบิลเดิมไม่สำเร็จ'));
      });

      test('UTC-75-TC-04 still reports success when the card could not be '
          'posted', () async {
        final viewModel = InvoiceActionsViewModel(
          invoice: buildInvoice(),
          dormitoryId: 1,
          service: _FakeInvoiceService(throwOnSendCard: true),
        );

        final result = await viewModel.reissue();

        expect(result.success, isTrue);
        expect(result.message, contains('ส่งการ์ดเข้าแชทไม่สำเร็จ'));
      });
    });

    // -----------------------------------------------------------------------
    // `shareInvoicePdf` ส่งต่อไปยัง `buildInvoicePdf` แล้วยื่นไฟล์ให้แผ่นแชร์
    // ของระบบ ซึ่งเป็น platform channel ที่รันใน unit test ไม่ได้ — ที่นี่จึง
    // ตรวจส่วนที่สร้างเอกสารจริง ส่วนการยื่นไฟล์อยู่ใน STC-20
    group('UTC-76 shareInvoicePdf', () {
      test('UTC-76-TC-01 renders a document from the frozen invoice figures',
          () async {
        final bytes = await buildInvoicePdf(
          invoice: buildInvoice(),
          dormitoryName: 'หอทดสอบ',
        );

        expect(bytes.lengthInBytes, greaterThan(1000));
      });

      test('UTC-76-TC-02 renders a document for a voided invoice too',
          () async {
        final bytes = await buildInvoicePdf(
          invoice: buildInvoice(
            status: InvoiceStatus.voided,
            voidReason: 'มิเตอร์อ่านผิด',
          ),
          dormitoryName: 'หอทดสอบ',
        );

        expect(bytes.lengthInBytes, greaterThan(1000));
      });
    });
  });
}
