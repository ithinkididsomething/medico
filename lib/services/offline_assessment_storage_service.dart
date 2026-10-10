import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/symptom_analysis.dart';

/// Item queued for transmission during network re-establishment.
class OfflineSyncQueueItem {
  final String queueId;
  final String entityType; // 'assessment', 'tag', 'referral', 'lifecycle'
  final String entityId;
  final String action; // 'create', 'update', 'delete'
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const OfflineSyncQueueItem({
    required this.queueId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.idempotencyKey,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'queue_id': queueId,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': payload,
      'idempotency_key': idempotencyKey,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  factory OfflineSyncQueueItem.fromMap(Map<String, dynamic> map) {
    return OfflineSyncQueueItem(
      queueId: (map['queue_id'] ?? '').toString(),
      entityType: (map['entity_type'] ?? 'assessment').toString(),
      entityId: (map['entity_id'] ?? '').toString(),
      action: (map['action'] ?? 'create').toString(),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      idempotencyKey: (map['idempotency_key'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      lastError: map['last_error']?.toString(),
    );
  }
}

/// Persistent local storage engine for offline patient assessments, custom tags,
/// and queued referral dispatches.
class OfflineAssessmentStorageService extends ChangeNotifier {
  static final OfflineAssessmentStorageService _instance = OfflineAssessmentStorageService._internal();
  static OfflineAssessmentStorageService get instance => _instance;

  static const String _assessmentsKey = 'smart_referral_offline_assessments_v1';
  static const String _customTagsKey = 'smart_referral_custom_tags_v1';
  static const String _syncQueueKey = 'smart_referral_offline_sync_queue_v1';
  static const String _lifecycleKey = 'smart_referral_referral_lifecycle_v1';

  final SharedPreferences? _customPrefs;
  SharedPreferences? _prefs;

  final Map<String, SymptomAnalysisResult> _cachedAssessments = {};
  final Map<String, ClinicianCustomTag> _cachedTags = {};
  final List<OfflineSyncQueueItem> _syncQueue = [];
  final Map<String, ReferralLifecycleState> _lifecycleStates = {};

  bool _isInitialized = false;

  OfflineAssessmentStorageService._internal({SharedPreferences? prefs}) : _customPrefs = prefs;

  /// Visible for testing to inject mock SharedPreferences.
  factory OfflineAssessmentStorageService.withPrefs(SharedPreferences prefs) {
    final s = OfflineAssessmentStorageService._internal(prefs: prefs);
    return s;
  }

  bool get isInitialized => _isInitialized;
  int get pendingQueueCount => _syncQueue.length;
  List<OfflineSyncQueueItem> get syncQueue => List.unmodifiable(_syncQueue);

  /// Initializes local persistent cache.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = _customPrefs ?? await SharedPreferences.getInstance();

    // 1. Load assessments
    final asmtRaw = _prefs!.getString(_assessmentsKey);
    if (asmtRaw != null) {
      try {
        final list = jsonDecode(asmtRaw) as List<dynamic>;
        for (final item in list) {
          final res = SymptomAnalysisResult.fromMap(Map<String, dynamic>.from(item as Map));
          _cachedAssessments[res.assessmentId] = res;
        }
      } catch (_) {}
    }

    // 2. Load custom tags
    final tagsRaw = _prefs!.getString(_customTagsKey);
    if (tagsRaw != null) {
      try {
        final list = jsonDecode(tagsRaw) as List<dynamic>;
        for (final item in list) {
          final tag = ClinicianCustomTag.fromMap(Map<String, dynamic>.from(item as Map));
          _cachedTags[tag.tagId] = tag;
        }
      } catch (_) {}
    } else {
      // Seed initial offline built-in tags
      _seedDefaultBuiltinTags();
    }

    // 3. Load sync queue
    final queueRaw = _prefs!.getString(_syncQueueKey);
    if (queueRaw != null) {
      try {
        final list = jsonDecode(queueRaw) as List<dynamic>;
        _syncQueue.clear();
        for (final item in list) {
          _syncQueue.add(OfflineSyncQueueItem.fromMap(Map<String, dynamic>.from(item as Map)));
        }
      } catch (_) {}
    }

    // 4. Load lifecycle states
    final lifeRaw = _prefs!.getString(_lifecycleKey);
    if (lifeRaw != null) {
      try {
        final map = jsonDecode(lifeRaw) as Map<String, dynamic>;
        map.forEach((k, v) {
          _lifecycleStates[k] = ReferralLifecycleState.fromCode(v.toString());
        });
      } catch (_) {}
    }

    _isInitialized = true;
    notifyListeners();
  }

  void _seedDefaultBuiltinTags() {
    final defaults = [
      'Possible cardiac symptoms',
      'Breathing difficulty',
      'Neurological warning signs',
      'Suspected infection',
      'Injury or trauma',
      'Pregnancy-related concern',
      'Pediatric concern',
      'Diagnostic information missing',
      'High fever',
      'Severe dehydration',
      'Acute abdominal pain',
      'Active bleeding',
    ];
    final now = DateTime.now();
    for (int i = 0; i < defaults.length; i++) {
      final name = defaults[i];
      final tag = ClinicianCustomTag(
        tagId: 'builtin_tag_$i',
        name: name,
        isBuiltin: true,
        createdAt: now,
      );
      _cachedTags[tag.tagId] = tag;
    }
  }

  // --- Assessments Local Storage ---

  Future<void> saveAssessmentLocally(SymptomAnalysisResult result, {bool queueForSync = true}) async {
    await _ensureInitialized();
    _cachedAssessments[result.assessmentId] = result;
    await _persistAssessments();

    if (queueForSync) {
      final queueItem = OfflineSyncQueueItem(
        queueId: 'q_asmt_${DateTime.now().millisecondsSinceEpoch}_${result.assessmentId}',
        entityType: 'assessment',
        entityId: result.assessmentId,
        action: 'create',
        payload: result.toMap(),
        idempotencyKey: 'idem_asmt_${result.assessmentId}',
        createdAt: DateTime.now(),
      );
      _syncQueue.add(queueItem);
      await _persistQueue();
    }
    notifyListeners();
  }

  SymptomAnalysisResult? getAssessment(String assessmentId) {
    return _cachedAssessments[assessmentId];
  }

  List<SymptomAnalysisResult> getPatientAssessments(String patientId) {
    return _cachedAssessments.values
        .where((a) => a.patientId == patientId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // --- Custom Tags Management ---

  List<ClinicianCustomTag> getAllTags() {
    return _cachedTags.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<ClinicianCustomTag> createCustomTagOffline(String name, {String category = 'general', String createdBy = 'Clinician'}) async {
    await _ensureInitialized();
    final trimmed = name.trim();
    // Prevent duplicate tag
    for (final tag in _cachedTags.values) {
      if (tag.name.toLowerCase() == trimmed.toLowerCase()) {
        return tag;
      }
    }

    final tagId = 'tag_offline_${DateTime.now().millisecondsSinceEpoch}';
    final newTag = ClinicianCustomTag(
      tagId: tagId,
      name: trimmed,
      category: category,
      isBuiltin: false,
      isAiSuggested: false,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      revision: 1,
    );

    _cachedTags[tagId] = newTag;
    await _persistTags();

    // Queue for sync
    final queueItem = OfflineSyncQueueItem(
      queueId: 'q_tag_${DateTime.now().millisecondsSinceEpoch}',
      entityType: 'tag',
      entityId: tagId,
      action: 'create',
      payload: newTag.toMap(),
      idempotencyKey: 'idem_tag_$tagId',
      createdAt: DateTime.now(),
    );
    _syncQueue.add(queueItem);
    await _persistQueue();

    notifyListeners();
    return newTag;
  }

  // --- Referral Delivery Lifecycle Tracking ---

  ReferralLifecycleState? getLifecycleState(String referralId) {
    return _lifecycleStates[referralId];
  }

  ReferralLifecycleState getReferralLifecycle(String referralId) {
    return _lifecycleStates[referralId] ?? ReferralLifecycleState.referralDraftSavedLocally;
  }

  Future<void> updateLifecycleState(
    String referralId,
    ReferralLifecycleState newState, {
    String patientId = 'PAT-UNSPECIFIED',
    String receivingFacilityId = 'indore_hospital_001',
    bool isAmbulanceDispatched = false,
  }) async {
    await updateReferralLifecycleOffline(
      referralId: referralId,
      newState: newState,
      patientId: patientId,
      receivingFacilityId: receivingFacilityId,
      isAmbulanceDispatched: isAmbulanceDispatched,
    );
  }

  Future<void> updateReferralLifecycleOffline({
    required String referralId,
    required ReferralLifecycleState newState,
    required String patientId,
    required String receivingFacilityId,
    bool isAmbulanceDispatched = false,
  }) async {
    await _ensureInitialized();
    _lifecycleStates[referralId] = newState;
    await _persistLifecycle();

    // Enqueue mutation
    final queueItem = OfflineSyncQueueItem(
      queueId: 'q_ref_${DateTime.now().millisecondsSinceEpoch}_$referralId',
      entityType: 'referral',
      entityId: referralId,
      action: 'update_lifecycle',
      payload: {
        'referral_id': referralId,
        'patient_id': patientId,
        'receiving_facility_id': receivingFacilityId,
        'current_state': newState.code,
        'is_ambulance_dispatched': isAmbulanceDispatched,
      },
      idempotencyKey: 'idem_ref_${referralId}_${newState.code}',
      createdAt: DateTime.now(),
    );
    _syncQueue.add(queueItem);
    await _persistQueue();

    notifyListeners();
  }

  // --- Sync Queue Maintenance ---

  Future<void> removeQueueItem(String queueId) async {
    await _ensureInitialized();
    _syncQueue.removeWhere((item) => item.queueId == queueId);
    await _persistQueue();
    notifyListeners();
  }

  Future<void> clearCompletedQueue(List<String> idempotencyKeys) async {
    await _ensureInitialized();
    _syncQueue.removeWhere((item) => idempotencyKeys.contains(item.idempotencyKey));
    await _persistQueue();
    notifyListeners();
  }

  // --- Persistence Helpers ---

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }

  Future<void> _persistAssessments() async {
    if (_prefs == null) return;
    final list = _cachedAssessments.values.map((a) => a.toMap()).toList();
    await _prefs!.setString(_assessmentsKey, jsonEncode(list));
  }

  Future<void> _persistTags() async {
    if (_prefs == null) return;
    final list = _cachedTags.values.map((t) => t.toMap()).toList();
    await _prefs!.setString(_customTagsKey, jsonEncode(list));
  }

  Future<void> _persistQueue() async {
    if (_prefs == null) return;
    final list = _syncQueue.map((q) => q.toMap()).toList();
    await _prefs!.setString(_syncQueueKey, jsonEncode(list));
  }

  Future<void> _persistLifecycle() async {
    if (_prefs == null) return;
    final map = _lifecycleStates.map((k, v) => MapEntry(k, v.code));
    await _prefs!.setString(_lifecycleKey, jsonEncode(map));
  }
}
