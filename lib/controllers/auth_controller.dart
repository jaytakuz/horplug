import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/auth_service.dart';

enum AuthStatus { loading, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _subscription = _authService.authStateChanges.listen((event) async {
      if (event.event == AuthChangeEvent.signedOut) {
        _profile = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      await refreshProfile();
    });
  }

  final AuthService _authService;
  StreamSubscription<AuthState>? _subscription;

  AuthStatus _status = AuthStatus.loading;
  UserProfile? _profile;

  AuthStatus get status => _status;
  UserProfile? get profile => _profile;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  AppRole? get role => _profile?.role;
  int? get dormitoryId => _profile?.dormitoryId;
  String? get dormitoryName => _profile?.dormitoryName;
  int? get dormitoryTotalFloors => _profile?.dormitoryTotalFloors;

  Future<void> initialize() async {
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final profile = await _authService.fetchCurrentUserProfile();
      _profile = profile;
      _status = profile == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      notifyListeners();

      if (profile?.role == AppRole.tenant) {
        _loadTenantOptionalFields(profile!);
      }
      return;
    } catch (e) {
      _profile = null;
      _status = AuthStatus.unauthenticated;
      debugPrint('[AuthController] refreshProfile error: $e');
    }

    notifyListeners();
  }

  Future<void> _loadTenantOptionalFields(UserProfile profile) async {
    try {
      final enrichedProfile = await _authService.enrichTenantProfile(profile);
      if (_profile?.id != enrichedProfile.id || _profile?.role != AppRole.tenant) {
        return;
      }

      _profile = enrichedProfile;
      notifyListeners();
    } catch (_) {
      // Optional tenant fields should not affect authenticated state.
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _authService.signIn(email: email, password: password);
    await refreshProfile();
  }

  Future<void> registerTenant({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    await _authService.signUpTenant(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
    await refreshProfile();
  }

  Future<void> registerLandlord({
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
    await _authService.signUpLandlord(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      dormitoryName: dormitoryName,
      location: location,
      totalFloors: totalFloors,
      roomsPerFloor: roomsPerFloor,
      baseWaterRate: baseWaterRate,
      baseElectricityRate: baseElectricityRate,
    );
    await refreshProfile();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static AuthController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}
