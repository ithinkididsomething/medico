import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'enums.dart';

/// Clinician-approved 4-tier Triage Urgency Categories (Prompt Section 4).
enum ClinicalUrgencyTier {
  level1ImmediateEmergency(
    level: 1,
    title: 'Level 1 — Immediate Emergency',
    shortLabel: 'L1 Immediate',
    actionAdvice: 'Immediate emergency response, airway/resuscitation stabilization, and emergency transfer.',
  ),
  level2Urgent(
    level: 2,
    title: 'Level 2 — Urgent',
    shortLabel: 'L2 Urgent',
    actionAdvice: 'Prompt medical evaluation, rapid diagnostic workup, or priority transfer within 2-4 hours.',
  ),
  level3PriorityAssessment(
    level: 3,
    title: 'Level 3 — Priority Assessment',
    shortLabel: 'L3 Priority',
    actionAdvice: 'Timely clinical examination and investigation within 12-24 hours.',
  ),
  level4RoutineAssessment(
    level: 4,
    title: 'Level 4 — Routine Assessment',
    shortLabel: 'L4 Routine',
    actionAdvice: 'Non-emergency primary care post assessment and routine outpatient management.',
  );

  final int level;
  final String title;
  final String shortLabel;
  final String actionAdvice;

  const ClinicalUrgencyTier({
    required this.level,
    required this.title,
    required this.shortLabel,
    required this.actionAdvice,
  });

  Color get color {
    switch (this) {
      case ClinicalUrgencyTier.level1ImmediateEmergency:
        return AppColors.statusRed;
      case ClinicalUrgencyTier.level2Urgent:
        return AppColors.statusAmber;
      case ClinicalUrgencyTier.level3PriorityAssessment:
        return AppColors.statusInfo;
      case ClinicalUrgencyTier.level4RoutineAssessment:
        return AppColors.statusGreen;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ClinicalUrgencyTier.level1ImmediateEmergency:
        return AppColors.statusRedBg;
      case ClinicalUrgencyTier.level2Urgent:
        return AppColors.statusAmberBg;
      case ClinicalUrgencyTier.level3PriorityAssessment:
        return AppColors.statusInfoBg;
      case ClinicalUrgencyTier.level4RoutineAssessment:
        return AppColors.statusGreenBg;
    }
  }

  UrgencyLevel toUrgencyLevel() {
    switch (this) {
      case ClinicalUrgencyTier.level1ImmediateEmergency:
        return UrgencyLevel.emergency;
      case ClinicalUrgencyTier.level2Urgent:
      case ClinicalUrgencyTier.level3PriorityAssessment:
        return UrgencyLevel.urgent;
      case ClinicalUrgencyTier.level4RoutineAssessment:
        return UrgencyLevel.routine;
    }
  }

  static ClinicalUrgencyTier fromInt(int val) {
    switch (val) {
      case 1:
        return ClinicalUrgencyTier.level1ImmediateEmergency;
      case 2:
        return ClinicalUrgencyTier.level2Urgent;
      case 3:
        return ClinicalUrgencyTier.level3PriorityAssessment;
      case 4:
      default:
        return ClinicalUrgencyTier.level4RoutineAssessment;
    }
  }
}

/// Clinician-approved Referral Categories.
enum ReferralLevel {
  referralA(
    code: 'Referral A',
    title: 'Referral A — Local Clinic / Primary Care',
    description: 'Appropriate only when required assessment and care are available locally on-site.',
  ),
  referralB(
    code: 'Referral B',
    title: 'Referral B — Secondary Hospital',
    description: 'Community Health Centre (CHC) or District Hospital with inpatient and basic surgical services.',
  ),
  referralC(
    code: 'Referral C',
    title: 'Referral C — Tertiary / Specialty Centre',
    description: 'Advanced medical centre with super-specialty intensive care (Cardiology, Neuro, Nephro, Trauma).',
  ),
  referralD(
    code: 'Referral D',
    title: 'Referral D — Immediate Emergency Stabilization & Transfer',
    description: 'Immediate resuscitation with emergency ALS transport to equipped receiving facility.',
  );

  final String code;
  final String title;
  final String description;

  const ReferralLevel({
    required this.code,
    required this.title,
    required this.description,
  });

