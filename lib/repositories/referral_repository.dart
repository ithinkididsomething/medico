import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart';
import '../models/mock_data.dart';
import '../models/referral.dart';
import '../models/referral_status_history.dart';

/// Repository interface for clinical referral storage and status tracking.
/// Designed for local persistence now and extensible for Firebase/Firestore sync.
abstract class ReferralRepository {
  Future<List<Referral>> getAllReferrals();
  Future<Referral?> getReferralById(String id);
  Future<List<Referral>> getReferralsByStatus(ReferralStatus status);
  Future<void> saveReferral(Referral referral);
  Future<Referral?> updateStatus(
    String referralId,
    ReferralStatus status,
    String note, {
    DateTime? timestamp,
  });
  Future<bool> deleteReferral(String id);
}

/// Persistent referral repository using SharedPreferences for local persistence,
/// with in-memory caching and JSON serialization.
class LocalReferralRepository implements ReferralRepository {
  static const String storageKey = 'smart_referral_records_v2';

  static LocalReferralRepository? _instance;
  static LocalReferralRepository get instance =>
      _instance ??= LocalReferralRepository();

  final bool usePersistentPrefs;
  final Map<String, Referral> _storage = {};
  SharedPreferences? _prefs;
  bool _initialized = false;

  LocalReferralRepository({
    bool preloadMockData = true,
    this.usePersistentPrefs = true,
  }) {
    if (preloadMockData) {
      _seedDefaultReferrals();
    }
  }

