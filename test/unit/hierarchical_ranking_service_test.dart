import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/hierarchical_referral_result.dart';
import 'package:smart_referral/models/synthetic_doctor.dart';
import 'package:smart_referral/services/hierarchical_ranking_service.dart';

void main() {
  group('Hierarchical Referral Models Tests', () {
    test('HierarchicalTechnicalEvaluation parses from and to JSON map correctly', () {
      final map = {
        'is_eligible': true,
        'eligibility_status': 'eligible',
        'technical_suitability_score': 95.0,
        'confirmed_capabilities': ['Cath Lab / Cardiac', '12-Lead ECG'],
        'missing_essential_capabilities': <String>[],
        'unknown_capabilities': <String>[],
        'specialty_score': 30.0,
        'equipment_score': 30.0,
        'doctor_score': 35.0,
      };

      final eval = HierarchicalTechnicalEvaluation.fromMap(map);
      expect(eval.isEligible, isTrue);
      expect(eval.eligibilityStatus, 'eligible');
      expect(eval.technicalSuitabilityScore, 95.0);
      expect(eval.confirmedCapabilities.length, 2);
      expect(eval.missingEssentialCapabilities, isEmpty);
      expect(eval.specialtyScore, 30.0);
      expect(eval.equipmentScore, 30.0);
      expect(eval.doctorScore, 35.0);
    });

    test('DoctorProfile model adheres to synthetic demarcation and 4-pillar scores', () {
      final map = {
        'doctor_id': 'synth_doc_001',
        'full_name': 'Dr. Rajesh Verma',
        'display_name': 'Dr. Rajesh Verma',
        'email': 'dr.rajesh.verma@example.com',
        'phone_number': '9826012345',
        'primary_practice_environment': 'tertiary_hospital',
        'primary_specialty': 'Cardiology',
        'facility_id': 'indore_hospital_001',
        'facility_name': 'Apollo Hospitals Indore',
        'total_experience_years': 18,
        'is_synthetic': true,
        'record_source': 'synthetic_demo',
        'verification_status': 'unverified_demo',
        'normalized_capability_score': 88.5,
        'score_breakdown': {
          'base_expertise_score': 30.0,
          'clinical_experience_score': 25.0,
          'clinical_volume_score': 20.0,
          'professional_standing_score': 13.5,
        },
        'isSimulatedDataNotice': 'SIMULATED DATA — NOT FOR CLINICAL DECISIONS',
      };

      final doc = DoctorProfile.fromMap(map);
      expect(doc.isSynthetic, isTrue);
      expect(doc.recordSource, 'synthetic_demo');
      expect(doc.verificationStatus, 'unverified_demo');
      expect(doc.isSimulatedDataNotice, contains('SIMULATED DATA'));
      expect(doc.normalizedCapabilityScore, 88.5);
      expect(doc.scoreBreakdown['base_expertise_score'], 30.0);
      expect(doc.scoreBreakdown['clinical_experience_score'], 25.0);
      expect(doc.scoreBreakdown['clinical_volume_score'], 20.0);
      expect(doc.scoreBreakdown['professional_standing_score'], 13.5);
    });

    test('HierarchicalRankingService maps condition categories cleanly', () {
      expect(
        HierarchicalRankingService.mapCategoryToConditionKey(PatientConditionCategory.suspectedCardiacEmergency),
        'suspected_heart_attack',
      );
      expect(
        HierarchicalRankingService.mapCategoryToConditionKey(PatientConditionCategory.suspectedStroke),
        'suspected_stroke',
      );
      expect(
        HierarchicalRankingService.mapCategoryToConditionKey(PatientConditionCategory.majorTrauma),
        'major_trauma',
      );
      expect(
        HierarchicalRankingService.mapCategoryToConditionKey(PatientConditionCategory.pediatricEmergency),
        'pediatric_respiratory_distress',
      );
      expect(
        HierarchicalRankingService.mapCategoryToConditionKey(PatientConditionCategory.obstetricEmergency),
        'pregnancy_danger_signs',
      );
      expect(
        HierarchicalRankingService.mapCategoryToConditionKey(PatientConditionCategory.criticalEmergency),
        'major_trauma',
      );
      expect(
        HierarchicalRankingService.mapCategoryToConditionKey(PatientConditionCategory.stableMedicalCase),
        'diabetes_followup',
      );
    });
  });

  group('Hierarchical Deterministic Offline Ranking Tests', () {
    test('Evaluates all 45 authoritative Indore healthcare facilities offline', () {
      final res = HierarchicalRankingService.evaluateHierarchicalRankingOffline(
        conditionKey: 'suspected_heart_attack',
        clinicLatitude: 22.7196,
        clinicLongitude: 75.8577,
        includeSynthetic: false,
      );

      expect(res.totalEvaluatedFacilities, 45);
      expect(res.rankingHierarchy.length, 3);
      expect(res.conditionKey, 'suspected_heart_attack');
      final totalAccounted = res.rankedRecommendations.length + res.excludedFacilities.length;
      expect(totalAccounted, 45, reason: 'All 45 preloaded facilities must be strictly accounted for.');
    });

    test('Priority 1 Hard Gate: Gating prevents missing Cath Lab from outranking tertiary cardiac center', () {
      final res = HierarchicalRankingService.evaluateHierarchicalRankingOffline(
        conditionKey: 'suspected_heart_attack',
        clinicLatitude: 22.7196,
        clinicLongitude: 75.8577,
        includeSynthetic: false,
      );

      expect(res.rankedRecommendations, isNotEmpty);
      final topRanked = res.rankedRecommendations.first;

      // Top ranked facility must be technically eligible with confirmed Cath Lab capability
      expect(topRanked.technicalEvaluation.isEligible, isTrue);
      expect(topRanked.rank, 1);
      expect(topRanked.technicalEvaluation.confirmedCapabilities, contains('CATH LAB / CARDIAC'));
      expect(res.rankedRecommendations.any((f) => f.facilityName.contains('Apollo') || f.facilityName.contains('CARE CHL')), isTrue);

      // Verify that excluded facilities are explicitly tagged with missing essential capabilities
      for (final excluded in res.excludedFacilities) {
        expect(excluded.technicalEvaluation.isEligible, isFalse);
        expect(excluded.technicalEvaluation.missingEssentialCapabilities, isNotEmpty);
      }
    });

    test('Synthetic data toggle properly flags simulated records', () {
      final resWithSynthetic = HierarchicalRankingService.evaluateHierarchicalRankingOffline(
        conditionKey: 'suspected_heart_attack',
        clinicLatitude: 22.7196,
        clinicLongitude: 75.8577,
        includeSynthetic: true,
      );

      expect(resWithSynthetic.isSyntheticDataIncluded, isTrue);
      expect(resWithSynthetic.dataNotice, contains('SIMULATED DATA'));
    });
  });
}