  static ReferralLevel fromCode(String code) {
    switch (code.trim().toUpperCase()) {
      case 'REFERRAL A':
      case 'A':
        return ReferralLevel.referralA;
      case 'REFERRAL B':
      case 'B':
        return ReferralLevel.referralB;
      case 'REFERRAL C':
      case 'C':
        return ReferralLevel.referralC;
      case 'REFERRAL D':
      case 'D':
      default:
        return ReferralLevel.referralD;
    }
  }
}

/// Provenance source of the clinical analysis.
enum AssessmentSource {
  gemini('gemini', 'Online — Gemini AI Assisted'),
  offlineRules('offline_rules', 'Offline rule-based assessment — not analyzed by Gemini'),
  clinicianOverride('clinician_override', 'Clinician Overridden');

  final String code;
  final String label;

  const AssessmentSource(this.code, this.label);

  static AssessmentSource fromCode(String code) {
    switch (code) {
      case 'gemini':
        return AssessmentSource.gemini;
      case 'clinician_override':
        return AssessmentSource.clinicianOverride;
      case 'offline_rules':
      default:
        return AssessmentSource.offlineRules;
    }
  }
}

/// Custom clinical tag with creator attribution and offline synchronization support.
class ClinicianCustomTag {
  final String tagId;
  final String name;
  final String category;
  final bool isBuiltin;
  final bool isAiSuggested;
  final String createdBy;
  final DateTime createdAt;
  final int revision;

  const ClinicianCustomTag({
    required this.tagId,
    required this.name,
    this.category = 'general',
    this.isBuiltin = false,
    this.isAiSuggested = false,
    this.createdBy = 'Clinician',
    required this.createdAt,
    this.revision = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'tag_id': tagId,
      'name': name,
      'category': category,
      'is_builtin': isBuiltin ? 1 : 0,
      'is_ai_suggested': isAiSuggested ? 1 : 0,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'revision': revision,
    };
  }

