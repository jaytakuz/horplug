import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/auth_service.dart';

enum AuthStatus { loading, unauthenticated, authenticated }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _subscription = _authService.authStateChanges.listen((event) async {
      if (event.event == AuthChangeEvent.signedOut) {
        _isRecovering = false;
        _profile = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      if (event.event == AuthChangeEvent.passwordRecovery) {
        _isRecovering = true;
        _status = AuthStatus.authenticated;
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
  bool _isRecovering = false;

  bool get isRecovering => _isRecovering;

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
      var profile = await _authService.fetchCurrentUserProfile();
      // ต้องรอห้อง/หอของผู้เช่าให้ครบก่อนประกาศว่า authenticated · roomId ไม่ใช่
      // ข้อมูลเสริม — มันตัดสินว่าหน้าหลักจะเป็น "รอเจ้าของหอเพิ่มเข้าห้อง" หรือ
      // แดชบอร์ดจริง เดิมโหลดตามหลังเลยเห็นหน้ารอห้องวาบหนึ่งทุกครั้งที่เปิดแอป
      if (profile != null && profile.role == AppRole.tenant) {
        profile = await _withTenantRoom(profile);
      }
      _profile = profile;
      _status = profile == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      notifyListeners();
      return;
    } catch (e) {
      _profile = null;
      _status = AuthStatus.unauthenticated;
      debugPrint('[AuthViewModel] refreshProfile error: $e');
    }

    notifyListeners();
  }

  /// อ่านโปรไฟล์ใหม่โดยไม่ออกจากหน้าที่อยู่ — ต่างจาก [refreshProfile] ที่ตั้ง
  /// status เป็น loading ซึ่งทำให้ router พาทั้งแอปกลับไปหน้า splash แล้วโหลดทุก
  /// อย่างใหม่ · ใช้กับท่าลากลงเพื่อรีเฟรช ที่ผู้ใช้คาดว่าแค่ข้อมูลในหน้านี้อัปเดต
  ///
  /// ล้มหรือหาโปรไฟล์ไม่เจอก็ไม่ทำอะไร คงข้อมูลเดิมไว้ · ท่าลากรีเฟรชต้องไม่ทำให้
  /// ผู้ใช้หลุดออกจากระบบ
  Future<void> reloadProfileInPlace() async {
    try {
      var profile = await _authService.fetchCurrentUserProfile();
      if (profile == null) return;
      if (profile.role == AppRole.tenant) {
        profile = await _withTenantRoom(profile);
      }
      _profile = profile;
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthViewModel] reloadProfileInPlace error: $e');
    }
  }

  /// โหลดห้อง/หอของผู้เช่า · ถ้าล้ม (เช่นออฟไลน์กลางทาง) ยังให้เข้าแอปด้วยโปรไฟล์
  /// พื้นฐาน ผู้เช่าเห็นหน้ารอห้องพร้อมปุ่มรีเฟรช ดีกว่าเด้งออกจากระบบ
  Future<UserProfile> _withTenantRoom(UserProfile profile) async {
    try {
      return await _authService.enrichTenantProfile(profile);
    } catch (e) {
      debugPrint('[AuthViewModel] enrichTenantProfile error: $e');
      return profile;
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

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _authService.sendPasswordResetEmail(email: email);
  }

  Future<void> updatePassword({required String password}) async {
    await _authService.updatePassword(password: password);
    _isRecovering = false;
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

class AuthScope extends InheritedNotifier<AuthViewModel> {
  const AuthScope({
    super.key,
    required AuthViewModel controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static AuthViewModel of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}
