import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

const _chatImageBucket = 'chat-image';

class SupabaseService {
  // เป็น getter ไม่ใช่ field เพื่อให้คลาสลูก (เช่นตัวปลอมในเทสต์) สร้างตัวเองได้
  // โดยไม่ไปแตะ Supabase.instance ซึ่ง assert เมื่อยังไม่ได้ initialize
  SupabaseClient get client => Supabase.instance.client;

  /// ดึงข้อมูลห้องพักทั้งหมด
  ///
  /// [roomDbId] ใช้จำกัดผลลัพธ์ให้เหลือห้องเดียว — ฝั่งผู้เช่าเรียกผ่านตัวนี้
  /// ทำให้ fetchElectricityRecords / fetchWaterRecords ที่เรียก fetchRooms
  /// อยู่แล้ว กลายเป็น "เฉพาะห้องของฉัน" ได้โดยไม่ต้องเขียน query ซ้ำ
  Future<List<Room>> fetchRooms({int? dormitoryId, int? roomDbId}) async {
    var baseQuery = client
        .from('rooms')
        .select('id, room_number, floor, base_price, status, current_tenant_id');

    if (dormitoryId != null) baseQuery = baseQuery.eq('dorm_id', dormitoryId);
    if (roomDbId != null) baseQuery = baseQuery.eq('id', roomDbId);

    final data = await baseQuery
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

  /// ดึงห้องเดียวตาม id — ใช้ในฝั่งผู้เช่าที่เห็นเฉพาะห้องตัวเอง
  Future<Room?> fetchRoom({required int roomDbId}) async {
    final rooms = await fetchRooms(roomDbId: roomDbId);
    return rooms.isEmpty ? null : rooms.first;
  }

  /// สตรีมแจ้งเตือนเมื่อข้อมูลห้องของหอพักนี้เปลี่ยน — ใช้เป็นสัญญาณให้โหลด
  /// ใหม่เท่านั้น (ไม่ใช้ payload ตรงๆ) เพื่อให้ยังใช้ fetchRooms() เดิมที่มี
  /// การ enrich ชื่อผู้เช่าอยู่แล้ว โดยไม่ต้องเขียน mapping ซ้ำ
  Stream<List<Map<String, dynamic>>> watchRoomChanges({
    required int dormitoryId,
  }) {
    return client.from('rooms').stream(primaryKey: ['id']).eq('dorm_id', dormitoryId);
  }

  // --- ระบบไฟฟ้า (ตาราง electricity_record) ---

  Future<List<ElectricityRecord>> fetchElectricityRecords({
    int? dormitoryId,
    int? roomDbId,
    required int month,
    required int year,
  }) async {
    final rooms = await fetchRooms(dormitoryId: dormitoryId, roomDbId: roomDbId);
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
        floor: room.floor,
        roomStatus: room.status,
      ));
    }
    return results;
  }

  Future<void> saveElectricityRecords(List<ElectricityRecord> records) async {
    final validRecords = records.where((r) => r.currentReading != null).toList();
    if (validRecords.isEmpty) return;

    // PostgREST merges all JSON keys across the batch — rows without 'id' get id=null
    // (overriding the sequence default) when batched with rows that have 'id'.
    // Split into two upserts so each batch has a uniform set of columns.
    final withId = validRecords.where((r) => r.id != null).map((r) => r.toJson()).toList();
    final withoutId = validRecords.where((r) => r.id == null).map((r) => r.toJson()).toList();

    if (withId.isNotEmpty) {
      await client.from('electricity_record').upsert(withId, onConflict: 'room_id,billing_month,billing_year');
    }
    if (withoutId.isNotEmpty) {
      await client.from('electricity_record').upsert(withoutId, onConflict: 'room_id,billing_month,billing_year');
    }
  }

  // --- ระบบน้ำ (ตาราง water_meter) ---

  Future<List<WaterRecord>> fetchWaterRecords({
    int? dormitoryId,
    int? roomDbId,
    required int month,
    required int year,
  }) async {
    final rooms = await fetchRooms(dormitoryId: dormitoryId, roomDbId: roomDbId);
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
        floor: room.floor,
        roomStatus: room.status,
      );
    }).toList();
  }

  Future<void> saveWaterRecords(List<WaterRecord> records) async {
    if (records.isEmpty) return;

    final withId = records.where((r) => r.id != null).map((r) => r.toJson()).toList();
    final withoutId = records.where((r) => r.id == null).map((r) => r.toJson()).toList();

    if (withId.isNotEmpty) {
      await client.from('water_meter').upsert(withId, onConflict: 'room_id,billing_month,billing_year');
    }
    if (withoutId.isNotEmpty) {
      await client.from('water_meter').upsert(withoutId, onConflict: 'room_id,billing_month,billing_year');
    }
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

  /// สร้างห้องหลายห้องใน insert เดียว
  ///
  /// Postgres รับประกัน all-or-nothing ให้เอง จึงไม่มีสภาพ "สร้างไป 40 จาก 84
  /// ห้องแล้วค้าง" ซึ่งเจ้าของหอต้องมานั่งไล่ว่าห้องไหนมีแล้วห้องไหนยัง
  Future<void> addRooms({
    required int dormitoryId,
    required List<({String number, String floor})> rooms,
    required double basePrice,
  }) async {
    if (rooms.isEmpty) return;

    await client.from('rooms').insert([
      for (final room in rooms)
        {
          'dorm_id': dormitoryId,
          'room_number': room.number,
          'floor': room.floor,
          'base_price': basePrice,
          'status': 'vacant',
        },
    ]);
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

  // --- ระบบแชท (ตาราง messages) ---

  MessageType _mapMessageType(String? value) {
    return MessageType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => MessageType.text,
    );
  }

  ChatMessage _mapMessageRow(
    Map<String, dynamic> row, {
    required String ownerName,
    required String tenantName,
    String? resolvedAttachmentUrl,
  }) {
    final isFromOwner = row['is_from_owner'] as bool;
    return ChatMessage(
      id: row['id'].toString(),
      senderName: isFromOwner ? ownerName : tenantName,
      text: row['body'] as String,
      timestamp: DateTime.parse(row['created_at'] as String),
      isFromOwner: isFromOwner,
      type: _mapMessageType(row['message_type'] as String?),
      attachmentUrl: resolvedAttachmentUrl,
      maintenanceRequestId: row['maintenance_request_id'] as int?,
      invoiceId: row['invoice_id'] as int?,
    );
  }

  /// แปลง storage path ในคอลัมน์ attachment_url ให้เป็น signed URL ที่แสดงผลได้
  /// (bucket เป็น private) — สร้างเป็น batch เดียวเพื่อลดจำนวน round-trip
  Future<Map<String, String>> _resolveAttachmentUrls(
      List<Map<String, dynamic>> rows) async {
    final paths = rows
        .map((row) => row['attachment_url'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (paths.isEmpty) return {};

    final signed =
        await client.storage.from(_chatImageBucket).createSignedUrls(paths, 3600);

    final result = <String, String>{};
    for (final entry in signed) {
      if (entry.signedUrl.isNotEmpty) {
        result[entry.path] = entry.signedUrl;
      }
    }
    return result;
  }

  /// รายการห้องที่มีผู้พักอาศัย พร้อมข้อความล่าสุดและจำนวนที่ยังไม่ได้อ่าน
  ///
  /// Computed entirely server-side via the fetch_chat_previews RPC — only one
  /// small row per room crosses the network, not full message history.
  Future<List<ChatPreview>> fetchChatPreviews({required int dormitoryId}) async {
    final data = await client
        .rpc('fetch_chat_previews', params: {'p_dorm_id': dormitoryId});
    final rows = (data as List).cast<Map<String, dynamic>>();

    return rows.map((row) {
      return ChatPreview(
        roomDbId: row['room_id'] as int,
        roomNumber: row['room_number'] as String,
        floor: row['floor'].toString(),
        tenantName: row['tenant_name'] as String? ?? '-',
        lastMessage: row['last_message'] as String? ?? '',
        unreadCount: (row['unread_count'] as num).toInt(),
      );
    }).toList();
  }

  /// ติดตามข้อความล่าสุด [limit] รายการของห้องแบบ realtime — เพิ่ม limit
  /// เพื่อ "โหลดข้อความเก่าเพิ่ม" แทนที่จะดึงประวัติทั้งหมดทุกครั้ง
  Stream<List<ChatMessage>> watchMessages({
    required int roomId,
    required String ownerName,
    required String tenantName,
    int limit = 50,
  }) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit)
        .asyncMap((rows) async {
      final signedUrlByPath = await _resolveAttachmentUrls(rows);

      final messages = rows.map((row) {
        final path = row['attachment_url'] as String?;
        return _mapMessageRow(
          row,
          ownerName: ownerName,
          tenantName: tenantName,
          resolvedAttachmentUrl: path != null ? signedUrlByPath[path] : null,
        );
      }).toList();

      // `.order()`/`.limit()` apply cleanly to the initial snapshot only;
      // realtime INSERT events get merged in arrival order, so re-sort
      // ascending here for chronological (oldest-first) display.
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  /// อัปโหลดรูปภาพไปยัง Storage bucket ส่วนตัว คืนค่าเป็น storage path
  /// (ไม่ใช่ URL) — path นี้จะถูกเก็บใน messages.attachment_url แล้วแปลงเป็น
  /// signed URL ตอนอ่านข้อความ เพราะ bucket เป็น private
  Future<String> uploadChatImage({
    required int roomId,
    required File imageFile,
  }) async {
    final extension = imageFile.path.split('.').last;
    final path =
        '$roomId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage.from(_chatImageBucket).upload(path, imageFile);
    return path;
  }

  Future<void> sendMessage({
    required int roomId,
    required String senderId,
    required bool isFromOwner,
    required String body,
    MessageType type = MessageType.text,
    String? attachmentUrl,
    int? maintenanceRequestId,
    int? invoiceId,
  }) async {
    await client.from('messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'is_from_owner': isFromOwner,
      'body': body,
      'message_type': type.name,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (maintenanceRequestId != null)
        'maintenance_request_id': maintenanceRequestId,
      if (invoiceId != null) 'invoice_id': invoiceId,
    });
  }

  /// จำนวนข้อความที่ยังไม่ได้อ่านรวมทุกห้อง (ใช้กับ badge หน้าแดชบอร์ด)
  /// Total unread messages across a dormitory (badges) — reuses the same
  /// server-side aggregate as fetchChatPreviews instead of a bespoke query.
  Future<int> countUnreadMessages({required int dormitoryId}) async {
    final previews = await fetchChatPreviews(dormitoryId: dormitoryId);
    return previews.fold<int>(0, (sum, preview) => sum + preview.unreadCount);
  }

  /// จำนวนข้อความจากเจ้าของหอที่ผู้เช่ายังไม่ได้อ่านในห้องนี้
  ///
  /// countUnreadMessages() เดิมใช้ RPC fetch_chat_previews ซึ่งรับ dorm_id และ
  /// เป็นมุมมองของเจ้าของหอ — ผู้เช่าจึงต้องมีตัวนับของตัวเอง
  Future<int> countUnreadMessagesForRoom({
    required int roomId,
    required String userId,
  }) async {
    final read = await client
        .from('message_reads')
        .select('last_read_at')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    final lastReadAt = read?['last_read_at'] as String?;

    var query = client
        .from('messages')
        .select('id')
        .eq('room_id', roomId)
        .eq('is_from_owner', true);
    if (lastReadAt != null) query = query.gt('created_at', lastReadAt);

    return ((await query) as List).length;
  }

  /// ข้อความล่าสุดของห้อง — ใช้แสดง preview บนแดชบอร์ดผู้เช่า
  ///
  /// จงใจเป็น one-shot ไม่ใช่ stream: แชทมี realtime subscription อยู่แล้วหนึ่งตัว
  /// การเพิ่มอีกตัวบนแดชบอร์ดจะเปิด subscription ค้างไว้ทั้ง session โดยไม่จำเป็น
  Future<ChatMessage?> fetchLatestMessage({
    required int roomId,
    required String ownerName,
    required String tenantName,
  }) async {
    final data = await client
        .from('messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(1);

    final rows = (data as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return null;

    final signedUrlByPath = await _resolveAttachmentUrls(rows);
    final path = rows.first['attachment_url'] as String?;

    return _mapMessageRow(
      rows.first,
      ownerName: ownerName,
      tenantName: tenantName,
      resolvedAttachmentUrl: path != null ? signedUrlByPath[path] : null,
    );
  }

  /// ข้อมูลหอพัก + ช่องทางติดต่อเจ้าของหอ
  ///
  /// ต้องรัน database/rls_tenant_access.sql ก่อน ไม่เช่นนั้น embed ของ
  /// landlord_profiles จะว่าง (policy เดิมให้อ่านได้เฉพาะเจ้าของแถวเอง)
  Future<DormitoryInfo?> fetchDormitoryInfo({required int dormitoryId}) async {
    final row = await client
        .from('dormitories')
        .select('id, name, base_water_rate, base_electricity_rate, '
            'landlord_profiles(first_name, last_name, phone, email)')
        .eq('id', dormitoryId)
        .maybeSingle();
    if (row == null) return null;

    // PostgREST คืน List สำหรับ one-to-many และ Map สำหรับ many-to-one
    // จึงรองรับทั้งสองแบบเหมือนที่ auth_service ทำ
    final embedded = row['landlord_profiles'];
    Map<String, dynamic>? landlord;
    if (embedded is List && embedded.isNotEmpty) {
      landlord = (embedded.first as Map).cast<String, dynamic>();
    } else if (embedded is Map) {
      landlord = embedded.cast<String, dynamic>();
    }

    final fullName = [
      landlord?['first_name'] as String?,
      landlord?['last_name'] as String?,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' ').trim();

    return DormitoryInfo(
      id: row['id'] as int,
      name: row['name'] as String? ?? '-',
      landlordName: fullName.isEmpty ? null : fullName,
      landlordPhone: landlord?['phone'] as String?,
      landlordEmail: landlord?['email'] as String?,
      baseWaterRate: _parseDouble(row['base_water_rate'], fallback: 100.0),
      baseElectricityRate:
          _parseDouble(row['base_electricity_rate'], fallback: 8.0),
    );
  }

  Future<void> markRoomRead({required int roomId, required String userId}) async {
    await client.from('message_reads').upsert(
      {
        'room_id': roomId,
        'user_id': userId,
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'room_id,user_id',
    );
  }

  // --- ระบบแจ้งซ่อม (ตาราง maintenance_requests) ---

  MaintenanceRequestType _mapRequestType(String? value) {
    return value == 'Cleaning'
        ? MaintenanceRequestType.cleaning
        : MaintenanceRequestType.repair;
  }

  String _requestTypeToDb(MaintenanceRequestType type) {
    switch (type) {
      case MaintenanceRequestType.cleaning:
        return 'Cleaning';
      case MaintenanceRequestType.repair:
        return 'Repair';
    }
  }

  MaintenanceStatus _mapMaintenanceStatus(String? value) {
    switch (value) {
      case 'In-Progress':
        return MaintenanceStatus.inProgress;
      case 'Completed':
        return MaintenanceStatus.completed;
      default:
        return MaintenanceStatus.pending;
    }
  }

  String _maintenanceStatusToDb(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.pending:
        return 'Pending';
      case MaintenanceStatus.inProgress:
        return 'In-Progress';
      case MaintenanceStatus.completed:
        return 'Completed';
    }
  }

  String _maintenanceStatusLabel(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.pending:
        return 'รอดำเนินการ';
      case MaintenanceStatus.inProgress:
        return 'กำลังดำเนินการ';
      case MaintenanceStatus.completed:
        return 'เสร็จสิ้น';
    }
  }

  MaintenanceRequest _mapMaintenanceRequestRow(Map<String, dynamic> row) {
    final tenant = row['tenant_profiles'] as Map<String, dynamic>?;
    final room = row['rooms'] as Map<String, dynamic>?;
    final tenantName = [tenant?['first_name'], tenant?['last_name']]
        .where((value) => value != null && (value as String).trim().isNotEmpty)
        .join(' ')
        .trim();

    return MaintenanceRequest(
      id: row['id'] as int,
      roomId: row['room_id'] as int,
      roomNumber: room?['room_number'] as String? ?? '-',
      tenantId: row['tenant_id'] as String,
      tenantName: tenantName.isEmpty ? '-' : tenantName,
      requestType: _mapRequestType(row['request_type'] as String?),
      description: row['description'] as String,
      imageUrl: row['image_url'] as String?,
      status: _mapMaintenanceStatus(row['status'] as String?),
      requestedAt: DateTime.parse(row['requested_at'] as String),
      completedAt: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String)
          : null,
      cleaningFee: _parseDouble(row['cleaning_fee']),
    );
  }

  /// ประวัติการแจ้งซ่อมของห้อง เรียงจากล่าสุดไปเก่าสุด
  Future<List<MaintenanceRequest>> fetchMaintenanceRequests({
    required int roomId,
  }) async {
    final data = await client
        .from('maintenance_requests')
        .select(
            'id, room_id, tenant_id, request_type, description, image_url, status, requested_at, completed_at, cleaning_fee, tenant_profiles(first_name, last_name), rooms(room_number)')
        .eq('room_id', roomId)
        .order('requested_at', ascending: false);

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(_mapMaintenanceRequestRow)
        .toList();
  }

  /// สร้างคำขอแจ้งซ่อม พร้อมส่งข้อความแจ้งในแชทให้เจ้าของหอในคราวเดียว
  Future<void> createMaintenanceRequest({
    required int roomId,
    required String tenantId,
    required String description,
    MaintenanceRequestType requestType = MaintenanceRequestType.repair,
  }) async {
    final row = await client
        .from('maintenance_requests')
        .insert({
          'room_id': roomId,
          'tenant_id': tenantId,
          'request_type': _requestTypeToDb(requestType),
          'description': description,
        })
        .select('id')
        .single();

    final requestId = row['id'] as int;

    await sendMessage(
      roomId: roomId,
      senderId: tenantId,
      isFromOwner: false,
      body: description,
      type: requestType == MaintenanceRequestType.cleaning
          ? MessageType.cleaningRequest
          : MessageType.maintenanceRequest,
      maintenanceRequestId: requestId,
    );
  }

  /// อัปเดตสถานะคำขอแจ้งซ่อม พร้อมส่งข้อความแจ้งในแชทให้ผู้เช่าในคราวเดียว
  Future<void> updateMaintenanceStatus({
    required int requestId,
    required int roomId,
    required String landlordId,
    required MaintenanceStatus status,
    required MaintenanceRequestType requestType,
  }) async {
    final updates = <String, dynamic>{
      'status': _maintenanceStatusToDb(status),
    };
    if (status == MaintenanceStatus.completed) {
      updates['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }

    await client.from('maintenance_requests').update(updates).eq('id', requestId);
    await _syncRoomStatusForMaintenance(roomId: roomId, status: status);

    final isCleaning = requestType == MaintenanceRequestType.cleaning;
    await sendMessage(
      roomId: roomId,
      senderId: landlordId,
      isFromOwner: true,
      body:
          '${isCleaning ? "อัปเดตสถานะทำความสะอาด" : "อัปเดตสถานะแจ้งซ่อม"}: ${_maintenanceStatusLabel(status)}',
      type: isCleaning ? MessageType.cleaningUpdate : MessageType.maintenanceUpdate,
      maintenanceRequestId: requestId,
    );
  }

  /// กำหนดค่าบริการทำความสะอาด (เฉพาะคำขอประเภท Cleaning) — ยอดนี้จะถูกรวม
  /// เข้าร่างบิลของห้องในเดือนที่คำขอนี้ "เสร็จสิ้น" ผ่าน
  /// InvoiceService.previewDrafts
  Future<void> updateCleaningFee({
    required int requestId,
    required double fee,
  }) async {
    await client
        .from('maintenance_requests')
        .update({'cleaning_fee': fee}).eq('id', requestId);
  }

  /// ห้องที่มีแจ้งซ่อมค้างอยู่ (รอดำเนินการ/กำลังดำเนินการ) จะถูกตั้งเป็น
  /// 'maintenance' อัตโนมัติ และกลับเป็น 'occupied' เมื่อเสร็จสิ้น — แต่จะกลับ
  /// เฉพาะตอนไม่มีแจ้งซ่อมอื่นของห้องเดียวกันที่ยังไม่เสร็จค้างอยู่แล้วเท่านั้น
  Future<void> _syncRoomStatusForMaintenance({
    required int roomId,
    required MaintenanceStatus status,
  }) async {
    if (status == MaintenanceStatus.pending ||
        status == MaintenanceStatus.inProgress) {
      await client.from('rooms').update({'status': 'maintenance'}).eq('id', roomId);
      return;
    }

    if (status == MaintenanceStatus.completed) {
      final remaining = await client
          .from('maintenance_requests')
          .select('id')
          .eq('room_id', roomId)
          .neq('status', 'Completed')
          .limit(1);

      if ((remaining as List).isEmpty) {
        await client.from('rooms').update({'status': 'occupied'}).eq('id', roomId);
      }
    }
  }
}
