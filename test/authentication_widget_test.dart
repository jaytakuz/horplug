import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:horplug/controllers/auth_controller.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/screens/auth/login_screen.dart';
import 'package:horplug/screens/auth/register_screen.dart';
import 'package:horplug/services/auth_service.dart';
import 'package:horplug/theme/app_theme.dart';
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

  group('UTC-01 Login', () {
    testWidgets('UTC-01-TC-01 displays login form fields',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester);

      expect(find.widgetWithText(TextFormField, 'อีเมล'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'รหัสผ่าน'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-01-TC-02 validates empty email on login',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'รหัสผ่าน'), 'Test1234!');
      await tester.tap(find.text('เข้าสู่ระบบ'));
      await tester.pump();

      expect(find.text('กรอกอีเมล'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-01-TC-03 validates invalid email format on login',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester);

      final emailField =
          tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'อีเมล'));
      expect(emailField.validator?.call('testmail.com'), 'รูปแบบอีเมลไม่ถูกต้อง');
      await harness.dispose();
    });

    testWidgets('UTC-01-TC-04 validates empty password on login',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'อีเมล'), 'tenant@test.com');
      await tester.tap(find.text('เข้าสู่ระบบ'));
      await tester.pump();

      expect(find.text('กรอกรหัสผ่าน'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-01-TC-05 shows incorrect credentials error',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signInError = Exception('invalid login credentials');
      final harness = await pumpAuthApp(tester, authService: fakeAuth);

      await login(tester, email: 'tenant@test.com', password: 'WrongPass');

      expect(
        find.text('เข้าสู่ระบบไม่สำเร็จ: อีเมลหรือรหัสผ่านไม่ถูกต้อง'),
        findsOneWidget,
      );
      await harness.dispose();
    });

    testWidgets('UTC-01-TC-06 redirects landlord to landlord screen',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signInProfile = landlordProfile(email: 'landlord@test.com');
      final harness = await pumpAuthApp(tester, authService: fakeAuth);

      await login(tester, email: 'landlord@test.com', password: 'Test1234!');

      expect(find.text('LANDLORD_HOME'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-01-TC-07 redirects tenant to tenant screen',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signInProfile = tenantProfile(email: 'tenant@test.com');
      final harness = await pumpAuthApp(tester, authService: fakeAuth);

      await login(tester, email: 'tenant@test.com', password: 'Test1234!');

      expect(find.text('TENANT_HOME'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-01-TC-08 shows network error on login',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signInError = const SocketException('Failed host lookup');
      final harness = await pumpAuthApp(tester, authService: fakeAuth);

      await login(tester, email: 'tenant@test.com', password: 'Test1234!');

      expect(
        find.text('เข้าสู่ระบบไม่สำเร็จ: กรุณาตรวจสอบอินเตอร์เน็ต'),
        findsOneWidget,
      );
      await harness.dispose();
    });

    testWidgets('UTC-01-TC-09 navigates from login to registration page',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester);

      await tester.tap(find.text('สมัครใช้งาน'));
      await tester.pumpAndSettle();

      expect(find.text('สมัครใช้งาน'), findsWidgets);
      expect(find.text('ผู้พักอาศัย'), findsOneWidget);
      await harness.dispose();
    });
  });

  group('UTC-02 Register Tenant', () {
    testWidgets('UTC-02-TC-01 displays registration role selection',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester, initialLocation: '/register');

      expect(find.text('ผู้พักอาศัย'), findsOneWidget);
      expect(find.text('เจ้าของหอพัก'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-02-TC-02 displays tenant registration fields',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester, initialLocation: '/register');

      for (final label in const [
        'ชื่อ',
        'นามสกุล',
        'อีเมล',
        'เบอร์โทรศัพท์',
        'รหัสผ่าน',
        'ยืนยันรหัสผ่าน',
      ]) {
        expect(find.widgetWithText(TextFormField, label), findsOneWidget);
      }
      await harness.dispose();
    });

    testWidgets('UTC-02-TC-03 to TC-09 validate tenant form fields',
        (WidgetTester tester) async {
      final cases = <Future<void> Function(WidgetTester)>[
        (tester) async {
          await submitRegister(tester);
          expect(find.text('กรอกชื่อ'), findsOneWidget);
        },
        (tester) async {
          await enterByLabel(tester, 'ชื่อ', 'สมชาย');
          await submitRegister(tester);
          expect(find.text('กรอกนามสกุล'), findsOneWidget);
        },
        (tester) async {
          await fillTenantForm(tester, firstName: 'สมชาย', lastName: 'ใจดี');
          await submitRegister(tester);
          expect(find.text('กรอกอีเมล'), findsOneWidget);
        },
        (tester) async {
          final emailField =
              tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'อีเมล'));
          expect(emailField.validator?.call('tenantmail.com'), 'รูปแบบอีเมลไม่ถูกต้อง');
        },
        (tester) async {
          await fillTenantForm(
            tester,
            firstName: 'สมชาย',
            lastName: 'ใจดี',
            email: 'tenant@test.com',
          );
          await submitRegister(tester);
          expect(find.text('กรอกเบอร์โทรศัพท์'), findsOneWidget);
        },
        (tester) async {
          await fillTenantForm(
            tester,
            firstName: 'สมชาย',
            lastName: 'ใจดี',
            email: 'tenant@test.com',
            phone: '0812345678',
            password: '12345',
            confirmPassword: '12345',
          );
          await submitRegister(tester);
          expect(find.text('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'), findsOneWidget);
        },
        (tester) async {
          await fillTenantForm(
            tester,
            firstName: 'สมชาย',
            lastName: 'ใจดี',
            email: 'tenant@test.com',
            phone: '0812345678',
            password: 'Test1234!',
            confirmPassword: 'Test0000!',
          );
          await submitRegister(tester);
          expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);
        },
      ];

      for (final runCase in cases) {
        final harness = await pumpAuthApp(tester, initialLocation: '/register');
        await runCase(tester);
        await harness.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('UTC-02-TC-10 registers tenant successfully',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..tenantRegistrationProfile = tenantProfile(email: 'tenant_new@test.com');
      final harness = await pumpAuthApp(tester,
          initialLocation: '/register', authService: fakeAuth);

      await fillTenantForm(
        tester,
        firstName: 'สมชาย',
        lastName: 'ใจดี',
        email: 'tenant_new@test.com',
        phone: '0812345678',
        password: 'Test1234!',
        confirmPassword: 'Test1234!',
      );
      await submitRegister(tester);

      expect(find.text('TENANT_HOME'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-02-TC-11 shows duplicate tenant email error',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signUpTenantError = Exception('email_exists');
      final harness = await pumpAuthApp(tester,
          initialLocation: '/register', authService: fakeAuth);

      await fillTenantForm(
        tester,
        firstName: 'สมชาย',
        lastName: 'ใจดี',
        email: 'existing@test.com',
        phone: '0812345678',
        password: 'Test1234!',
        confirmPassword: 'Test1234!',
      );
      await submitRegister(tester);

      expect(find.text('สมัครไม่สำเร็จ: อีเมลถูกใช้ไปแล้ว'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-02-TC-12 shows duplicate tenant name error',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signUpTenantError = Exception('database error saving new user');
      final harness = await pumpAuthApp(tester,
          initialLocation: '/register', authService: fakeAuth);

      await fillTenantForm(
        tester,
        firstName: 'สมชาย',
        lastName: 'ใจดี',
        email: 'tenant_new@test.com',
        phone: '0812345678',
        password: 'Test1234!',
        confirmPassword: 'Test1234!',
      );
      await submitRegister(tester);

      expect(find.text('สมัครไม่สำเร็จ: ชื่อถูกใช้ไปแล้ว'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-02-TC-13 shows network error on tenant registration',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signUpTenantError = const SocketException('Failed host lookup');
      final harness = await pumpAuthApp(tester,
          initialLocation: '/register', authService: fakeAuth);

      await fillTenantForm(
        tester,
        firstName: 'สมชาย',
        lastName: 'ใจดี',
        email: 'tenant_new@test.com',
        phone: '0812345678',
        password: 'Test1234!',
        confirmPassword: 'Test1234!',
      );
      await submitRegister(tester);

      expect(find.text('สมัครไม่สำเร็จ: กรุณาตรวจสอบอินเตอร์เน็ต'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-02-TC-14 navigates back to login from register page',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester, initialLocation: '/register');

      final loginLink = find.text('เข้าสู่ระบบ');
      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink);
      await tester.pumpAndSettle();

      expect(find.text('เข้าสู่ระบบ HorPlug'), findsOneWidget);
      await harness.dispose();
    });
  });

  group('UTC-03 Register Landlord', () {
    testWidgets('UTC-03-TC-01 displays landlord registration fields',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester, initialLocation: '/register');

      await selectLandlordRole(tester);

      for (final label in const [
        'ชื่อ',
        'นามสกุล',
        'อีเมล',
        'เบอร์โทรศัพท์',
        'รหัสผ่าน',
        'ยืนยันรหัสผ่าน',
        'ชื่อหอพัก',
        'ที่อยู่',
        'จำนวนชั้น',
        'ห้องต่อชั้น',
        'ค่าน้ำพื้นฐาน',
        'ค่าไฟพื้นฐาน',
      ]) {
        expect(find.widgetWithText(TextFormField, label), findsOneWidget);
      }
      await harness.dispose();
    });

    testWidgets('UTC-03-TC-02 to TC-11 validate landlord form fields',
        (WidgetTester tester) async {
      final cases = <Future<void> Function(WidgetTester)>[
        (tester) async {
          await selectLandlordRole(tester);
          await submitLandlordRegister(tester);
          expect(find.text('กรอกชื่อ'), findsOneWidget);
        },
        (tester) async {
          await selectLandlordRole(tester);
          await fillLandlordCommonForm(
            tester,
            firstName: 'สมหญิง',
            email: 'ownermail.com',
          );
          await submitLandlordRegister(tester);
          expect(find.text('กรอกนามสกุล'), findsOneWidget);
        },
        (tester) async {
          await selectLandlordRole(tester);
          final emailField =
              tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'อีเมล'));
          expect(emailField.validator?.call('ownermail.com'), 'รูปแบบอีเมลไม่ถูกต้อง');
        },
        (tester) async {
          await selectLandlordRole(tester);
          await fillLandlordCommonForm(
            tester,
            firstName: 'สมหญิง',
            lastName: 'เจ้าของ',
            email: 'owner@test.com',
            phone: '0898765432',
            password: '12345',
            confirmPassword: '12345',
          );
          await submitLandlordRegister(tester);
          expect(find.text('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'), findsOneWidget);
        },
        (tester) async {
          await selectLandlordRole(tester);
          await fillLandlordCommonForm(
            tester,
            firstName: 'สมหญิง',
            lastName: 'เจ้าของ',
            email: 'owner@test.com',
            phone: '0898765432',
            password: 'Test1234!',
            confirmPassword: 'Test0000!',
          );
          await submitLandlordRegister(tester);
          expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);
        },
        (tester) async {
          await selectLandlordRole(tester);
          await fillLandlordCommonForm(
            tester,
            firstName: 'สมหญิง',
            lastName: 'เจ้าของ',
            email: 'owner@test.com',
            phone: '0898765432',
            password: 'Test1234!',
            confirmPassword: 'Test1234!',
          );
          await submitLandlordRegister(tester);
          expect(find.text('กรอกชื่อหอพัก'), findsOneWidget);
        },
        (tester) async {
          await selectLandlordRole(tester);
          await fillLandlordForm(
            tester,
            firstName: 'สมหญิง',
            lastName: 'เจ้าของ',
            email: 'owner@test.com',
            phone: '0898765432',
            password: 'Test1234!',
            confirmPassword: 'Test1234!',
            dormitoryName: 'หอพักทดสอบ',
          );
          await submitLandlordRegister(tester);
          expect(find.text('กรอกที่อยู่'), findsOneWidget);
        },
        (tester) async {
          await selectLandlordRole(tester);
          await fillLandlordForm(
            tester,
            firstName: 'สมหญิง',
            lastName: 'เจ้าของ',
            email: 'owner@test.com',
            phone: '0898765432',
            password: 'Test1234!',
            confirmPassword: 'Test1234!',
            dormitoryName: 'หอพักทดสอบ',
            location: 'เชียงใหม่',
          );
          await submitLandlordRegister(tester);
          expect(find.text('กรอกจำนวนชั้น'), findsOneWidget);
        },
        (tester) async {
          await selectLandlordRole(tester);
          await fillLandlordForm(
            tester,
            firstName: 'สมหญิง',
            lastName: 'เจ้าของ',
            email: 'owner@test.com',
            phone: '0898765432',
            password: 'Test1234!',
            confirmPassword: 'Test1234!',
            dormitoryName: 'หอพักทดสอบ',
            location: 'เชียงใหม่',
            totalFloors: '3',
          );
          await submitLandlordRegister(tester);
          expect(find.text('กรอกห้องต่อชั้น'), findsOneWidget);
        },
        (tester) async {
          await selectLandlordRole(tester);
          await fillLandlordForm(
            tester,
            firstName: 'สมหญิง',
            lastName: 'เจ้าของ',
            email: 'owner@test.com',
            phone: '0898765432',
            password: 'Test1234!',
            confirmPassword: 'Test1234!',
            dormitoryName: 'หอพักทดสอบ',
            location: 'เชียงใหม่',
            totalFloors: '3',
            roomsPerFloor: '10',
          );
          await submitLandlordRegister(tester);
          expect(find.text('กรอกค่าน้ำพื้นฐาน'), findsOneWidget);
        },
        (tester) async {
          await selectLandlordRole(tester);
          await fillLandlordForm(
            tester,
            firstName: 'สมหญิง',
            lastName: 'เจ้าของ',
            email: 'owner@test.com',
            phone: '0898765432',
            password: 'Test1234!',
            confirmPassword: 'Test1234!',
            dormitoryName: 'หอพักทดสอบ',
            location: 'เชียงใหม่',
            totalFloors: '3',
            roomsPerFloor: '10',
            baseWaterRate: '100.0',
          );
          await submitLandlordRegister(tester);
          expect(find.text('กรอกค่าไฟพื้นฐาน'), findsOneWidget);
        },
      ];

      for (final runCase in cases) {
        final harness = await pumpAuthApp(tester, initialLocation: '/register');
        await runCase(tester);
        await harness.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('UTC-03-TC-12 registers landlord successfully',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..landlordRegistrationProfile = landlordProfile(email: 'owner_new@test.com');
      final harness = await pumpAuthApp(tester,
          initialLocation: '/register', authService: fakeAuth);

      await selectLandlordRole(tester);
      await fillLandlordForm(
        tester,
        firstName: 'สมหญิง',
        lastName: 'เจ้าของ',
        email: 'owner_new@test.com',
        phone: '0898765432',
        password: 'Test1234!',
        confirmPassword: 'Test1234!',
        dormitoryName: 'หอพักทดสอบ',
        location: 'เชียงใหม่',
        totalFloors: '3',
        roomsPerFloor: '10',
        baseWaterRate: '100.0',
        baseElectricityRate: '8.0',
      );
      await submitLandlordRegister(tester);

      expect(find.text('LANDLORD_HOME'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-03-TC-13 shows duplicate landlord email error',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signUpLandlordError = Exception('email_exists');
      final harness = await pumpAuthApp(tester,
          initialLocation: '/register', authService: fakeAuth);

      await selectLandlordRole(tester);
      await fillLandlordForm(
        tester,
        firstName: 'สมหญิง',
        lastName: 'เจ้าของ',
        email: 'existing@test.com',
        phone: '0898765432',
        password: 'Test1234!',
        confirmPassword: 'Test1234!',
        dormitoryName: 'หอพักทดสอบ',
        location: 'เชียงใหม่',
        totalFloors: '3',
        roomsPerFloor: '10',
        baseWaterRate: '100.0',
        baseElectricityRate: '8.0',
      );
      await submitLandlordRegister(tester);

      expect(find.text('สมัครไม่สำเร็จ: อีเมลถูกใช้ไปแล้ว'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-03-TC-14 shows duplicate landlord name error',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signUpLandlordError = Exception('database error saving new user');
      final harness = await pumpAuthApp(tester,
          initialLocation: '/register', authService: fakeAuth);

      await selectLandlordRole(tester);
      await fillLandlordForm(
        tester,
        firstName: 'สมหญิง',
        lastName: 'เจ้าของ',
        email: 'owner_new@test.com',
        phone: '0898765432',
        password: 'Test1234!',
        confirmPassword: 'Test1234!',
        dormitoryName: 'หอพักทดสอบ',
        location: 'เชียงใหม่',
        totalFloors: '3',
        roomsPerFloor: '10',
        baseWaterRate: '100.0',
        baseElectricityRate: '8.0',
      );
      await submitLandlordRegister(tester);

      expect(find.text('สมัครไม่สำเร็จ: ชื่อถูกใช้ไปแล้ว'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-03-TC-15 shows duplicate dormitory name error',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signUpLandlordError = Exception('dormitory_name_exists');
      final harness = await pumpAuthApp(tester,
          initialLocation: '/register', authService: fakeAuth);

      await selectLandlordRole(tester);
      await fillLandlordForm(
        tester,
        firstName: 'สมหญิง',
        lastName: 'เจ้าของ',
        email: 'owner_new@test.com',
        phone: '0898765432',
        password: 'Test1234!',
        confirmPassword: 'Test1234!',
        dormitoryName: 'หอพักซ้ำ',
        location: 'เชียงใหม่',
        totalFloors: '3',
        roomsPerFloor: '10',
        baseWaterRate: '100.0',
        baseElectricityRate: '8.0',
      );
      await submitLandlordRegister(tester);

      expect(find.text('สมัครไม่สำเร็จ: ชื่อหอพักถูกใช้ไปแล้ว'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-03-TC-16 shows network error on landlord registration',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()
        ..signUpLandlordError = const SocketException('Failed host lookup');
      final harness = await pumpAuthApp(tester,
          initialLocation: '/register', authService: fakeAuth);

      await selectLandlordRole(tester);
      await fillLandlordForm(
        tester,
        firstName: 'สมหญิง',
        lastName: 'เจ้าของ',
        email: 'owner_new@test.com',
        phone: '0898765432',
        password: 'Test1234!',
        confirmPassword: 'Test1234!',
        dormitoryName: 'หอพักทดสอบ',
        location: 'เชียงใหม่',
        totalFloors: '3',
        roomsPerFloor: '10',
        baseWaterRate: '100.0',
        baseElectricityRate: '8.0',
      );
      await submitLandlordRegister(tester);

      expect(find.text('สมัครไม่สำเร็จ: กรุณาตรวจสอบอินเตอร์เน็ต'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('UTC-03-TC-17 navigates back to login from landlord flow',
        (WidgetTester tester) async {
      final harness = await pumpAuthApp(tester, initialLocation: '/register');

      await selectLandlordRole(tester);
      final loginLink = find.text('เข้าสู่ระบบ');
      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink);
      await tester.pumpAndSettle();

      expect(find.text('เข้าสู่ระบบ HorPlug'), findsOneWidget);
      await harness.dispose();
    });
  });
}

class FakeAuthService extends AuthService {
  FakeAuthService() : super(client: Supabase.instance.client);

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  UserProfile? currentProfile;
  UserProfile? signInProfile;
  UserProfile? tenantRegistrationProfile;
  UserProfile? landlordRegistrationProfile;
  Object? signInError;
  Object? signUpTenantError;
  Object? signUpLandlordError;

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    currentProfile = signInProfile;
  }

  @override
  Future<void> signUpTenant({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    if (signUpTenantError != null) throw signUpTenantError!;
    currentProfile = tenantRegistrationProfile;
  }

  @override
  Future<void> signUpLandlord({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String dormitoryName,
    required String location,
    required int totalFloors,
    required int roomsPerFloor,
    required double baseWaterRate,
    required double baseElectricityRate,
  }) async {
    if (signUpLandlordError != null) throw signUpLandlordError!;
    currentProfile = landlordRegistrationProfile;
  }

  @override
  Future<UserProfile?> fetchCurrentUserProfile() async => currentProfile;

  void dispose() {
    _authStateController.close();
  }
}

class TestHarness {
  TestHarness(this.controller, this.authService);

  final AuthController controller;
  final FakeAuthService authService;

  Future<void> dispose() async {
    controller.dispose();
    authService.dispose();
  }
}

Future<TestHarness> pumpAuthApp(
  WidgetTester tester, {
  String initialLocation = '/login',
  FakeAuthService? authService,
}) async {
  final service = authService ?? FakeAuthService();
  final controller = AuthController(authService: service);
  await controller.initialize();

  final router = GoRouter(
    initialLocation: initialLocation,
    refreshListenable: controller,
    redirect: (context, state) {
      final location = state.uri.path;
      final isLoading = controller.status == AuthStatus.loading;
      final isAuthPage = location == '/login' || location == '/register';

      if (isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      if (!controller.isAuthenticated) {
        if (isAuthPage) return null;
        return '/login';
      }

      final role = controller.role;
      if (role == null) return '/login';

      if (isAuthPage || location == '/' || location == '/splash') {
        return role == AppRole.landlord ? '/landlord' : '/tenant';
      }

      if (role == AppRole.landlord && location.startsWith('/tenant')) {
        return '/landlord';
      }

      if (role == AppRole.tenant && location.startsWith('/landlord')) {
        return '/tenant';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/landlord',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('LANDLORD_HOME')),
        ),
      ),
      GoRoute(
        path: '/tenant',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('TENANT_HOME')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    AuthScope(
      controller: controller,
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return TestHarness(controller, service);
}

Future<void> login(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'อีเมล'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'รหัสผ่าน'), password);
  final button = find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> submitRegister(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'สมัครใช้งาน');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> submitLandlordRegister(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'สมัครใช้งานเจ้าของหอพัก');
  await tester.ensureVisible(button);
  final widget = tester.widget<ElevatedButton>(button);
  widget.onPressed?.call();
  await tester.pumpAndSettle();
}

Future<void> selectLandlordRole(WidgetTester tester) async {
  await tester.tap(find.text('เจ้าของหอพัก'));
  await tester.pumpAndSettle();
}

Future<void> fillTenantForm(
  WidgetTester tester, {
  String firstName = '',
  String lastName = '',
  String email = '',
  String phone = '',
  String password = '',
  String confirmPassword = '',
}) async {
  if (firstName.isNotEmpty) {
    await enterByLabel(tester, 'ชื่อ', firstName);
  }
  if (lastName.isNotEmpty) {
    await enterByLabel(tester, 'นามสกุล', lastName);
  }
  if (email.isNotEmpty) {
    await enterByLabel(tester, 'อีเมล', email);
  }
  if (phone.isNotEmpty) {
    await enterByLabel(tester, 'เบอร์โทรศัพท์', phone);
  }
  if (password.isNotEmpty) {
    await enterByLabel(tester, 'รหัสผ่าน', password);
  }
  if (confirmPassword.isNotEmpty) {
    await enterByLabel(tester, 'ยืนยันรหัสผ่าน', confirmPassword);
  }
}

Future<void> fillLandlordCommonForm(
  WidgetTester tester, {
  String firstName = '',
  String lastName = '',
  String email = '',
  String phone = '',
  String password = '',
  String confirmPassword = '',
}) async {
  await fillTenantForm(
    tester,
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: phone,
    password: password,
    confirmPassword: confirmPassword,
  );
}

Future<void> fillLandlordForm(
  WidgetTester tester, {
  String firstName = '',
  String lastName = '',
  String email = '',
  String phone = '',
  String password = '',
  String confirmPassword = '',
  String dormitoryName = '',
  String location = '',
  String totalFloors = '',
  String roomsPerFloor = '',
  String baseWaterRate = '',
  String baseElectricityRate = '',
}) async {
  await fillLandlordCommonForm(
    tester,
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: phone,
    password: password,
    confirmPassword: confirmPassword,
  );
  if (dormitoryName.isNotEmpty) {
    await enterByLabel(tester, 'ชื่อหอพัก', dormitoryName);
  }
  if (location.isNotEmpty) {
    await enterByLabel(tester, 'ที่อยู่', location);
  }
  if (totalFloors.isNotEmpty) {
    await enterByLabel(tester, 'จำนวนชั้น', totalFloors);
  }
  if (roomsPerFloor.isNotEmpty) {
    await enterByLabel(tester, 'ห้องต่อชั้น', roomsPerFloor);
  }
  if (baseWaterRate.isNotEmpty) {
    await enterByLabel(tester, 'ค่าน้ำพื้นฐาน', baseWaterRate);
  }
  if (baseElectricityRate.isNotEmpty) {
    await enterByLabel(tester, 'ค่าไฟพื้นฐาน', baseElectricityRate);
  }
}

Future<void> enterByLabel(
  WidgetTester tester,
  String label,
  String value,
) async {
  final finder = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
}

UserProfile tenantProfile({required String email}) {
  return UserProfile(
    id: 'tenant-id',
    role: AppRole.tenant,
    firstName: 'Tenant',
    lastName: 'User',
    email: email,
    phone: '0812345678',
  );
}

UserProfile landlordProfile({required String email}) {
  return UserProfile(
    id: 'landlord-id',
    role: AppRole.landlord,
    firstName: 'Landlord',
    lastName: 'User',
    email: email,
    phone: '0898765432',
    dormitoryId: 1,
    dormitoryName: 'Test Dorm',
    dormitoryTotalFloors: 3,
  );
}
