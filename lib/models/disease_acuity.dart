import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../core/theme/app_colors.dart';
import 'enums.dart';

/// Clinical triage & disease acuity tier representing a level in the
/// World Health Organization (WHO) and primary healthcare referral protocol.
class DiseaseTriageLevel {
  final String level;
  final int severity;
  final String recommendation;
  final List<String> examples;
  final String typicalAction;

  const DiseaseTriageLevel({
    required this.level,
    required this.severity,
    required this.recommendation,
    required this.examples,
    required this.typicalAction,
  });

  factory DiseaseTriageLevel.fromMap(Map<String, dynamic> map) {
    return DiseaseTriageLevel(
      level: map['level'] as String? ?? '',
      severity: (map['severity'] as num?)?.toInt() ?? 1,
      recommendation: map['recommendation'] as String? ?? '',
      examples: (map['examples'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      typicalAction: map['typical_action'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'level': level,
        'severity': severity,
        'recommendation': recommendation,
        'examples': examples,
        'typical_action': typicalAction,
      };

  String get shortLabel {
    switch (severity) {
      case 1:
        return 'Level 1: Home Care';
      case 2:
        return 'Level 2: Clinic / PHC';
      case 3:
        return 'Level 3: Urgent Referral';
      case 4:
        return 'Level 4: Emergency';
      default:
        return 'Level $severity';
    }
  }

  UrgencyLevel get urgencyLevel {
    switch (severity) {
      case 1:
      case 2:
        return UrgencyLevel.routine;
      case 3:
        return UrgencyLevel.urgent;
      case 4:
      default:
        return UrgencyLevel.emergency;
    }
  }

  RecommendedAction get recommendedAction {
    switch (severity) {
      case 1:
      case 2:
        return RecommendedAction.manageLocally;
      case 3:
        return RecommendedAction.referralRecommended;
      case 4:
      default:
        return RecommendedAction.immediateReferral;
    }
  }

  Color get color {
    switch (severity) {
      case 1:
        return AppColors.statusGreen;
      case 2:
        return AppColors.tealAccentDark;
      case 3:
        return AppColors.statusAmber;
      case 4:
      default:
        return AppColors.statusRed;
    }
  }

  Color get backgroundColor {
    switch (severity) {
      case 1:
        return AppColors.statusGreenBg;
      case 2:
        return AppColors.tealAccentLight;
      case 3:
        return AppColors.statusAmberBg;
      case 4:
      default:
        return AppColors.statusRedBg;
    }
  }

  IconData get icon {
    switch (severity) {
      case 1:
        return Icons.home_outlined;
      case 2:
        return Icons.local_hospital_rounded;
      case 3:
        return Icons.warning_amber_rounded;
      case 4:
      default:
        return Icons.emergency_rounded;
    }
  }

  bool containsCondition(String condition) {
    final query = condition.trim().toLowerCase();
    return examples.any((ex) =>
        ex.toLowerCase() == query ||
        ex.toLowerCase().contains(query) ||
        query.contains(ex.toLowerCase()));
  }
}

/// Structured dataset of disease acuity and triage levels based on
/// gemini-code-1791532188800.json and standard emergency referral guidance.
class DiseaseAcuityDataset {
  DiseaseAcuityDataset._();

  static const DiseaseTriageLevel level1 = DiseaseTriageLevel(
    level: 'LEVEL 1 — Home care / Observe',
    severity: 1,
    recommendation: 'Mild, uncomplicated symptoms',
    examples: [
      'Common cold',
      'Mild headache',
      'Mild muscle pain',
      'Minor superficial wound',
      'Mild diarrhea without dehydration',
    ],
    typicalAction: 'Rest, fluids, basic supportive care; monitor',
  );

  static const DiseaseTriageLevel level2 = DiseaseTriageLevel(
    level: 'LEVEL 2 — Local Clinic / PHC',
    severity: 2,
    recommendation: 'Needs examination or treatment but no immediate danger signs',
    examples: [
      'Persistent fever',
      'Suspected uncomplicated malaria/dengue',
      'UTI symptoms',
      'Moderate diarrhea',
      'Skin infection',
      'Minor burns',
      'Simple wound',
      'Stable asthma symptoms',
    ],
    typicalAction: 'Visit clinic/PHC; testing and treatment',
  );

  static const DiseaseTriageLevel level3 = DiseaseTriageLevel(
    level: 'LEVEL 3 — Urgent Referral',
    severity: 3,
    recommendation: 'Potentially serious; needs higher-level evaluation',
    examples: [
      'Suspected severe infection',
      'Pneumonia with breathing difficulty',
      'Significant dehydration',
      'Fracture',
      'Deep wound',
      'Animal bite',
      'Persistent abdominal pain',
      'Pregnancy complications',
    ],
    typicalAction: 'Clinic/PHC first for stabilization → CHC/hospital',
  );

  static const DiseaseTriageLevel level4 = DiseaseTriageLevel(
    level: 'LEVEL 4 — Emergency / Big Hospital',
    severity: 4,
    recommendation: 'Life-threatening or needs specialist/emergency facilities',
    examples: [
      'Severe breathing difficulty',
      'Unconsciousness',
      'Shock',
      'Severe bleeding',
      'Chest pain with concerning features',
      'Stroke symptoms',
      'Severe burns',
      'Major trauma',
      'Seizures',
      'Severe poisoning',
      'Complicated childbirth',
    ],
    typicalAction: "Immediate emergency referral/ambulance; don't wait for routine clinic treatment",
  );

  static const List<DiseaseTriageLevel> allLevels = [
    level1,
    level2,
    level3,
    level4,
  ];

  /// Find the triage level that contains a specific disease or condition.
  static DiseaseTriageLevel? findLevelForCondition(String conditionName) {
    final query = conditionName.trim().toLowerCase();
    for (final level in allLevels) {
      if (level.examples.any((ex) {
        final exLow = ex.toLowerCase();
        return exLow == query || query.contains(exLow) || exLow.contains(query);
      })) {
        return level;
      }
    }
    return null;
  }

  /// Evaluates clinical text (complaint, symptoms, notes) and returns the highest severity level matched.
  static DiseaseTriageLevel? evaluateTextAcuity(String text) {
    final normalized = text.toLowerCase();
    // Check in descending order of severity (Level 4 down to Level 1)
    for (int sev = 4; sev >= 1; sev--) {
      final level = getLevelBySeverity(sev);
      if (level != null) {
        for (final ex in level.examples) {
          if (_matchesConditionText(normalized, ex)) {
            return level;
          }
        }
      }
    }
    return null;
  }

  /// Returns all matching conditions detected in the text across all levels.
  static List<String> findMatchedConditions(String text) {
    final normalized = text.toLowerCase();
    final matched = <String>[];
    for (int sev = 4; sev >= 1; sev--) {
      final level = getLevelBySeverity(sev);
      if (level != null) {
        for (final ex in level.examples) {
          if (_matchesConditionText(normalized, ex) && !matched.contains(ex)) {
            matched.add(ex);
          }
        }
      }
    }
    return matched;
  }

  static bool _isNegated(String text, String phrase) {
    final lowerText = text.toLowerCase();
    final lowerPhrase = phrase.toLowerCase();
    final patterns = [
      'no $lowerPhrase',
      'without $lowerPhrase',
      'denies $lowerPhrase',
      'nil $lowerPhrase',
      'not $lowerPhrase',
      'negative for $lowerPhrase',
      'no signs of $lowerPhrase',
    ];
    return patterns.any((p) => lowerText.contains(p));
  }

  static bool _matchesConditionText(String text, String condition) {
    final c = condition.toLowerCase();
    if (_isNegated(text, c)) return false;
    if (text.contains(c)) return true;

    // Clinical synonyms & sub-tokens
    if (c == 'chest pain with concerning features') {
      if (_isNegated(text, 'chest pain')) return false;
      return text.contains('chest pain with concerning features') ||
          (text.contains('chest pain') &&
              (text.contains('concerning') ||
                  text.contains('shock') ||
                  text.contains('syncope') ||
                  text.contains('hypotension') ||
                  text.contains('collapse')));
    }
    if (c == 'severe breathing difficulty') {
      if (_isNegated(text, 'respiratory distress') ||
          _isNegated(text, 'breathing difficulty') ||
          _isNegated(text, 'dyspnea') ||
          text.contains('no respiratory distress') ||
          text.contains('without respiratory distress')) {
        return false;
      }
      return text.contains('severe breathing') ||
          text.contains('severe respiratory distress') ||
          text.contains('respiratory failure') ||
          text.contains('stridor') ||
          (text.contains('respiratory distress') && !_isNegated(text, 'respiratory distress'));
    }
    if (c == 'pneumonia with breathing difficulty') {
      if (_isNegated(text, 'pneumonia')) return false;
      return text.contains('pneumonia') ||
          (text.contains('chest in-drawing') && !text.contains('no chest in-drawing')) ||
          text.contains('subcostal');
    }
    if (c == 'stroke symptoms') {
      if (_isNegated(text, 'stroke')) return false;
      return text.contains('stroke') ||
          text.contains('facial droop') ||
          text.contains('slurred') ||
          text.contains('hemiplegia');
    }
    if (c == 'severe bleeding') {
      if (_isNegated(text, 'bleeding') || _isNegated(text, 'hemorrhage')) return false;
      return text.contains('severe bleeding') ||
          text.contains('hemorrhage') ||
          text.contains('heavy bleeding') ||
          text.contains('pph');
    }
    if (c == 'unconsciousness') {
      if (_isNegated(text, 'unconscious') || _isNegated(text, 'unresponsive')) return false;
      return text.contains('unconscious') ||
          text.contains('coma') ||
          text.contains('unresponsive');
    }
    if (c == 'seizures') {
      if (_isNegated(text, 'seizure') || _isNegated(text, 'convulsion')) return false;
      return text.contains('seizure') || text.contains('convulsion');
    }
    if (c == 'major trauma') {
      if (_isNegated(text, 'trauma')) return false;
      return text.contains('major trauma') ||
          text.contains('polytrauma') ||
          text.contains('compound fracture') ||
          text.contains('limb trauma');
    }
    if (c == 'complicated childbirth') {
      return text.contains('complicated childbirth') ||
          text.contains('obstructed labor') ||
          text.contains('postpartum hemorrhage') ||
          text.contains('eclampsia');
    }
    if (c == 'pregnancy complications') {
      return text.contains('pregnancy') ||
          text.contains('gestational') ||
          text.contains('pre-eclampsia') ||
          text.contains('vaginal bleeding');
    }
    if (c == 'fracture') {
      if (_isNegated(text, 'fracture')) return false;
      return text.contains('fracture') || text.contains('broken bone');
    }
    if (c == 'significant dehydration') {
      if (text.contains('without dehydration') || text.contains('no dehydration')) return false;
      return text.contains('severe dehydration') || text.contains('sunken eyes');
    }
    return false;
  }

  static DiseaseTriageLevel? getLevelBySeverity(int severity) {
    switch (severity) {
      case 1:
        return level1;
      case 2:
        return level2;
      case 3:
        return level3;
      case 4:
        return level4;
      default:
        return null;
    }
  }

  static List<String> getAllConditions() {
    return allLevels.expand((l) => l.examples).toList();
  }

  static List<String> getConditionsForSeverity(int severity) {
    return getLevelBySeverity(severity)?.examples ?? const [];
  }

  /// Maps a specific condition to a recommended PatientConditionCategory.
  static PatientConditionCategory mapConditionToCategory(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('chest pain') || c.contains('cardiac') || c.contains('coronary')) {
      return PatientConditionCategory.suspectedCardiacEmergency;
    }
    if (c.contains('stroke')) {
      return PatientConditionCategory.suspectedStroke;
    }
    if (c.contains('trauma') || c.contains('deep wound') || c.contains('severe burns') || c.contains('compound')) {
      return PatientConditionCategory.majorTrauma;
    }
    if (c.contains('childbirth') || c.contains('pregnancy') || c.contains('obstetric') || c.contains('bleeding after delivery') || c.contains('pph')) {
      return PatientConditionCategory.obstetricEmergency;
    }
    if (c.contains('pneumonia') || c.contains('pediatric')) {
      return PatientConditionCategory.pediatricEmergency;
    }
    if (c.contains('fracture')) {
      return PatientConditionCategory.stableFracture;
    }
    if (c.contains('shock') || c.contains('unconsciousness') || c.contains('severe bleeding') || c.contains('poisoning') || c.contains('seizures') || c.contains('severe breathing')) {
      return PatientConditionCategory.criticalEmergency;
    }
    return PatientConditionCategory.stableMedicalCase;
  }

  /// Deduces the required clinical medical specialty for a condition.
  static String deduceSpecialtyForCondition(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('pregnancy') || c.contains('childbirth') || c.contains('delivery') || c.contains('obstetric')) {
      return 'Obstetrics & Gynecology';
    }
    if (c.contains('chest pain') || c.contains('cardiac') || c.contains('coronary')) {
      return 'Cardiology';
    }
    if (c.contains('stroke') || c.contains('neuro')) {
      return 'Neurosurgery';
    }
    if (c.contains('fracture') || c.contains('trauma')) {
      return 'Orthopedics & Trauma Surgery';
    }
    if (c.contains('pneumonia with breathing difficulty')) {
      return 'Pediatrics';
    }
    if (c.contains('abdominal pain') || c.contains('deep wound') || c.contains('burns')) {
      return 'General Surgery';
    }
    return 'General Medicine';
  }

  /// Loads levels from the provided JSON string.
  static List<DiseaseTriageLevel> fromJsonString(String jsonStr) {
    final decoded = json.decode(jsonStr) as List<dynamic>;
    return decoded
        .map((item) => DiseaseTriageLevel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Loads the disease acuity dataset dynamically from assets.
  static Future<List<DiseaseTriageLevel>> loadFromAsset([
    String assetPath = 'assets/data/gemini-code-1791532188800.json',
  ]) async {
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      return fromJsonString(jsonStr);
    } catch (_) {
      return allLevels;
    }
  }
}
