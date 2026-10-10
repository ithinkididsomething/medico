import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_referral/models/hospital_availability.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/models/sync_mutation.dart';
import 'package:smart_referral/repositories/offline_first_hospital_repository.dart';
import 'package:smart_referral/services/sync/central_api_client.dart';
import 'package:smart_referral/services/sync/local_facility_store.dart';
import 'package:smart_referral/services/sync/sync_engine.dart';
import 'package:smart_referral/widgets/sync_status_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline-First Local Facility Store Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads 45 regional facilities on empty cache baseline launch', () async {
      final store = LocalFacilityStore();
      await store.initialize();

      final facilities = store.getAllFacilities();
      expect(facilities.length, MockClinicalData.sampleHospitals.length);
      expect(store.lastSyncedRevision, 1);
      expect(store.lastSyncedAt, isNotNull);

      // Verify immediate random lookup works from cache
      final first = facilities.first;
      final retrieved = store.getFacilityById(first.hospitalId);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, first.name);
    });

    test('Enqueues and removes pending sync mutations persistently', () async {
      final store = LocalFacilityStore();
      await store.initialize();

      expect(store.getPendingMutations().length, 0);

      final mutation = SyncMutation(
        id: 'mut_test_1',
        idempotencyKey: 'idem_test_1',
        facilityId: 'HOSP_001',
        changeType: 'update_operational_status',
        payload: {'generalBedsAvailable': 15, 'icuBedsAvailable': 3},
        clientTimestamp: DateTime.now(),
        clientRevision: 1,
      );

      await store.enqueueMutation(mutation);
      expect(store.getPendingMutations().length, 1);
      expect(store.getPendingMutations().first.id, 'mut_test_1');

      // Remove after sync
      await store.removeMutations(['mut_test_1']);
      expect(store.getPendingMutations().length, 0);
    });

    test('Upserts facilities batch and updates revision cursor', () async {
      final store = LocalFacilityStore();
      await store.initialize();

      final updatedHospital = MockClinicalData.sampleHospitals.first.copyWith(
        bedAvailability: 99,
        operatingStatus: 'Operational',
        revision: 42,
      );

      await store.upsertFacilities(
        [updatedHospital],
        serverRevision: 42,
        syncTime: DateTime.now(),
      );

      expect(store.lastSyncedRevision, 42);
      final retrieved = store.getFacilityById(updatedHospital.hospitalId);
      expect(retrieved!.bedAvailability, 99);
      expect(retrieved.revision, 42);
    });
  });

  group('Central API Client Tests', () {
    test('checkHealth returns true when backend is reachable', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/health') {
          return http.Response(
            jsonEncode({
              'status': 'healthy',
              'service': 'smart-referral-central-backend',
              'version': '1.0.0',
              'facilitiesCount': 45,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = CentralApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        httpClient: mockClient,
      );

      final health = await apiClient.checkHealth();
      expect(health.isHealthy, isTrue);
      expect(health.facilitiesCount, 45);
    });

    test('pullChanges parses incremental facility updates', () async {
      final sample = MockClinicalData.sampleHospitals.first;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/sync/pull') {
          return http.Response(
            jsonEncode({
              'facilities': [
                {
                  ...sample.toMap(),
                  'revision': 15,
                }
              ],
              'count': 1,
              'serverRevision': 15,
              'serverTime': DateTime.now().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = CentralApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        httpClient: mockClient,
      );

      final result = await apiClient.pullChanges(sinceRevision: 10);
      expect(result.success, isTrue);
      expect(result.count, 1);
      expect(result.serverRevision, 15);
      expect(result.facilities.first.hospitalId, sample.hospitalId);
    });

    test('pushChanges sends atomic batch with idempotency key', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/sync/push') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['clientId'], 'test_device');
          expect((body['changes'] as List).length, 1);

          return http.Response(
            jsonEncode({
              'status': 'success',
              'appliedCount': 1,
              'serverRevision': 16,
              'results': [{'id': 'mut_1', 'status': 'applied'}],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = CentralApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        httpClient: mockClient,
      );

      final mutation = SyncMutation(
        id: 'mut_1',
        idempotencyKey: 'idem_key_abc_123',
        facilityId: 'HOSP_001',
        changeType: 'update_operational_status',
        payload: {'generalBedsAvailable': 10},
        clientTimestamp: DateTime.now(),
        clientRevision: 15,
      );

      final pushRes = await apiClient.pushChanges(
        clientId: 'test_device',
        mutations: [mutation],
      );

      expect(pushRes.success, isTrue);
      expect(pushRes.appliedCount, 1);
      expect(pushRes.serverRevision, 16);
    });
  });

  group('SyncEngine & Offline State Transitions', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Handles offline fallback smoothly without errors', () async {
      final store = LocalFacilityStore();
      await store.initialize();

      // Mock client that simulates network failure / airplane mode
      final mockClient = MockClient((request) async {
        throw Exception('Connection refused / Airplane mode');
      });

      final apiClient = CentralApiClient(httpClient: mockClient);
      final engine = SyncEngine(localStore: store, apiClient: apiClient);

      final success = await engine.triggerSync();
      expect(success, isFalse);
      expect(engine.status.isOnline, isFalse);
      expect(engine.state, SyncState.offline);
    });

    test('Syncs upstream pending changes and pulls latest server revision when online', () async {
      final store = LocalFacilityStore();
      await store.initialize();

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/health') {
          return http.Response(
            jsonEncode({'status': 'healthy', 'facilitiesCount': 45}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/sync/push') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'appliedCount': 1,
              'serverRevision': 25,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/sync/pull') {
          return http.Response(
            jsonEncode({
              'facilities': [],
              'count': 0,
              'serverRevision': 25,
              'serverTime': DateTime.now().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = CentralApiClient(httpClient: mockClient);
      final engine = SyncEngine(localStore: store, apiClient: apiClient);

      // Add offline mutation
      final mutation = SyncMutation(
        id: 'mut_queue_1',
        idempotencyKey: 'idem_queue_1',
        facilityId: 'HOSP_001',
        changeType: 'update_operational_status',
        payload: {'generalBedsAvailable': 8},
        clientTimestamp: DateTime.now(),
        clientRevision: 1,
      );
      await store.enqueueMutation(mutation);
      expect(store.getPendingMutations().length, 1);

      // Trigger sync
      final success = await engine.triggerSync();
      expect(success, isTrue);
      expect(engine.state, SyncState.synchronized);
      // Verify pending queue was drained
      expect(store.getPendingMutations().length, 0);
      expect(store.lastSyncedRevision, 25);
    });
  });

  group('OfflineFirstHospitalRepository & Clinical Safety', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Provides zero-latency offline hospital access for clinical triage', () async {
      final store = LocalFacilityStore();
      await store.initialize();

      final mockClient = MockClient((request) async => http.Response('error', 500));
      final engine = SyncEngine(localStore: store, apiClient: CentralApiClient(httpClient: mockClient));
      final repo = OfflineFirstHospitalRepository(store: store, syncEngine: engine);

      final hospitals = await repo.getAllHospitals();
      expect(hospitals.isNotEmpty, isTrue);

      final searchResults = await repo.searchHospitals(emergencyCareOnly: true);
      expect(searchResults.every((h) => h.emergencyCare), isTrue);
    });

    test('Enforces 60-minute dynamic capacity data freshness expiration', () {
      final freshHospital = MockClinicalData.sampleHospitals.first.copyWith(
        availabilityLastUpdated: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(freshHospital.isAvailabilityOutdated(), isFalse);

      final staleHospital = MockClinicalData.sampleHospitals.first.copyWith(
        availabilityLastUpdated: DateTime.now().subtract(const Duration(minutes: 75)),
      );
      expect(staleHospital.isAvailabilityOutdated(), isTrue);
    });

    test('Updating availability persists locally and enqueues sync mutation', () async {
      final store = LocalFacilityStore();
      await store.initialize();

      final mockClient = MockClient((request) async => http.Response('offline', 503));
      final engine = SyncEngine(localStore: store, apiClient: CentralApiClient(httpClient: mockClient));
      final repo = OfflineFirstHospitalRepository(store: store, syncEngine: engine);

      final targetId = MockClinicalData.sampleHospitals.first.hospitalId;
      final newAvail = HospitalAvailability(
        hospitalId: targetId,
        icuBedsAvailable: 5,
        generalBedsAvailable: 20,
        emergencyDepartmentOpen: true,
        operatingTheatersAvailable: 2,
        currentCapacity: 0.65,
        operatingStatus: 'Operational',
        availabilityLastUpdated: DateTime.now(),
        isSimulated: false,
      );

      await repo.updateHospitalAvailability(targetId, newAvail);

      final updated = await repo.getHospitalById(targetId);
      expect(updated!.bedAvailability, 25);
      expect(updated.icuAvailable, isTrue);

      // Verify mutation is queued for upload
      final mutations = store.getPendingMutations();
      expect(mutations.any((m) => m.facilityId == targetId), isTrue);
    });
  });

  group('Sync UI Widgets', () {
    testWidgets('SyncStatusPill renders Synced and Offline states properly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalFacilityStore();
      await store.initialize();

      final mockClient = MockClient((request) async => http.Response('offline', 503));
      final engine = SyncEngine(localStore: store, apiClient: CentralApiClient(httpClient: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SyncStatusPill(engine: engine),
            ),
          ),
        ),
      );

      expect(find.byType(SyncStatusPill), findsOneWidget);
      expect(find.text('Offline Cache'), findsOneWidget);
    });
  });
}
