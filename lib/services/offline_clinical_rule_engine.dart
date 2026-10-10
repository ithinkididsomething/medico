import '../models/symptom_analysis.dart';

/// Predefined Mandatory Clinical Red Flag Rule.
class _RedFlagRule {
  final List<String> keywords;
  final String flag;
  final ClinicalUrgencyTier urgency;
  final ReferralLevel referral;

  const _RedFlagRule({
    required this.keywords,
    required this.flag,
    required this.urgency,
    required this.referral,
  });
}

/// Structured clinical facts extracted from free text.
class ExtractedClinicalFacts {
  final ExtractedVitals vitals;
  final List<String> symptoms;
  final String duration;
  final String onset;
  final List<String> history;

  const ExtractedClinicalFacts({
    required this.vitals,
    required this.symptoms,
    required this.duration,
    required this.onset,
    required this.history,
  });
}

/// Clinician-Approved Deterministic Local Fallback Engine.
///
/// Operates 100% offline with zero dependencies on remote servers or Gemini API.
/// Performs red-flag triage, detects missing critical data, recommends urgency/referral levels,
/// and enforces mandatory safety overrides that Gemini cannot downgrade.
class OfflineClinicalRuleEngine {
  OfflineClinicalRuleEngine._();

  static const List<_RedFlagRule> _mandatoryRedFlags = [
    _RedFlagRule(
      keywords: ['postpartum hemorrhage', 'post-partum hemorrhage', 'pph', 'heavy bleeding after delivery', 'uterine bleeding'],
      flag: 'Severe Postpartum Hemorrhage (Obstetric Emergency)',
      urgency: ClinicalUrgencyTier.level1ImmediateEmergency,
      referral: ReferralLevel.referralD,
    ),
    _RedFlagRule(
      keywords: ['chest in-drawing', 'stridor', 'gasping', 'respiratory arrest', 'severe breathlessness', 'apnea', 'cyanosis'],
      flag: 'Severe Acute Respiratory Distress / Impending Respiratory Failure',
      urgency: ClinicalUrgencyTier.level1ImmediateEmergency,
      referral: ReferralLevel.referralD,
    ),
    _RedFlagRule(
      keywords: ['crushing chest pain', 'cardiac arrest', 'radiating to left arm', 'myocardial infarction', 'acute chest tightness with sweating'],
      flag: 'Suspected Acute Coronary Syndrome / Myocardial Infarction',
      urgency: ClinicalUrgencyTier.level1ImmediateEmergency,
      referral: ReferralLevel.referralD,
    ),
    _RedFlagRule(
      keywords: ['unconscious', 'unresponsive', 'coma', 'convulsion', 'seizure', 'status epilepticus', 'lethargic child unable to drink'],
      flag: 'Altered Mental Status / Convulsions / Coma',
      urgency: ClinicalUrgencyTier.level1ImmediateEmergency,
      referral: ReferralLevel.referralD,
    ),
    _RedFlagRule(
      keywords: ['polytrauma', 'crush injury', 'open fracture', 'penetrating wound', 'traumatic amputation', 'head injury vomiting'],
      flag: 'High-Energy Polytrauma / Compound Fracture / Traumatic Brain Injury',
      urgency: ClinicalUrgencyTier.level1ImmediateEmergency,
      referral: ReferralLevel.referralD,
    ),
    _RedFlagRule(
      keywords: ['severe dehydration', 'sunken eyes', 'skin pinch > 2s', 'anuria', 'choleraic diarrhea'],
      flag: 'Hypovolemic Shock / Severe Dehydration with Hemodynamic Compromise',
      urgency: ClinicalUrgencyTier.level1ImmediateEmergency,
      referral: ReferralLevel.referralD,
    ),
    _RedFlagRule(
      keywords: ['high fever with stiff neck', 'meningismus', 'purpuric rash', 'petechiae with fever'],
      flag: 'Suspected Meningococcal Sepsis / Meningitis',
      urgency: ClinicalUrgencyTier.level1ImmediateEmergency,
      referral: ReferralLevel.referralD,
    ),
    _RedFlagRule(
      keywords: ['acute abdomen', 'board-like rigidity', 'peritonitis', 'strangulated hernia'],
      flag: 'Acute Surgical Abdomen / Peritonitis',
      urgency: ClinicalUrgencyTier.level2Urgent,
      referral: ReferralLevel.referralC,
    ),
    _RedFlagRule(
      keywords: ['severe hypertension', 'preeclampsia', 'eclampsia', 'bp > 180', 'scotoma with pregnancy'],
      flag: 'Hypertensive Crisis / Severe Pre-eclampsia',
      urgency: ClinicalUrgencyTier.level1ImmediateEmergency,
      referral: ReferralLevel.referralD,
    ),
  ];

