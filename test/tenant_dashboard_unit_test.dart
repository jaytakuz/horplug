import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/models/picked_image.dart';
import 'package:horplug/models/quick_action.dart';
import 'package:horplug/services/quick_action_store.dart';
import 'package:horplug/services/supabase_service.dart';
import 'package:horplug/services/tenant_billing_source.dart';
import 'package:horplug/viewmodels/action_result.dart';
import 'package:horplug/viewmodels/quick_actions_view_model.dart';
import 'package:horplug/viewmodels/tenant_dashboard_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

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
  double total = 3820,
  InvoiceStatus status = InvoiceStatus.unpaid,
  PaymentMethod? paymentMethod,
}) =>
    Invoice(
      dbId: dbId,
      invoiceNo: invoiceNo,
      roomDbId: roomDbId,
      roomNumber: roomNumber,
      tenantName: 'สมชาย ใจดี',
      billingMonth: billingMonth,
      billingYear: billingYear,
      roomPrice: roomPrice,
      electricityUnits: electricityUnits,
      electricityCost: electricityCost,
      waterCost: waterCost,
      total: total,
      status: status,
      paymentMethod: paymentMethod,
      dueDate: DateTime(billingYear, billingMonth + 1, 5),
      issuedAt: DateTime(billingYear, billingMonth, 28),
    );

MaintenanceRequest buildRequest({
  int id = 1,
  String description = 'ก๊อกน้ำรั่ว',
  MaintenanceRequestType requestType = MaintenanceRequestType.repair,
  MaintenanceStatus status = MaintenanceStatus.pending,
}) =>
    MaintenanceRequest(
      id: id,
      roomId: 101,
      roomNumber: '101',
      tenantId: 'tenant-uuid',
      tenantName: 'สมชาย ใจดี',
      requestType: requestType,
      description: description,
      status: status,
      requestedAt: DateTime(2026, 9, 1),
    );

TenantJoinRequest buildJoinRequest({int id = 1}) => TenantJoinRequest(
      id: id,
      tenantId: 'tenant-uuid',
      landlordId: 'landlord-uuid',
      dormitoryId: 1,
      requestedRoomId: 101,
      dormitoryName: 'หอทดสอบ',
      landlordName: 'สมหญิง เจ้าของหอ',
      roomNumber: '101',
      status: JoinRequestStatus.pending,
      createdAt: DateTime(2026, 9, 1),
    );

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// แหล่งข้อมูลบิลปลอมของฝั่งผู้เช่า — [TenantBillingSource] ถูกทำเป็น abstract
/// ไว้ให้ทดสอบได้โดยไม่ต้องมี Supabase client จริง
class _FakeBillingSource implements TenantBillingSource {
  _FakeBillingSource({
    this.currentBill,
    this.history = const [],
    this.throwOnCurrentBill = false,
    this.throwOnHistory = false,
  });

  final Invoice? currentBill;
  final List<Invoice> history;
  final bool throwOnCurrentBill;
  final bool throwOnHistory;

  int? requestedMonthCount;

  @override
  Future<Invoice?> fetchCurrentBill({
    required int roomDbId,
    required int month,
    required int year,
  }) async {
    if (throwOnCurrentBill) throw const SocketException('Failed host lookup');
    return currentBill;
  }

  @override
  Future<List<Invoice>> fetchBillHistory({
    required int roomDbId,
    int monthCount = 6,
  }) async {
    requestedMonthCount = monthCount;
    if (throwOnHistory) throw const SocketException('Failed host lookup');
    return history;
  }

  @override
  Future<PaymentChannel?> fetchPaymentChannel({required int dormitoryId}) async =>
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

class _FakeTenantService extends SupabaseService {
  _FakeTenantService({
    this.requests = const [],
    this.joinRequests = const [],
    this.throwOnMaintenance = false,
    this.throwOnJoinRequests = false,
    this.throwOnCreate = false,
  });

  final List<MaintenanceRequest> requests;
  final List<TenantJoinRequest> joinRequests;
  final bool throwOnMaintenance;
  final bool throwOnJoinRequests;
  final bool throwOnCreate;

