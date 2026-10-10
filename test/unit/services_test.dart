import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/repositories/hospital_repository.dart';
import 'package:smart_referral/repositories/patient_repository.dart';
import 'package:smart_referral/repositories/referral_repository.dart';
import 'package:smart_referral/services/assessment_service.dart';
import 'package:smart_referral/services/distance_service.dart';
import 'package:smart_referral/services/hospital_matching_service.dart';
import 'package:smart_referral/services/referral_service.dart';

void main() {
  group('DistanceService Unit Tests', () {
    const distanceService = HaversineDistanceService();

    test('Same coordinates result in zero distance and travel time', () {
      final distance = distanceService.calculateDistanceKm(12.9716, 77.5946, 12.9716, 77.5946);
      expect(distance, 0.0);

      final travelTime = distanceService.estimateTravelTime(distance);
      expect(travelTime, Duration.zero);
    });

    test('Known distance between Bangalore Center and Kempegowda Airport (~28-30 km straight)', () {
      // Lat/Lon: Majestic (12.9767, 77.5713) to Airport (13.1986, 77.7066)
      final distance = distanceService.calculateDistanceKm(12.9767, 77.5713, 13.1986, 77.7066);

      // Straight line is ~28-30 km
      expect(distance, greaterThan(25.0));
      expect(distance, lessThan(35.0));

      // With rural road circuity factor 1.25x and 40 km/h:
      // ~30 * 1.25 = 37.5 km / 40 km/h = ~56 mins
      final travelTime = distanceService.estimateTravelTime(distance);
      expect(travelTime.inMinutes, greaterThan(40));
      expect(travelTime.inMinutes, lessThan(80));
    });
  });

  group('AssessmentService Unit Tests', () {
    const assessmentService = RuleBasedAssessmentService();

    test('Emergency obstetric triage: Postpartum hemorrhage triggers immediate referral', () {
      final patient = MockClinicalData.patientPostpartumHemorrhage;
      final result = assessmentService.evaluate(patient);

      expect(result.urgencyLevel, UrgencyLevel.emergency);
      expect(result.recommendedAction, RecommendedAction.immediateReferral);
      expect(result.requiredSpecialty, 'Obstetrics & Gynecology');
      expect(result.requiredFacilities, contains('24/7 Blood Bank'));
      expect(result.isRedFlag, isTrue);
      expect(result.dangerSignsDetected, isNotEmpty);
    });

    test('Emergency pediatric hypoxia triggers emergency referral', () {
      final patient = MockClinicalData.patientPediatricPneumonia;
      final result = assessmentService.evaluate(patient);

      expect(result.urgencyLevel, UrgencyLevel.emergency);
      expect(result.recommendedAction, RecommendedAction.immediateReferral);
      expect(result.requiredSpecialty, 'Pediatrics');
      expect(result.isRedFlag, isTrue);
      expect(
        result.dangerSignsDetected.any((d) => d.contains('SpO2') || d.contains('Hypoxia')),
        isTrue,
      );
    });

    test('Trauma fracture triggers urgent referral to Orthopedics', () {
      final patient = MockClinicalData.patientCompoundFracture;
      final result = assessmentService.evaluate(patient);

      expect(result.urgencyLevel, UrgencyLevel.urgent);
      expect(result.recommendedAction, RecommendedAction.referralRecommended);
      expect(result.requiredSpecialty, 'Orthopedics & Trauma Surgery');
      expect(result.requiredFacilities, contains('Digital X-Ray'));
    });

    test('Mild cold symptoms result in routine local management', () {
      final patient = MockClinicalData.patientMildViralInfection;
      final result = assessmentService.evaluate(patient);

      expect(result.urgencyLevel, UrgencyLevel.routine);
      expect(result.recommendedAction, RecommendedAction.manageLocally);
      expect(result.isRedFlag, isFalse);
    });
  });

  group('HospitalMatchingService Unit Tests', () {
    const matchingService = ClinicalHospitalMatchingService();
    const assessmentService = RuleBasedAssessmentService();

    test('Maternal emergency matches hospital with OB/GYN, blood bank, and ICU highest', () {
      final patient = MockClinicalData.patientPostpartumHemorrhage;
      final assessment = assessmentService.evaluate(patient);
      final hospitals = MockClinicalData.sampleHospitals;

      // Primary Health Center coordinates: 12.9600, 77.5600
      final matches = matchingService.matchHospitals(
        patient: patient,
        assessment: assessment,
        availableHospitals: hospitals,
        clinicLatitude: 12.9600,
        clinicLongitude: 77.5600,
      );

      expect(matches, isNotEmpty);
      // Scores should be sorted descending
      for (int i = 0; i < matches.length - 1; i++) {
        expect(matches[i].matchScore, greaterThanOrEqualTo(matches[i + 1].matchScore));
      }

      // Top match should have obstetrics and available beds
      final topMatch = matches.first;
      expect(topMatch.hasRequiredSpecialty, isTrue);
      expect(topMatch.hasAvailableBeds, isTrue);
      expect(topMatch.matchScore, greaterThan(70.0));
    });
  });

  group('ReferralService Unit Tests', () {
    test('generateReferral creates and persists a complete referral', () async {
      final patientRepo = InMemoryPatientRepository(preloadMockData: false);
      final hospitalRepo = InMemoryHospitalRepository(preloadMockData: true);
      final referralRepo = InMemoryReferralRepository(preloadMockData: false);

      final referralService = DefaultReferralService(
        assessmentService: const RuleBasedAssessmentService(),
        matchingService: const ClinicalHospitalMatchingService(),
        hospitalRepository: hospitalRepo,
        referralRepository: referralRepo,
        patientRepository: patientRepo,
      );

      final patient = MockClinicalData.patientAcuteCoronary;

      final referral = await referralService.generateReferral(
        patient: patient,
        referringClinic: 'North Rural Primary Health Center',
        clinicLatitude: 12.9500,
        clinicLongitude: 77.5500,
      );

      expect(referral.referralId, startsWith('REF-'));
      expect(referral.patient.patientId, patient.patientId);
      expect(referral.urgencyLevel, UrgencyLevel.urgent);
      expect(referral.status, ReferralStatus.pending);
      expect(referral.recommendedHospital, isNotNull);
      expect(referral.statusHistory.length, 1);

      // Verify persistence in repos
      final storedPatient = await patientRepo.getPatientById(patient.patientId);
      expect(storedPatient, isNotNull);

      final storedReferral = await referralRepo.getReferralById(referral.referralId);
      expect(storedReferral, isNotNull);
    });

    test('updateReferralStatus updates status and appends history', () async {
      final referralRepo = InMemoryReferralRepository(preloadMockData: true);
      final referralService = DefaultReferralService(
        assessmentService: const RuleBasedAssessmentService(),
        matchingService: const ClinicalHospitalMatchingService(),
        hospitalRepository: InMemoryHospitalRepository(),
        referralRepository: referralRepo,
        patientRepository: InMemoryPatientRepository(),
      );

      final sampleId = MockClinicalData.sampleEmergencyReferral.referralId;

      final updated = await referralService.updateReferralStatus(
        referralId: sampleId,
        newStatus: ReferralStatus.completed,
        note: 'Patient received and stabilized at district ICU.',
      );

      expect(updated.status, ReferralStatus.completed);
      expect(updated.statusHistory.last.note, 'Patient received and stabilized at district ICU.');
    });
  });
}