  /// Extracts structured clinical facts (vitals, individual symptoms, duration, onset, history)
  /// from clinician free-text notes using deterministic clinical regex patterns and vocabulary extraction.
  /// Never fabricates values not supported by the input text.
  static ExtractedClinicalFacts extractClinicalFacts(String text) {
    if (text.trim().isEmpty) {
      return const ExtractedClinicalFacts(
        vitals: ExtractedVitals(),
        symptoms: [],
        duration: 'Unknown',
        onset: 'Unknown',
        history: [],
      );
    }

    double? spo2;
    int? systolicBP;
    int? diastolicBP;
    int? heartRate;
    double? temperature;
    int? respiratoryRate;

    // 1. SpO2 / Oxygen Saturation
    final spo2Reg = RegExp(
      r'(?:spo2|spo₂|o2\s*sat(?:uration)?|saturation|oximetry)[\s:=]*(\d{2,3})(?:\s*%)?',
      caseSensitive: false,
    );
    final spo2Match = spo2Reg.firstMatch(text) ??
        RegExp(r'(\d{2,3})\s*%\s*(?:spo2|spo₂|o2|sat\b)', caseSensitive: false).firstMatch(text);
    if (spo2Match != null) {
      final val = double.tryParse(spo2Match.group(1)!);
      if (val != null && val >= 40 && val <= 100) {
        spo2 = val;
      }
    }

    // 2. Blood Pressure (Systolic / Diastolic)
    final bpReg = RegExp(
      r'(?:bp|blood\s*pressure)[\s:=]*(\d{2,3})\s*[\/\\-]\s*(\d{2,3})(?:\s*mm\s*hg)?',
      caseSensitive: false,
    );
    final bpMatch = bpReg.firstMatch(text) ??
        RegExp(r'(\d{2,3})\s*[\/\\-]\s*(\d{2,3})\s*(?:mm\s*hg|bp\b)', caseSensitive: false).firstMatch(text);
    if (bpMatch != null) {
      final sVal = int.tryParse(bpMatch.group(1)!);
      final dVal = int.tryParse(bpMatch.group(2)!);
      if (sVal != null && dVal != null && sVal >= 40 && sVal <= 260 && dVal >= 20 && dVal <= 160) {
        systolicBP = sVal;
        diastolicBP = dVal;
      }
    } else {
      final sysOnlyMatch = RegExp(r'(?:sbp|systolic(?:[\s\w]*bp)?)[\s:=]*(\d{2,3})', caseSensitive: false).firstMatch(text);
      if (sysOnlyMatch != null) {
        final sVal = int.tryParse(sysOnlyMatch.group(1)!);
        if (sVal != null && sVal >= 40 && sVal <= 260) {
          systolicBP = sVal;
        }
      }
    }

    // 3. Heart Rate / Pulse
    final hrReg = RegExp(
      r'(?:pulse(?:[\s\w]*rate)?|heart\s*rate|hr|pr)[\s:=]*(\d{2,3})(?:\s*(?:bpm|beats?\/min|\/min))?',
      caseSensitive: false,
    );
    final hrMatch = hrReg.firstMatch(text) ??
        RegExp(r'(\d{2,3})\s*(?:bpm|beats?\/min)\b', caseSensitive: false).firstMatch(text);
    if (hrMatch != null) {
      final hVal = int.tryParse(hrMatch.group(1)!);
      if (hVal != null && hVal >= 30 && hVal <= 250) {
        heartRate = hVal;
      }
    }

    // 4. Temperature
    final tempReg = RegExp(
      r'(?:temp(?:erature)?|fever\s*(?:of)?)[\s:=]*(\d{2,3}(?:\.\d+)?)\s*(?:°?\s*([cfCF]))?',
      caseSensitive: false,
    );
    final tempMatch = tempReg.firstMatch(text) ??
        RegExp(r'(\d{2,3}(?:\.\d+)?)\s*°\s*([cfCF])\b', caseSensitive: false).firstMatch(text);
    if (tempMatch != null) {
      final tVal = double.tryParse(tempMatch.group(1)!);
      if (tVal != null) {
        final unit = (tempMatch.group(2) ?? '').toUpperCase();
        if (unit == 'F' || tVal >= 90.0) {
          final cVal = (tVal - 32.0) * 5.0 / 9.0;
          if (cVal >= 30.0 && cVal <= 45.0) {
            temperature = double.parse(cVal.toStringAsFixed(1));
          }
        } else if (tVal >= 32.0 && tVal <= 44.0) {
          temperature = double.parse(tVal.toStringAsFixed(1));
        }
      }
    }

    // 5. Respiratory Rate
    final rrReg = RegExp(
      r'(?:resp(?:iratory)?(?:\s*rate)?|rr)[\s:=]*(\d{1,2})(?:\s*(?:breaths?\/min|\/min|cpm))?',
      caseSensitive: false,
    );
    final rrMatch = rrReg.firstMatch(text) ??
        RegExp(r'(\d{1,2})\s*(?:breaths?\/min|cpm)\b', caseSensitive: false).firstMatch(text);
    if (rrMatch != null) {
      final rVal = int.tryParse(rrMatch.group(1)!);
      if (rVal != null && rVal >= 8 && rVal <= 60) {
        respiratoryRate = rVal;
      }
    }

    // 6. Duration
    String duration = 'Unknown';
    final durMatch = RegExp(
      r'(?:for|since|duration(?:[\s\w]*is)?|lasting)?\s*(\d+\s*(?:day|hour|week|month|year)s?|yesterday|morning|night|two\s*days|three\s*days|few\s*days|several\s*days)',
      caseSensitive: false,
    ).firstMatch(text);
    if (durMatch != null) {
      duration = durMatch.group(1)!.trim();
    }

    // 7. Onset
    final textLower = text.toLowerCase();
    String onset = 'unknown';
    if (['sudden', 'acute', 'abrupt', 'hours', 'minutes'].any((w) => textLower.contains(w))) {
      onset = 'sudden';
    } else if (['gradual', 'slowly', 'days', 'weeks', 'months'].any((w) => textLower.contains(w))) {
      onset = 'gradual';
    }

    // 8. Discrete Symptoms
    final symptoms = <String>[];
    final symptomPatterns = [
      (RegExp(r'\b(?:fever|pyrexia|high\s*temp|chills)\b', caseSensitive: false), 'Fever'),
      (RegExp(r'\b(?:breathing\s*difficult(?:y|ies)?|shortness\s*of\s*breath|breathless(?:ness)?|dyspnea|gasping|wheez(?:e|ing))\b', caseSensitive: false), 'Breathing difficulty'),
      (RegExp(r'\b(?:chest\s*pain|chest\s*tightness|angina)\b', caseSensitive: false), 'Chest pain'),
      (RegExp(r'\b(?:cough(?:ing)?|productive\s*cough)\b', caseSensitive: false), 'Cough'),
      (RegExp(r'\b(?:vomit(?:ing)?|nausea)\b', caseSensitive: false), 'Vomiting'),
      (RegExp(r'\b(?:diarrhea|loose\s*(?:stools|motions))\b', caseSensitive: false), 'Diarrhea'),
      (RegExp(r'\b(?:headache|migraine)\b', caseSensitive: false), 'Headache'),
      (RegExp(r'\b(?:dizz(?:y|iness)|vertigo|syncope|faint(?:ing)?)\b', caseSensitive: false), 'Dizziness / Syncope'),
      (RegExp(r'\b(?:abdominal\s*pain|stomach\s*pain|belly\s*pain)\b', caseSensitive: false), 'Abdominal pain'),
      (RegExp(r'\b(?:seizure|convulsion|fit)\b', caseSensitive: false), 'Convulsions / Seizures'),
      (RegExp(r'\b(?:unconscious(?:ness)?|unresponsive|coma|letharg(?:y|ic))\b', caseSensitive: false), 'Altered mental status'),
      (RegExp(r'\b(?:postpartum\s*hemorrhage|bleeding\s*after\s*delivery|uterine\s*bleeding)\b', caseSensitive: false), 'Postpartum hemorrhage'),
      (RegExp(r'\b(?:active\s*bleeding|hemorrhage|blood\s*loss)\b', caseSensitive: false), 'Active bleeding'),
      (RegExp(r'\b(?:fracture|broken\s*bone|dislocation)\b', caseSensitive: false), 'Fracture / Dislocation'),
      (RegExp(r'\b(?:joint\s*pain|ankle\s*pain|backache|sprain|swelling)\b', caseSensitive: false), 'Musculoskeletal pain'),
      (RegExp(r'\b(?:rash|skin\s*lesion|itching)\b', caseSensitive: false), 'Skin rash / lesion'),
      (RegExp(r'\b(?:burns?|scald)\b', caseSensitive: false), 'Burns'),
    ];
    for (final entry in symptomPatterns) {
      if (entry.$1.hasMatch(textLower)) {
        if (!symptoms.contains(entry.$2)) {
          symptoms.add(entry.$2);
        }
      }
    }

    // 9. History
    final history = <String>[];
    final historyPatterns = [
      (RegExp(r'\b(?:diabet(?:es|ic))\b', caseSensitive: false), 'Diabetes Mellitus'),
      (RegExp(r'\b(?:hypertens(?:ion|ive)|high\s*bp)\b', caseSensitive: false), 'Hypertension'),
      (RegExp(r'\b(?:asthma|copd)\b', caseSensitive: false), 'Asthma / COPD'),
      (RegExp(r'\b(?:cardiac|heart\s*disease|cad|mi)\b', caseSensitive: false), 'Cardiovascular Disease'),
      (RegExp(r'\b(?:pregnant|pregnancy|antenatal)\b', caseSensitive: false), 'Pregnancy'),
      (RegExp(r'\b(?:allerg(?:y|ic|ies))\b', caseSensitive: false), 'Documented Allergies'),
    ];
    for (final entry in historyPatterns) {
      if (entry.$1.hasMatch(textLower)) {
        if (!history.contains(entry.$2)) {
          history.add(entry.$2);
        }
      }
    }

    return ExtractedClinicalFacts(
      vitals: ExtractedVitals(
        oxygenSaturation: spo2,
        systolicBP: systolicBP,
        diastolicBP: diastolicBP,
        heartRate: heartRate,
        temperature: temperature,
        respiratoryRate: respiratoryRate,
      ),
      symptoms: symptoms,
      duration: duration,
      onset: onset,
      history: history,
    );
  }

