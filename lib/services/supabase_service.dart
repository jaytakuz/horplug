import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Room>> fetchRooms({int? dormitoryId}) async {
    final query = client
        .from('rooms')
        .select('id, room_number, floor, base_price, status, current_tenant_id');

    if (dormitoryId != null) {
      query.eq('dorm_id', dormitoryId);
    }

    final data = await query
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
          .select('id, first_name, last_name, email, phone')
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
        tenantName: fullName.isEmpty ? null : fullName,
        tenantEmail: tenant?['email'] as String?,
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
        .select('id, first_name, last_name, email, phone')
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
        email: row['email'] as String?,
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

  Future<void> removeTenantFromRoom({
    required int roomDbId,
  }) async {
    await client.from('rooms').update({
      'current_tenant_id': null,
      'status': 'vacant',
    }).eq('id', roomDbId);
  }

  /// อัปเดตสถานะห้องพัก
  Future<void> updateRoomStatus({
    required int roomDbId,
    required RoomStatus newStatus,
  }) async {
    final statusString = _mapRoomStatusToString(newStatus);

    await client.from('rooms').update({
      'status': statusString,
    }).eq('id', roomDbId);
  }

  /// อัปเดตราคาห้องพัก
  Future<void> updateRoomPrice({
    required int roomDbId,
    required double newPrice,
  }) async {
    await client.from('rooms').update({
      'base_price': newPrice,
    }).eq('id', roomDbId);
  }

  /// เพิ่มห้องพักใหม่
  Future<void> addRoom({
    required int dormitoryId,
    required String roomNumber,
    required String floor,
    required double basePrice,
  }) async {
    // ตรวจสอบว่าเลขห้องไม่ซ้ำกัน
    final existingRoom = await client
        .from('rooms')
        .select('id')
        .eq('room_number', roomNumber)
        .eq('dorm_id', dormitoryId)
        .maybeSingle();

    if (existingRoom != null) {
      throw Exception('หมายเลขห้องนี้มีอยู่ในระบบแล้ว');
    }

    // เพิ่มห้องพักใหม่ด้วยสถานะว่าง
    await client.from('rooms').insert({
      'dorm_id': dormitoryId,
      'room_number': roomNumber,
      'floor': floor,
      'base_price': basePrice,
      'status': 'vacant',
      'current_tenant_id': null,
    });
  }

  /// ลบห้องพัก
  Future<void> deleteRoom({required int roomDbId}) async {
    // ดึงข้อมูลห้องเพื่อตรวจสอบสถานะ
    final room = await client
        .from('rooms')
        .select('status, current_tenant_id')
        .eq('id', roomDbId)
        .single();

    final status = room['status'] as String?;
    final currentTenantId = room['current_tenant_id'] as String?;

    // ตรวจสอบว่าห้องไม่มีผู้พักอาศัยและไม่อยู่ในสถานะอื่น
    if (status != 'vacant' || currentTenantId != null) {
      throw Exception(
          'ไม่สามารถลบห้องได้: ห้องนี้กำลังถูกเช่าโดยผู้เช่าที่ยังใช้งานอยู่');
    }

    // TODO: เปลี่ยนให้เป็น soft delete โดยอัปเดตสถานะเป็น 'inactive' แทนการลบข้อมูลจริง
    // NOTE: ยังไม่ตรวจสอบ pending invoices เนื่องจากยังไม่เชื่อมโยง billing data ในโมดูลนี้
    await client.from('rooms').delete().eq('id', roomDbId);
  }

  /// อัปเดตเลขห้อง
  Future<void> updateRoomNumber({
    required int roomDbId,
    required String newRoomNumber,
  }) async {
    // ตรวจสอบว่าเลขห้องใหม่ไม่ซ้ำกัน
    final existingRoom = await client
        .from('rooms')
        .select('id')
        .eq('room_number', newRoomNumber)
        .neq('id', roomDbId)
        .maybeSingle();

    if (existingRoom != null) {
      throw Exception('หมายเลขห้องนี้ถูกใช้งานอยู่แล้ว');
    }

    await client.from('rooms').update({
      'room_number': newRoomNumber,
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

  /// แปลง RoomStatus enum เป็น string สำหรับ database
  String _mapRoomStatusToString(RoomStatus status) {
    switch (status) {
      case RoomStatus.occupied:
        return 'occupied';
      case RoomStatus.vacant:
        return 'vacant';
      case RoomStatus.maintenance:
        return 'maintenance';
    }
  }
}