  factory ClinicianCustomTag.fromMap(Map<String, dynamic> map) {
    return ClinicianCustomTag(
      tagId: (map['tag_id'] ?? map['tagId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? 'general').toString(),
      isBuiltin: map['is_builtin'] == 1 || map['is_builtin'] == true,
      isAiSuggested: map['is_ai_suggested'] == 1 || map['is_ai_suggested'] == true,
      createdBy: (map['created_by'] ?? 'Clinician').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
      revision: (map['revision'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Discrete extracted vital signs supported by assessment form fields.
class ExtractedVitals {
  final double? oxygenSaturation;
  final int? systolicBP;
  final int? diastolicBP;
  final int? heartRate;
  final double? temperature;
  final int? respiratoryRate;

  const ExtractedVitals({
    this.oxygenSaturation,
    this.systolicBP,
    this.diastolicBP,
    this.heartRate,
    this.temperature,
    this.respiratoryRate,
  });

  bool get isEmpty =>
      oxygenSaturation == null &&
      systolicBP == null &&
      diastolicBP == null &&
      heartRate == null &&
      temperature == null &&
      respiratoryRate == null;

  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toMap() {
    return {
      if (oxygenSaturation != null) 'spo2': oxygenSaturation,
      if (systolicBP != null) 'systolic_bp': systolicBP,
      if (diastolicBP != null) 'diastolic_bp': diastolicBP,
      if (heartRate != null) 'heart_rate': heartRate,
      if (temperature != null) 'temperature': temperature,
      if (respiratoryRate != null) 'respiratory_rate': respiratoryRate,
    };
  }

  factory ExtractedVitals.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ExtractedVitals();
    return ExtractedVitals(
      oxygenSaturation: (map['spo2'] ?? map['oxygen_saturation'] as num?)?.toDouble(),
      systolicBP: (map['systolic_bp'] ?? map['systolic'] as num?)?.toInt(),
      diastolicBP: (map['diastolic_bp'] ?? map['diastolic'] as num?)?.toInt(),
      heartRate: (map['heart_rate'] ?? map['pulse'] ?? map['hr'] as num?)?.toInt(),
      temperature: (map['temperature'] ?? map['temp'] as num?)?.toDouble(),
      respiratoryRate: (map['respiratory_rate'] ?? map['rr'] as num?)?.toInt(),
    );
  }
}

/// Validated Structured Symptom Analysis Record.
class SymptomAnalysisResult {
  final String assessmentId;
  final String patientId;
  final String freeTextDescription;
  final List<String> extractedSymptoms;
  final ExtractedVitals extractedVitals;
  final String duration;
  final String onset;
  final String severity;
  final List<String> relevantHistory;
  final List<String> reportedWarningSigns;
  final List<String> missingInformation;
  final List<String> followUpQuestions;
  final List<String> suggestedTags;
  final ClinicalUrgencyTier urgencyLevel;
  final String urgencyLabel;
  final ReferralLevel referralLevel;
  final String referralLabel;
  final String reasoning;
  final List<String> redFlags;
  final bool isEmergency;
  final bool isUndetermined;
  final String analysisStatus;
  final AssessmentSource source;
  final String sourceLabel;
  final String modelVersion;
  final String rulesetVersion;
  final String clinicianReviewStatus; // 'unreviewed', 'confirmed', 'overridden'
  final String? clinicianOverrideReason;
  final String? clinicianNotes;
  final DateTime createdAt;
  final bool safetyOverrideApplied;

  const SymptomAnalysisResult({
    required this.assessmentId,
    required this.patientId,
    required this.freeTextDescription,
    this.extractedSymptoms = const [],
    this.extractedVitals = const ExtractedVitals(),
    this.duration = 'Unknown',
    this.onset = 'Unknown',
    this.severity = 'moderate',
    this.relevantHistory = const [],
    this.reportedWarningSigns = const [],
    this.missingInformation = const [],
    this.followUpQuestions = const [],
    this.suggestedTags = const [],
    required this.urgencyLevel,
    required this.urgencyLabel,
    required this.referralLevel,
    required this.referralLabel,
    required this.reasoning,
    this.redFlags = const [],
    this.isEmergency = false,
    this.isUndetermined = false,
    this.analysisStatus = 'success',
    required this.source,
    required this.sourceLabel,
    this.modelVersion = 'gemini-1.5-flash',
    this.rulesetVersion = 'indore-clinical-safety-v1',
    this.clinicianReviewStatus = 'unreviewed',
    this.clinicianOverrideReason,
    this.clinicianNotes,
    required this.createdAt,
    this.safetyOverrideApplied = false,
  });

  bool get isClinicianReviewed => clinicianReviewStatus != 'unreviewed';

  Map<String, dynamic> toMap() {
    return {
      'assessment_id': assessmentId,
      'patient_id': patientId,
      'free_text_description': freeTextDescription,
      'extracted_symptoms': extractedSymptoms,
      'extracted_vitals': extractedVitals.toMap(),
      'duration': duration,
      'onset': onset,
      'severity': severity,
      'relevant_history': relevantHistory,
      'reported_warning_signs': reportedWarningSigns,
      'missing_information': missingInformation,
      'follow_up_questions': followUpQuestions,
      'suggested_tags': suggestedTags,
      'urgency_level': urgencyLevel.level,
      'urgency_label': urgencyLabel,
      'referral_level': referralLevel.code,
      'referral_label': referralLabel,
      'reasoning': reasoning,
      'red_flags': redFlags,
      'is_emergency': isEmergency,
      'is_undetermined': isUndetermined,
      'analysis_status': analysisStatus,
      'assessment_source': source.code,
      'source_label': sourceLabel,
      'model_version': modelVersion,
      'ruleset_version': rulesetVersion,
      'clinician_review_status': clinicianReviewStatus,
      'override_reason': clinicianOverrideReason,
      'clinician_notes': clinicianNotes,
      'created_at': createdAt.toIso8601String(),
      'safety_override_applied': safetyOverrideApplied,
    };
  }

  factory SymptomAnalysisResult.fromMap(Map<String, dynamic> map) {
    final urgencyInt = (map['urgency_level'] as num?)?.toInt() ?? 4;
    final refCode = (map['referral_level'] ?? 'Referral A').toString();
    final srcCode = (map['assessment_source'] ?? map['source'] ?? 'offline_rules').toString();

    return SymptomAnalysisResult(
      assessmentId: (map['assessment_id'] ?? map['assessmentId'] ?? '').toString(),
      patientId: (map['patient_id'] ?? map['patientId'] ?? 'PAT-UNSPECIFIED').toString(),
      freeTextDescription: (map['free_text_description'] ?? map['free_text'] ?? map['description'] ?? '').toString(),
      extractedSymptoms: List<String>.from(map['extracted_symptoms'] ?? []),
      extractedVitals: ExtractedVitals.fromMap(map['extracted_vitals'] as Map<String, dynamic>?),
      duration: (map['duration'] ?? 'Unknown').toString(),
      onset: (map['onset'] ?? 'Unknown').toString(),
      severity: (map['severity'] ?? 'moderate').toString(),
      relevantHistory: List<String>.from(map['relevant_history'] ?? []),
      reportedWarningSigns: List<String>.from(map['reported_warning_signs'] ?? []),
      missingInformation: List<String>.from(map['missing_information'] ?? []),
      followUpQuestions: List<String>.from(map['follow_up_questions'] ?? []),
      suggestedTags: List<String>.from(map['suggested_tags'] ?? map['tags'] ?? []),
      urgencyLevel: ClinicalUrgencyTier.fromInt(urgencyInt),
      urgencyLabel: (map['urgency_label'] ?? ClinicalUrgencyTier.fromInt(urgencyInt).title).toString(),
      referralLevel: ReferralLevel.fromCode(refCode),
      referralLabel: (map['referral_label'] ?? ReferralLevel.fromCode(refCode).title).toString(),
      reasoning: (map['reasoning'] ?? '').toString(),
      redFlags: List<String>.from(map['red_flags'] ?? []),
      isEmergency: map['is_emergency'] == true || urgencyInt == 1,
      isUndetermined: map['is_undetermined'] == true,
      analysisStatus: (map['analysis_status'] ?? (map['is_undetermined'] == true ? 'insufficient_information' : 'success')).toString(),
      source: AssessmentSource.fromCode(srcCode),
      sourceLabel: (map['source_label'] ?? AssessmentSource.fromCode(srcCode).label).toString(),
      modelVersion: (map['model_version'] ?? 'gemini-1.5-flash').toString(),
      rulesetVersion: (map['ruleset_version'] ?? 'indore-clinical-safety-v1').toString(),
      clinicianReviewStatus: (map['clinician_review_status'] ?? 'unreviewed').toString(),
      clinicianOverrideReason: map['override_reason']?.toString(),
      clinicianNotes: map['clinician_notes']?.toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
      safetyOverrideApplied: map['safety_override_applied'] == true,
    );
  }

  SymptomAnalysisResult copyWith({
    String? assessmentId,
    String? patientId,
    String? freeTextDescription,
    List<String>? extractedSymptoms,
    ExtractedVitals? extractedVitals,
    String? duration,
    String? onset,
    String? severity,
    List<String>? relevantHistory,
    List<String>? reportedWarningSigns,
    List<String>? missingInformation,
    List<String>? followUpQuestions,
    List<String>? suggestedTags,
    ClinicalUrgencyTier? urgencyLevel,
    String? urgencyLabel,
    ReferralLevel? referralLevel,
    String? referralLabel,
    String? reasoning,
    List<String>? redFlags,
    bool? isEmergency,
    bool? isUndetermined,
    String? analysisStatus,
    AssessmentSource? source,
    String? sourceLabel,
    String? modelVersion,
    String? rulesetVersion,
    String? clinicianReviewStatus,
    String? clinicianOverrideReason,
    String? clinicianNotes,
    DateTime? createdAt,
    bool? safetyOverrideApplied,
  }) {
    return SymptomAnalysisResult(
      assessmentId: assessmentId ?? this.assessmentId,
      patientId: patientId ?? this.patientId,
      freeTextDescription: freeTextDescription ?? this.freeTextDescription,
      extractedSymptoms: extractedSymptoms ?? this.extractedSymptoms,
      extractedVitals: extractedVitals ?? this.extractedVitals,
      duration: duration ?? this.duration,
      onset: onset ?? this.onset,
      severity: severity ?? this.severity,
      relevantHistory: relevantHistory ?? this.relevantHistory,
      reportedWarningSigns: reportedWarningSigns ?? this.reportedWarningSigns,
      missingInformation: missingInformation ?? this.missingInformation,
      followUpQuestions: followUpQuestions ?? this.followUpQuestions,
      suggestedTags: suggestedTags ?? this.suggestedTags,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      urgencyLabel: urgencyLabel ?? this.urgencyLabel,
      referralLevel: referralLevel ?? this.referralLevel,
      referralLabel: referralLabel ?? this.referralLabel,
      reasoning: reasoning ?? this.reasoning,
      redFlags: redFlags ?? this.redFlags,
      isEmergency: isEmergency ?? this.isEmergency,
      isUndetermined: isUndetermined ?? this.isUndetermined,
      analysisStatus: analysisStatus ?? this.analysisStatus,
      source: source ?? this.source,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      modelVersion: modelVersion ?? this.modelVersion,
      rulesetVersion: rulesetVersion ?? this.rulesetVersion,
      clinicianReviewStatus: clinicianReviewStatus ?? this.clinicianReviewStatus,
      clinicianOverrideReason: clinicianOverrideReason ?? this.clinicianOverrideReason,
      clinicianNotes: clinicianNotes ?? this.clinicianNotes,
      createdAt: createdAt ?? this.createdAt,
      safetyOverrideApplied: safetyOverrideApplied ?? this.safetyOverrideApplied,
    );
  }

  SymptomAnalysisResult copyWithOverride({
    required ClinicalUrgencyTier newUrgency,
    required ReferralLevel newReferral,
    required String reason,
    String? notes,
  }) {
    return SymptomAnalysisResult(
      assessmentId: assessmentId,
      patientId: patientId,
      freeTextDescription: freeTextDescription,
      extractedSymptoms: extractedSymptoms,
      extractedVitals: extractedVitals,
      analysisStatus: analysisStatus,
      duration: duration,
      onset: onset,
      severity: severity,
      relevantHistory: relevantHistory,
      reportedWarningSigns: reportedWarningSigns,
      missingInformation: missingInformation,
      followUpQuestions: followUpQuestions,
      suggestedTags: suggestedTags,
      urgencyLevel: newUrgency,
      urgencyLabel: newUrgency.title,
      referralLevel: newReferral,
      referralLabel: newReferral.title,
      reasoning: '$reason (Overrode original: $reasoning)',
      redFlags: redFlags,
      isEmergency: newUrgency == ClinicalUrgencyTier.level1ImmediateEmergency,
      isUndetermined: false,
      source: AssessmentSource.clinicianOverride,
      sourceLabel: 'Clinician Overridden (${newUrgency.shortLabel})',
      modelVersion: modelVersion,
      rulesetVersion: rulesetVersion,
      clinicianReviewStatus: 'overridden',
      clinicianOverrideReason: reason,
      clinicianNotes: notes,
      createdAt: DateTime.now(),
      safetyOverrideApplied: false,
    );
  }
}

/// Seven explicit lifecycle states of a referral.
enum ReferralLifecycleState {
  assessmentSaved('assessment_saved', 'Assessment Saved (Local)', Icons.bookmark_added_outlined),
  referralDraftSavedLocally('referral_draft_saved_locally', 'Referral saved — not yet sent', Icons.save_as_outlined),
  referralQueuedForTransmission('referral_queued_for_transmission', 'Queued for transmission', Icons.cloud_queue_outlined),
  referralSuccessfullySent('referral_successfully_sent', 'Referral sent to destination', Icons.send_outlined),
  deliveryConfirmed('delivery_confirmed', 'Delivery confirmed', Icons.mark_email_read_outlined),
  receivingFacilityAcknowledged('receiving_facility_acknowledged', 'Receiving hospital acknowledged', Icons.domain_verification_outlined),
  ambulanceDispatched('ambulance_dispatched', '108 Ambulance Dispatched', Icons.emergency_outlined);

  final String code;
  final String label;
  final IconData icon;

  const ReferralLifecycleState(this.code, this.label, this.icon);

  bool get isOfflinePending =>
      this == ReferralLifecycleState.assessmentSaved ||
      this == ReferralLifecycleState.referralDraftSavedLocally ||
      this == ReferralLifecycleState.referralQueuedForTransmission;

  bool get isConfirmed =>
      this == ReferralLifecycleState.deliveryConfirmed ||
      this == ReferralLifecycleState.receivingFacilityAcknowledged ||
      this == ReferralLifecycleState.ambulanceDispatched;

  static ReferralLifecycleState fromCode(String code) {
    switch (code) {
      case 'assessment_saved':
        return ReferralLifecycleState.assessmentSaved;
      case 'referral_draft_saved_locally':
        return ReferralLifecycleState.referralDraftSavedLocally;
      case 'referral_queued_for_transmission':
        return ReferralLifecycleState.referralQueuedForTransmission;
      case 'referral_successfully_sent':
        return ReferralLifecycleState.referralSuccessfullySent;
      case 'delivery_confirmed':
        return ReferralLifecycleState.deliveryConfirmed;
      case 'receiving_facility_acknowledged':
        return ReferralLifecycleState.receivingFacilityAcknowledged;
      case 'ambulance_dispatched':
        return ReferralLifecycleState.ambulanceDispatched;
      default:
        return ReferralLifecycleState.referralDraftSavedLocally;
    }
  }
}