  /// Convenience extractor for vital signs only.
  static ExtractedVitals extractVitalsFromText(String text) {
    return extractClinicalFacts(text).vitals;
  }

  /// Evaluates clinical presentation deterministically according to approved rural triage rules.
  static SymptomAnalysisResult evaluate({
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
  }) {
    final textLower = freeText.toLowerCase().trim();
    final extracted = extractClinicalFacts(freeText);

    // Merge structured parameters with text-extracted vitals
    final effSpO2 = oxygenSaturation ?? extracted.vitals.oxygenSaturation;
    final effSysBP = systolicBP ?? extracted.vitals.systolicBP;
    final effDiaBP = diastolicBP ?? extracted.vitals.diastolicBP;
    final effHR = heartRate ?? extracted.vitals.heartRate;
    final effTemp = temperature ?? extracted.vitals.temperature;
    final effRR = respiratoryRate ?? extracted.vitals.respiratoryRate;

    final redFlags = <String>[];
    final missingInfo = <String>[];
    final followUpQuestions = <String>[];
    final detectedSymptoms = List<String>.from(extracted.symptoms);
    final suggestedTags = Set<String>.from(selectedTags);

    bool vitalEmergency = false;

    // 1. Oxygen Saturation (SpO2)
    if (effSpO2 != null) {
      if (effSpO2 < 90.0) {
        redFlags.add('Severe Hypoxia: SpO2 ${effSpO2.toStringAsFixed(0)}% (<90%) requires emergency oxygen resuscitation.');
        vitalEmergency = true;
        suggestedTags.add('Breathing difficulty');
        suggestedTags.add('Low SpO₂');
        suggestedTags.add('Severe Hypoxia');
      } else if (effSpO2 < 94.0) {
        missingInfo.add('Moderate desaturation: SpO2 ${effSpO2.toStringAsFixed(0)}% requires serial monitoring.');
        suggestedTags.add('Breathing difficulty');
        suggestedTags.add('Low SpO₂');
      }
    } else {
      missingInfo.add('Oxygen saturation (SpO2) not recorded.');
      followUpQuestions.add('Can point-of-care pulse oximetry be performed immediately?');
    }

    // 2. Systolic Blood Pressure
    if (effSysBP != null) {
      if (effSysBP < 85) {
        redFlags.add('Hypotensive Shock: Systolic BP $effSysBP mmHg (<85 mmHg).');
        vitalEmergency = true;
        suggestedTags.add('Shock / Hemodynamic instability');
        suggestedTags.add('Hypotension');
      } else if (effSysBP > 180) {
        redFlags.add('Hypertensive Crisis: Systolic BP $effSysBP mmHg (>180 mmHg).');
        vitalEmergency = true;
        suggestedTags.add('Possible cardiac symptoms');
        suggestedTags.add('Hypertensive Crisis');
      }
    } else {
      missingInfo.add('Blood pressure not recorded.');
      followUpQuestions.add('What is the patient\'s current systolic and diastolic blood pressure?');
    }

    // 3. Heart Rate
    if (effHR != null) {
      if (effHR > 135) {
        redFlags.add('Extreme Tachycardia: Heart rate $effHR bpm (>135 bpm).');
        vitalEmergency = true;
        suggestedTags.add('Tachycardia');
      } else if (effHR > 100) {
        suggestedTags.add('Tachycardia');
      } else if (effHR < 45) {
        redFlags.add('Severe Bradycardia: Heart rate $effHR bpm (<45 bpm).');
        vitalEmergency = true;
        suggestedTags.add('Bradycardia');
      }
    } else {
      missingInfo.add('Pulse / Heart rate not recorded.');
    }

    // 4. Temperature
    if (effTemp != null) {
      if (effTemp > 40.0) {
        redFlags.add('Hyperpyrexia: Temperature ${effTemp.toStringAsFixed(1)}°C (>40.0°C). Risk of febrile seizure or severe sepsis.');
        vitalEmergency = true;
        suggestedTags.add('High Fever');
        suggestedTags.add('Suspected infection');
      } else if (effTemp >= 38.0) {
        suggestedTags.add('Fever');
        suggestedTags.add('Suspected infection');
      }
    }

    // 5. Predefined mandatory red flags from text
    bool textEmergency = false;
    for (final rule in _mandatoryRedFlags) {
      for (final kw in rule.keywords) {
        if (textLower.contains(kw)) {
          redFlags.add(rule.flag);
          if (rule.urgency == ClinicalUrgencyTier.level1ImmediateEmergency) {
            textEmergency = true;
          }
          break;
        }
      }
    }

    // 6. Secondary symptoms and tags
    if ((textLower.contains('fever') || textLower.contains('pyrexia') || textLower.contains('chills')) && !detectedSymptoms.contains('Fever')) {
      detectedSymptoms.add('Fever');
      suggestedTags.add('Suspected infection');
    }
    if ((textLower.contains('cough') || textLower.contains('breathless') || textLower.contains('wheeze')) && !detectedSymptoms.contains('Breathing difficulty')) {
      detectedSymptoms.add('Breathing difficulty');
      suggestedTags.add('Breathing difficulty');
    }
    if ((textLower.contains('vomit') || textLower.contains('diarrhea') || textLower.contains('loose motion')) && !detectedSymptoms.contains('Gastroenteritis')) {
      detectedSymptoms.add('Gastroenteritis');
      suggestedTags.add('Dehydration risk');
    }
    if (textLower.contains('pregnant') || textLower.contains('antenatal') || textLower.contains('labor')) {
      suggestedTags.add('Pregnancy-related concern');
    }
    if (textLower.contains('chest pain') || textLower.contains('palpitation')) {
      suggestedTags.add('Possible cardiac symptoms');
    }
    if (textLower.contains('fall') || textLower.contains('trauma') || textLower.contains('fracture') || textLower.contains('accident') || textLower.contains('sprain')) {
      suggestedTags.add('Injury or trauma');
    }

    // 7. Context checklist
    final hasOnsetWord = ['day', 'hour', 'since', 'yesterday', 'morning', 'night', 'week', 'onset', 'started', 'duration']
        .any((w) => textLower.contains(w));
    if (!hasOnsetWord && extracted.duration == 'Unknown') {
      missingInfo.add('Exact onset time / duration of symptoms not mentioned.');
      followUpQuestions.add('When exactly did symptoms start or last known well?');
    }

    final hasHistoryWord = ['allerg', 'history', 'diabet', 'hypertens', 'asthma', 'medicat', 'past']
        .any((w) => textLower.contains(w));
    if (!hasHistoryWord && extracted.history.isEmpty) {
      missingInfo.add('Past medical history, chronic diseases, and drug allergies not documented.');
      followUpQuestions.add('Does the patient have known allergies or pre-existing medical conditions?');
    }

    // 8. Urgency and Referral Determination
    ClinicalUrgencyTier urgency = ClinicalUrgencyTier.level4RoutineAssessment;
    ReferralLevel referral = ReferralLevel.referralA;
    String reasoning = '';
    bool isUndetermined = false;

    final vitalsCompletelyMissing = effSpO2 == null && effSysBP == null && effHR == null && effTemp == null && effRR == null;

    if (vitalEmergency || textEmergency || redFlags.isNotEmpty) {
      urgency = ClinicalUrgencyTier.level1ImmediateEmergency;
      referral = ReferralLevel.referralD;
      suggestedTags.add('Immediate Emergency');
      reasoning = 'MANDATORY EMERGENCY RULE TRIGGERED: ${redFlags.length} life-threatening warning sign(s) detected (${redFlags.take(2).join("; ")}). '
          'Requires immediate emergency stabilization and 108 ALS ambulance transfer to an equipped hospital.';
    } else if (suggestedTags.contains('Pregnancy-related concern') ||
        suggestedTags.contains('Possible cardiac symptoms') ||
        suggestedTags.contains('Breathing difficulty')) {
      urgency = ClinicalUrgencyTier.level2Urgent;
      referral = ReferralLevel.referralB;
      suggestedTags.add('Urgent Review');
      reasoning = 'URGENT: High-risk clinical concern identified. Prompt medical evaluation and hospital-level diagnostic workup indicated.';
    } else if (suggestedTags.contains('Suspected infection') || suggestedTags.contains('Dehydration risk') || suggestedTags.contains('Fever')) {
      urgency = ClinicalUrgencyTier.level3PriorityAssessment;
      referral = ReferralLevel.referralB;
      reasoning = 'PRIORITY ASSESSMENT: Patient exhibits symptomatic presentation requiring timely clinical examination within 12-24 hours.';
    } else if (suggestedTags.contains('Injury or trauma') && !vitalsCompletelyMissing) {
      urgency = ClinicalUrgencyTier.level4RoutineAssessment;
      referral = ReferralLevel.referralA;
      reasoning = 'ROUTINE ASSESSMENT: Mild or stable presentation suitable for local outpatient primary care post.';
    } else if (vitalsCompletelyMissing) {
      isUndetermined = true;
      urgency = (detectedSymptoms.contains('Dizziness / Syncope') || detectedSymptoms.contains('Altered mental status'))
          ? ClinicalUrgencyTier.level2Urgent
          : ClinicalUrgencyTier.level3PriorityAssessment;
      referral = ReferralLevel.referralB;
      suggestedTags.add('Information Incomplete');
      reasoning = 'Urgency undetermined — clinician assessment required: Vital signs are unrecorded and clinical description requires evaluation. '
          'Per clinical safety protocol, uncertainty is never assigned routine triage.';
    } else {
      urgency = ClinicalUrgencyTier.level4RoutineAssessment;
      referral = ReferralLevel.referralA;
      reasoning = 'ROUTINE ASSESSMENT: Stable presentation suitable for local outpatient primary care post.';
    }

    String analysisStatus;
    if (vitalEmergency || textEmergency || redFlags.isNotEmpty) {
      analysisStatus = 'safety_escalation';
    } else if (isUndetermined) {
      analysisStatus = 'insufficient_information';
    } else if (vitalsCompletelyMissing || missingInfo.isNotEmpty) {
      analysisStatus = 'partial';
    } else {
      analysisStatus = 'success';
    }

    if (detectedSymptoms.isEmpty && textLower.isNotEmpty && !isUndetermined) {
      detectedSymptoms.add(textLower.length > 50 ? '${textLower.substring(0, 50)}...' : textLower);
    }

    final mergedVitals = ExtractedVitals(
      oxygenSaturation: effSpO2,
      systolicBP: effSysBP,
      diastolicBP: effDiaBP,
      heartRate: effHR,
      temperature: effTemp,
      respiratoryRate: effRR,
    );

    return SymptomAnalysisResult(
      assessmentId: 'asmt_offline_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      freeTextDescription: freeText,
      extractedSymptoms: detectedSymptoms,
      extractedVitals: mergedVitals,
      duration: extracted.duration,
      onset: extracted.onset,
      relevantHistory: extracted.history,
      reportedWarningSigns: redFlags,
      missingInformation: missingInfo,
      followUpQuestions: followUpQuestions,
      suggestedTags: suggestedTags.toList()..sort(),
      urgencyLevel: urgency,
      urgencyLabel: isUndetermined ? 'Urgency undetermined — clinician assessment required' : urgency.title,
      referralLevel: referral,
      referralLabel: referral.title,
      reasoning: reasoning,
      redFlags: redFlags,
      isEmergency: urgency == ClinicalUrgencyTier.level1ImmediateEmergency,
      isUndetermined: isUndetermined,
      analysisStatus: analysisStatus,
      source: AssessmentSource.offlineRules,
      sourceLabel: 'Offline rule-based assessment — not analyzed by Gemini',
      createdAt: DateTime.now(),
    );
  }

