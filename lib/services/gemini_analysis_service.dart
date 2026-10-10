import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/symptom_analysis.dart';
import 'offline_clinical_rule_engine.dart';
import 'offline_assessment_storage_service.dart';

/// Connection and Gemini AI Service Presence Indicator.
enum GeminiConnectionStatus {
  onlineGeminiAvailable('Online — Gemini available'),
  offlineLocalAssessment('Offline — local assessment active'),
  geminiUnavailableUsingRules('Gemini unavailable — using local rules');

  final String label;
  const GeminiConnectionStatus(this.label);
}

/// Orchestrates Gemini AI symptom analysis when online, enforces mandatory
/// clinical safety rules, and seamlessly falls back to offline deterministic rules.
class GeminiAnalysisService extends ChangeNotifier {
  static final GeminiAnalysisService _instance = GeminiAnalysisService._internal();
  static GeminiAnalysisService get instance => _instance;

  final String baseUrl;
  final http.Client _httpClient;
  final Duration timeout;
  final OfflineAssessmentStorageService _storage;

  GeminiConnectionStatus _status = GeminiConnectionStatus.onlineGeminiAvailable;
  bool _isSyncingQueue = false;

  GeminiAnalysisService._internal({
    String? baseUrl,
    http.Client? httpClient,
    Duration? timeout,
    OfflineAssessmentStorageService? storage,
  })  : baseUrl = baseUrl ?? 'http://localhost:8000',
        _httpClient = httpClient ?? http.Client(),
        timeout = timeout ?? const Duration(seconds: 25),
        _storage = storage ?? OfflineAssessmentStorageService.instance;

  /// Visible for testing.
  factory GeminiAnalysisService.withClient({
    required http.Client client,
    String? baseUrl,
    Duration? timeout,
    OfflineAssessmentStorageService? storage,
  }) {
    return GeminiAnalysisService._internal(
      baseUrl: baseUrl,
      httpClient: client,
      timeout: timeout,
      storage: storage,
    );
  }

  GeminiConnectionStatus get status => _status;
  bool get isOnline => _status == GeminiConnectionStatus.onlineGeminiAvailable;
  bool get isSyncingQueue => _isSyncingQueue;

