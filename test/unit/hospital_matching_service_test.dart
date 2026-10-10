import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/hospital.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/services/assessment_service.dart';
import 'package:smart_referral/services/hospital_matching_service.dart';

void main() {
  const matchingService = ClinicalHospitalMatchingService();
  const assessmentService = RuleBasedAssessmentService();

  // Reference rural clinic coordinates (Primary Health Center)
  const clinicLat = 22.8100;
  const clinicLon = 75.9200;

  group('Hospital Recommendation Engine Unit Tests', () {
    test('1. Perfect match: High capability, close distance, and ample beds yield top score', () {
      final patient = MockClinicalData.patientPostpartumHemorrhage;
      final assessment = assessmentService.evaluate(patient);
      final hospitals = MockClinicalData.sampleHospitals;

      final result = matchingService.evaluateRecommendations(
        patient: patient,
        assessment: assessment,
        availableHospitals: hospitals,
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLon,
      );

      expect(result.hasMatches, isTrue);
      expect(result.bestMatch, isNotNull);

      final best = result.bestMatch!;
      // St. Jude Maternal & Child or Apex should rank top for obstetric emergency
      expect(best.hasRequiredSpecialty, isTrue);
      expect(best.hasEmergencyCapability, isTrue);
      expect(best.hasIcu, isTrue);
      expect(best.hasAvailableBeds, isTrue);
      expect(best.matchScore, greaterThan(80.0));

      // Verify Score Breakdown has all 6 components
      final breakdown = best.scoreBreakdown;
      expect(breakdown.medicalCapabilityScore, greaterThan(25.0)); // out of 35
      expect(breakdown.specialtyMatchScore, equals(20.0));        // 100% of 20
      expect(breakdown.emergencyIcuScore, equals(15.0));          // 100% of 15
      expect(breakdown.availabilityScore, greaterThan(5.0));       // out of 15
      expect(breakdown.travelTimeScore, greaterThan(5.0));        // out of 10
      expect(breakdown.distanceScore, greaterThan(2.0));          // out of 5
      expect(breakdown.totalScore, equals(best.matchScore));

      // Check alternatives exist
      expect(result.alternatives, isNotEmpty);
      expect(result.alternatives.length, inInclusiveRange(1, 2));
      expect(best.matchScore, greaterThanOrEqualTo(result.alternatives.first.matchScore));
    });

    test('2. Partial match: Eligible hospital with incomplete facilities scores lower than full match', () {
      final patient = MockClinicalData.patientCompoundFracture;
      final assessment = assessmentService.evaluate(patient);

      // Hospital A: Full trauma, CT, blood bank, fracture fixation (Metro Trauma)
      final fullMatchHospital = MockClinicalData.hospitalMetroTrauma;

      // Hospital B: Has Orthopedics and general facilities, but fewer advanced capabilities and farther
      final partialHospital = Hospital(
        hospitalId: 'HOSP-PARTIAL-01',
        name: 'Peripheral Sub-District Orthopedic Unit',
        address: 'Sector 55, Outer Rural Ring',
        latitude: 13.2500, // ~35 km away
        longitude: 77.7500,
        specialties: const ['Orthopedics & Trauma Surgery', 'General Medicine'],
        emergencyCare: true,
        icuAvailable: false,
        diagnosticFacilities: const ['Digital X-Ray'],
        treatmentCapabilities: const ['Orthopedic Fracture Fixation'],
        currentCapacity: 0.70,
        bedAvailability: 8,
        operatingStatus: 'Operational',
        availabilityLastUpdated: DateTime.now(),
      );

      final result = matchingService.evaluateRecommendations(
        patient: patient,
        assessment: assessment,
        availableHospitals: [fullMatchHospital, partialHospital],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLon,
      );

      expect(result.eligibleHospitals.length, equals(2));
      expect(result.bestMatch!.hospital.hospitalId, equals(fullMatchHospital.hospitalId));

      final partialMatch = result.eligibleHospitals.firstWhere(
        (h) => h.hospital.hospitalId == 'HOSP-PARTIAL-01',
      );

      // Partial hospital matches specialty but lacks advanced CT/blood bank facilities and ICU
      expect(partialMatch.hasRequiredSpecialty, isTrue);
      expect(partialMatch.matchScore, lessThan(result.bestMatch!.matchScore));
      expect(partialMatch.scoreBreakdown.medicalCapabilityScore,
          lessThan(result.bestMatch!.scoreBreakdown.medicalCapabilityScore));
    });

    test('3. Missing mandatory capability: Hard filter immediately excludes hospital regardless of score', () {
      final patient = MockClinicalData.patientPostpartumHemorrhage; // Needs Obstetrics & Gynecology + Emergency
      final assessment = assessmentService.evaluate(patient);

      // A cardiology hospital with 100 available beds, 2km away, but NO OB/GYN specialty
      final nearCardioHospital = Hospital(
        hospitalId: 'HOSP-CARDIO-NEAR',
        name: 'Nearby Premier Heart Institute',
        address: 'Main Road 1km',
        latitude: 12.9620,
        longitude: 77.5620, // 0.3 km away
        specialties: const ['Cardiology', 'Cardiothoracic Surgery'],
        emergencyCare: true,
        icuAvailable: true,
        diagnosticFacilities: const ['Cath Lab', 'Full Pathology Lab', '128-Slice CT Scanner'],
        treatmentCapabilities: const ['ICU Mechanical Ventilation', 'PCI'],
        currentCapacity: 0.20,
        bedAvailability: 120,
        operatingStatus: 'Operational',
        availabilityLastUpdated: DateTime.now(),
      );

      final result = matchingService.evaluateRecommendations(
        patient: patient,
        assessment: assessment,
        availableHospitals: [nearCardioHospital],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLon,
      );

      // Hard filter must exclude this hospital completely
      expect(result.eligibleHospitals, isEmpty);
      expect(result.bestMatch, isNull);
      expect(result.excludedHospitals, hasLength(1));

      final excluded = result.excludedHospitals.first;
      expect(excluded.hospital.hospitalId, equals('HOSP-CARDIO-NEAR'));
      expect(
        excluded.exclusionReasons,
        contains('Excluded because missing required specialty: Obstetrics & Gynecology.'),
      );
    });

    test('4. Unavailable hospital: Diverting status or zero beds triggers immediate exclusion', () {
      final patient = MockClinicalData.patientPostpartumHemorrhage;
      final assessment = assessmentService.evaluate(patient);

      // Hospital with matching specialty but Diverting status and 0 beds (Sunrise Hospital)
      final divertingHospital = MockClinicalData.hospitalSunriseDiverting;

      final zeroBedsHospital = Hospital(
        hospitalId: 'HOSP-FULL-01',
        name: 'District Full Maternity Hospital',
        address: 'Civil Lines Road',
        latitude: 12.9800,
        longitude: 77.5800,
        specialties: const ['Obstetrics & Gynecology'],
        emergencyCare: true,
        icuAvailable: true,
        diagnosticFacilities: const ['Ultrasound', 'Blood Bank'],
        treatmentCapabilities: const ['Emergency Cesarean Section (C-Section)'],
        currentCapacity: 1.0,
        bedAvailability: 0, // No beds
        operatingStatus: 'Operational',
        availabilityLastUpdated: DateTime.now(),
      );

      final result = matchingService.evaluateRecommendations(
        patient: patient,
        assessment: assessment,
        availableHospitals: [divertingHospital, zeroBedsHospital],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLon,
      );

      expect(result.eligibleHospitals, isEmpty);
      expect(result.excludedHospitals, hasLength(2));

      final reasonsDiverting = result.excludedHospitals
          .firstWhere((h) => h.hospital.hospitalId == divertingHospital.hospitalId)
          .exclusionReasons;
      expect(reasonsDiverting, contains('Excluded because hospital operating status is Diverting.'));

      final reasonsZeroBeds = result.excludedHospitals
          .firstWhere((h) => h.hospital.hospitalId == zeroBedsHospital.hospitalId)
          .exclusionReasons;
      expect(reasonsZeroBeds, contains('Excluded because zero beds are currently available.'));
    });

    test('5. Tie scores: Deterministic tie-breaking ranks by travel time, then beds, then distance', () {
      final patient = MockClinicalData.patientMildViralInfection;
      final assessment = assessmentService.evaluate(patient);

      // Two hospitals with identical clinical capabilities, beds, and capacity,
      // but Hospital A is closer (10 mins) and Hospital B is farther (40 mins).
      final hospitalA = Hospital(
        hospitalId: 'HOSP-TIE-A',
        name: 'Alpha General Hospital',
        address: 'Zone 1',
        latitude: 22.8200, // ~1.5 km from clinic (22.8100, 75.9200)
        longitude: 75.9250,
        specialties: const ['General Medicine'],
        emergencyCare: true,
        icuAvailable: false,
        diagnosticFacilities: const ['Basic Clinical Lab'],
        treatmentCapabilities: const ['IV Rehydration'],
        currentCapacity: 0.50,
        bedAvailability: 20,
        operatingStatus: 'Operational',
        availabilityLastUpdated: DateTime.now(),
      );

      final hospitalB = Hospital(
        hospitalId: 'HOSP-TIE-B',
        name: 'Beta General Hospital',
        address: 'Zone 4',
        latitude: 23.0100, // ~24 km from clinic
        longitude: 76.0200,
        specialties: const ['General Medicine'],
        emergencyCare: true,
        icuAvailable: false,
        diagnosticFacilities: const ['Basic Clinical Lab'],
        treatmentCapabilities: const ['IV Rehydration'],
        currentCapacity: 0.50,
        bedAvailability: 20,
        operatingStatus: 'Operational',
        availabilityLastUpdated: DateTime.now(),
      );

      final result = matchingService.evaluateRecommendations(
        patient: patient,
        assessment: assessment,
        availableHospitals: [hospitalB, hospitalA], // Passed in reverse order
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLon,
      );

      expect(result.eligibleHospitals.length, equals(2));
      // Closer hospital with lower travel time must rank first
      expect(result.eligibleHospitals.first.hospital.hospitalId, equals('HOSP-TIE-A'));
      expect(result.eligibleHospitals.last.hospital.hospitalId, equals('HOSP-TIE-B'));
    });

    test('6. No suitable hospital: When all facilities fail mandatory criteria, bestMatch is null', () {
      final patient = MockClinicalData.patientAcuteCoronary; // Needs Cardiology / Cath lab / Emergency
      final assessment = assessmentService.evaluate(patient);

      // Only candidate is a rural clinic with no cardiology and closed ED
      final ruralClinic = MockClinicalData.hospitalGreenValley;

      final result = matchingService.evaluateRecommendations(
        patient: patient,
        assessment: assessment,
        availableHospitals: [ruralClinic],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLon,
      );

      expect(result.hasMatches, isFalse);
      expect(result.bestMatch, isNull);
      expect(result.alternatives, isEmpty);
      expect(result.eligibleHospitals, isEmpty);
      expect(result.excludedHospitals, hasLength(1));

      final excluded = result.excludedHospitals.first;
      expect(excluded.hospital.hospitalId, equals(ruralClinic.hospitalId));
      expect(excluded.exclusionReasons.length, greaterThanOrEqualTo(1));
    });
  });
}
