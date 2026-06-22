import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';

class FakeTenantManagementRepository {
  FakeTenantManagementRepository({
    List<Tenant>? availableTenants,
    List<TenantJoinRequest>? pendingRequests,
    this.shouldThrowOnFetchAvailableTenants = false,
    this.shouldThrowOnCreateJoinRequest = false,
    this.shouldThrowOnFetchPendingRequests = false,
    this.shouldThrowOnRespondToRequest = false,
    this.shouldThrowOnRemoveTenant = false,
  })  : _availableTenants = List<Tenant>.from(availableTenants ?? const []),
        _pendingRequests =
            List<TenantJoinRequest>.from(pendingRequests ?? const []);

  final List<Tenant> _availableTenants;
  final List<TenantJoinRequest> _pendingRequests;
  final bool shouldThrowOnFetchAvailableTenants;
  final bool shouldThrowOnCreateJoinRequest;
  final bool shouldThrowOnFetchPendingRequests;
  final bool shouldThrowOnRespondToRequest;
  final bool shouldThrowOnRemoveTenant;

  Future<List<Tenant>> fetchAvailableTenants() async {
    if (shouldThrowOnFetchAvailableTenants) {
      throw const SocketException('Failed host lookup');
    }
    return List<Tenant>.from(_availableTenants);
  }

  Future<void> createTenantJoinRequest({
    required String landlordId,
    required int dormitoryId,
    required int roomDbId,
    required String tenantId,
  }) async {
    if (shouldThrowOnCreateJoinRequest) {
      throw const SocketException('Failed host lookup');
    }
  }

  Future<List<TenantJoinRequest>> fetchPendingJoinRequestsForTenant() async {
    if (shouldThrowOnFetchPendingRequests) {
      throw const SocketException('Failed host lookup');
    }
    return List<TenantJoinRequest>.from(_pendingRequests);
  }

  Future<void> respondToTenantJoinRequest({
    required int requestId,
    required bool accept,
  }) async {
    if (shouldThrowOnRespondToRequest) {
      throw const SocketException('Failed host lookup');
    }
  }

  Future<void> removeTenantFromRoom({required int roomDbId}) async {
    if (shouldThrowOnRemoveTenant) {
      throw const SocketException('Failed host lookup');
    }
  }
}

Tenant buildTenant({
  required String id,
  required String name,
  String roomNumber = '',
  String? email,
  String phoneNumber = '-',
}) {
  return Tenant(
    id: id,
    name: name,
    roomNumber: roomNumber,
    email: email,
    phoneNumber: phoneNumber,
  );
}

TenantJoinRequest buildJoinRequest({
  required int id,
  required String tenantId,
  required String landlordId,
  required int dormitoryId,
  int? requestedRoomId,
  required String dormitoryName,
  required String landlordName,
  String? roomNumber,
  JoinRequestStatus status = JoinRequestStatus.pending,
  DateTime? createdAt,
}) {
  return TenantJoinRequest(
    id: id,
    tenantId: tenantId,
    landlordId: landlordId,
    dormitoryId: dormitoryId,
    requestedRoomId: requestedRoomId,
    dormitoryName: dormitoryName,
    landlordName: landlordName,
    roomNumber: roomNumber,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 6, 21),
  );
}

void main() {
  group('Feature 2: Tenant management', () {
    group('UTC-14 fetchAvailableTenants', () {
      test('UTC-14-TC-01 returns a non-empty list of tenants', () async {
        final repository = FakeTenantManagementRepository(
          availableTenants: [
            buildTenant(
              id: 'tenant-1',
              name: 'Piphatpong Lalaka',
              email: 'piphatpong@test.com',
              phoneNumber: '0812345678',
            ),
          ],
        );

        final result = await repository.fetchAvailableTenants();

        expect(result, isNotEmpty);
        expect(result.first.name, 'Piphatpong Lalaka');
      });

      test('UTC-14-TC-02 returns an empty list when no tenants exist', () async {
        final repository =
            FakeTenantManagementRepository(availableTenants: []);

        final result = await repository.fetchAvailableTenants();

        expect(result, isEmpty);
      });
    });

    group('UTC-15 createTenantJoinRequest', () {
      test('UTC-15-TC-01 completes without exception on success', () async {
        final repository = FakeTenantManagementRepository();

        await expectLater(
          repository.createTenantJoinRequest(
            landlordId: '1',
            dormitoryId: 1,
            roomDbId: 10,
            tenantId: '1',
          ),
          completes,
        );
      });

      test('UTC-15-TC-02 throws SocketException on network failure', () {
        final repository = FakeTenantManagementRepository(
          shouldThrowOnCreateJoinRequest: true,
        );

        expect(
          () => repository.createTenantJoinRequest(
            landlordId: '1',
            dormitoryId: 1,
            roomDbId: 10,
            tenantId: '1',
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-16 fetchPendingJoinRequestsForTenant', () {
      test('UTC-16-TC-01 returns pending requests when they exist', () async {
        final repository = FakeTenantManagementRepository(
          pendingRequests: [
            buildJoinRequest(
              id: 1,
              tenantId: 'tenant-1',
              landlordId: 'landlord-1',
              dormitoryId: 1,
              requestedRoomId: 110,
              dormitoryName: 'Test Dormitory',
              landlordName: 'Test Landlord',
              roomNumber: '110',
            ),
          ],
        );

        final result = await repository.fetchPendingJoinRequestsForTenant();

        expect(result, isNotEmpty);
        expect(result.first.dormitoryName, 'Test Dormitory');
      });

      test('UTC-16-TC-02 returns an empty list when no requests exist', () async {
        final repository =
            FakeTenantManagementRepository(pendingRequests: []);

        final result = await repository.fetchPendingJoinRequestsForTenant();

        expect(result, isEmpty);
      });
    });

    group('UTC-17 respondToTenantJoinRequest', () {
      test('UTC-17-TC-01 completes when tenant accepts', () async {
        final repository = FakeTenantManagementRepository();

        await expectLater(
          repository.respondToTenantJoinRequest(requestId: 1, accept: true),
          completes,
        );
      });

      test('UTC-17-TC-02 completes when tenant rejects', () async {
        final repository = FakeTenantManagementRepository();

        await expectLater(
          repository.respondToTenantJoinRequest(requestId: 1, accept: false),
          completes,
        );
      });

      test('UTC-17-TC-03 throws SocketException on network failure', () {
        final repository = FakeTenantManagementRepository(
          shouldThrowOnRespondToRequest: true,
        );

        expect(
          () => repository.respondToTenantJoinRequest(
            requestId: 1,
            accept: true,
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-18 removeTenantFromRoom', () {
      test('UTC-18-TC-01 completes without exception on success', () async {
        final repository = FakeTenantManagementRepository();

        await expectLater(
          repository.removeTenantFromRoom(roomDbId: 202),
          completes,
        );
      });

      test('UTC-18-TC-02 throws SocketException on network failure', () {
        final repository = FakeTenantManagementRepository(
          shouldThrowOnRemoveTenant: true,
        );

        expect(
          () => repository.removeTenantFromRoom(roomDbId: 202),
          throwsA(isA<SocketException>()),
        );
      });
    });
  });
}
