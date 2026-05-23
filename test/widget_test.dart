import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/controllers/auth_controller.dart';
import 'package:horplug/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('HorPlug app renders login flow by default',
      (WidgetTester tester) async {
    final authController = AuthController();
    await authController.initialize();

    await tester.pumpWidget(HorPlugApp(authController: authController));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบ HorPlug'), findsOneWidget);
  });
}
