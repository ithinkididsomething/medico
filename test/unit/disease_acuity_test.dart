import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/disease_acuity.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/patient.dart';
import 'package:smart_referral/services/assessment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Disease Acuity & Triage Protocol Unit Tests', () {
    test('1. Validates all 4 triage levels from dataset schema', () {
      expect(DiseaseAcuityDataset.allLevels.length, equals(4));

      // Level 1 — Home care / Observe
      final l1 = DiseaseAcuityDataset.level1;
      expect(l1.severity, equals(1));
      expect(l1.level, contains('LEVEL 1'));
      expect(l1.recommendation, contains('Mild, uncomplicated symptoms'));
      expect(l1.typicalAction, contains('Rest, fluids'));
      expect(l1.examples, contains('Common cold'));
      expect(l1.examples, contains('Mild headache'));
      expect(l1.examples, contains('Mild diarrhea without dehydration'));
      expect(l1.urgencyLevel, equals(UrgencyLevel.routine));
      expect(l1.recommendedAction, equals(RecommendedAction.manageLocally));

      // Level 2 — Local Clinic / PHC
      final l2 = DiseaseAcuityDataset.level2;
      expect(l2.severity, equals(2));
      expect(l2.level, contains('LEVEL 2'));
      expect(l2.recommendation, contains('Needs examination or treatment'));
      expect(l2.typicalAction, contains('Visit clinic/PHC'));
      expect(l2.examples, contains('Persistent fever'));
      expect(l2.examples, contains('Suspected uncomplicated malaria/dengue'));
      expect(l2.examples, contains('Stable asthma symptoms'));
      expect(l2.urgencyLevel, equals(UrgencyLevel.routine));

      // Level 3 — Urgent Referral
      final l3 = DiseaseAcuityDataset.level3;
      expect(l3.severity, equals(3));
      expect(l3.level, contains('LEVEL 3'));
      expect(l3.recommendation, contains('Potentially serious'));
      expect(l3.typicalAction, contains('Clinic/PHC first for stabilization'));
      expect(l3.examples, contains('Fracture'));
      expect(l3.examples, contains('Pneumonia with breathing difficulty'));
      expect(l3.examples, contains('Pregnancy complications'));
      expect(l3.urgencyLevel, equals(UrgencyLevel.urgent));
      expect(l3.recommendedAction, equals(RecommendedAction.referralRecommended));

      // Level 4 — Emergency / Big Hospital
      final l4 = DiseaseAcuityDataset.level4;
      expect(l4.severity, equals(4));
      expect(l4.level, contains('LEVEL 4'));
      expect(l4.recommendation, contains('Life-threatening'));
      expect(l4.typicalAction, contains('Immediate emergency referral'));
      expect(l4.examples, contains('Severe breathing difficulty'));
      expect(l4.examples, contains('Unconsciousness'));
      expect(l4.examples, contains('Chest pain with concerning features'));
      expect(l4.examples, contains('Stroke symptoms'));
      expect(l4.examples, contains('Complicated childbirth'));
      expect(l4.urgencyLevel, equals(UrgencyLevel.emergency));
      expect(l4.recommendedAction, equals(RecommendedAction.immediateReferral));
    });

    test('2. Validates JSON deserialization against raw file data', () {
      final file = File('assets/data/gemini-code-1791532188800.json');
      expect(file.existsSync(), isTrue);
      final jsonStr = file.readAsStringSync();
      final loadedLevels = DiseaseAcuityDataset.fromJsonString(jsonStr);

      expect(loadedLevels.length, equals(4));
      expect(loadedLevels[0].severity, equals(1));
      expect(loadedLevels[1].severity, equals(2));
      expect(loadedLevels[2].severity, equals(3));
      expect(loadedLevels[3].severity, equals(4));
      expect(loadedLevels[3].examples, contains('Severe breathing difficulty'));
    });

    test('3. Evaluates text and condition lookups accurately', () {
      expect(DiseaseAcuityDataset.findLevelForCondition('Common cold')?.severity, equals(1));
      expect(DiseaseAcuityDataset.findLevelForCondition('Persistent fever')?.severity, equals(2));
      expect(DiseaseAcuityDataset.findLevelForCondition('Fracture')?.severity, equals(3));
      expect(DiseaseAcuityDataset.findLevelForCondition('Stroke symptoms')?.severity, equals(4));

      // Acuity evaluation selects the highest severity tier
      final textWithMultiple = 'Patient with persistent fever and sudden chest pain with concerning features';
      final evaluated = DiseaseAcuityDataset.evaluateTextAcuity(textWithMultiple);
      expect(evaluated?.severity, equals(4)); // Level 4 takes precedence over Level 2
    });

    test('4. Condition to Category and Specialty mappings', () {
      expect(
        DiseaseAcuityDataset.mapConditionToCategory('Stroke symptoms'),
        equals(PatientConditionCategory.suspectedStroke),
      );
      expect(
        DiseaseAcuityDataset.mapConditionToCategory('Chest pain with concerning features'),
        equals(PatientConditionCategory.suspectedCardiacEmergency),
      );
      expect(
        DiseaseAcuityDataset.mapConditionToCategory('Complicated childbirth'),
        equals(PatientConditionCategory.obstetricEmergency),
      );
      expect(
        DiseaseAcuityDataset.mapConditionToCategory('Fracture'),
        equals(PatientConditionCategory.stableFracture),
      );

      expect(
        DiseaseAcuityDataset.deduceSpecialtyForCondition('Complicated childbirth'),
        equals('Obstetrics & Gynecology'),
      );
      expect(
        DiseaseAcuityDataset.deduceSpecialtyForCondition('Chest pain with concerning features'),
        equals('Cardiology'),
      );
      expect(
        DiseaseAcuityDataset.deduceSpecialtyForCondition('Stroke symptoms'),
        equals('Neurosurgery'),
      );
    });

    test('5. RuleBasedAssessmentService integrates disease acuity protocol in triage evaluation', () {
      const service = RuleBasedAssessmentService();

      // Case A: Level 4 emergency presentation
      final emergencyPatient = Patient(
        patientId: 'TEST-EMG-01',
        age: 55,
        sex: Sex.male,
        mainComplaint: 'Sudden chest pain with concerning features',
        symptoms: const ['Severe breathing difficulty'],
        injuryOrIllnessDetails: 'Onset 40 minutes ago while resting',
        clinicalFindings: 'Diaphoretic, pale, clutching chest',
        heartRate: 110,
        systolicBP: 130,
        diastolicBP: 85,
        respiratoryRate: 26,
        oxygenSaturation: 94.0,
        temperature: 36.8,
        requiredSpecialty: 'Cardiology',
        createdAt: DateTime.now(),
      );

      final emgResult = service.evaluate(emergencyPatient);
      expect(emgResult.urgencyLevel, equals(UrgencyLevel.emergency));
      expect(emgResult.recommendedAction, equals(RecommendedAction.immediateReferral));
      expect(emgResult.matchedDiseaseLevel?.severity, equals(4));
      expect(emgResult.matchedDiseases, contains('Chest pain with concerning features'));
      expect(emgResult.clinicalRationale.any((r) => r.contains('Protocol Action')), isTrue);

      // Case B: Level 3 urgent presentation
      final urgentPatient = Patient(
        patientId: 'TEST-URG-01',
        age: 22,
        sex: Sex.male,
        mainComplaint: 'Suspected severe infection and deep wound after animal bite',
        symptoms: const ['Animal bite', 'Deep wound'],
        injuryOrIllnessDetails: 'Dog bite on forearm 3 hours ago',
        clinicalFindings: 'Laceration 5cm, edges jagged, swelling present',
        heartRate: 85,
        systolicBP: 120,
        diastolicBP: 80,
        respiratoryRate: 18,
        oxygenSaturation: 98.0,
        temperature: 37.5,
        requiredSpecialty: 'General Surgery',
        createdAt: DateTime.now(),
      );

      final urgResult = service.evaluate(urgentPatient);
      expect(urgResult.urgencyLevel, equals(UrgencyLevel.urgent));
      expect(urgResult.recommendedAction, equals(RecommendedAction.referralRecommended));
      expect(urgResult.matchedDiseaseLevel?.severity, equals(3));
      expect(urgResult.matchedDiseases, contains('Animal bite'));

      // Case C: Level 1 routine home care presentation
      final routinePatient = Patient(
        patientId: 'TEST-ROUT-01',
        age: 28,
        sex: Sex.female,
        mainComplaint: 'Common cold with mild headache',
        symptoms: const ['Mild headache', 'Mild muscle pain'],
        injuryOrIllnessDetails: 'Symptoms for 1 day, no red flags',
        clinicalFindings: 'Nasal congestion, pharynx normal',
        heartRate: 72,
        systolicBP: 116,
        diastolicBP: 74,
        respiratoryRate: 16,
        oxygenSaturation: 99.0,
        temperature: 36.6,
        requiredSpecialty: 'General Medicine',
        createdAt: DateTime.now(),
      );

      final routResult = service.evaluate(routinePatient);
      expect(routResult.urgencyLevel, equals(UrgencyLevel.routine));
      expect(routResult.recommendedAction, equals(RecommendedAction.manageLocally));
      expect(routResult.matchedDiseaseLevel?.severity, equals(1));
    });
  });
}
