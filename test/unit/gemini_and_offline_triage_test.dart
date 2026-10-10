import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_referral/models/symptom_analysis.dart';
import 'package:smart_referral/services/offline_clinical_rule_engine.dart';
import 'package:smart_referral/services/offline_assessment_storage_service.dart';
import 'package:smart_referral/services/gemini_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineClinicalRuleEngine Tests', () {
    test('Identifies SpO2 < 90% as Level 1 Immediate Emergency and Referral D', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Patient feeling weak and breathless',
        oxygenSaturation: 88.0,
      );

      expect(res.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(res.referralLevel, equals(ReferralLevel.referralD));
      expect(res.isEmergency, isTrue);
      expect(res.redFlags.any((rf) => rf.contains('SpO2') && rf.contains('<90%')), isTrue);
    });

    test('Identifies severe hypotension SBP < 85 as Level 1 Immediate Emergency', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Cold clammy skin and dizziness',
        systolicBP: 78,
      );

      expect(res.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(res.referralLevel, equals(ReferralLevel.referralD));
      expect(res.redFlags.any((rf) => rf.contains('Systolic BP') && rf.contains('<85')), isTrue);
    });

    test('Identifies hypertensive crisis SBP > 180 as Level 1 Emergency', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Severe pounding headache and blurred vision',
        systolicBP: 195,
      );

      expect(res.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(res.redFlags.any((rf) => rf.contains('Systolic BP') && rf.contains('>180')), isTrue);
    });

    test('Identifies severe postpartum hemorrhage as Level 1 Emergency', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Excessive postpartum hemorrhage after home delivery, soaked 4 pads in 30 minutes',
      );

      expect(res.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(res.referralLevel, equals(ReferralLevel.referralD));
      expect(res.redFlags.any((rf) => rf.toLowerCase().contains('hemorrhage') || rf.toLowerCase().contains('bleeding')), isTrue);
    });

    test('Identifies crushing chest pain as Level 1 Emergency with Referral D', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Crushing chest pain radiating to left arm and jaw since 1 hour',
      );

      expect(res.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(res.referralLevel, equals(ReferralLevel.referralD));
      expect(res.redFlags.any((rf) => rf.toLowerCase().contains('coronary') || rf.toLowerCase().contains('chest pain')), isTrue);
    });

    test('Ambiguous or missing clinical information yields undetermined urgency', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Not feeling well today',
      );

      expect(res.isUndetermined, isTrue);
      expect(res.urgencyLabel, contains('Urgency undetermined — clinician assessment required'));
      // Mandatory offline safety rule: never produce a false low-urgency Level 4 reassurance
      expect(res.urgencyLevel, isNot(equals(ClinicalUrgencyTier.level4RoutineAssessment)));
      expect(res.missingInformation.isNotEmpty, isTrue);
      expect(res.followUpQuestions.isNotEmpty, isTrue);
    });

    test('Detects missing onset duration and recommends follow-up question', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Patient has high fever and cough',
      );

      expect(res.missingInformation.any((m) => m.toLowerCase().contains('onset') || m.toLowerCase().contains('duration')), isTrue);
      expect(res.followUpQuestions.any((q) => q.toLowerCase().contains('start') || q.toLowerCase().contains('long')), isTrue);
    });

    test('Mandatory Safety Policy: Gemini output cannot downgrade urgency if red-flag rule fired', () {
      final localEmergency = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Crushing chest pain SpO2 88%',
        oxygenSaturation: 88.0,
      );
      expect(localEmergency.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));

      // Simulating hypothetical flawed AI response that suggested Level 3
      final simulatedWeakAiResult = SymptomAnalysisResult(
        assessmentId: 'asmt_ai_test',
        patientId: 'PAT-001',
        freeTextDescription: 'Crushing chest pain SpO2 88%',
        urgencyLevel: ClinicalUrgencyTier.level3PriorityAssessment,
        urgencyLabel: ClinicalUrgencyTier.level3PriorityAssessment.title,
        referralLevel: ReferralLevel.referralB,
        referralLabel: ReferralLevel.referralB.title,
        reasoning: 'Non-emergency evaluation suggested by model',
        source: AssessmentSource.gemini,
        sourceLabel: 'Gemini AI',
        createdAt: DateTime.now(),
      );

      final safeResult = OfflineClinicalRuleEngine.enforceSafetyRules(
        geminiResult: simulatedWeakAiResult,
        localRuleResult: localEmergency,
      );

      expect(safeResult.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(safeResult.referralLevel, equals(ReferralLevel.referralD));
      expect(safeResult.safetyOverrideApplied, isTrue);
      expect(safeResult.reasoning, contains('MANDATORY SAFETY RULE ENFORCED'));
    });
  });

  group('OfflineAssessmentStorageService Tests', () {
    late OfflineAssessmentStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = OfflineAssessmentStorageService.withPrefs(prefs);
      await storage.initialize();
    });

    test('Saves and retrieves assessments offline', () async {
      final asmt = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Acute limb fracture from motor vehicle collision',
        patientId: 'PAT-TEST-100',
      );

      await storage.saveAssessmentLocally(asmt);

      final fetched = storage.getAssessment(asmt.assessmentId);
      expect(fetched, isNotNull);
      expect(fetched!.patientId, equals('PAT-TEST-100'));
      expect(storage.pendingQueueCount, equals(1));
    });

    test('Creates custom clinician tag offline and avoids duplicates', () async {
      final tag1 = await storage.createCustomTagOffline('Nocturnal dyspnea', category: 'respiratory');
      expect(tag1.name, equals('Nocturnal dyspnea'));
      expect(tag1.isBuiltin, isFalse);

      final tag2 = await storage.createCustomTagOffline('Nocturnal dyspnea', category: 'respiratory');
      expect(tag2.tagId, equals(tag1.tagId)); // Reuses existing tag
    });

    test('Manages 7 truthful referral lifecycle states', () async {
      const refId = 'REF-TEST-777';

      // Default state when saved locally
      expect(storage.getReferralLifecycle(refId), equals(ReferralLifecycleState.referralDraftSavedLocally));

      // Transition to Queued for transmission
      await storage.updateLifecycleState(
        refId,
        ReferralLifecycleState.referralQueuedForTransmission,
        patientId: 'PAT-777',
      );

      expect(storage.getLifecycleState(refId), equals(ReferralLifecycleState.referralQueuedForTransmission));
      expect(storage.getLifecycleState(refId)!.isOfflinePending, isTrue);

      // Transition to Delivery confirmed
      await storage.updateLifecycleState(
        refId,
        ReferralLifecycleState.deliveryConfirmed,
        patientId: 'PAT-777',
      );

      expect(storage.getLifecycleState(refId), equals(ReferralLifecycleState.deliveryConfirmed));
      expect(storage.getLifecycleState(refId)!.isConfirmed, isTrue);
    });

    test('Clears completed sync queue items after successful transmission', () async {
      final asmt = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Fever and chills for 3 days',
        patientId: 'PAT-SYNC-01',
      );
      await storage.saveAssessmentLocally(asmt);

      expect(storage.pendingQueueCount, greaterThanOrEqualTo(1));
      final item = storage.syncQueue.first;

      await storage.clearCompletedQueue([item.idempotencyKey]);
      expect(storage.syncQueue.any((q) => q.idempotencyKey == item.idempotencyKey), isFalse);
    });
  });

  group('Clinician Override Tests', () {
    test('Allows clinician to override urgency and referral level with audit rationale', () {
      final base = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Severe pain in right lower quadrant',
        patientId: 'PAT-OVERRIDE-01',
      );

      final overridden = base.copyWithOverride(
        newUrgency: ClinicalUrgencyTier.level1ImmediateEmergency,
        newReferral: ReferralLevel.referralD,
        reason: 'Acute appendicitis with peritoneal signs on palpation',
        notes: 'Emergency surgeon on-call alerted',
      );

      expect(overridden.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(overridden.referralLevel, equals(ReferralLevel.referralD));
      expect(overridden.source, equals(AssessmentSource.clinicianOverride));
      expect(overridden.clinicianReviewStatus, equals('overridden'));
      expect(overridden.clinicianOverrideReason, contains('Acute appendicitis'));
      expect(overridden.clinicianNotes, contains('Emergency surgeon'));
    });
  });

  group('GeminiAnalysisService Offline Fallback Tests', () {
    test('Falls back to deterministic offline rules when forced offline', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = OfflineAssessmentStorageService.withPrefs(prefs);
      await storage.initialize();

      final service = GeminiAnalysisService.withClient(
        client: FakeOfflineHttpClient(),
        storage: storage,
      );

      final res = await service.analyzePresentation(
        freeText: 'Postpartum hemorrhage soaking clothes',
        forceOffline: true,
      );

      expect(res.source, equals(AssessmentSource.offlineRules));
      expect(res.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(service.status, equals(GeminiConnectionStatus.offlineLocalAssessment));
    });

    test('Falls back to deterministic offline rules when backend HTTP connection drops', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = OfflineAssessmentStorageService.withPrefs(prefs);
      await storage.initialize();

      final service = GeminiAnalysisService.withClient(
        client: FakeNetworkFailureHttpClient(),
        storage: storage,
      );

      final res = await service.analyzePresentation(
        freeText: 'Crushing chest pain with diaphoresis',
        oxygenSaturation: 89.0,
      );

      expect(res.source, equals(AssessmentSource.offlineRules));
      expect(res.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(res.isEmergency, isTrue);
      expect(service.status, equals(GeminiConnectionStatus.offlineLocalAssessment));
    });
  });

  group('BugFixGeminiAndOfflineTriageTests - Fact Extraction and Auto-Fill', () {
    test('extractClinicalFacts extracts vitals, discrete symptoms, duration and onset correctly', () {
      final facts = OfflineClinicalRuleEngine.extractClinicalFacts(
        '32yo female with severe fever of 102 F and productive cough for 3 days, SpO2 88%, BP 90/60 mmHg, pulse 120 bpm, RR 26',
      );

      expect(facts.vitals.oxygenSaturation, equals(88.0));
      expect(facts.vitals.systolicBP, equals(90));
      expect(facts.vitals.diastolicBP, equals(60));
      expect(facts.vitals.heartRate, equals(120));
      expect(facts.vitals.respiratoryRate, equals(26));
      expect(facts.vitals.temperature, closeTo(38.9, 0.2)); // 102F converted to ~38.9C
      expect(facts.symptoms, contains('Fever'));
      expect(facts.symptoms, contains('Cough'));
      expect(facts.duration, equals('3 days'));
      // Never returns raw text blobs in symptoms
      expect(facts.symptoms.any((s) => s.contains('...')), isFalse);
    });

    test('Free text with SpO2 88% triggers Level 1 Immediate Emergency even without structured vitals', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Patient severe breathlessness, SpO2 88%, pulse 110 bpm',
      );

      expect(res.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(res.referralLevel, equals(ReferralLevel.referralD));
      expect(res.isEmergency, isTrue);
      expect(res.isUndetermined, isFalse);
      expect(res.extractedVitals.oxygenSaturation, equals(88.0));
      expect(res.extractedVitals.heartRate, equals(110));
      expect(res.redFlags.any((rf) => rf.contains('SpO2 88%')), isTrue);
      expect(res.analysisStatus, equals('safety_escalation'));
    });

    test('Informative clinical text is not marked undetermined', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Severe chest pain radiating to left arm with sweating since 2 hours, BP 140/90, pulse 95',
      );

      expect(res.isUndetermined, isFalse);
      expect(res.urgencyLevel, equals(ClinicalUrgencyTier.level1ImmediateEmergency));
      expect(res.referralLevel, equals(ReferralLevel.referralD));
    });

    test('Truly ambiguous presentation with no vitals or facts is marked undetermined', () {
      final res = OfflineClinicalRuleEngine.evaluate(
        freeText: 'Feeling weak',
      );

      expect(res.isUndetermined, isTrue);
      expect(res.urgencyLabel, contains('Urgency undetermined — clinician assessment required'));
      expect(res.analysisStatus, equals('insufficient_information'));
    });

    test('Differentiates technical failure (HTTP 401) as authentication_error', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = OfflineAssessmentStorageService.withPrefs(prefs);
      await storage.initialize();

      final service = GeminiAnalysisService.withClient(
        client: FakeHttpAuthErrorClient(),
        storage: storage,
      );

      final res = await service.analyzePresentation(
        freeText: 'Patient with fever and cough for 2 days, pulse 80',
      );

      expect(res.analysisStatus, equals('authentication_error'));
      expect(res.sourceLabel, contains('HTTP 401'));
      // Truthful: Did not disguise auth error as clinician assessment required
      expect(res.isUndetermined, isFalse);
    });

    test('Differentiates timeout failure as timeout status', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = OfflineAssessmentStorageService.withPrefs(prefs);
      await storage.initialize();

      final service = GeminiAnalysisService.withClient(
        client: FakeHttpTimeoutClient(),
        storage: storage,
        timeout: const Duration(milliseconds: 50),
      );

      final res = await service.analyzePresentation(
        freeText: 'Patient with fever and cough for 2 days, pulse 80',
      );

      expect(res.analysisStatus, equals('timeout'));
      expect(res.sourceLabel, contains('timed out'));
    });
  });
}

class FakeOfflineHttpClient extends Fake implements http.Client {}

class FakeNetworkFailureHttpClient extends Fake implements http.Client {
  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw Exception('SocketException: OS Error: Connection refused');
  }
}

class FakeHttpAuthErrorClient extends Fake implements http.Client {
  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    return http.Response(jsonEncode({'error': 'Invalid API Key'}), 401);
  }
}

class FakeHttpTimeoutClient extends Fake implements http.Client {
  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return http.Response(jsonEncode({'status': 'ok'}), 200);
  }
}