  int maintenanceCallCount = 0;
  int? createdRoomId;
  String? createdTenantId;
  String? createdDescription;
  MaintenanceRequestType? createdRequestType;

  @override
  Future<List<MaintenanceRequest>> fetchMaintenanceRequests({
    required int roomId,
  }) async {
    maintenanceCallCount++;
    if (throwOnMaintenance) throw const SocketException('Failed host lookup');
    return requests;
  }

  @override
  Future<List<TenantJoinRequest>> fetchPendingJoinRequestsForTenant() async {
    if (throwOnJoinRequests) throw const SocketException('Failed host lookup');
    return joinRequests;
  }

  @override
  Future<void> createMaintenanceRequest({
    required int roomId,
    required String tenantId,
    required String description,
    MaintenanceRequestType requestType = MaintenanceRequestType.repair,
  }) async {
    if (throwOnCreate) throw const SocketException('Failed host lookup');
    createdRoomId = roomId;
    createdTenantId = tenantId;
    createdDescription = description;
    createdRequestType = requestType;
  }
}

TenantDashboardViewModel buildDashboard({
  int? roomId = 101,
  String? tenantId = 'tenant-uuid',
  SupabaseService? service,
  TenantBillingSource? billingSource,
}) =>
    TenantDashboardViewModel(
      roomId: roomId,
      dormitoryId: 1,
      tenantId: tenantId,
      service: service ?? _FakeTenantService(),
      billingSource: billingSource ?? _FakeBillingSource(),
    );

QuickActionsViewModel<QuickAction> buildQuickActions({
  String userId = 'tenant-uuid',
  SharedPreferences? preferences,
}) =>
    QuickActionsViewModel<QuickAction>(
      userId: userId,
      store: QuickActionStore<QuickAction>(
        catalog: tenantQuickActions,
        preferences: preferences,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Feature 7: Dashboard for Tenant', () {
    // -----------------------------------------------------------------------
    group('UTC-42 loadTenantDashboard', () {
      test('UTC-42-TC-01 loads every section when the tenant has a room',
          () async {
        final viewModel = buildDashboard(
          service: _FakeTenantService(requests: [buildRequest()]),
          billingSource: _FakeBillingSource(
            currentBill: buildInvoice(),
            history: [
              buildInvoice(electricityUnits: 90),
              buildInvoice(electricityUnits: 60),
            ],
          ),
        );

        await viewModel.load();

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.currentBill, isNotNull);
        expect(viewModel.electricityTrend, isNotNull);
        expect(viewModel.openRequests, hasLength(1));
        expect(viewModel.billErrorMessage, isNull);
        expect(viewModel.maintenanceErrorMessage, isNull);
      });

      test(
          'UTC-42-TC-02 loads only the join requests when the tenant has no room',
          () async {
        final service = _FakeTenantService(joinRequests: [buildJoinRequest()]);
        final viewModel = buildDashboard(roomId: null, service: service);

        await viewModel.load();

        expect(viewModel.pendingRequests, hasLength(1));
        expect(viewModel.currentBill, isNull);
        expect(viewModel.openRequests, isEmpty);
        expect(service.maintenanceCallCount, 0);
      });

      test(
          'UTC-42-TC-03 a failing bill section leaves the other sections intact',
          () async {
        final viewModel = buildDashboard(
          service: _FakeTenantService(requests: [buildRequest()]),
          billingSource: _FakeBillingSource(throwOnCurrentBill: true),
        );

        await viewModel.load();

        expect(viewModel.billErrorMessage, isNotNull);
        expect(viewModel.currentBill, isNull);
        expect(viewModel.openRequests, hasLength(1));
        expect(viewModel.maintenanceErrorMessage, isNull);
      });

      test('UTC-42-TC-04 records each failure per section instead of throwing',
          () async {
        final viewModel = buildDashboard(
          service: _FakeTenantService(throwOnMaintenance: true),
          billingSource: _FakeBillingSource(
            throwOnCurrentBill: true,
            throwOnHistory: true,
          ),
        );

        await viewModel.load();

        expect(viewModel.billErrorMessage, isNotNull);
        expect(viewModel.usageErrorMessage, isNotNull);
        expect(viewModel.maintenanceErrorMessage, isNotNull);
        expect(viewModel.isLoading, isFalse);
      });

      test('UTC-42-TC-05 a failing join-request section still loads the room '
          'sections', () async {
        final viewModel = buildDashboard(
          service: _FakeTenantService(
            throwOnJoinRequests: true,
            requests: [buildRequest()],
          ),
          billingSource: _FakeBillingSource(currentBill: buildInvoice()),
        );

        await viewModel.load();

        expect(viewModel.requestErrorMessage, isNotNull);
        expect(viewModel.pendingRequests, isEmpty);
        expect(viewModel.currentBill, isNotNull);
        expect(viewModel.openRequests, hasLength(1));
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-43 fetchCurrentBill', () {
      test('UTC-43-TC-01 returns the invoice issued for the period', () async {
        final source = _FakeBillingSource(currentBill: buildInvoice());

        final result = await source.fetchCurrentBill(
          roomDbId: 101,
          month: 9,
          year: 2026,
        );

        expect(result, isNotNull);
        expect(result!.invoiceNo, 'INV-202609-101');
      });

      test('UTC-43-TC-02 returns null when no invoice has been issued',
          () async {
        final source = _FakeBillingSource();

        final result = await source.fetchCurrentBill(
          roomDbId: 101,
          month: 9,
          year: 2026,
        );

        expect(result, isNull);
      });

      test('UTC-43-TC-03 throws when the network is unavailable', () {
        final source = _FakeBillingSource(throwOnCurrentBill: true);

        expect(
          () => source.fetchCurrentBill(roomDbId: 101, month: 9, year: 2026),
          throwsA(isA<SocketException>()),
        );
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-44 fetchBillHistory', () {
      test('UTC-44-TC-01 returns the room history newest period first',
          () async {
        final source = _FakeBillingSource(history: [
          buildInvoice(invoiceNo: 'INV-202609-101', billingMonth: 9),
          buildInvoice(invoiceNo: 'INV-202608-101', billingMonth: 8),
        ]);

        final result = await source.fetchBillHistory(roomDbId: 101);

        expect(result.map((i) => i.billingMonth), [9, 8]);
      });

      test('UTC-44-TC-02 returns an empty list when never invoiced', () async {
        final source = _FakeBillingSource();

        expect(await source.fetchBillHistory(roomDbId: 101), isEmpty);
      });

      test('UTC-44-TC-03 the dashboard requests only the last two periods',
          () async {
        final source = _FakeBillingSource(history: [
          buildInvoice(electricityUnits: 90),
          buildInvoice(electricityUnits: 60),
        ]);

        await buildDashboard(billingSource: source).load();

        expect(source.requestedMonthCount, 2);
      });

      test('UTC-44-TC-04 throws when the network is unavailable', () {
        final source = _FakeBillingSource(throwOnHistory: true);

        expect(
          () => source.fetchBillHistory(roomDbId: 101),
          throwsA(isA<SocketException>()),
        );
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-45 utilityTrend', () {
      test('UTC-45-TC-01 reports an increase against the previous period', () {
        final trend = utilityTrend(current: 90, previous: 60);

        expect(trend.direction, TrendDirection.up);
        expect(trend.delta, 30);
        expect(trend.percent, closeTo(50, 0.001));
      });

      test('UTC-45-TC-02 reports a decrease against the previous period', () {
        final trend = utilityTrend(current: 45, previous: 60);

        expect(trend.direction, TrendDirection.down);
        expect(trend.delta, -15);
        expect(trend.percent, closeTo(-25, 0.001));
      });

      test('UTC-45-TC-03 reports no change when both periods are equal', () {
        final trend = utilityTrend(current: 60, previous: 60);

        expect(trend.direction, TrendDirection.flat);
        expect(trend.delta, 0);
      });

      test('UTC-45-TC-04 leaves the percentage undefined when the previous '
          'period is zero', () {
        final trend = utilityTrend(current: 60, previous: 0);

        expect(trend.direction, TrendDirection.up);
        expect(trend.delta, 60);
        expect(trend.percent, isNull);
      });

      test('UTC-45-TC-05 the dashboard omits the trend with fewer than two '
          'periods', () async {
        final viewModel = buildDashboard(
          billingSource: _FakeBillingSource(
            currentBill: buildInvoice(),
            history: [buildInvoice()],
          ),
        );

        await viewModel.load();

        expect(viewModel.electricityTrend, isNull);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-46 loadOpenMaintenanceRequests', () {
      test('UTC-46-TC-01 keeps the requests that are still outstanding',
          () async {
        final viewModel = buildDashboard(
          service: _FakeTenantService(requests: [
            buildRequest(id: 1, status: MaintenanceStatus.pending),
            buildRequest(id: 2, status: MaintenanceStatus.inProgress),
          ]),
        );

        await viewModel.load();

        expect(viewModel.openRequests.map((r) => r.id), [1, 2]);
      });

      test('UTC-46-TC-02 excludes Completed and Cancelled requests', () async {
        final viewModel = buildDashboard(
          service: _FakeTenantService(requests: [
            buildRequest(id: 1, status: MaintenanceStatus.pending),
            buildRequest(id: 2, status: MaintenanceStatus.completed),
            buildRequest(id: 3, status: MaintenanceStatus.cancelled),
          ]),
        );

        await viewModel.load();

        expect(viewModel.openRequests.map((r) => r.id), [1]);
      });

      test('UTC-46-TC-03 returns an empty list when nothing is outstanding',
          () async {
        final viewModel = buildDashboard(
          service: _FakeTenantService(requests: [
            buildRequest(id: 1, status: MaintenanceStatus.completed),
          ]),
        );

        await viewModel.load();

        expect(viewModel.openRequests, isEmpty);
      });

      test('UTC-46-TC-04 records the failure as the maintenance section error',
          () async {
        final viewModel = buildDashboard(
          service: _FakeTenantService(throwOnMaintenance: true),
        );

        await viewModel.load();

        expect(viewModel.maintenanceErrorMessage, isNotNull);
        expect(viewModel.openRequests, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-47 submitMaintenanceRequest', () {
      test('UTC-47-TC-01 creates the request and confirms it to the tenant',
          () async {
        final service = _FakeTenantService();
        final viewModel = buildDashboard(service: service);

        final result = await viewModel.submitMaintenanceRequest(
          description: 'ก๊อกน้ำรั่ว',
          requestType: MaintenanceRequestType.repair,
        );

        expect(result.success, isTrue);
        expect(result.message, 'ส่งคำขอแล้ว เจ้าของหอจะติดต่อกลับ');
        expect(service.createdRoomId, 101);
        expect(service.createdTenantId, 'tenant-uuid');
        expect(service.createdRequestType, MaintenanceRequestType.repair);
      });

      test('UTC-47-TC-02 trims the description before creating the request',
          () async {
        final service = _FakeTenantService();
        final viewModel = buildDashboard(service: service);

        await viewModel.submitMaintenanceRequest(
          description: '   ก๊อกน้ำรั่ว   ',
          requestType: MaintenanceRequestType.cleaning,
        );

        expect(service.createdDescription, 'ก๊อกน้ำรั่ว');
        expect(service.createdRequestType, MaintenanceRequestType.cleaning);
      });

      test('UTC-47-TC-03 reloads the outstanding request list on success',
          () async {
        final service = _FakeTenantService(requests: [buildRequest()]);
        final viewModel = buildDashboard(service: service);
        await viewModel.load();
        final callsAfterLoad = service.maintenanceCallCount;

        await viewModel.submitMaintenanceRequest(
          description: 'แอร์เสีย',
          requestType: MaintenanceRequestType.repair,
        );

        expect(service.maintenanceCallCount, callsAfterLoad + 1);
      });

      test('UTC-47-TC-04 rejects the request when the tenant has no room',
          () async {
        final viewModel = buildDashboard(roomId: null);

        final result = await viewModel.submitMaintenanceRequest(
          description: 'ก๊อกน้ำรั่ว',
          requestType: MaintenanceRequestType.repair,
        );

        expect(result.success, isFalse);
        expect(result.message, 'ยังไม่ได้เข้าพักในห้องใด');
      });

      test('UTC-47-TC-05 reports a network failure without changing the list',
          () async {
        final viewModel = buildDashboard(
          service: _FakeTenantService(throwOnCreate: true),
        );

        final result = await viewModel.submitMaintenanceRequest(
          description: 'ก๊อกน้ำรั่ว',
          requestType: MaintenanceRequestType.repair,
        );

        expect(result.success, isFalse);
        expect(result.message, startsWith('ส่งคำขอไม่สำเร็จ:'));
        expect(viewModel.openRequests, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-48 loadQuickActions', () {
      test('UTC-48-TC-01 returns the defaults when nothing has been saved',
          () async {
        final viewModel = buildQuickActions();

        await viewModel.load();

        expect(viewModel.actions, defaultQuickActions);
      });

      test('UTC-48-TC-02 returns the saved arrangement in its saved order',
          () async {
        SharedPreferences.setMockInitialValues({
          'quick_actions.tenant-uuid': ['openChat', 'reportRepair'],
        });
        final viewModel = buildQuickActions();

        await viewModel.load();

        expect(viewModel.actions,
            [QuickAction.openChat, QuickAction.reportRepair]);
      });

      test('UTC-48-TC-03 keeps a deliberately emptied arrangement empty',
          () async {
        SharedPreferences.setMockInitialValues({
          'quick_actions.tenant-uuid': <String>[],
        });
        final viewModel = buildQuickActions();

        await viewModel.load();

        expect(viewModel.actions, isEmpty);
      });

      test('UTC-48-TC-04 drops entries that are no longer recognised',
          () async {
        SharedPreferences.setMockInitialValues({
          'quick_actions.tenant-uuid': ['reportRepair', 'removedInV2'],
        });
        final viewModel = buildQuickActions();

        await viewModel.load();

        expect(viewModel.actions, [QuickAction.reportRepair]);
      });

      test('UTC-48-TC-05 falls back to the defaults when no entry is '
          'recognised', () async {
        SharedPreferences.setMockInitialValues({
          'quick_actions.tenant-uuid': ['removedInV2', 'alsoRemoved'],
        });
        final viewModel = buildQuickActions();

        await viewModel.load();

        expect(viewModel.actions, defaultQuickActions);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-49 saveQuickActions', () {
      test('UTC-49-TC-01 writes the arrangement under the role and user key',
          () async {
        final preferences = await SharedPreferences.getInstance();
        final store = QuickActionStore<QuickAction>(
          catalog: tenantQuickActions,
          preferences: preferences,
        );

        await store.save('tenant-uuid', [QuickAction.openChat]);

        expect(preferences.getStringList('quick_actions.tenant-uuid'),
            ['openChat']);
      });

      test('UTC-49-TC-02 writes at most the maximum number of shortcuts',
          () async {
        final preferences = await SharedPreferences.getInstance();
        final store = QuickActionStore<QuickAction>(
          catalog: tenantQuickActions,
          preferences: preferences,
        );

        await store.save('tenant-uuid', QuickAction.values);

        expect(
          preferences.getStringList('quick_actions.tenant-uuid'),
          hasLength(maxQuickActions),
        );
      });

      test('UTC-49-TC-03 two accounts on one device do not share an '
          'arrangement', () async {
        final preferences = await SharedPreferences.getInstance();
        final store = QuickActionStore<QuickAction>(
          catalog: tenantQuickActions,
          preferences: preferences,
        );

        await store.save('tenant-a', [QuickAction.openChat]);
        await store.save('tenant-b', [QuickAction.openBills]);

        expect(await store.load('tenant-a'), [QuickAction.openChat]);
        expect(await store.load('tenant-b'), [QuickAction.openBills]);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-50 addQuickAction', () {
      test('UTC-50-TC-01 appends the shortcut to the end of the arrangement',
          () async {
        final viewModel = buildQuickActions();
        await viewModel.load();

        await viewModel.add(QuickAction.openChat);

        expect(viewModel.actions.last, QuickAction.openChat);
        expect(viewModel.actions, hasLength(defaultQuickActions.length + 1));
      });

      test('UTC-50-TC-02 ignores a shortcut that is already selected',
          () async {
        final viewModel = buildQuickActions();
        await viewModel.load();

        await viewModel.add(QuickAction.reportRepair);

        expect(viewModel.actions, defaultQuickActions);
      });

      test('UTC-50-TC-03 refuses to add beyond the maximum', () async {
        SharedPreferences.setMockInitialValues({
          'quick_actions.tenant-uuid':
              QuickAction.values.take(maxQuickActions).map((a) => a.name).toList(),
        });
        final viewModel = buildQuickActions();
        await viewModel.load();

        expect(viewModel.canAddMore, isFalse);
        expect(viewModel.available, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-51 removeQuickAction', () {
      test('UTC-51-TC-01 removes the shortcut and returns it to the available '
          'list', () async {
        final viewModel = buildQuickActions();
        await viewModel.load();

        await viewModel.remove(QuickAction.payLatestBill);

        expect(viewModel.actions, isNot(contains(QuickAction.payLatestBill)));
        expect(viewModel.available, contains(QuickAction.payLatestBill));
      });

      test('UTC-51-TC-02 allows every shortcut to be removed and persists the '
          'empty arrangement', () async {
        final preferences = await SharedPreferences.getInstance();
        final viewModel = buildQuickActions(preferences: preferences);
        await viewModel.load();

        for (final action in [...viewModel.actions]) {
          await viewModel.remove(action);
        }

        expect(viewModel.actions, isEmpty);
        expect(preferences.getStringList('quick_actions.tenant-uuid'), isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-52 reorderQuickAction', () {
      test('UTC-52-TC-01 moves a shortcut towards the end of the list',
          () async {
        final viewModel = buildQuickActions();
        await viewModel.load();
        final first = viewModel.actions.first;

        await viewModel.reorder(0, 2);

        expect(viewModel.actions[2], first);
        expect(viewModel.actions, hasLength(defaultQuickActions.length));
      });

      test('UTC-52-TC-02 moves a shortcut towards the start of the list',
          () async {
        final viewModel = buildQuickActions();
        await viewModel.load();
        final last = viewModel.actions.last;

        await viewModel.reorder(viewModel.actions.length - 1, 0);

        expect(viewModel.actions.first, last);
      });

      test('UTC-52-TC-03 does nothing when the position is unchanged',
          () async {
        final viewModel = buildQuickActions();
        await viewModel.load();
        final before = [...viewModel.actions];

        await viewModel.reorder(1, 1);

        expect(viewModel.actions, before);
      });
    });

    // -----------------------------------------------------------------------
    group('UTC-53 resetQuickActionsToDefault', () {
      test('UTC-53-TC-01 restores the default arrangement', () async {
        SharedPreferences.setMockInitialValues({
          'quick_actions.tenant-uuid': ['openChat'],
        });
        final viewModel = buildQuickActions();
        await viewModel.load();

        await viewModel.resetToDefault();

        expect(viewModel.actions, defaultQuickActions);
      });

      test('UTC-53-TC-02 clears the saved key so the defaults survive a '
          'restart', () async {
        final preferences = await SharedPreferences.getInstance();
        await preferences
            .setStringList('quick_actions.tenant-uuid', ['openChat']);
        final viewModel = buildQuickActions(preferences: preferences);
        await viewModel.load();

        await viewModel.resetToDefault();

        expect(preferences.getStringList('quick_actions.tenant-uuid'), isNull);
      });
    });
  });
}
