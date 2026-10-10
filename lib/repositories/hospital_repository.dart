import '../models/hospital.dart';
import '../models/hospital_availability.dart';
import '../models/mock_data.dart';

/// Repository contract for hospital directory query and search operations.
abstract class HospitalRepository {
  Future<List<Hospital>> getAllHospitals();
  Future<Hospital?> getHospitalById(String id);
  Future<List<Hospital>> getHospitalsBySpecialty(String specialty);
  Future<List<Hospital>> getHospitalsByTag(String tag);
  Future<List<String>> getAllTags();
  Future<void> updateHospitalAvailability(String hospitalId, HospitalAvailability availability);
  Future<List<Hospital>> searchHospitals({
    String? query,
    String? specialty,
    String? tag,
    bool? emergencyCareOnly,
    bool? icuAvailableOnly,
    String? diagnosticFacility,
    bool? availableBedsOnly,
    bool? operationalOnly,
  });
}

/// In-memory repository implementing the hospital directory using synthetic hospital data.
class InMemoryHospitalRepository implements HospitalRepository {
  final Map<String, Hospital> _storage = {};

  InMemoryHospitalRepository({
    bool preloadMockData = true,
    List<Hospital>? initialHospitals,
  }) {
    if (initialHospitals != null) {
      for (final h in initialHospitals) {
        _storage[h.hospitalId] = h;
      }
    } else if (preloadMockData) {
      for (final h in MockClinicalData.sampleHospitals) {
        _storage[h.hospitalId] = h;
      }
    }
  }

  @override
  Future<List<Hospital>> getAllHospitals() async {
    return List.unmodifiable(_storage.values.toList());
  }

  @override
  Future<Hospital?> getHospitalById(String id) async {
    return _storage[id];
  }

  @override
  Future<List<Hospital>> getHospitalsBySpecialty(String specialty) async {
    return _storage.values.where((h) => h.hasSpecialty(specialty)).toList();
  }

  @override
  Future<List<Hospital>> getHospitalsByTag(String tag) async {
    return _storage.values.where((h) => h.hasTag(tag)).toList();
  }

  @override
  Future<List<String>> getAllTags() async {
    final set = <String>{};
    for (final h in _storage.values) {
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
    final existing = _storage[hospitalId];
    if (existing != null) {
      final updated = existing.copyWith(
        bedAvailability: availability.generalBedsAvailable + availability.icuBedsAvailable,
        icuAvailable: availability.icuBedsAvailable > 0,
        currentCapacity: availability.currentCapacity,
        operatingStatus: availability.operatingStatus,
        availabilityLastUpdated: availability.availabilityLastUpdated,
        availability: availability,
      );
      _storage[hospitalId] = updated;
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
    return _storage.values.where((hospital) {
      // 1. Text Query (Hospital name, address, specialties, diagnostics, or tags)
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final nameMatch = hospital.name.toLowerCase().contains(q);
        final addressMatch = hospital.address.toLowerCase().contains(q);
        final specMatch = hospital.specialties.any((s) => s.toLowerCase().contains(q));
        final tagMatch = hospital.tags.any((t) => t.toLowerCase().contains(q));
        final facilityMatch = hospital.diagnosticFacilities.any((d) => d.toLowerCase().contains(q)) ||
            hospital.treatmentCapabilities.any((t) => t.toLowerCase().contains(q));
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

      // 4. ICU Available Filter
      if (icuAvailableOnly == true && (!hospital.icuAvailable || (hospital.availability?.icuBedsAvailable ?? 0) <= 0)) {
        return false;
      }

      // 5. Diagnostic Facility Filter
      if (diagnosticFacility != null && diagnosticFacility.trim().isNotEmpty && diagnosticFacility != 'All') {
        if (!hospital.hasFacility(diagnosticFacility)) {
          return false;
        }
      }

      // 6. Available Beds Filter
      if (availableBedsOnly == true && hospital.bedAvailability <= 0) {
        return false;
      }

      // 7. Operational Status Filter
      if (operationalOnly == true && hospital.operatingStatus.toLowerCase() == 'diverting') {
        return false;
      }

      return true;
    }).toList();
  }
}

/// Alias for backward compatibility
typedef MockHospitalRepository = InMemoryHospitalRepository;