  /// Mandatory Safety Rule Check: Enforces that Gemini cannot downgrade an urgency
  /// level established by a mandatory safety rule.
  static SymptomAnalysisResult enforceSafetyRules({
    required SymptomAnalysisResult geminiResult,
    required SymptomAnalysisResult localRuleResult,
  }) {
    if (localRuleResult.redFlags.isNotEmpty &&
        geminiResult.urgencyLevel.level > localRuleResult.urgencyLevel.level) {
      // Gemini suggested a lower urgency, but mandatory red flags exist. Override Gemini!
      return SymptomAnalysisResult(
        assessmentId: geminiResult.assessmentId,
        patientId: geminiResult.patientId,
        freeTextDescription: geminiResult.freeTextDescription,
        extractedSymptoms: geminiResult.extractedSymptoms.isNotEmpty
            ? geminiResult.extractedSymptoms
            : localRuleResult.extractedSymptoms,
        extractedVitals: geminiResult.extractedVitals.isNotEmpty
            ? geminiResult.extractedVitals
            : localRuleResult.extractedVitals,
        duration: geminiResult.duration != 'Unknown' ? geminiResult.duration : localRuleResult.duration,
        onset: geminiResult.onset != 'Unknown' && geminiResult.onset != 'unknown' ? geminiResult.onset : localRuleResult.onset,
        severity: geminiResult.severity,
        relevantHistory: {...geminiResult.relevantHistory, ...localRuleResult.relevantHistory}.toList(),
        reportedWarningSigns: {...geminiResult.reportedWarningSigns, ...localRuleResult.reportedWarningSigns}.toList(),
        missingInformation: {...geminiResult.missingInformation, ...localRuleResult.missingInformation}.toList(),
        followUpQuestions: geminiResult.followUpQuestions,
        suggestedTags: {...geminiResult.suggestedTags, ...localRuleResult.suggestedTags}.toList(),
        urgencyLevel: localRuleResult.urgencyLevel,
        urgencyLabel: localRuleResult.urgencyLabel,
        referralLevel: localRuleResult.referralLevel,
        referralLabel: localRuleResult.referralLabel,
        reasoning: 'MANDATORY SAFETY RULE ENFORCED: Local red flag rule (${localRuleResult.redFlags.join("; ")}) '
            'prevented AI downgrade. Original AI suggestion: ${geminiResult.reasoning}',
        redFlags: {...geminiResult.redFlags, ...localRuleResult.redFlags}.toList(),
        isEmergency: localRuleResult.isEmergency,
        isUndetermined: false,
        analysisStatus: 'safety_escalation',
        source: AssessmentSource.gemini,
        sourceLabel: 'Gemini AI Assisted (Safety Rule Enforced)',
        modelVersion: geminiResult.modelVersion,
        rulesetVersion: localRuleResult.rulesetVersion,
        createdAt: geminiResult.createdAt,
        safetyOverrideApplied: true,
      );
    }
    return geminiResult;
  }
}
