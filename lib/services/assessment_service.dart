import '../models/disease_acuity.dart';
import '../models/enums.dart';
import '../models/patient.dart';

/// Clinical decision-support evaluation outcome.
class AssessmentResult {
  final UrgencyLevel urgencyLevel;
  final RecommendedAction recommendedAction;
  final String requiredSpecialty;
  final List<String> requiredFacilities;
  final List<String> clinicalRationale;
  final List<String> dangerSignsDetected;
  final bool isRedFlag;
  final PatientConditionCategory? conditionCategory;
  final DiseaseTriageLevel? matchedDiseaseLevel;
  final List<String> matchedDiseases;

  const AssessmentResult({
    required this.urgencyLevel,
    required this.recommendedAction,
    required this.requiredSpecialty,
    required this.requiredFacilities,
    required this.clinicalRationale,
    required this.dangerSignsDetected,
    required this.isRedFlag,
    this.conditionCategory,
    this.matchedDiseaseLevel,
    this.matchedDiseases = const [],
  });

  AssessmentResult copyWith({
    UrgencyLevel? urgencyLevel,
    RecommendedAction? recommendedAction,
    String? requiredSpecialty,
    List<String>? requiredFacilities,
    List<String>? clinicalRationale,
    List<String>? dangerSignsDetected,
    bool? isRedFlag,
    PatientConditionCategory? conditionCategory,
    DiseaseTriageLevel? matchedDiseaseLevel,
    List<String>? matchedDiseases,
  }) {
    return AssessmentResult(
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      requiredSpecialty: requiredSpecialty ?? this.requiredSpecialty,
      requiredFacilities: requiredFacilities ?? this.requiredFacilities,
      clinicalRationale: clinicalRationale ?? this.clinicalRationale,
      dangerSignsDetected: dangerSignsDetected ?? this.dangerSignsDetected,
      isRedFlag: isRedFlag ?? this.isRedFlag,
      conditionCategory: conditionCategory ?? this.conditionCategory,
      matchedDiseaseLevel: matchedDiseaseLevel ?? this.matchedDiseaseLevel,
      matchedDiseases: matchedDiseases ?? this.matchedDiseases,
    );
  }

  @override
  String toString() =>
      'AssessmentResult(Urgency: ${urgencyLevel.displayName}, Action: ${recommendedAction.displayName}, Specialty: "$requiredSpecialty", Category: ${conditionCategory?.displayName ?? "Unassigned"})';
}

/// Abstract contract for clinical triage and decision-support evaluation.
abstract class AssessmentService {
  AssessmentResult evaluate(Patient patient);
}

/// Deterministic clinical decision-support evaluator based on WHO Integrated
/// Management of Adolescent and Adult Illness (IMAI) and rural emergency triage protocols.
class RuleBasedAssessmentService implements AssessmentService {
  const RuleBasedAssessmentService();

