import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_referral.dart';

/// Offline-first repository managing Emergency Referrals, post-dispatch
/// versioning, local queueing, and central backend synchronization.
class EmergencyReferralRepository {
  static const String _storageKey = 'smart_referral_emergency_referrals_v1';
  static const String _draftKey = 'smart_referral_emergency_draft_v1';

  final String baseUrl;
  final http.Client _httpClient;
  final SharedPreferences? _prefs;

  final Map<String, EmergencyReferral> _cache = {};
  bool _isInitialized = false;

  static EmergencyReferralRepository? _instance;
  static EmergencyReferralRepository get instance {
    _instance ??= EmergencyReferralRepository();
    return _instance!;
  }

  static void setInstance(EmergencyReferralRepository repo) {
    _instance = repo;
  }

  EmergencyReferralRepository({
    String? baseUrl,
    http.Client? httpClient,
    SharedPreferences? prefs,
  })  : baseUrl = (baseUrl ?? 'http://localhost:8000/api/v1').replaceAll(RegExp(r'/+$'), ''),
        _httpClient = httpClient ?? http.Client(),
        // ignore: prefer_initializing_formals
        _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _cache.clear();
        for (final entry in decoded.entries) {
          try {
            _cache[entry.key] = EmergencyReferral.fromMap(Map<String, dynamic>.from(entry.value as Map));
          } catch (_) {}
        }
      }
    } catch (_) {}
    _isInitialized = true;
  }

  Future<void> _persistCache() async {
    try {
      final prefs = await _getPrefs();
      final map = <String, dynamic>{};
      for (final e in _cache.entries) {
        map[e.key] = e.value.toMap();
      }
      await prefs.setString(_storageKey, jsonEncode(map));
    } catch (_) {}
  }

  /// Saves local draft of in-progress emergency referral.
  Future<void> saveDraft(Map<String, dynamic> draftData) async {
    final prefs = await _getPrefs();
    await prefs.setString(_draftKey, jsonEncode(draftData));
  }

  /// Retrieves local emergency draft if any exists.
  Future<Map<String, dynamic>?> getDraft() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_draftKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    return null;
  }

  /// Clears active emergency referral draft.
  Future<void> clearDraft() async {
    final prefs = await _getPrefs();
    await prefs.remove(_draftKey);
  }

  /// Returns all emergency referrals (local cache + online delta).
  Future<List<EmergencyReferral>> getAllReferrals({bool forceRefresh = false}) async {
    await initialize();

    if (forceRefresh || _cache.isEmpty) {
      try {
        final uri = Uri.parse('$baseUrl/emergency-referrals?limit=100');
        final res = await _httpClient.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = (data['referrals'] as List<dynamic>?) ?? [];
          for (final item in list) {
            final ref = EmergencyReferral.fromMap(Map<String, dynamic>.from(item as Map));
            _cache[ref.referralId] = ref;
          }
          await _persistCache();
        }
      } catch (_) {
        // Fall back to local persistent storage gracefully
      }
    }

    final sorted = _cache.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  /// Fetches a specific emergency referral by ID.
  Future<EmergencyReferral?> getReferralById(String referralId) async {
    await initialize();

    try {
      final uri = Uri.parse('$baseUrl/emergency-referrals/$referralId');
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['referral'] != null) {
          final ref = EmergencyReferral.fromMap(Map<String, dynamic>.from(data['referral'] as Map));
          _cache[ref.referralId] = ref;
          await _persistCache();
          return ref;
        }
      }
    } catch (_) {}

    return _cache[referralId];
  }

  /// Creates a new emergency referral record.
  /// Immediate local persistence ensures network latency NEVER delays clinical care.
  Future<EmergencyReferral> createEmergencyReferral(EmergencyReferral referral) async {
    await initialize();

    // 1. Immediately store in local cache
    _cache[referral.referralId] = referral;
    await _persistCache();
    await clearDraft();

    // 2. Synchronize to central backend
    try {
      final uri = Uri.parse('$baseUrl/emergency-referrals');
      final res = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: referral.toJson(),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['referral'] != null) {
          final serverRef = EmergencyReferral.fromMap(Map<String, dynamic>.from(data['referral'] as Map));
          _cache[serverRef.referralId] = serverRef;
          await _persistCache();
          return serverRef;
        }
      }
    } catch (_) {
      // Stored locally - marked for sync
      final localRef = referral.copyWith(isOfflineSynced: false);
      _cache[localRef.referralId] = localRef;
      await _persistCache();
      return localRef;
    }

    return referral;
  }

  /// Adds a post-dispatch versioned clinical update / amendment.
  Future<EmergencyReferral> addClinicalAmendment({
    required String referralId,
    required Map<String, dynamic> updateData,
    required String amendmentReason,
    String editorName = 'Dr. Parth Saxena',
  }) async {
    await initialize();

    final payload = {
      ...updateData,
      'amendmentReason': amendmentReason,
      'editorName': editorName,
    };

    try {
      final uri = Uri.parse('$baseUrl/emergency-referrals/$referralId/versions');
      final res = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['referral'] != null) {
          final serverRef = EmergencyReferral.fromMap(Map<String, dynamic>.from(data['referral'] as Map));
          _cache[serverRef.referralId] = serverRef;
          await _persistCache();
          return serverRef;
        }
      }
    } catch (_) {}

    // Offline optimistic update
    final current = _cache[referralId];
    if (current != null) {
      final newVer = current.currentVersion + 1;
      final newVersionObj = EmergencyReferralVersion(
        referralId: referralId,
        versionNumber: newVer,
        createdAt: DateTime.now(),
        createdById: 'doc_offline',
        createdByName: editorName,
        amendmentReason: amendmentReason,
        changedFields: updateData.keys.toList(),
        snapshotData: updateData,
      );

      final updated = current.copyWith(
        currentVersion: newVer,
        updatedAt: DateTime.now(),
        versions: [...current.versions, newVersionObj],
        isOfflineSynced: false,
      );
      _cache[referralId] = updated;
      await _persistCache();
      return updated;
    }

    throw Exception('Referral $referralId not found');
  }

  /// Updates ambulance dispatch status and estimated arrival.
  Future<EmergencyReferral> updateAmbulanceDispatch({
    required String referralId,
    required AmbulanceDispatchStatus status,
    String? vehicleNumber,
    int? etaMinutes,
    String? notes,
  }) async {
    await initialize();

    final payload = {
      'ambulanceStatus': status.key,
      'ambulanceVehicleNumber': vehicleNumber,
      'ambulanceEtaMinutes': etaMinutes,
      'notes': notes ?? 'Ambulance status updated',
    };

    try {
      final uri = Uri.parse('$baseUrl/emergency-referrals/$referralId/dispatch');
      final res = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['referral'] != null) {
          final serverRef = EmergencyReferral.fromMap(Map<String, dynamic>.from(data['referral'] as Map));
          _cache[serverRef.referralId] = serverRef;
          await _persistCache();
          return serverRef;
        }
      }
    } catch (_) {}

    // Offline update
    final current = _cache[referralId];
    if (current != null) {
      final updated = current.copyWith(
        ambulanceStatus: status,
        ambulanceVehicleNumber: vehicleNumber ?? current.ambulanceVehicleNumber,
        ambulanceEtaMinutes: etaMinutes ?? current.ambulanceEtaMinutes,
        updatedAt: DateTime.now(),
      );
      _cache[referralId] = updated;
      await _persistCache();
      return updated;
    }

    throw Exception('Referral $referralId not found');
  }

  /// Dispatches the emergency referral notification via external delivery channel.
  Future<EmergencyReferral> sendReferralNotification({
    required String referralId,
    required String channel, // 'email', 'clinical_message', 'sms_alert', 'whatsapp_direct'
    String? recipientAddress,
    String? recipientName,
    String? customNotes,
    String senderName = 'Dr. Parth Saxena',
  }) async {
    await initialize();

    final payload = {
      'channel': channel,
      'recipientAddress': recipientAddress,
      'recipientName': recipientName,
      'notes': customNotes,
      'senderName': senderName,
    };

    try {
      final uri = Uri.parse('$baseUrl/emergency-referrals/$referralId/send');
      final res = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['referral'] != null) {
          final serverRef = EmergencyReferral.fromMap(Map<String, dynamic>.from(data['referral'] as Map));
          _cache[serverRef.referralId] = serverRef;
          await _persistCache();
          return serverRef;
        }
      }
    } catch (_) {}

    // Offline simulation: mark as queued
    final current = _cache[referralId];
    if (current != null) {
      final delivery = EmergencyDeliveryAttempt(
        referralId: referralId,
        channel: channel,
        recipientAddress: recipientAddress ?? 'facility_reception@health.gov.in',
        recipientName: recipientName,
        subjectOrPreview: 'URGENT EMERGENCY REFERRAL — $referralId',
        messageBody: customNotes ?? 'Clinical summary queued for transmission',
        deliveryStatus: 'queued',
        attemptedAt: DateTime.now(),
      );

      final updated = current.copyWith(
        deliveryStatus: EmergencyDeliveryStatus.queued,
        deliveries: [...current.deliveries, delivery],
        updatedAt: DateTime.now(),
      );
      _cache[referralId] = updated;
      await _persistCache();
      return updated;
    }

    throw Exception('Referral $referralId not found');
  }

  /// Records receiving hospital response (acknowledged, accepted, declined).
  Future<EmergencyReferral> recordAcknowledgement({
    required String referralId,
    required ReceivingResponseStatus responseStatus,
    String responderName = 'Duty Emergency Physician',
    String responderRole = 'Emergency Physician',
    String? alternativeFacilityId,
    String? notes,
  }) async {
    await initialize();

    final payload = {
      'responseStatus': responseStatus.key,
      'responderName': responderName,
      'responderRole': responderRole,
      'alternativeFacilityId': alternativeFacilityId,
      'notes': notes,
    };

    try {
      final uri = Uri.parse('$baseUrl/emergency-referrals/$referralId/acknowledge');
      final res = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['referral'] != null) {
          final serverRef = EmergencyReferral.fromMap(Map<String, dynamic>.from(data['referral'] as Map));
          _cache[serverRef.referralId] = serverRef;
          await _persistCache();
          return serverRef;
        }
      }
    } catch (_) {}

    final current = _cache[referralId];
    if (current != null) {
      final updated = current.copyWith(
        responseStatus: responseStatus,
        updatedAt: DateTime.now(),
      );
      _cache[referralId] = updated;
      await _persistCache();
      return updated;
    }

    throw Exception('Referral $referralId not found');
  }

  /// Records arrival at destination and completion of clinical handover.
  Future<EmergencyReferral> recordHandover({
    required String referralId,
    String actorName = 'Dr. Parth Saxena',
    String? notes,
  }) async {
    await initialize();

    final payload = {
      'actorName': actorName,
      'notes': notes,
    };

    try {
      final uri = Uri.parse('$baseUrl/emergency-referrals/$referralId/handover');
      final res = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['referral'] != null) {
          final serverRef = EmergencyReferral.fromMap(Map<String, dynamic>.from(data['referral'] as Map));
          _cache[serverRef.referralId] = serverRef;
          await _persistCache();
          return serverRef;
        }
      }
    } catch (_) {}

    final current = _cache[referralId];
    if (current != null) {
      final updated = current.copyWith(
        workflowStatus: EmergencyWorkflowStatus.handoverCompleted,
        ambulanceStatus: AmbulanceDispatchStatus.arrived,
        updatedAt: DateTime.now(),
      );
      _cache[referralId] = updated;
      await _persistCache();
      return updated;
    }

    throw Exception('Referral $referralId not found');
  }
}
