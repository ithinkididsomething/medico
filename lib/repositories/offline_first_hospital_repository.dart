import 'dart:async';
import '../models/hospital.dart';
import '../models/hospital_availability.dart';
import '../services/sync/central_api_client.dart';
import '../services/sync/local_facility_store.dart';
import '../services/sync/sync_engine.dart';
import 'hospital_repository.dart';

/// Offline-first hospital repository implementing the authoritative central sync architecture.
///
/// Features:
/// - Instant, zero-latency in-memory and local persistent reads for emergency triage.
/// - Automatic delta synchronization when online.
/// - Offline change queueing with idempotency keys.
/// - Clinical data freshness enforcement (60-minute dynamic capacity expiration).
class OfflineFirstHospitalRepository implements HospitalRepository {
  static OfflineFirstHospitalRepository? _instance;

  final LocalFacilityStore store;
  final SyncEngine syncEngine;

  OfflineFirstHospitalRepository({
    required this.store,
    required this.syncEngine,
  });

  /// Global shared instance for application-wide consistency.
  static OfflineFirstHospitalRepository get instance {
    if (_instance == null) {
      final localStore = LocalFacilityStore();
      final client = CentralApiClient();
      final engine = SyncEngine(localStore: localStore, apiClient: client);
      _instance = OfflineFirstHospitalRepository(
        store: localStore,
        syncEngine: engine,
      );
    }
    return _instance!;
  }

  /// Sets or replaces the singleton instance (useful for unit testing and DI).
  static void setInstance(OfflineFirstHospitalRepository repo) {
    _instance = repo;
  }

  /// Ensures underlying local store is initialized.
  Future<void> initialize() async {
    if (!store.isInitialized) {
      await store.initialize();
    }
  }

  @override
  Future<List<Hospital>> getAllHospitals() async {
    await initialize();
    return store.getAllFacilities();
  }

  @override
  Future<Hospital?> getHospitalById(String id) async {
    await initialize();
    return store.getFacilityById(id);
  }

  @override
  Future<List<Hospital>> getHospitalsBySpecialty(String specialty) async {
    await initialize();
    return store
        .getAllFacilities()
        .where((h) => h.hasSpecialty(specialty))
        .toList();
  }

  @override
  Future<List<Hospital>> getHospitalsByTag(String tag) async {
    await initialize();
    return store
        .getAllFacilities()
        .where((h) => h.hasTag(tag))
        .toList();
  }

  @override
  Future<List<String>> getAllTags() async {
    await initialize();
    final set = <String>{};
    for (final h in store.getAllFacilities()) {
      set.addAll(h.tags);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Future<void> updateHospitalAvailability(
    String hospitalId,
    HospitalAvailability availability,
  ) async {
    await initialize();
    final existing = store.getFacilityById(hospitalId);
    if (existing != null) {
      final updated = existing.copyWith(
        bedAvailability:
            availability.generalBedsAvailable + availability.icuBedsAvailable,
        icuAvailable: availability.icuBedsAvailable > 0,
        currentCapacity: availability.currentCapacity,
        operatingStatus: availability.operatingStatus,
        availabilityLastUpdated: availability.availabilityLastUpdated,
        availability: availability,
        isSimulatedData: false,
      );
      await store.upsertFacility(updated);

      // Enqueue mutation for server synchronization
      await syncEngine.recordLocalChange(
        facilityId: hospitalId,
        changeType: 'update_operational_status',
        payload: {
          'generalBedsAvailable': availability.generalBedsAvailable,
          'icuBedsAvailable': availability.icuBedsAvailable,
          'currentCapacity': availability.currentCapacity,
          'operatingStatus': availability.operatingStatus,
          'emergencyDepartmentOpen': availability.emergencyDepartmentOpen,
          'operatingTheatersAvailable': availability.operatingTheatersAvailable,
          'lastReportedAt': availability.availabilityLastUpdated.toIso8601String(),
        },
      );
    }
  }

  @override
  Future<List<Hospital>> searchHospitals({
    String? query,
    String? specialty,
    String? tag,
    bool? emergencyCareOnly,
    bool? icuAvailableOnly,
    String? diagnosticFacility,
    bool? availableBedsOnly,
    bool? operationalOnly,
  }) async {
    await initialize();
    return store.getAllFacilities().where((hospital) {
      // 1. Text Query (Hospital name, address, specialties, diagnostics, or tags)
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final nameMatch = hospital.name.toLowerCase().contains(q);
        final addressMatch = hospital.address.toLowerCase().contains(q);
        final specMatch =
            hospital.specialties.any((s) => s.toLowerCase().contains(q));
        final tagMatch = hospital.tags.any((t) => t.toLowerCase().contains(q));
        final facilityMatch = hospital.diagnosticFacilities
                .any((d) => d.toLowerCase().contains(q)) ||
            hospital.treatmentCapabilities
                .any((t) => t.toLowerCase().contains(q));
        if (!nameMatch && !addressMatch && !specMatch && !tagMatch && !facilityMatch) {
          return false;
        }
      }

      // 2. Tag Filter
      if (tag != null && tag.trim().isNotEmpty && tag != 'All') {
        if (!hospital.hasTag(tag)) {
          return false;
        }
      }

      // 3. Specialty Filter
      if (specialty != null && specialty.trim().isNotEmpty && specialty != 'All') {
        if (!hospital.hasSpecialty(specialty)) {
          return false;
        }
      }

      // 4. Emergency Care Filter
      if (emergencyCareOnly == true && !hospital.emergencyCare) {
        return false;
      }

      // 5. ICU Available Filter
      if (icuAvailableOnly == true &&
          (!hospital.icuAvailable ||
              (hospital.availability?.icuBedsAvailable ?? 0) <= 0)) {
        return false;
      }

      // 6. Diagnostic Facility Filter
      if (diagnosticFacility != null &&
          diagnosticFacility.trim().isNotEmpty &&
          diagnosticFacility != 'All') {
        if (!hospital.hasFacility(diagnosticFacility)) {
          return false;
        }
      }

      // 7. Available Beds Filter
      if (availableBedsOnly == true && hospital.bedAvailability <= 0) {
        return false;
      }

      // 8. Operational Status Filter
      if (operationalOnly == true &&
          hospital.operatingStatus.toLowerCase() == 'diverting') {
        return false;
      }

      return true;
    }).toList();
  }
}
