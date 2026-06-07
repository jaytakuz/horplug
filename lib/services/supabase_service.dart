import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  /// ดึงข้อมูลห้องพักทั้งหมด
  Future<List<Room>> fetchRooms({int? dormitoryId}) async {
    var query = client.from('rooms').select(
        'id, room_number, floor, base_price, status, current_tenant_id');

    if (dormitoryId != null && dormitoryId != 0) {
      query = query.eq('dorm_id', dormitoryId);
    }

    final data = await query
        .order('floor', ascending: true)
        .order('room_number', ascending: true);

    final roomsData = (data as List).cast<Map<String, dynamic>>();
    
    if (roomsData.isEmpty) return [];

    final tenantIds = roomsData
        .map((row) => row['current_tenant_id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
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
          .where((value) => value != null && value.trim().isNotEmpty)
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

  // --- ระบบไฟฟ้า (ตาราง electricity_record) ---

  Future<List<ElectricityRecord>> fetchElectricityRecords({
    int? dormitoryId,
    required int month,
    required int year,
  }) async {
    final rooms = await fetchRooms(dormitoryId: dormitoryId);
    if (rooms.isEmpty) return [];

    final roomIds = rooms.map((room) => room.dbId).toList();

    // ดึงอัตราค่าไฟพื้นฐาน
    Map<String, dynamic>? dormSettings;
    if (dormitoryId != null && dormitoryId != 0) {
      dormSettings = await client.from('dormitories').select('base_electricity_rate').eq('id', dormitoryId).maybeSingle();
    }
    final defaultRate = _parseDouble(dormSettings?['base_electricity_rate'], fallback: 8.0);

    // ดึงประวัติมิเตอร์ไฟทั้งหมด
    final allHistory = await client
        .from('electricity_record')
        .select()
        .inFilter('room_id', roomIds)
        .order('billing_year', ascending: false)
        .order('billing_month', ascending: false);
    
    final historyData = (allHistory as List).cast<Map<String, dynamic>>();

    final results = <ElectricityRecord>[];
    for (final room in rooms) {
      final currentPeriod = historyData.firstWhere(
        (r) => r['room_id'] == room.dbId && r['billing_month'] == month && r['billing_year'] == year,
        orElse: () => {},
      );

      // ค้นหาเลขล่าสุดก่อนงวดนี้ (เพื่อเป็น Previous Value)
      final lastKnown = historyData.firstWhere(
        (r) {
          final rYear = r['billing_year'] as int;
          final rMonth = r['billing_month'] as int;
          return r['room_id'] == room.dbId && ((rYear < year) || (rYear == year && rMonth < month));
        },
        orElse: () => historyData.firstWhere((r) => r['room_id'] == room.dbId, orElse: () => {}),
      );

      double prevVal = 0.0;
      if (currentPeriod.isNotEmpty) {
        prevVal = _parseDouble(currentPeriod['previous_reading']);
      } else if (lastKnown.isNotEmpty) {
        prevVal = _parseDouble(lastKnown['current_reading']);
      }

      results.add(ElectricityRecord(
        id: currentPeriod['id']?.toString(),
        roomDbId: room.dbId,
        roomNumber: room.id,
        tenantName: room.tenantName ?? (room.status == RoomStatus.vacant ? 'ห้องว่าง' : '-'),
        billingMonth: month,
        billingYear: year,
        previousReading: prevVal,
        currentReading: currentPeriod.isNotEmpty
            ? _parseDouble(currentPeriod['current_reading'])
            : (room.status == RoomStatus.vacant ? prevVal : null),
        unitRate: currentPeriod.isNotEmpty ? _parseDouble(currentPeriod['unit_rate']) : defaultRate,
      ));
    }
    return results;
  }

  Future<void> saveElectricityRecords(List<ElectricityRecord> records) async {
    final rows = records.where((r) => r.currentReading != null).map((r) => r.toJson()).toList();
    if (rows.isEmpty) return;
    await client.from('electricity_record').upsert(rows, onConflict: 'room_id,billing_month,billing_year');
  }

  // --- ระบบน้ำ (ตาราง water_meter) ---

  Future<List<WaterRecord>> fetchWaterRecords({
    int? dormitoryId,
    required int month,
    required int year,
  }) async {
    final rooms = await fetchRooms(dormitoryId: dormitoryId);
    if (rooms.isEmpty) return [];

    final roomIds = rooms.map((room) => room.dbId).toList();

    Map<String, dynamic>? dormSettings;
    if (dormitoryId != null && dormitoryId != 0) {
      dormSettings = await client.from('dormitories').select('base_water_rate').eq('id', dormitoryId).maybeSingle();
    }
    final defaultAmount = _parseDouble(dormSettings?['base_water_rate'], fallback: 100.0);

    final data = await client
        .from('water_meter')
        .select()
        .inFilter('room_id', roomIds)
        .eq('billing_month', month)
        .eq('billing_year', year);
    
    final recordsData = (data as List).cast<Map<String, dynamic>>();

    return rooms.map((room) {
      final existing = recordsData.firstWhere((r) => r['room_id'] == room.dbId, orElse: () => {});
      return WaterRecord(
        id: existing['id']?.toString(),
        roomDbId: room.dbId,
        roomNumber: room.id,
        tenantName: room.tenantName ?? (room.status == RoomStatus.vacant ? 'ห้องว่าง' : '-'),
        billingMonth: month,
        billingYear: year,
        amount: existing.isNotEmpty
            ? _parseDouble(existing['amount'])
            : (room.status == RoomStatus.vacant ? 0.0 : defaultAmount),
      );
    }).toList();
  }

  Future<void> saveWaterRecords(List<WaterRecord> records) async {
    final rows = records.map((r) => r.toJson()).toList();
    if (rows.isEmpty) return;
    await client.from('water_meter').upsert(rows, onConflict: 'room_id,billing_month,billing_year');
  }

  // --- ระบบ Billing ---

  Future<List<Invoice>> fetchInvoices({
    int? dormitoryId,
    required int month,
    required int year,
  }) async {
    final rooms = await fetchRooms(dormitoryId: dormitoryId);
    final roomIds = rooms.map((room) => room.dbId).toList();
    if (roomIds.isEmpty) return [];

    final elecs = await client.from('electricity_record').select().inFilter('room_id', roomIds).eq('billing_month', month).eq('billing_year', year);
    final waters = await client.from('water_meter').select().inFilter('room_id', roomIds).eq('billing_month', month).eq('billing_year', year);

    final elecData = (elecs as List).cast<Map<String, dynamic>>();
    final waterData = (waters as List).cast<Map<String, dynamic>>();

    final invoices = <Invoice>[];
    for (final room in rooms) {
      if (room.status != RoomStatus.occupied) continue;

      final e = elecData.firstWhere((r) => r['room_id'] == room.dbId, orElse: () => {});
      final w = waterData.firstWhere((r) => r['room_id'] == room.dbId, orElse: () => {});

      if (e.isEmpty && w.isEmpty) continue;

      final elecUnits = e.isNotEmpty ? (_parseDouble(e['current_reading']) - _parseDouble(e['previous_reading'])) : 0.0;
      final elecCost = e.isNotEmpty ? _parseDouble(e['amount']) : 0.0;
      final waterCost = w.isNotEmpty ? _parseDouble(w['amount']) : 0.0;

      invoices.add(Invoice(
        id: 'INV-${room.dbId}-$month-$year',
        roomNumber: room.id,
        tenantName: room.tenantName ?? '-',
        waterUnits: w.isNotEmpty ? 1.0 : 0.0,
        electricityUnits: elecUnits,
        roomPrice: room.price,
        waterCost: waterCost,
        electricityCost: elecCost,
        status: InvoiceStatus.unpaid,
        date: DateTime(year, month, 1),
      ));
    }
    return invoices;
  }

  // --- Helpers & Others ---

  double _parseDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  RoomStatus _mapRoomStatus(String? value) {
    switch (value) {
      case 'occupied': return RoomStatus.occupied;
      case 'maintenance': return RoomStatus.maintenance;
      default: return RoomStatus.vacant;
    }
  }

  Future<void> updateRoomStatus({required int roomDbId, required RoomStatus newStatus}) async {
    await client.from('rooms').update({'status': newStatus.name}).eq('id', roomDbId);
  }

  Future<void> updateRoomPrice({required int roomDbId, required double newPrice}) async {
    await client.from('rooms').update({'base_price': newPrice}).eq('id', roomDbId);
  }

  Future<void> addRoom({required int dormitoryId, required String roomNumber, required String floor, required double basePrice}) async {
    await client.from('rooms').insert({'dorm_id': dormitoryId, 'room_number': roomNumber, 'floor': floor, 'base_price': basePrice, 'status': 'vacant'});
  }

  Future<void> deleteRoom({required int roomDbId}) async {
    await client.from('rooms').delete().eq('id', roomDbId);
  }

  Future<void> updateRoomNumber({required int roomDbId, required String newRoomNumber}) async {
    await client.from('rooms').update({'room_number': newRoomNumber}).eq('id', roomDbId);
  }

  Future<List<Tenant>> fetchAvailableTenants() async {
    final tenantsData = await client.from('tenant_profiles').select('id, first_name, last_name, email, phone').filter('room_id', 'is', null);
    return (tenantsData as List).map((row) => Tenant(id: row['id'] as String, name: '${row['first_name']} ${row['last_name']}', email: row['email'] as String?, phoneNumber: row['phone'] as String? ?? '-',)).toList();
  }

  Future<void> assignTenantToRoom({required int roomDbId, required String tenantId}) async {
    final room = await client.from('rooms').select('dorm_id').eq('id', roomDbId).single();
    await client.from('rooms').update({'current_tenant_id': tenantId, 'status': 'occupied'}).eq('id', roomDbId);
    await client.from('tenant_profiles').update({'dorm_id': room['dorm_id'], 'room_id': roomDbId}).eq('id', tenantId);
  }

  Future<void> removeTenantFromRoom({required int roomDbId}) async {
    final room = await client.from('rooms').select('current_tenant_id').eq('id', roomDbId).single();
    await client.from('rooms').update({'current_tenant_id': null, 'status': 'vacant'}).eq('id', roomDbId);
    if (room['current_tenant_id'] != null) {
      await client.from('tenant_profiles').update({'dorm_id': null, 'room_id': null}).eq('id', room['current_tenant_id']);
    }
  }

  Future<void> createTenantJoinRequest({required String landlordId, required int dormitoryId, required int roomDbId, required String tenantId}) async {
    await client.rpc('create_tenant_join_request', params: {'p_landlord_id': landlordId, 'p_dorm_id': dormitoryId, 'p_room_id': roomDbId, 'p_tenant_id': tenantId});
  }

  Future<List<TenantJoinRequest>> fetchPendingJoinRequestsForTenant() async {
    final requestRows = await client.rpc('fetch_pending_tenant_join_requests');
    return (requestRows as List).cast<Map<String, dynamic>>().map((row) => TenantJoinRequest(id: row['id'] as int, tenantId: row['tenant_id'] as String, landlordId: row['landlord_id'] as String, dormitoryId: row['dorm_id'] as int, requestedRoomId: row['requested_room_id'] as int?, dormitoryName: row['dormitory_name'] as String? ?? 'Unknown dormitory', landlordName: row['landlord_name'] as String? ?? 'Unknown landlord', roomNumber: row['room_number'] as String?, status: JoinRequestStatus.pending, createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),)).toList();
  }

  Future<void> respondToTenantJoinRequest({required int requestId, required bool accept}) async {
    await client.rpc('respond_to_tenant_join_request', params: {'p_request_id': requestId, 'p_accept': accept});
  }
}
