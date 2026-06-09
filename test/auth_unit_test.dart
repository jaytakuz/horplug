import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:horplug/controllers/auth_controller.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Fake service — overrides every method so no real Supabase calls are made.
// ---------------------------------------------------------------------------
class FakeAuthService extends AuthService {
  FakeAuthService() : super(client: Supabase.instance.client);

  final _authStateController = StreamController<AuthState>.broadcast();

  UserProfile? profile;
  Object? signInError;
  Object? signUpTenantError;
  Object? signUpLandlordError;

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (signInError != null) throw signInError!;
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
  }

  @override
  Future<UserProfile?> fetchCurrentUserProfile() async => profile;

  @override
  Future<UserProfile> enrichTenantProfile(UserProfile p) async => p;

  void dispose() => _authStateController.close();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
UserProfile landlordProfile({String email = 'landlord@test.com'}) => UserProfile(
      id: 'landlord-id',
      role: AppRole.landlord,
      firstName: 'Landlord',
      lastName: 'User',
      email: email,
      dormitoryId: 1,
      dormitoryName: 'Test Dorm',
      dormitoryTotalFloors: 3,
    );

UserProfile tenantProfile({String email = 'tenant@test.com'}) => UserProfile(
      id: 'tenant-id',
      role: AppRole.tenant,
      firstName: 'Tenant',
      lastName: 'User',
      email: email,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  // -------------------------------------------------------------------------
  // UTC-01: AuthController.signIn()
  // -------------------------------------------------------------------------
  group('UTC-01 AuthController.signIn()', () {
    test(
        'UTC-01-TC-01: status becomes authenticated and role is landlord '
        'after successful sign in with landlord credentials', () async {
      final service = FakeAuthService()..profile = landlordProfile();
      final controller = AuthController(authService: service);
      await controller.initialize();

      await controller.signIn(
          email: 'landlord@test.com', password: 'Test1234!');

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.role, AppRole.landlord);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-01-TC-02: status becomes authenticated and role is tenant '
        'after successful sign in with tenant credentials', () async {
      final service = FakeAuthService()..profile = tenantProfile();
      final controller = AuthController(authService: service);
      await controller.initialize();

      await controller.signIn(
          email: 'tenant@test.com', password: 'Test1234!');

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.role, AppRole.tenant);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-01-TC-03: exception is rethrown and status stays unauthenticated '
        'when credentials are incorrect', () async {
      final service = FakeAuthService()
        ..signInError = Exception('invalid login credentials');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.signIn(email: 'tenant@test.com', password: 'WrongPass'),
        throwsException,
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-01-TC-04: exception is rethrown and status stays unauthenticated '
        'when email and password are empty', () async {
      final service = FakeAuthService()
        ..signInError = Exception('invalid login credentials');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.signIn(email: '', password: ''),
        throwsException,
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-01-TC-05: SocketException is rethrown and status stays unauthenticated '
        'when network is unavailable', () async {
      final service = FakeAuthService()
        ..signInError = const SocketException('Failed host lookup');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.signIn(email: 'tenant@test.com', password: 'Test1234!'),
        throwsA(isA<SocketException>()),
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // UTC-02: AuthController.registerTenant()
  // -------------------------------------------------------------------------
  group('UTC-02 AuthController.registerTenant()', () {
    test(
        'UTC-02-TC-01: status becomes authenticated and role is tenant '
        'after successful tenant registration', () async {
      final service = FakeAuthService()
        ..profile = tenantProfile(email: 'tenant_new@test.com');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await controller.registerTenant(
        email: 'tenant_new@test.com',
        password: 'Test1234!',
        firstName: 'สมชาย',
        lastName: 'ใจดี',
        phone: '0812345678',
      );

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.role, AppRole.tenant);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-02-TC-02: exception is rethrown and status stays unauthenticated '
        'when email is already registered', () async {
      final service = FakeAuthService()
        ..signUpTenantError = Exception('email_exists');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.registerTenant(
          email: 'existing@test.com',
          password: 'Test1234!',
          firstName: 'ทดสอบ',
          lastName: 'ซ้ำ',
          phone: '0812345678',
        ),
        throwsException,
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-02-TC-03: exception is rethrown and status stays unauthenticated '
        'when name is already taken', () async {
      final service = FakeAuthService()
        ..signUpTenantError = Exception('database error saving new user');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.registerTenant(
          email: 'tenant_new@test.com',
          password: 'Test1234!',
          firstName: 'สมชาย',
          lastName: 'ใจดี',
          phone: '0812345678',
        ),
        throwsException,
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-02-TC-04: SocketException is rethrown and status stays unauthenticated '
        'when network is unavailable during tenant registration', () async {
      final service = FakeAuthService()
        ..signUpTenantError = const SocketException('Failed host lookup');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.registerTenant(
          email: 'tenant_new@test.com',
          password: 'Test1234!',
          firstName: 'สมชาย',
          lastName: 'ใจดี',
          phone: '0812345678',
        ),
        throwsA(isA<SocketException>()),
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // UTC-03: AuthController.registerLandlord()
  // -------------------------------------------------------------------------
  group('UTC-03 AuthController.registerLandlord()', () {
    test(
        'UTC-03-TC-01: status becomes authenticated and role is landlord '
        'after successful landlord registration', () async {
      final service = FakeAuthService()
        ..profile = landlordProfile(email: 'owner_new@test.com');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await controller.registerLandlord(
        email: 'owner_new@test.com',
        password: 'Test1234!',
        firstName: 'สมหญิง',
        lastName: 'เจ้าของ',
        phone: '0898765432',
        dormitoryName: 'หอพักทดสอบ',
        location: 'เชียงใหม่',
        totalFloors: 3,
        roomsPerFloor: 10,
        baseWaterRate: 100.0,
        baseElectricityRate: 8.0,
      );

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.role, AppRole.landlord);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-03-TC-02: exception is rethrown and status stays unauthenticated '
        'when email is already registered', () async {
      final service = FakeAuthService()
        ..signUpLandlordError = Exception('email_exists');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.registerLandlord(
          email: 'existing@test.com',
          password: 'Test1234!',
          firstName: 'ซ้ำ',
          lastName: 'ซ้ำ',
          phone: '0898765432',
          dormitoryName: 'หอพักซ้ำ',
          location: 'เชียงใหม่',
          totalFloors: 2,
          roomsPerFloor: 5,
          baseWaterRate: 100.0,
          baseElectricityRate: 8.0,
        ),
        throwsException,
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-03-TC-03: exception is rethrown and status stays unauthenticated '
        'when dormitory name is already taken', () async {
      final service = FakeAuthService()
        ..signUpLandlordError = Exception('dormitory_name_exists');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.registerLandlord(
          email: 'owner_new@test.com',
          password: 'Test1234!',
          firstName: 'สมหญิง',
          lastName: 'เจ้าของ',
          phone: '0898765432',
          dormitoryName: 'หอพักซ้ำ',
          location: 'เชียงใหม่',
          totalFloors: 3,
          roomsPerFloor: 10,
          baseWaterRate: 100.0,
          baseElectricityRate: 8.0,
        ),
        throwsException,
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-03-TC-04: exception is rethrown and status stays unauthenticated '
        'when name is already taken', () async {
      final service = FakeAuthService()
        ..signUpLandlordError = Exception('database error saving new user');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.registerLandlord(
          email: 'owner_new@test.com',
          password: 'Test1234!',
          firstName: 'ซ้ำ',
          lastName: 'ซ้ำ',
          phone: '0898765432',
          dormitoryName: 'หอพักทดสอบ',
          location: 'เชียงใหม่',
          totalFloors: 2,
          roomsPerFloor: 5,
          baseWaterRate: 100.0,
          baseElectricityRate: 8.0,
        ),
        throwsException,
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });

    test(
        'UTC-03-TC-05: SocketException is rethrown and status stays unauthenticated '
        'when network is unavailable during landlord registration', () async {
      final service = FakeAuthService()
        ..signUpLandlordError = const SocketException('Failed host lookup');
      final controller = AuthController(authService: service);
      await controller.initialize();

      await expectLater(
        controller.registerLandlord(
          email: 'owner_new@test.com',
          password: 'Test1234!',
          firstName: 'สมหญิง',
          lastName: 'เจ้าของ',
          phone: '0898765432',
          dormitoryName: 'หอพักทดสอบ',
          location: 'เชียงใหม่',
          totalFloors: 3,
          roomsPerFloor: 10,
          baseWaterRate: 100.0,
          baseElectricityRate: 8.0,
        ),
        throwsA(isA<SocketException>()),
      );
      expect(controller.status, AuthStatus.unauthenticated);
      service.dispose();
      controller.dispose();
    });
  });
}
