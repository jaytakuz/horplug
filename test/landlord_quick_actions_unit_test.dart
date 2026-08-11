import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/landlord_quick_action.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/models/quick_action.dart';
import 'package:horplug/services/invoice_service.dart';
import 'package:horplug/services/quick_action_store.dart';
import 'package:horplug/services/supabase_service.dart';
import 'package:horplug/viewmodels/dashboard_view_model.dart';
import 'package:horplug/viewmodels/quick_actions_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSupabaseService extends SupabaseService {
  @override
  Future<List<Room>> fetchRooms({int? dormitoryId, int? roomDbId}) async => [
        Room(
          dbId: 1,
          id: '301',
          floor: '3',
          status: RoomStatus.occupied,
          currentTenantId: 'tenant-uuid',
          tenantName: 'สมชาย ใจดี',
          price: 3500,
        ),
      ];

  @override
  Future<List<Tenant>> fetchAvailableTenants() async => [];

  @override
  Future<int> countUnreadMessages({required int dormitoryId}) async => 2;
}

class _FakeInvoiceService extends InvoiceService {
  _FakeInvoiceService({this.count = 0, this.error});

  final int count;
  final Object? error;

  @override
  Future<int> countAwaitingReview({required int dormitoryId}) async {
    if (error != null) throw error!;
    return count;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('แคตตาล็อกทางลัดของเจ้าของหอ', () {
    // สี่ปุ่มเดียวกับที่ hardcode อยู่บนหน้าจอมาตลอด คนที่ใช้อยู่ทุกวันจึงไม่
    // ตื่นมาเจอปุ่มย้ายที่ในวันที่อัปเดต
    test('ค่าตั้งต้นคือสี่ปุ่มเดิมบนแดชบอร์ด', () {
      expect(defaultLandlordQuickActions, [
        LandlordQuickAction.recordMeter,
        LandlordQuickAction.issueInvoice,
        LandlordQuickAction.lease,
        LandlordQuickAction.chat,
      ]);
    });

    test('คีย์ที่เก็บแยกจากฝั่งผู้เช่า', () {
      expect(
        landlordQuickActions.storageKeyPrefix,
        isNot(tenantQuickActions.storageKeyPrefix),
      );
    });

    test('ทุกทางลัดมีป้ายและคำอธิบายที่ไม่ว่าง', () {
      for (final action in LandlordQuickAction.values) {
        expect(action.label.trim(), isNotEmpty);
        expect(action.description.trim(), isNotEmpty);
      }
    });

    test('เจ้าของหอกับผู้เช่าที่ id เดียวกัน ไม่ใช้การจัดปุ่มร่วมกัน',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final landlord = QuickActionsViewModel<LandlordQuickAction>(
        userId: 'same-id',
        store: QuickActionStore(
          catalog: landlordQuickActions,
          preferences: prefs,
        ),
      );
      await landlord.load();
      await landlord.remove(landlord.actions.first);

      final tenant = QuickActionsViewModel<QuickAction>(
        userId: 'same-id',
        store: QuickActionStore(
          catalog: tenantQuickActions,
          preferences: prefs,
        ),
      );
      await tenant.load();

      expect(tenant.actions, defaultQuickActions);
      expect(
          landlord.actions, hasLength(defaultLandlordQuickActions.length - 1));
    });
  });

  group('จำนวนบิลที่รอตรวจบนแดชบอร์ด', () {
    test('อ่านค่ามาแสดงเป็น badge ได้', () async {
      final viewModel = DashboardViewModel(
        dormitoryId: 1,
        service: _FakeSupabaseService(),
        invoices: _FakeInvoiceService(count: 3),
      );

      await viewModel.loadRooms();

      expect(viewModel.pendingSlipCount, 3);
    });

    // ตัวเลขบน badge ปุ่มเดียวไม่คุ้มกับการที่แผนผังห้องและการ์ดสรุปหายไปทั้งหน้า
    // — ฐานข้อมูลที่ยังไม่ได้รัน migration ของตาราง invoices เข้าเคสนี้ทันที
    test('นับไม่สำเร็จ ไม่ทำให้ทั้งแดชบอร์ดล้ม', () async {
      final viewModel = DashboardViewModel(
        dormitoryId: 1,
        service: _FakeSupabaseService(),
        invoices:
            _FakeInvoiceService(error: Exception('ยังไม่มีตาราง invoices')),
      );

      await viewModel.loadRooms();

      expect(viewModel.pendingSlipCount, 0);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.rooms, hasLength(1));
      expect(viewModel.unreadMessageCount, 2);
    });
  });
}