  @override
  AssessmentResult evaluate(Patient patient) {
    final dangerSigns = <String>[];
    final rationale = <String>[];
    var isEmergency = false;
    var isUrgent = false;

    // 1. Vital Signs Evaluation
    final spo2 = patient.oxygenSaturation;
    if (spo2 != null) {
      if (spo2 < 90.0) {
        dangerSigns.add('Critical Hypoxia: SpO2 ${spo2.toStringAsFixed(1)}% (< 90%)');
        rationale.add('Severely compromised oxygenation indicates impending respiratory failure.');
        isEmergency = true;
      } else if (spo2 <= 93.0) {
        dangerSigns.add('Moderate Hypoxia: SpO2 ${spo2.toStringAsFixed(1)}% (90-93%)');
        rationale.add('Sub-optimal oxygen saturation requiring supplemental oxygen and monitoring.');
        isUrgent = true;
      }
    }

    final hr = patient.heartRate;
    if (hr != null) {
      if (hr > 140) {
        dangerSigns.add('Severe Tachycardia: Heart Rate $hr bpm');
        rationale.add('Marked tachycardia indicative of severe shock, sepsis, or arrhythmia.');
        isEmergency = true;
      } else if (hr < 45) {
        dangerSigns.add('Severe Bradycardia: Heart Rate $hr bpm');
        rationale.add('Severe bradycardia carries acute risk of hemodynamic collapse.');
        isEmergency = true;
      } else if (hr > 115 || hr < 50) {
        dangerSigns.add('Abnormal Heart Rate: $hr bpm');
        isUrgent = true;
      }
    }

    final sbp = patient.systolicBP;
    final dbp = patient.diastolicBP;
    if (sbp != null) {
      if (sbp < 85) {
        dangerSigns.add('Hypotensive Shock: Systolic BP $sbp mmHg (< 85 mmHg)');
        rationale.add('Critically low perfusion pressure; immediate fluid resuscitation and emergency transfer required.');
        isEmergency = true;
      } else if (sbp >= 200 || (dbp != null && dbp >= 120)) {
        dangerSigns.add('Hypertensive Emergency: BP $sbp/${dbp ?? '-'} mmHg');
        rationale.add('Extreme blood pressure elevation carries acute risk of stroke, aortic dissection, or heart failure.');
        isEmergency = true;
      } else if (sbp < 95 || sbp >= 165 || (dbp != null && dbp >= 100)) {
        dangerSigns.add('Borderline Blood Pressure: BP $sbp/${dbp ?? '-'} mmHg');
        isUrgent = true;
      }
    }

    final rr = patient.respiratoryRate;
    if (rr != null) {
      final isPediatric = patient.age <= 5;
      final tachypneaThreshold = isPediatric ? 50 : 32;
      if (rr >= tachypneaThreshold || rr <= 8) {
        dangerSigns.add('Critical Respiratory Rate: $rr breaths/min');
        rationale.add('Severe tachypnea or bradypnea reflects acute physiological distress.');
        isEmergency = true;
      } else if (rr >= (isPediatric ? 40 : 24)) {
        dangerSigns.add('Elevated Respiratory Rate: $rr breaths/min');
        isUrgent = true;
      }
    }

    final temp = patient.temperature;
    if (temp != null) {
      if (temp >= 40.0 || temp <= 35.0) {
        dangerSigns.add('Dangerous Temperature: ${temp.toStringAsFixed(1)}°C');
        isUrgent = true;
      }
    }

    // 2. Syndromic & Protocolized Disease Acuity Evaluation
    final allText = '${patient.mainComplaint} ${patient.symptoms.join(" ")} ${patient.injuryOrIllnessDetails} ${patient.clinicalFindings}'.toLowerCase();
    final matchedDiseases = DiseaseAcuityDataset.findMatchedConditions(allText);
    final matchedDiseaseLevel = DiseaseAcuityDataset.evaluateTextAcuity(allText);

    if (matchedDiseaseLevel != null) {
      if (matchedDiseaseLevel.severity == 4) {
        dangerSigns.add('Disease Protocol Level 4 (Emergency): ${matchedDiseases.join(", ")}');
        rationale.add('Protocol Action: ${matchedDiseaseLevel.typicalAction}');
        isEmergency = true;
      } else if (matchedDiseaseLevel.severity == 3) {
        dangerSigns.add('Disease Protocol Level 3 (Urgent): ${matchedDiseases.join(", ")}');
        rationale.add('Protocol Action: ${matchedDiseaseLevel.typicalAction}');
        isUrgent = true;
      } else if (matchedDiseaseLevel.severity == 2) {
        rationale.add('Disease Protocol Level 2 (Clinic/PHC): ${matchedDiseases.join(", ")} — ${matchedDiseaseLevel.typicalAction}');
      } else if (matchedDiseaseLevel.severity == 1) {
        rationale.add('Disease Protocol Level 1 (Home Care / Observe): ${matchedDiseases.join(", ")} — ${matchedDiseaseLevel.typicalAction}');
      }
    }

    if (_matchesAny(allText, ['hemorrhage', 'heavy bleeding', 'bleeding after delivery', 'pph', 'shock', 'unconscious', 'altered mental', 'convulsion', 'seizure', 'coma', 'stridor', 'cyanosis'])) {
      if (!dangerSigns.any((d) => d.contains('Syndromic') || d.contains('Level 4'))) {
        dangerSigns.add('Syndromic Red Flag Keyword Match');
        rationale.add('Active severe bleeding, airway compromise, or neurological depression detected.');
      }
      isEmergency = true;
    } else if (_matchesAny(allText, ['fracture', 'compound', 'chest pain', 'st elevation', 'retrosternal', 'appendicitis', 'peritonitis', 'acute abdomen', 'burn', 'deep laceration'])) {
      if (!dangerSigns.any((d) => d.contains('Priority') || d.contains('Level 3') || d.contains('Level 4'))) {
        dangerSigns.add('Priority Clinical Condition Detected');
        rationale.add('Patient presentation indicates condition requiring hospital-level intervention.');
      }
      isUrgent = true;
    }

    // 3. Determine Urgency & Action
    final UrgencyLevel finalUrgency;
    final RecommendedAction finalAction;

    if (isEmergency) {
      finalUrgency = UrgencyLevel.emergency;
      finalAction = RecommendedAction.immediateReferral;
    } else if (isUrgent) {
      finalUrgency = UrgencyLevel.urgent;
      finalAction = RecommendedAction.referralRecommended;
    } else {
      finalUrgency = UrgencyLevel.routine;
      finalAction = RecommendedAction.manageLocally;
      rationale.add('Vital signs and clinical symptoms appear stable; can be managed locally with observation.');
    }

    // 4. Determine Specialty & Facility Needs
    final deducedSpecialty = _deduceSpecialty(patient, allText);
    final deducedFacilities = _deduceRequiredFacilities(deducedSpecialty, finalUrgency, allText);
    final category = patient.conditionCategory;

    return AssessmentResult(
      urgencyLevel: finalUrgency,
      recommendedAction: finalAction,
      requiredSpecialty: deducedSpecialty,
      requiredFacilities: deducedFacilities,
      clinicalRationale: rationale,
      dangerSignsDetected: dangerSigns,
      isRedFlag: isEmergency,
      conditionCategory: category,
      matchedDiseaseLevel: matchedDiseaseLevel,
      matchedDiseases: matchedDiseases,
    );
  }

