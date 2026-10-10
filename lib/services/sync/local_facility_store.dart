import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/hospital.dart';
import '../../models/mock_data.dart';
import '../../models/sync_mutation.dart';

/// Persistent local storage engine for offline-first facility data and pending mutations.
///
/// Backed by persistent storage with an in-memory high-speed cache to ensure zero latency
/// during emergency patient assessments and referral matching.
class LocalFacilityStore {
  static const String _facilitiesKey = 'smart_referral_facilities_cache_v1';
  static const String _revisionKey = 'smart_referral_last_synced_revision_v1';
  static const String _lastSyncedAtKey = 'smart_referral_last_synced_at_v1';
  static const String _mutationsKey = 'smart_referral_pending_mutations_v1';

  final SharedPreferences? _prefsInstance;
  final Map<String, Hospital> _facilities = {};
  final List<SyncMutation> _pendingMutations = [];
  int _lastSyncedRevision = 0;
  DateTime? _lastSyncedAt;
  bool _isInitialized = false;

  LocalFacilityStore({SharedPreferences? prefs}) : _prefsInstance = prefs;

  bool get isInitialized => _isInitialized;
  int get lastSyncedRevision => _lastSyncedRevision;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Initializes the local store from persistent storage,
  /// falling back to standard regional facilities if first launch offline.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = _prefsInstance ?? await SharedPreferences.getInstance();

    // 1. Load revision and sync timestamp
    _lastSyncedRevision = prefs.getInt(_revisionKey) ?? 0;
    final lastSyncedStr = prefs.getString(_lastSyncedAtKey);
    if (lastSyncedStr != null) {
      _lastSyncedAt = DateTime.tryParse(lastSyncedStr);
    }

    // 2. Load pending mutations
    final mutationsRaw = prefs.getString(_mutationsKey);
    if (mutationsRaw != null) {
      try {
        final list = jsonDecode(mutationsRaw) as List<dynamic>;
        _pendingMutations.clear();
        for (final item in list) {
          _pendingMutations.add(
            SyncMutation.fromMap(Map<String, dynamic>.from(item as Map)),
          );
        }
      } catch (_) {
        _pendingMutations.clear();
      }
    }

    // 3. Load cached facilities
    final facilitiesRaw = prefs.getString(_facilitiesKey);
    if (facilitiesRaw != null) {
      try {
        final decoded = jsonDecode(facilitiesRaw) as Map<String, dynamic>;
        _facilities.clear();
        for (final entry in decoded.entries) {
          _facilities[entry.key] = Hospital.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      } catch (_) {
        _facilities.clear();
      }
    }

    // 4. First-time offline baseline fallback: load regional mock data if store is empty
    if (_facilities.isEmpty) {
      for (final h in MockClinicalData.sampleHospitals) {
        _facilities[h.hospitalId] = h;
      }
      _lastSyncedRevision = 1;
      _lastSyncedAt = DateTime.now();
      await _persistFacilities(prefs);
      await prefs.setInt(_revisionKey, _lastSyncedRevision);
      await prefs.setString(_lastSyncedAtKey, _lastSyncedAt!.toIso8601String());
    }

    _isInitialized = true;
  }

  /// Synchronously returns all cached facilities from memory.
  List<Hospital> getAllFacilities() {
    return List.unmodifiable(_facilities.values.toList());
  }

  /// Synchronously returns a single hospital by ID from memory.
  Hospital? getFacilityById(String id) {
    return _facilities[id];
  }

  /// Upserts a batch of facilities downloaded from the central backend.
  Future<void> upsertFacilities(
    List<Hospital> facilities, {
    int? serverRevision,
    DateTime? syncTime,
  }) async {
    for (final h in facilities) {
      _facilities[h.hospitalId] = h;
    }

    if (serverRevision != null && serverRevision > _lastSyncedRevision) {
      _lastSyncedRevision = serverRevision;
    }
    if (syncTime != null) {
      _lastSyncedAt = syncTime;
    } else {
      _lastSyncedAt = DateTime.now();
    }

    final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
    await _persistFacilities(prefs);
    await prefs.setInt(_revisionKey, _lastSyncedRevision);
    await prefs.setString(_lastSyncedAtKey, _lastSyncedAt!.toIso8601String());
  }

  /// Upserts or updates a single facility locally.
  Future<void> upsertFacility(Hospital facility) async {
    _facilities[facility.hospitalId] = facility;
    final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
    await _persistFacilities(prefs);
  }

  /// Enqueues a pending mutation to be pushed to the backend when online.
  Future<void> enqueueMutation(SyncMutation mutation) async {
    _pendingMutations.add(mutation);
    final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
    await _persistMutations(prefs);
  }

  /// Returns unmodifiable list of pending sync mutations.
  List<SyncMutation> getPendingMutations() {
    return List.unmodifiable(_pendingMutations);
  }

  /// Removes successfully synced mutations by ID.
  Future<void> removeMutations(List<String> mutationIds) async {
    _pendingMutations.removeWhere((m) => mutationIds.contains(m.id));
    final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
    await _persistMutations(prefs);
  }

  /// Updates a mutation with error details and increments retry count.
  Future<void> updateMutationError(String mutationId, String error) async {
    final idx = _pendingMutations.indexWhere((m) => m.id == mutationId);
    if (idx != -1) {
      final existing = _pendingMutations[idx];
      _pendingMutations[idx] = existing.copyWith(
        retryCount: existing.retryCount + 1,
        lastError: error,
      );
      final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
      await _persistMutations(prefs);
    }
  }

  /// Clears all local store data (useful for full re-sync or testing).
  Future<void> clearAll() async {
    _facilities.clear();
    _pendingMutations.clear();
    _lastSyncedRevision = 0;
    _lastSyncedAt = null;

    final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
    await prefs.remove(_facilitiesKey);
    await prefs.remove(_revisionKey);
    await prefs.remove(_lastSyncedAtKey);
    await prefs.remove(_mutationsKey);
  }

  Future<void> _persistFacilities(SharedPreferences prefs) async {
    final map = <String, dynamic>{};
    for (final entry in _facilities.entries) {
      map[entry.key] = entry.value.toMap();
    }
    await prefs.setString(_facilitiesKey, jsonEncode(map));
  }

  Future<void> _persistMutations(SharedPreferences prefs) async {
    final list = _pendingMutations.map((m) => m.toMap()).toList();
    await prefs.setString(_mutationsKey, jsonEncode(list));
  }
}