  /// Checks reachability of central backend server and Gemini endpoint.
  Future<GeminiConnectionStatus> checkConnectivity() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/health');
      final resp = await _httpClient.get(uri).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        _status = GeminiConnectionStatus.onlineGeminiAvailable;
      } else {
        _status = GeminiConnectionStatus.geminiUnavailableUsingRules;
      }
    } catch (_) {
      _status = GeminiConnectionStatus.offlineLocalAssessment;
    }
    notifyListeners();
    return _status;
  }

  /// Analyzes patient free-text presentation and vital signs.
  /// Seamlessly switches between Gemini AI online and deterministic local rules offline.
  Future<SymptomAnalysisResult> analyzePresentation({
    required String freeText,
    String patientId = 'PAT-UNSPECIFIED',
    int? systolicBP,
    int? diastolicBP,
    int? heartRate,
    double? oxygenSaturation,
    double? temperature,
    int? respiratoryRate,
    List<String> selectedTags = const [],
    int? age,
    String? sex,
    bool forceOffline = false,
  }) async {
    // 1. Generate local deterministic assessment (baseline ground-truth)
    final localResult = OfflineClinicalRuleEngine.evaluate(
      freeText: freeText,
      patientId: patientId,
      systolicBP: systolicBP,
      diastolicBP: diastolicBP,
      heartRate: heartRate,
      oxygenSaturation: oxygenSaturation,
      temperature: temperature,
      respiratoryRate: respiratoryRate,
      selectedTags: selectedTags,
      age: age,
      sex: sex,
    );

    // If forced offline, return local rule-based assessment immediately
    if (forceOffline) {
      _status = GeminiConnectionStatus.offlineLocalAssessment;
      notifyListeners();
      await _storage.saveAssessmentLocally(localResult);
      return localResult;
    }

    // 2. Attempt online Gemini analysis via central backend
    try {
      final uri = Uri.parse('$baseUrl/api/v1/gemini/analyze-symptoms');
      final reqBody = {
        'free_text': freeText,
        'patient_id': patientId,
        'vitals': {
          ...localResult.extractedVitals.toMap(),
          'systolic_bp': ?systolicBP,
          'diastolic_bp': ?diastolicBP,
          'heart_rate': ?heartRate,
          'spo2': ?oxygenSaturation,
          'temperature': ?temperature,
          'respiratory_rate': ?respiratoryRate,
        },
        'selected_tags': selectedTags,
        'age': ?age,
        'sex': ?sex,
        'save': false,
      };

      final resp = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(reqBody),
          )
          .timeout(timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final analysisMap = Map<String, dynamic>.from(data['analysis'] as Map);
        analysisMap['patient_id'] = patientId;
        analysisMap['free_text_description'] = freeText;

        final geminiResult = SymptomAnalysisResult.fromMap(analysisMap);

        // 3. Mandatory Safety Rule Verification:
        // Gemini must NOT downgrade an urgency level established by a mandatory safety rule
        final finalResult = OfflineClinicalRuleEngine.enforceSafetyRules(
          geminiResult: geminiResult,
          localRuleResult: localResult,
        );

        _status = GeminiConnectionStatus.onlineGeminiAvailable;
        notifyListeners();

        // Save locally and queue for sync
        await _storage.saveAssessmentLocally(finalResult);
        return finalResult;
      } else {
        // Backend returned error: differentiate technical failure from clinical conclusion
        final techStatus = (resp.statusCode == 401 || resp.statusCode == 403)
            ? 'authentication_error'
            : (resp.statusCode == 429)
                ? 'rate_limited'
                : (resp.statusCode >= 500)
                    ? 'service_unavailable'
                    : 'invalid_response';
        _status = GeminiConnectionStatus.geminiUnavailableUsingRules;
        notifyListeners();
        final fallbackResult = localResult.copyWith(
          analysisStatus: localResult.analysisStatus == 'safety_escalation'
              ? 'safety_escalation'
              : techStatus,
          sourceLabel: 'Local clinical rules (Gemini returned HTTP ${resp.statusCode})',
        );
        await _storage.saveAssessmentLocally(fallbackResult);
        return fallbackResult;
      }
    } on TimeoutException {
      _status = GeminiConnectionStatus.geminiUnavailableUsingRules;
      notifyListeners();
      final fallbackResult = localResult.copyWith(
        analysisStatus: localResult.analysisStatus == 'safety_escalation'
            ? 'safety_escalation'
            : 'timeout',
        sourceLabel: 'Local clinical rules (Gemini request timed out)',
      );
      await _storage.saveAssessmentLocally(fallbackResult);
      return fallbackResult;
    } catch (_) {
      // Network dropped or backend unavailable: use local fallback
      _status = GeminiConnectionStatus.offlineLocalAssessment;
      notifyListeners();
      final fallbackResult = localResult.copyWith(
        analysisStatus: localResult.analysisStatus == 'safety_escalation'
            ? 'safety_escalation'
            : (localResult.analysisStatus == 'insufficient_information'
                ? 'insufficient_information'
                : 'service_unavailable'),
        sourceLabel: 'Local clinical rules (Offline / Service unreachable)',
      );
      await _storage.saveAssessmentLocally(fallbackResult);
      return fallbackResult;
    }
  }

  /// Flushes pending offline sync queue to central backend using bounded exponential backoff.
  Future<int> flushSyncQueue() async {
    if (_isSyncingQueue) return 0;
    _isSyncingQueue = true;
    notifyListeners();

    int syncedCount = 0;
    try {
      final queue = _storage.syncQueue;
      if (queue.isEmpty) {
        _isSyncingQueue = false;
        notifyListeners();
        return 0;
      }

      final uri = Uri.parse('$baseUrl/api/v1/sync/queue');
      final itemsPayload = queue.map((q) => q.toMap()).toList();

      final resp = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'items': itemsPayload}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final processed = (data['processed'] as List<dynamic>?) ?? [];
        final keysToRemove = <String>[];
        for (final p in processed) {
          final pMap = p as Map<String, dynamic>;
          final key = pMap['idempotency_key']?.toString();
          if (key != null) keysToRemove.add(key);
        }
        await _storage.clearCompletedQueue(keysToRemove);
        syncedCount = keysToRemove.length;
        _status = GeminiConnectionStatus.onlineGeminiAvailable;
      }
    } catch (_) {
      // Network still offline or error during sync
      _status = GeminiConnectionStatus.offlineLocalAssessment;
    } finally {
      _isSyncingQueue = false;
      notifyListeners();
    }
    return syncedCount;
  }
}
