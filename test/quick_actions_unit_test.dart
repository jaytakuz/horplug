import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/quick_action.dart';
import 'package:horplug/services/quick_action_store.dart';
import 'package:horplug/viewmodels/quick_actions_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<QuickActionsViewModel> _viewModel({
  Map<String, Object> initial = const {},
  String userId = 'tenant-1',
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final viewModel = QuickActionsViewModel(
    userId: userId,
    store: QuickActionStore(preferences: prefs),
  );
  await viewModel.load();
  return viewModel;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ค่าตั้งต้น', () {
    test('ผู้เช่าที่ยังไม่เคยจัด ได้ทางลัดตั้งต้น', () async {
      final viewModel = await _viewModel();
      expect(viewModel.actions, defaultQuickActions);
    });

    // ทุกแท็บใน bottom navigation กดถึงอยู่แล้ว ทางลัดตั้งต้นจึงควรเป็นสิ่งที่
    // ทำอะไรบางอย่างทันที ไม่ใช่พาไปหน้าที่อยู่ใต้นิ้วอยู่แล้ว
    test('ค่าตั้งต้นไม่มีอันไหนซ้ำกับแท็บด้านล่าง', () async {
      final viewModel = await _viewModel();
      const navigationOnly = {
        QuickAction.openBills,
        QuickAction.openMaintenance,
        QuickAction.openChat,
        QuickAction.openProfile,
      };

      expect(
        viewModel.actions.any(navigationOnly.contains),
        isFalse,
        reason: 'ทางลัดตั้งต้นควรเป็นการกระทำ ไม่ใช่ทางลัดไปแท็บ',
      );
    });
  });

  group('จัดลำดับ', () {
    // onReorderItem ส่ง index ที่ปรับแล้ว ต่างจาก onReorder ตัวเก่าที่ผู้เรียก
    // ต้องลบหนึ่งเองตอนลากลง — ต่อผิดตัวจะได้บั๊ก "วางเลยไปหนึ่งช่อง"
    test('ลากลงไปท้ายสุด', () async {
      final viewModel = await _viewModel();
      final first = viewModel.actions.first;
      final length = viewModel.actions.length;

      await viewModel.reorder(0, length - 1);

      expect(viewModel.actions.last, first);
      expect(viewModel.actions, hasLength(length));
    });

    test('ลากขึ้นมาหน้าสุด', () async {
      final viewModel = await _viewModel();
      final last = viewModel.actions.last;

      await viewModel.reorder(viewModel.actions.length - 1, 0);

      expect(viewModel.actions.first, last);
    });

    test('ลากไปตำแหน่งเดิมไม่เปลี่ยนอะไร', () async {
      final viewModel = await _viewModel();
      final before = [...viewModel.actions];

      await viewModel.reorder(1, 1);

      expect(viewModel.actions, before);
    });

    test('ลำดับที่จัดไว้ถูกอ่านกลับมาได้', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = QuickActionStore(preferences: prefs);

      final first = QuickActionsViewModel(userId: 'tenant-1', store: store);
      await first.load();
      await first.reorder(0, 2);
      final expected = [...first.actions];

      final reopened = QuickActionsViewModel(userId: 'tenant-1', store: store);
      await reopened.load();

      expect(reopened.actions, expected);
    });
  });

  group('เพิ่มและลบ', () {
    test('เพิ่มทางลัดที่ยังไม่ได้เลือก', () async {
      final viewModel = await _viewModel();

      await viewModel.add(QuickAction.openChat);

      expect(viewModel.actions.last, QuickAction.openChat);
    });

    test('เพิ่มตัวที่มีอยู่แล้วไม่ทำให้ซ้ำ', () async {
      final viewModel = await _viewModel();
      final before = [...viewModel.actions];

      await viewModel.add(viewModel.actions.first);

      expect(viewModel.actions, before);
    });

    test('available ไม่รวมตัวที่เลือกไว้แล้ว', () async {
      final viewModel = await _viewModel();

      for (final action in viewModel.actions) {
        expect(viewModel.available.contains(action), isFalse);
      }
    });

    test('เพิ่มเกินจำนวนสูงสุดไม่ได้', () async {
      final viewModel = await _viewModel();

      for (final action in QuickAction.values) {
        await viewModel.add(action);
      }

      expect(viewModel.actions, hasLength(maxQuickActions));
      expect(viewModel.canAddMore, isFalse);
    });

    // ลบจนหมดคือวิธีเดียวที่ผู้เช่าซึ่งไม่ต้องการการ์ดนี้จะเอามันออกจากจอได้
    test('ลบได้จนหมด', () async {
      final viewModel = await _viewModel();

      for (final action in [...viewModel.actions]) {
        await viewModel.remove(action);
      }

      expect(viewModel.actions, isEmpty);
    });

    test('คืนค่าเริ่มต้นได้หลังจัดไปแล้ว', () async {
      final viewModel = await _viewModel();
      await viewModel.remove(viewModel.actions.first);

      await viewModel.resetToDefault();

      expect(viewModel.actions, defaultQuickActions);
    });
  });

  group('ความทนทานของข้อมูลที่เก็บไว้', () {
    // เกิดได้เมื่ออัปเดตแอปแล้วทางลัดตัวเก่าถูกลบออกจาก enum — การล้มทั้งรายการ
    // เพราะปุ่มเดียวที่หายไปแย่กว่าการข้ามปุ่มนั้น
    test('ชื่อที่ถอดรหัสไม่ออกถูกข้าม ไม่ทำให้ทั้งรายการพัง', () async {
      final viewModel = await _viewModel(initial: {
        'flutter.quick_actions.tenant-1': [
          'reportRepair',
          'ทางลัดที่ถูกลบไปแล้ว',
          'openChat',
        ],
      });

      expect(viewModel.actions,
          [QuickAction.reportRepair, QuickAction.openChat]);
    });

    test('รายการที่ถอดรหัสไม่ได้เลย ตกกลับไปใช้ค่าตั้งต้น', () async {
      final viewModel = await _viewModel(initial: {
        'flutter.quick_actions.tenant-1': ['ไม่มีอยู่จริง'],
      });

      expect(viewModel.actions, defaultQuickActions);
    });

    // เครื่องเดียวอาจถูกใช้ล็อกอินหลายบัญชี ถ้าใช้คีย์เดียวกันหมด คนหลังจะได้
    // การจัดปุ่มของคนก่อนหน้าไปโดยไม่รู้ตัว
    test('การตั้งค่าของแต่ละบัญชีแยกจากกัน', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = QuickActionStore(preferences: prefs);

      final first = QuickActionsViewModel(userId: 'tenant-1', store: store);
      await first.load();
      await first.remove(first.actions.first);

      final second = QuickActionsViewModel(userId: 'tenant-2', store: store);
      await second.load();

      expect(second.actions, defaultQuickActions);
    });
  });
}