  /// Suggests a probable condition category for clinical confirmation.
  PatientConditionCategory deduceConditionCategory(
    Patient patient,
    String specialty,
    UrgencyLevel urgency,
    String text,
  ) {
    if (specialty == 'Obstetrics & Gynecology' && (urgency.isEmergency || urgency.isUrgent)) {
      return PatientConditionCategory.obstetricEmergency;
    }
    if ((specialty == 'Pediatrics' || patient.age < 12) && urgency.isEmergency) {
      return PatientConditionCategory.pediatricEmergency;
    }
    if (specialty == 'Cardiology' && (urgency.isEmergency || _matchesAny(text, ['stemi', 'chest pain', 'coronary']))) {
      return PatientConditionCategory.suspectedCardiacEmergency;
    }
    if (_matchesAny(text, ['stroke', 'hemiplegia', 'facial droop', 'slurred', 'neuro']) ||
        specialty == 'Neurosurgery') {
      return PatientConditionCategory.suspectedStroke;
    }
    if ((specialty == 'Orthopedics & Trauma Surgery' || _matchesAny(text, ['fracture', 'trauma', 'accident'])) &&
        (urgency.isEmergency || _matchesAny(text, ['compound', 'bleeding', 'polytrauma']))) {
      return PatientConditionCategory.majorTrauma;
    }
    if (specialty == 'Orthopedics & Trauma Surgery' || _matchesAny(text, ['fracture', 'bone', 'dislocation'])) {
      return PatientConditionCategory.stableFracture;
    }
    if (urgency.isEmergency) {
      return PatientConditionCategory.criticalEmergency;
    }
    return PatientConditionCategory.stableMedicalCase;
  }

  bool _matchesAny(String source, List<String> terms) {
    return terms.any((term) => source.contains(term));
  }

  String _deduceSpecialty(Patient patient, String text) {
    if (patient.requiredSpecialty.isNotEmpty && patient.requiredSpecialty != 'General Medicine') {
      return patient.requiredSpecialty;
    }

    if (_matchesAny(text, ['postpartum', 'pregnancy', 'delivery', 'obstetric', 'vaginal bleeding', 'uterus', 'atony', 'labor', 'pre-eclampsia'])) {
      return 'Obstetrics & Gynecology';
    }
    if (patient.age < 12 || _matchesAny(text, ['pediatric', 'child', 'infant', 'chest in-drawing', 'subcostal', 'fontanelle'])) {
      return 'Pediatrics';
    }
    if (_matchesAny(text, ['chest pain', 'cardiac', 'angina', 'coronary', 'st elevation', 'myocardial infarction', 'arrhythmia'])) {
      return 'Cardiology';
    }
    if (_matchesAny(text, ['fracture', 'orthopedic', 'bone', 'compound', 'dislocation', 'tibia', 'femur'])) {
      return 'Orthopedics & Trauma Surgery';
    }
    if (_matchesAny(text, ['appendicitis', 'acute abdomen', 'peritonitis', 'hernia', 'obstruction', 'laparotomy'])) {
      return 'General Surgery';
    }
    return 'General Medicine';
  }

  List<String> _deduceRequiredFacilities(String specialty, UrgencyLevel urgency, String text) {
    final facilities = <String>{};

    if (specialty == 'Obstetrics & Gynecology') {
      facilities.addAll(['24/7 Blood Bank', 'Emergency Cesarean Section (C-Section)', 'Ultrasound']);
      if (urgency == UrgencyLevel.emergency) {
        facilities.add('ICU Mechanical Ventilation');
      }
    } else if (specialty == 'Pediatrics') {
      facilities.addAll(['Pediatric Intensive Care', 'Neonatal Resuscitation & Incubators']);
    } else if (specialty == 'Cardiology') {
      facilities.addAll(['Echocardiography', 'ICU Mechanical Ventilation', 'Cath Lab']);
    } else if (specialty == 'Orthopedics & Trauma Surgery') {
      facilities.addAll(['Digital X-Ray', 'Orthopedic Fracture Fixation']);
      if (text.contains('compound') || text.contains('bleeding')) {
        facilities.add('24/7 Blood Bank');
      }
    } else if (specialty == 'General Surgery') {
      facilities.addAll(['Laparoscopic Surgery', 'Full Pathology Lab']);
    }

    if (urgency == UrgencyLevel.emergency && !facilities.contains('ICU Mechanical Ventilation')) {
      facilities.add('ICU Mechanical Ventilation');
    }

    if (facilities.isEmpty) {
      facilities.add('Basic Clinical Lab');
    }

    return facilities.toList();
  }
}