  void _seedDefaultReferrals() {
    // 1. Emergency referral: P001 | Emergency | District General | Pending
    final sample1 = Referral(
      referralId: 'REF-001',
      patient: MockClinicalData.patientPostpartumHemorrhage.copyWith(
        patientId: 'P001',
      ),
      urgencyLevel: UrgencyLevel.emergency,
      referralReason:
          'Severe postpartum hemorrhage and hypovolemic shock requiring urgent blood transfusion and surgical intervention.',
      requiredSpecialty: 'Obstetrics & Gynecology',
      requiredFacilities: const [
        '24/7 Blood Bank',
        'Emergency Cesarean Section (C-Section)',
        'ICU Mechanical Ventilation',
      ],
      recommendedHospital: MockClinicalData.hospitalDistrictGeneral,
      alternativeHospitals: [
        MockClinicalData.hospitalMaternalChild,
        MockClinicalData.hospitalRegionalApex,
      ],
      estimatedDistance: 24.8,
      estimatedTravelTime: const Duration(minutes: 38),
      recommendationScore: 94.5,
      status: ReferralStatus.pending,
      statusHistory: [
        ReferralStatusHistory(
          status: ReferralStatus.pending,
          timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
          note: 'Initial emergency referral generated at rural clinic.',
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 25)),
      referringClinic: 'Primary Health Center Sector 4',
    );

    // 2. Urgent referral: P002 | Urgent | St. Jude Maternal & Child | Referred
    final sample2 = Referral(
      referralId: 'REF-002',
      patient: MockClinicalData.patientPediatricPneumonia.copyWith(
        patientId: 'P002',
      ),
      urgencyLevel: UrgencyLevel.urgent,
      referralReason: 'Severe pediatric pneumonia requiring pediatric ICU and supplemental oxygen.',
      requiredSpecialty: 'Pediatrics',
      requiredFacilities: const ['High-flow Oxygen', 'Pediatric ICU', 'Digital X-Ray'],
      recommendedHospital: MockClinicalData.hospitalMaternalChild,
      alternativeHospitals: [MockClinicalData.hospitalRegionalApex],
      estimatedDistance: 19.4,
      estimatedTravelTime: const Duration(minutes: 32),
      recommendationScore: 88.0,
      status: ReferralStatus.referred,
      statusHistory: [
        ReferralStatusHistory(
          status: ReferralStatus.pending,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          note: 'Referral order created.',
        ),
        ReferralStatusHistory(
          status: ReferralStatus.referred,
          timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
          note: 'Transfer request dispatched to St. Jude Maternal & Child.',
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
      referringClinic: 'Primary Health Center Sector 4',
    );

    // 3. Routine referral: P003 | Routine | Taluk Community Hospital | Completed
    final sample3 = Referral(
      referralId: 'REF-003',
      patient: MockClinicalData.patientMildViralInfection.copyWith(
        patientId: 'P003',
      ),
      urgencyLevel: UrgencyLevel.routine,
      referralReason: 'Elective specialist consultation for persistent respiratory symptoms.',
      requiredSpecialty: 'General Medicine',
      requiredFacilities: const ['Basic Clinical Lab'],
      recommendedHospital: MockClinicalData.hospitalTalukCommunity,
      alternativeHospitals: [MockClinicalData.hospitalDistrictGeneral],
      estimatedDistance: 8.5,
      estimatedTravelTime: const Duration(minutes: 16),
      recommendationScore: 82.0,
      status: ReferralStatus.completed,
      statusHistory: [
        ReferralStatusHistory(
          status: ReferralStatus.pending,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
          note: 'Elective referral logged.',
        ),
        ReferralStatusHistory(
          status: ReferralStatus.referred,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
          note: 'Scheduled consultation referral dispatched.',
        ),
        ReferralStatusHistory(
          status: ReferralStatus.accepted,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          note: 'Community hospital outpatient desk accepted appointment.',
        ),
        ReferralStatusHistory(
          status: ReferralStatus.transferred,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
          note: 'Patient reached facility for evaluation.',
        ),
        ReferralStatusHistory(
          status: ReferralStatus.completed,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          note: 'Consultation completed; return care plan issued.',
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      referringClinic: 'Primary Health Center Sector 4',
    );

    final sampleOriginal = MockClinicalData.sampleEmergencyReferral;
    _storage[sampleOriginal.referralId] = sampleOriginal;
    _storage[sample1.referralId] = sample1;
    _storage[sample2.referralId] = sample2;
    _storage[sample3.referralId] = sample3;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!usePersistentPrefs) {
      _initialized = true;
      return;
    }
    try {
      _prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 500),
      );
      final raw = _prefs?.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          final ref = Referral.fromMap(Map<String, dynamic>.from(item as Map));
          _storage[ref.referralId] = ref;
        }
      }
      // Guarantee any stale duplicate PAT-SIM-101 in storage is replaced by the new sampleEmergencyReferral
      if (_storage['REF-SIM-901']?.patient.patientId == 'PAT-SIM-101') {
        _storage['REF-SIM-901'] = MockClinicalData.sampleEmergencyReferral;
      }
    } catch (e) {
      // Graceful fallback for non-native plugin test harnesses
      if (kDebugMode) {
        print('LocalReferralRepository: Falling back to in-memory cache ($e)');
      }
    } finally {
      _initialized = true;
    }
  }

  Future<void> _persist() async {
    if (!usePersistentPrefs || _prefs == null) return;
    try {
      final list = _storage.values.map((r) => r.toMap()).toList();
      await _prefs!.setString(storageKey, jsonEncode(list));
    } catch (e) {
      if (kDebugMode) {
        print('LocalReferralRepository: Persist failed ($e)');
      }
    }
  }

  @override
  Future<List<Referral>> getAllReferrals() async {
    await initialize();
    final list = _storage.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Referral?> getReferralById(String id) async {
    await initialize();
    return _storage[id];
  }

  @override
  Future<List<Referral>> getReferralsByStatus(ReferralStatus status) async {
    await initialize();
    final list = _storage.values.where((r) => r.status == status).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> saveReferral(Referral referral) async {
    await initialize();
    _storage[referral.referralId] = referral;
    await _persist();
  }

  @override
  Future<Referral?> updateStatus(
    String referralId,
    ReferralStatus status,
    String note, {
    DateTime? timestamp,
  }) async {
    await initialize();
    final existing = _storage[referralId];
    if (existing == null) return null;

    final updated = existing.withNewStatus(
      status,
      note: note,
      timestamp: timestamp,
    );
    _storage[referralId] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<bool> deleteReferral(String id) async {
    await initialize();
    final removed = _storage.remove(id) != null;
    if (removed) {
      await _persist();
    }
    return removed;
  }
}

/// Backward compatible in-memory repository alias.
class InMemoryReferralRepository extends LocalReferralRepository {
  InMemoryReferralRepository({super.preloadMockData})
      : super(usePersistentPrefs: false);
}
