import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/hospital_capability_profile.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/services/assessment_service.dart';
import 'package:smart_referral/services/condition_specific_ranking_service.dart';
import 'package:smart_referral/services/hospital_matching_service.dart';

void main() {
  const rankingService = ConditionSpecificRankingService();
  const matchingService = ClinicalHospitalMatchingService();
  const assessmentService = RuleBasedAssessmentService();

  // Reference coordinates for Primary Health Center Sector 4
  const clinicLat = 12.9600;
  const clinicLng = 77.5600;

  final basePatient = MockClinicalData.samplePatients.first;

  group('Condition-Specific Hospital Prioritization Engine Tests', () {
    // -------------------------------------------------------------------------
    // TEST 1: Critical Emergency Prioritization
    // Priority 1: Life-saving capability > Priority 2: Immediate availability >
    // Priority 3: Travel time > Priority 4: Required specialty
    // -------------------------------------------------------------------------
    test('1. Critical Emergency: Ranks life-saving capability & immediate availability above distance', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-CRIT-01',
        conditionCategory: PatientConditionCategory.criticalEmergency,
        mainComplaint: 'Anaphylactic shock with severe respiratory arrest and hypotension',
        requiredSpecialty: 'Emergency Medicine',
        systolicBP: 60,
        diastolicBP: 35,
        heartRate: 140,
        oxygenSaturation: 82.0,
      );

      // Hospital A: 12 km away, full emergency resuscitation, immediate ICU bed, 24/7 ED
      final hospitalA = MockClinicalData.sampleHospitals[1].copyWith(
        hospitalId: 'HOSP-A',
        name: 'Apex Trauma & Resuscitation Center',
        latitude: clinicLat + 0.08,
        longitude: clinicLng + 0.08,
        operatingStatus: 'Operational',
        bedAvailability: 15,
        emergencyCare: true,
        icuAvailable: true,
        availability: MockClinicalData.sampleHospitals[1].availability?.copyWith(
          icuBedsAvailable: 4,
          operatingStatus: 'Operational',
        ),
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          lifeSavingEmergency: CapabilityStatus.confirmed,
          icuAvailability: CapabilityStatus.confirmed,
          cardiacCapability: CapabilityStatus.confirmed,
        ),
      );

      // Hospital B: 2 km away, general medicine clinic, no confirmed ICU
      final hospitalB = MockClinicalData.sampleHospitals[2].copyWith(
        hospitalId: 'HOSP-B',
        name: 'Neighborhood Day Care Clinic',
        latitude: clinicLat + 0.01,
        longitude: clinicLng + 0.01,
        operatingStatus: 'Operational',
        bedAvailability: 20,
        emergencyCare: true,
        icuAvailable: false,
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          lifeSavingEmergency: CapabilityStatus.confirmed,
          icuAvailability: CapabilityStatus.unavailable, // Lacks mandatory ICU
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.criticalEmergency,
        patient: patient,
        availableHospitals: [hospitalA, hospitalB],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals.length, 1);
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-A');
      expect(result.rankedEligibleHospitals.first.priority1.satisfied, isTrue);
      expect(result.rankedEligibleHospitals.first.priority2.satisfied, isTrue);

      // Hospital B must be excluded due to missing ICU capability despite being much closer
      expect(result.excludedHospitals.length, 1);
      expect(result.excludedHospitals.first.hospital.hospitalId, 'HOSP-B');
      expect(result.excludedHospitals.first.exclusionReasons.first, contains('ICU'));
    });

    // -------------------------------------------------------------------------
    // TEST 2: Suspected Cardiac Emergency Prioritization
    // Priority 1: Cardiac capability > Priority 2: Emergency & ICU availability >
    // Priority 3: Travel time > Priority 4: Capacity
    // -------------------------------------------------------------------------
    test('2. Suspected Cardiac Emergency: Prioritizes Cath Lab & cardiology capability', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-CARD-02',
        conditionCategory: PatientConditionCategory.suspectedCardiacEmergency,
        mainComplaint: 'Crushing retrosternal chest pain radiating to left jaw',
        requiredSpecialty: 'Cardiology',
      );

      // Hospital Cardiac: Has Cath Lab / Interventional Cardiology, 24/7 ED, ICU
      final cardiacHosp = MockClinicalData.sampleHospitals[0].copyWith(
        hospitalId: 'HOSP-CARD',
        name: 'Heart & Vascular Institute',
        latitude: clinicLat + 0.05,
        longitude: clinicLng + 0.05,
        emergencyCare: true,
        icuAvailable: true,
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          cardiacCapability: CapabilityStatus.confirmed,
          lifeSavingEmergency: CapabilityStatus.confirmed,
          icuAvailability: CapabilityStatus.confirmed,
        ),
      );

      // Hospital Non-Cardiac: Closer, has 50 beds, but no Cath Lab
      final nonCardiacHosp = MockClinicalData.sampleHospitals[1].copyWith(
        hospitalId: 'HOSP-GENERAL',
        name: 'General Community Care',
        latitude: clinicLat + 0.01,
        longitude: clinicLng + 0.01,
        emergencyCare: true,
        icuAvailable: true,
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          cardiacCapability: CapabilityStatus.unavailable, // Lacks Cath Lab
          lifeSavingEmergency: CapabilityStatus.confirmed,
          icuAvailability: CapabilityStatus.confirmed,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.suspectedCardiacEmergency,
        patient: patient,
        availableHospitals: [cardiacHosp, nonCardiacHosp],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals.length, 1);
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-CARD');
      expect(result.rankedEligibleHospitals.first.priority1.name, 'Cardiac capability');
      expect(result.rankedEligibleHospitals.first.priority1.satisfied, isTrue);

      expect(result.excludedHospitals.any((e) => e.hospital.hospitalId == 'HOSP-GENERAL'), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 3: Suspected Stroke Prioritization
    // Priority 1: Stroke/neuro capability > Priority 2: Time to treatment >
    // Priority 3: Availability > Priority 4: Travel time
    // -------------------------------------------------------------------------
    test('3. Suspected Stroke: Stroke/neuro capability checked first, followed by time-to-treatment', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-STROKE-03',
        conditionCategory: PatientConditionCategory.suspectedStroke,
        mainComplaint: 'Acute right-sided hemiplegia, facial droop, slurred speech',
        requiredSpecialty: 'Neurosurgery',
      );

      // Comprehensive Stroke Center: 10 km away, 24/7 CT scanner, neuro-ICU
      final strokeCenter = MockClinicalData.sampleHospitals[0].copyWith(
        hospitalId: 'HOSP-STROKE',
        name: 'Regional Neurosciences & Stroke Center',
        latitude: clinicLat + 0.06,
        longitude: clinicLng + 0.06,
        emergencyCare: true,
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          strokeNeuroCapability: CapabilityStatus.confirmed,
          lifeSavingEmergency: CapabilityStatus.confirmed,
          icuAvailability: CapabilityStatus.confirmed,
        ),
      );

      // General Hospital: 1 km away, but no CT scanner / neuro capability
      final generalHosp = MockClinicalData.sampleHospitals[3].copyWith(
        hospitalId: 'HOSP-NO-CT',
        name: 'Sub-District General Hospital',
        latitude: clinicLat + 0.01,
        longitude: clinicLng + 0.01,
        emergencyCare: true,
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          strokeNeuroCapability: CapabilityStatus.unavailable,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.suspectedStroke,
        patient: patient,
        availableHospitals: [strokeCenter, generalHosp],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals.length, 1);
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-STROKE');
      expect(result.rankedEligibleHospitals.first.priority1.name, 'Stroke/neuro capability');

      expect(result.excludedHospitals.first.hospital.hospitalId, 'HOSP-NO-CT');
      expect(result.excludedHospitals.first.exclusionReasons.first, contains('Stroke / Neuro Care'));
    });

    // -------------------------------------------------------------------------
    // TEST 4: Major Trauma Prioritization
    // Priority 1: Trauma & operative capability > Priority 2: Blood availability & ICU >
    // Priority 3: Travel time > Priority 4: Required specialty
    // -------------------------------------------------------------------------
    test('4. Major Trauma: Trauma operative capability and Blood Bank are mandatory hard filters', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-TRAUMA-04',
        conditionCategory: PatientConditionCategory.majorTrauma,
        mainComplaint: 'Compound open femur fracture with arterial bleed',
        requiredSpecialty: 'Orthopedics & Trauma Surgery',
      );

      // Trauma Center: 24/7 OT, Blood Bank, ICU
      final traumaCenter = MockClinicalData.sampleHospitals[0].copyWith(
        hospitalId: 'HOSP-TRAUMA',
        name: 'Level-1 Tertiary Trauma Center',
        latitude: clinicLat + 0.07,
        longitude: clinicLng + 0.07,
        emergencyCare: true,
        icuAvailable: true,
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          traumaOperativeCapability: CapabilityStatus.confirmed,
          bloodBankAvailability: CapabilityStatus.confirmed,
          lifeSavingEmergency: CapabilityStatus.confirmed,
          icuAvailability: CapabilityStatus.confirmed,
          orthopaedicCapability: CapabilityStatus.confirmed,
        ),
      );

      // Hospital without Blood Bank: Cannot manage massive hemorrhage
      final noBloodHosp = MockClinicalData.sampleHospitals[1].copyWith(
        hospitalId: 'HOSP-NO-BLOOD',
        name: 'Orthopedic Day Center',
        latitude: clinicLat + 0.02,
        longitude: clinicLng + 0.02,
        emergencyCare: true,
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          traumaOperativeCapability: CapabilityStatus.confirmed,
          bloodBankAvailability: CapabilityStatus.unavailable, // Lacks blood bank
          icuAvailability: CapabilityStatus.confirmed,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.majorTrauma,
        patient: patient,
        availableHospitals: [traumaCenter, noBloodHosp],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals.length, 1);
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-TRAUMA');
      expect(result.rankedEligibleHospitals.first.priority1.name, 'Trauma & operative capability');
      expect(result.rankedEligibleHospitals.first.priority2.name, 'Blood availability & ICU capability');

      expect(result.excludedHospitals.any((e) => e.hospital.hospitalId == 'HOSP-NO-BLOOD'), isTrue);
      expect(result.excludedHospitals.first.exclusionReasons.any((r) => r.contains('Blood Bank')), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 5: Obstetric Emergency Prioritization
    // Priority 1: Obstetric emergency capability > Priority 2: Blood bank, OT & ICU >
    // Priority 3: Travel time > Priority 4: Capacity
    // -------------------------------------------------------------------------
    test('5. Obstetric Emergency: Requires C-Section and Blood Bank', () {
      final patient = MockClinicalData.patientPostpartumHemorrhage.copyWith(
        conditionCategory: PatientConditionCategory.obstetricEmergency,
      );

      final obGynHosp = MockClinicalData.sampleHospitals[0].copyWith(
        hospitalId: 'HOSP-OBGYN',
        name: 'Maternal & Child Apex Hospital',
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          obstetricEmergencyCapability: CapabilityStatus.confirmed,
          bloodBankAvailability: CapabilityStatus.confirmed,
          icuAvailability: CapabilityStatus.confirmed,
          operationTheatreAvailability: CapabilityStatus.confirmed,
        ),
      );

      final nonObGynHosp = MockClinicalData.sampleHospitals[3].copyWith(
        hospitalId: 'HOSP-ORTHO-ONLY',
        name: 'Bone & Joint Clinic',
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          obstetricEmergencyCapability: CapabilityStatus.unavailable,
          bloodBankAvailability: CapabilityStatus.confirmed,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.obstetricEmergency,
        patient: patient,
        availableHospitals: [obGynHosp, nonObGynHosp],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals.length, 1);
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-OBGYN');
      expect(result.rankedEligibleHospitals.first.priority1.name, 'Obstetric emergency capability');
      expect(result.excludedHospitals.first.hospital.hospitalId, 'HOSP-ORTHO-ONLY');
    });

    // -------------------------------------------------------------------------
    // TEST 6: Pediatric Emergency Prioritization
    // Priority 1: Pediatric emergency capability > Priority 2: Pediatric ICU >
    // Priority 3: Travel time > Priority 4: Capacity
    // -------------------------------------------------------------------------
    test('6. Pediatric Emergency: Dedicated pediatrics and PICU prioritized', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-PED-06',
        age: 3,
        conditionCategory: PatientConditionCategory.pediatricEmergency,
        mainComplaint: 'Severe respiratory distress with chest indrawing',
        requiredSpecialty: 'Pediatrics',
      );

      final childrenHosp = MockClinicalData.sampleHospitals[0].copyWith(
        hospitalId: 'HOSP-PED',
        name: 'Rainbow Children Hospital',
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          pediatricEmergencyCapability: CapabilityStatus.confirmed,
          pediatricIcuAvailability: CapabilityStatus.confirmed,
          lifeSavingEmergency: CapabilityStatus.confirmed,
        ),
      );

      final adultHosp = MockClinicalData.sampleHospitals[2].copyWith(
        hospitalId: 'HOSP-ADULT',
        name: 'Adult Specialty Center',
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          pediatricEmergencyCapability: CapabilityStatus.unavailable,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.pediatricEmergency,
        patient: patient,
        availableHospitals: [childrenHosp, adultHosp],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals.length, 1);
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-PED');
      expect(result.rankedEligibleHospitals.first.priority1.name, 'Pediatric emergency capability');
      expect(result.rankedEligibleHospitals.first.priority2.name, 'Pediatric ICU availability');
      expect(result.excludedHospitals.first.hospital.hospitalId, 'HOSP-ADULT');
    });

    // -------------------------------------------------------------------------
    // TEST 7: Stable Fracture Prioritization
    // Priority 1: Orthopaedic capability > Priority 2: Overall availability >
    // Priority 3: Travel time > Priority 4: Distance
    // -------------------------------------------------------------------------
    test('7. Stable Fracture: Orthopaedic capability checked first, followed by availability & travel time', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-FRACT-07',
        conditionCategory: PatientConditionCategory.stableFracture,
        mainComplaint: 'Closed non-displaced distal radius fracture',
        requiredSpecialty: 'Orthopedics & Trauma Surgery',
      );

      // Hospital A: Orthopedic capability, 25 beds, 8 km
      final hospA = MockClinicalData.sampleHospitals[1].copyWith(
        hospitalId: 'HOSP-ORTHO',
        name: 'Orthopedic Specialty Center',
        operatingStatus: 'Operational',
        bedAvailability: 25,
        latitude: clinicLat + 0.05,
        longitude: clinicLng + 0.05,
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          orthopaedicCapability: CapabilityStatus.confirmed,
        ),
      );

      // Hospital B: Dermatology clinic, no orthopedics
      final hospB = MockClinicalData.sampleHospitals[3].copyWith(
        hospitalId: 'HOSP-DERM',
        name: 'Skin & Allergy Clinic',
        operatingStatus: 'Operational',
        bedAvailability: 50,
        latitude: clinicLat + 0.01,
        longitude: clinicLng + 0.01,
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          orthopaedicCapability: CapabilityStatus.unavailable,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.stableFracture,
        patient: patient,
        availableHospitals: [hospA, hospB],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals.length, 1);
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-ORTHO');
      expect(result.rankedEligibleHospitals.first.priority1.name, 'Orthopaedic capability');
      expect(result.excludedHospitals.first.hospital.hospitalId, 'HOSP-DERM');
    });

    // -------------------------------------------------------------------------
    // TEST 8: Stable Medical Case Prioritization
    // Priority 1: Required medical specialty > Priority 2: Required diagnostic capability >
    // Priority 3: Overall availability > Priority 4: Travel time
    // -------------------------------------------------------------------------
    test('8. Stable Medical Case: Required specialty & diagnostics take precedence', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-MED-08',
        conditionCategory: PatientConditionCategory.stableMedicalCase,
        mainComplaint: 'Uncontrolled Type 2 Diabetes with routine review',
        requiredSpecialty: 'Endocrinology',
      );

      final hospEndo = MockClinicalData.sampleHospitals[0].copyWith(
        hospitalId: 'HOSP-ENDO',
        name: 'Diabetes & Endocrine Care Center',
        operatingStatus: 'Operational',
        specialties: ['Endocrinology', 'General Medicine'],
        diagnosticFacilities: ['Full Pathology Lab', 'Ultrasound'],
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          lifeSavingEmergency: CapabilityStatus.confirmed,
        ),
      );

      final hospNoEndo = MockClinicalData.sampleHospitals[2].copyWith(
        hospitalId: 'HOSP-NO-ENDO',
        name: 'General Dispensary',
        operatingStatus: 'Operational',
        specialties: ['General Medicine'], // Missing Endocrinology
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.stableMedicalCase,
        patient: patient,
        availableHospitals: [hospEndo, hospNoEndo],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals.length, 1);
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-ENDO');
      expect(result.rankedEligibleHospitals.first.priority1.name, 'Required medical specialty');
      expect(result.rankedEligibleHospitals.first.priority2.name, 'Required diagnostic capability');
      expect(result.excludedHospitals.first.hospital.hospitalId, 'HOSP-NO-ENDO');
    });

    // -------------------------------------------------------------------------
    // TEST 9: Low Travel Time Cannot Compensate for Missing Mandatory Capability
    // -------------------------------------------------------------------------
    test('9. Low travel time or high capacity NEVER compensates for missing mandatory capability', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-STROKE-09',
        conditionCategory: PatientConditionCategory.suspectedStroke,
        mainComplaint: 'Acute stroke symptoms',
        requiredSpecialty: 'Neurosurgery',
      );

      // Hospital 1: Only 500 meters away, 100 free beds, but NO stroke/neuro capability
      final veryCloseHosp = MockClinicalData.sampleHospitals[2].copyWith(
        hospitalId: 'HOSP-CLOSE-NO-NEURO',
        name: 'Local Clinic Next Door',
        latitude: clinicLat + 0.002,
        longitude: clinicLng + 0.002,
        bedAvailability: 100,
        operatingStatus: 'Operational',
        emergencyCare: true,
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          strokeNeuroCapability: CapabilityStatus.unavailable, // MISSING
        ),
      );

      // Hospital 2: 18 km away, 5 beds, but HAS stroke & neuroimaging
      final distantStrokeHosp = MockClinicalData.sampleHospitals[0].copyWith(
        hospitalId: 'HOSP-FAR-STROKE',
        name: 'Far City Stroke Institute',
        latitude: clinicLat + 0.12,
        longitude: clinicLng + 0.12,
        bedAvailability: 5,
        operatingStatus: 'Operational',
        emergencyCare: true,
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          strokeNeuroCapability: CapabilityStatus.confirmed,
          lifeSavingEmergency: CapabilityStatus.confirmed,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.suspectedStroke,
        patient: patient,
        availableHospitals: [veryCloseHosp, distantStrokeHosp],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      // The close hospital must be disqualified completely
      expect(result.excludedHospitals.any((h) => h.hospital.hospitalId == 'HOSP-CLOSE-NO-NEURO'), isTrue);
      // The distant hospital with stroke capability must be ranked #1
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-FAR-STROKE');
    });

    // -------------------------------------------------------------------------
    // TEST 10: Unknown Capability Status Is Not Treated as Confirmed
    // -------------------------------------------------------------------------
    test('10. Unknown capability data is never treated as confirmed available', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-CARD-10',
        conditionCategory: PatientConditionCategory.suspectedCardiacEmergency,
        mainComplaint: 'Severe chest pain, suspected STEMI',
        requiredSpecialty: 'Cardiology',
      );

      // Hospital with Unknown Cath Lab status
      final unverifiedHosp = MockClinicalData.sampleHospitals[1].copyWith(
        hospitalId: 'HOSP-UNVERIFIED',
        name: 'Unverified Regional Hospital',
        operatingStatus: 'Operational',
        emergencyCare: true,
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          cardiacCapability: CapabilityStatus.unknown, // UNKNOWN
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.suspectedCardiacEmergency,
        patient: patient,
        availableHospitals: [unverifiedHosp],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals, isEmpty);
      expect(result.excludedHospitals.length, 1);
      expect(result.excludedHospitals.first.exclusionReasons.first, contains('unknown/unverified'));
    });

    // -------------------------------------------------------------------------
    // TEST 11: Diverting or Closed Operating Status Triggers Immediate Exclusion
    // -------------------------------------------------------------------------
    test('11. Hospital operating status Diverting or Closed triggers immediate exclusion', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-CRIT-11',
        conditionCategory: PatientConditionCategory.criticalEmergency,
        mainComplaint: 'Critical respiratory arrest',
        requiredSpecialty: 'Emergency Medicine',
      );

      final divertingHosp = MockClinicalData.sampleHospitals[0].copyWith(
        hospitalId: 'HOSP-DIVERTING',
        name: 'Apex Hospital (Diverting)',
        operatingStatus: 'Diverting',
        bedAvailability: 0,
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          lifeSavingEmergency: CapabilityStatus.confirmed,
          icuAvailability: CapabilityStatus.confirmed,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.criticalEmergency,
        patient: patient,
        availableHospitals: [divertingHosp],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals, isEmpty);
      expect(result.excludedHospitals.first.exclusionReasons.first, contains('Diverting'));
    });

    // -------------------------------------------------------------------------
    // TEST 12: Ties on Priority 1 Broken by Priority 2, then Travel Time
    // -------------------------------------------------------------------------
    test('12. Priority 1 ties are broken lexicographically by Priority 2, then Travel Time', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-FRACT-12',
        conditionCategory: PatientConditionCategory.stableFracture,
        mainComplaint: 'Closed ankle fracture',
        requiredSpecialty: 'Orthopedics & Trauma Surgery',
      );

      // Hospital X: Ortho confirmed (P1 tie), high bed availability (P2: 40 beds), 8 km
      final hospX = MockClinicalData.sampleHospitals[1].copyWith(
        hospitalId: 'HOSP-X',
        name: 'Hospital X (Ample Beds)',
        latitude: clinicLat + 0.05,
        longitude: clinicLng + 0.05,
        bedAvailability: 40,
        currentCapacity: 0.4,
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          orthopaedicCapability: CapabilityStatus.confirmed,
        ),
      );

      // Hospital Y: Ortho confirmed (P1 tie), low bed availability (P2: 2 beds), 5 km
      final hospY = MockClinicalData.sampleHospitals[0].copyWith(
        hospitalId: 'HOSP-Y',
        name: 'Hospital Y (Few Beds)',
        latitude: clinicLat + 0.03,
        longitude: clinicLng + 0.03,
        bedAvailability: 2,
        currentCapacity: 0.95,
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          orthopaedicCapability: CapabilityStatus.confirmed,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.stableFracture,
        patient: patient,
        availableHospitals: [hospY, hospX],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.rankedEligibleHospitals.length, 2);
      // Hospital X has much higher availability (Priority 2), so it must win over Y
      expect(result.rankedEligibleHospitals.first.hospital.hospitalId, 'HOSP-X');
      expect(result.rankedEligibleHospitals.last.hospital.hospitalId, 'HOSP-Y');
    });

    // -------------------------------------------------------------------------
    // TEST 13: Escalation Notice When No Suitable Hospital Is Found
    // Must contain exact string: 'No suitable hospital could be confirmed from available data.'
    // -------------------------------------------------------------------------
    test('13. No suitable hospital returns exact prompt escalation notice and missing capabilities', () {
      final patient = basePatient.copyWith(
        patientId: 'PT-CRIT-13',
        conditionCategory: PatientConditionCategory.suspectedStroke,
        mainComplaint: 'Severe acute stroke with unresponsiveness',
        requiredSpecialty: 'Neurosurgery',
      );

      // Candidate hospitals that all lack stroke capability
      final hosp1 = MockClinicalData.sampleHospitals[2].copyWith(
        hospitalId: 'HOSP-1',
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          strokeNeuroCapability: CapabilityStatus.unavailable,
        ),
      );
      final hosp2 = MockClinicalData.sampleHospitals[3].copyWith(
        hospitalId: 'HOSP-2',
        operatingStatus: 'Operational',
        capabilityProfile: const HospitalCapabilityProfile.empty().copyWith(
          strokeNeuroCapability: CapabilityStatus.unavailable,
        ),
      );

      final result = rankingService.rankHospitals(
        conditionCategory: PatientConditionCategory.suspectedStroke,
        patient: patient,
        availableHospitals: [hosp1, hosp2],
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
      );

      expect(result.hasSuitableHospital, isFalse);
      expect(result.rankedEligibleHospitals, isEmpty);
      expect(result.escalationProtocol, contains('No suitable hospital could be confirmed from available data.'));
      expect(result.missingCapabilities, isNotEmpty);
      expect(result.missingCapabilities, contains('Stroke Care / CT Neuroimaging'));
    });

    // -------------------------------------------------------------------------
    // TEST 14: Integration with ClinicalHospitalMatchingService
    // -------------------------------------------------------------------------
    test('14. ClinicalHospitalMatchingService correctly integrates ConditionSpecificRankingService', () {
      final patient = MockClinicalData.patientPostpartumHemorrhage.copyWith(
        conditionCategory: PatientConditionCategory.obstetricEmergency,
      );
      final assessment = assessmentService.evaluate(patient);

      final recommendation = matchingService.evaluateRecommendations(
        patient: patient,
        assessment: assessment,
        availableHospitals: MockClinicalData.sampleHospitals,
        clinicLatitude: clinicLat,
        clinicLongitude: clinicLng,
        conditionCategory: PatientConditionCategory.obstetricEmergency,
      );

      expect(recommendation.conditionRecommendation, isNotNull);
      expect(recommendation.conditionRecommendation!.category, PatientConditionCategory.obstetricEmergency);
      expect(recommendation.bestMatch, isNotNull);
      expect(recommendation.bestMatch!.conditionRanking, isNotNull);
      expect(recommendation.bestMatch!.conditionRanking!.priority1.name, 'Obstetric emergency capability');
      expect(recommendation.bestMatch!.conditionRanking!.whyThisHospitalSummary, isNotEmpty);
    });
  });
}
