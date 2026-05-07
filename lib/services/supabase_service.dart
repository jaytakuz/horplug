import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Room>> fetchRooms() async {
    final data = await client
        .from('rooms')
        .select('id, room_number, floor, base_price, status, current_tenant_id')
        .order('floor', ascending: true)
        .order('room_number', ascending: true);

    final roomsData = (data as List).cast<Map<String, dynamic>>();
    final tenantIds = roomsData
        .map((row) => row['current_tenant_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final tenantById = <String, Map<String, dynamic>>{};

    if (tenantIds.isNotEmpty) {
      final tenantsData = await client
          .from('tenant_profiles')
          .select('id, first_name, last_name, phone')
          .inFilter('id', tenantIds);

      for (final tenant in (tenantsData as List).cast<Map<String, dynamic>>()) {
        tenantById[tenant['id'] as String] = tenant;
      }
    }

    return roomsData.map((row) {
      final tenantId = row['current_tenant_id'] as String?;
      final tenant = tenantId == null ? null : tenantById[tenantId];
      final firstName = tenant?['first_name'] as String?;
      final lastName = tenant?['last_name'] as String?;
      final fullName = [firstName, lastName]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' ')
          .trim();

      return Room(
        dbId: row['id'] as int,
        id: row['room_number'] as String,
        floor: row['floor'].toString(),
        status: _mapRoomStatus(row['status'] as String?),
        currentTenantId: tenantId,
        tenantFirstName: firstName,
        tenantName: fullName.isEmpty ? null : fullName,
        phoneNumber: tenant?['phone'] as String?,
        price: (row['base_price'] as num).toDouble(),
      );
    }).toList();
  }

  Future<List<Tenant>> fetchAvailableTenants() async {
    final roomsData = await client
        .from('rooms')
        .select('current_tenant_id')
        .not('current_tenant_id', 'is', null);

    final assignedTenantIds = (roomsData as List)
        .map((row) => row['current_tenant_id'] as String?)
        .whereType<String>()
        .toSet();

    final tenantsData = await client
        .from('tenant_profiles')
        .select('id, first_name, last_name, phone')
        .order('first_name', ascending: true);

    return (tenantsData as List)
        .where((row) => !assignedTenantIds.contains(row['id']))
        .map((row) {
      final firstName = row['first_name'] as String? ?? '';
      final lastName = row['last_name'] as String? ?? '';
      final fullName = [firstName, lastName]
          .where((value) => value.trim().isNotEmpty)
          .join(' ')
          .trim();

      return Tenant(
        id: row['id'] as String,
        name: fullName.isEmpty ? 'Unknown tenant' : fullName,
        phoneNumber: row['phone'] as String? ?? '-',
      );
    }).toList();
  }

  Future<void> assignTenantToRoom({
    required int roomDbId,
    required String tenantId,
  }) async {
    await client.from('rooms').update({
      'current_tenant_id': tenantId,
      'status': 'occupied',
    }).eq('id', roomDbId);
  }

  RoomStatus _mapRoomStatus(String? value) {
    switch (value) {
      case 'occupied':
        return RoomStatus.occupied;
      case 'maintenance':
        return RoomStatus.maintenance;
      case 'vacant':
      default:
        return RoomStatus.vacant;
    }
  }
}
