import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'horplug://reset-callback',
    );
  }

  Future<void> updatePassword({required String password}) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signUpTenant({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': 'tenant',
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
      },
    );

    final user = response.user;
    if (user == null) {
      throw Exception('ไม่สามารถสร้างบัญชีผู้เช่าได้');
    }
  }

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
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': 'landlord',
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
        'dormitory_name': dormitoryName.trim(),
        'location': location.trim(),
        'total_floors': totalFloors,
        'rooms_per_floor': roomsPerFloor,
        'base_water_rate': baseWaterRate,
        'base_electricity_rate': baseElectricityRate,
      },
    );

    final user = response.user;
    if (user == null) {
      throw Exception('ไม่สามารถสร้างบัญชีผู้ดูแลหอพักได้');
    }
  }

  Future<UserProfile?> fetchCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final landlordRows = await _client
        .from('landlord_profiles')
        .select(
          'id, first_name, last_name, email, phone, dormitories(id, name, total_floors)',
        )
        .eq('id', user.id)
        .limit(1);

    final landlordList =
        (landlordRows as List).cast<Map<String, dynamic>>();
    if (landlordList.isNotEmpty) {
      final row = landlordList.first;
      // PostgREST returns a List for one-to-many (dormitories.landlord_id → landlord_profiles.id)
      // or a Map for many-to-one. Handle both defensively.
      final dormitoriesRaw = row['dormitories'];
      Map<String, dynamic>? dormitory;
      if (dormitoriesRaw is List) {
        final list = dormitoriesRaw.cast<Map<String, dynamic>>();
        dormitory = list.isEmpty ? null : list.first;
      } else if (dormitoriesRaw is Map) {
        dormitory = Map<String, dynamic>.from(dormitoriesRaw);
      }

      return UserProfile(
        id: row['id'] as String,
        role: AppRole.landlord,
        firstName: row['first_name'] as String? ?? '',
        lastName: row['last_name'] as String? ?? '',
        email: row['email'] as String? ?? user.email ?? '',
        phone: row['phone'] as String?,
        dormitoryId: dormitory?['id'] as int?,
        dormitoryName: dormitory?['name'] as String?,
        dormitoryTotalFloors: dormitory?['total_floors'] as int?,
      );
    }

    final tenantRow = await _client
        .from('tenant_profiles')
        .select('id, first_name, last_name, email, phone')
        .eq('id', user.id)
        .maybeSingle();

    if (tenantRow != null) {
      return UserProfile(
        id: tenantRow['id'] as String,
        role: AppRole.tenant,
        firstName: tenantRow['first_name'] as String? ?? '',
        lastName: tenantRow['last_name'] as String? ?? '',
        email: tenantRow['email'] as String? ?? user.email ?? '',
        phone: tenantRow['phone'] as String?,
      );
    }

    return null;
  }

  Future<UserProfile> enrichTenantProfile(UserProfile profile) async {
    if (profile.role != AppRole.tenant) return profile;

    final tenantExtendedRow = await _client
        .from('tenant_profiles')
        .select('dorm_id, room_id')
        .eq('id', profile.id)
        .maybeSingle();

    if (tenantExtendedRow == null) {
      return profile;
    }

    final dormitoryId = tenantExtendedRow['dorm_id'] as int?;
    final roomId = tenantExtendedRow['room_id'] as int?;

    String? dormitoryName;
    if (dormitoryId != null) {
      final dormitoryRow = await _client
          .from('dormitories')
          .select('name')
          .eq('id', dormitoryId)
          .maybeSingle();
      dormitoryName = dormitoryRow?['name'] as String?;
    }

    String? roomNumber;
    if (roomId != null) {
      final roomRow = await _client
          .from('rooms')
          .select('room_number')
          .eq('id', roomId)
          .maybeSingle();
      roomNumber = roomRow?['room_number'] as String?;
    }

    return profile.copyWith(
      dormitoryId: dormitoryId,
      dormitoryName: dormitoryName,
      roomId: roomId,
      roomNumber: roomNumber,
    );
  }
}
