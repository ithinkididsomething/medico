import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/hospital_availability.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/models/patient.dart';
import 'package:smart_referral/models/referral.dart';

void main() {
  group('Enums Unit Tests', () {
    test('Sex enum displayName and fromString', () {
      expect(Sex.male.displayName, 'Male');
      expect(Sex.female.displayName, 'Female');
      expect(Sex.other.displayName, 'Other');
      expect(Sex.fromString('FEMALE'), Sex.female);
      expect(Sex.fromString('unknown'), Sex.other);
    });

    test('UrgencyLevel helpers and fromString', () {
      expect(UrgencyLevel.emergency.isEmergency, isTrue);
      expect(UrgencyLevel.urgent.isUrgent, isTrue);
      expect(UrgencyLevel.routine.isRoutine, isTrue);
      expect(UrgencyLevel.fromString('urgent'), UrgencyLevel.urgent);
      expect(UrgencyLevel.fromString('invalid'), UrgencyLevel.routine);
    });

    test('RecommendedAction helpers', () {
      expect(RecommendedAction.manageLocally.requiresTransfer, isFalse);
      expect(RecommendedAction.referralRecommended.requiresTransfer, isTrue);
      expect(RecommendedAction.immediateReferral.requiresTransfer, isTrue);
    });

    test('ReferralStatus lifecycle and helpers', () {
      expect(ReferralStatus.pending.isActive, isTrue);
      expect(ReferralStatus.transferred.isActive, isTrue);
      expect(ReferralStatus.completed.isActive, isFalse);
      expect(ReferralStatus.fromString('transferred'), ReferralStatus.transferred);
    });
  });

  group('Patient Model Unit Tests', () {
    test('Patient creation, formattedBloodPressure and abnormal vitals detection', () {
      final patient = Patient(
        patientId: 'P001',
        age: 30,
        sex: Sex.female,
        mainComplaint: 'Acute headache',
        symptoms: const ['Severe headache', 'Blurred vision'],
        injuryOrIllnessDetails: 'Started 2 hours ago',
        clinicalFindings: 'Pupils equal and reactive',
        heartRate: 110,
        systolicBP: 170,
        diastolicBP: 105,
        respiratoryRate: 20,
        oxygenSaturation: 97.0,
        temperature: 37.0,
        requiredSpecialty: 'General Medicine',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(patient.formattedBloodPressure, '170/105 mmHg');
      expect(patient.hasAbnormalVitals, isTrue); // Due to SBP 170 / DBP 105
    });

    test('Patient serialization round-trip', () {
      final sample = MockClinicalData.patientPostpartumHemorrhage;
      final map = sample.toMap();
      final reconstructed = Patient.fromMap(map);

      expect(reconstructed.patientId, sample.patientId);
      expect(reconstructed.age, sample.age);
      expect(reconstructed.sex, sample.sex);
      expect(reconstructed.heartRate, sample.heartRate);
      expect(reconstructed.systolicBP, sample.systolicBP);
      expect(reconstructed.diastolicBP, sample.diastolicBP);
    });
  });

  group('Hospital & HospitalAvailability Unit Tests', () {
    test('Hospital hasSpecialty and hasFacility', () {
      final hospital = MockClinicalData.hospitalDistrictGeneral;

      expect(hospital.hasSpecialty('Obstetrics'), isTrue);
      expect(hospital.hasSpecialty('Neurosurgery'), isFalse);
      expect(hospital.hasFacility('Blood Bank'), isTrue);
      expect(hospital.hasFacility('CT Scanner'), isTrue);
      expect(hospital.hasFacility('3T MRI'), isFalse);
    });

    test('HospitalAvailability simulated flag and capacity update', () {
      final availability = HospitalAvailability(
        hospitalId: 'HOSP-SIM-001',
        icuBedsAvailable: 2,
        generalBedsAvailable: 10,
        emergencyDepartmentOpen: true,
        operatingTheatersAvailable: 1,
        currentCapacity: 0.65,
        operatingStatus: 'Operational',
        availabilityLastUpdated: DateTime.now(),
        isSimulated: true,
        dataSource: 'SYNTHETIC_SIMULATED_FEED',
      );

      expect(availability.isSimulated, isTrue);
      expect(availability.totalBedsAvailable, 12);
      expect(availability.hasIcuBed, isTrue);

      final hospital = MockClinicalData.hospitalTalukCommunity;
      final updatedHospital = hospital.withAvailability(availability);

      expect(updatedHospital.bedAvailability, 12);
      expect(updatedHospital.icuAvailable, isTrue);
      expect(updatedHospital.currentCapacity, 0.65);
    });
  });

  group('Referral Model Unit Tests', () {
    test('Referral status transition and audit history append', () {
      final referral = MockClinicalData.sampleEmergencyReferral;
      final initialHistoryLength = referral.statusHistory.length;

      final updated = referral.withNewStatus(
        ReferralStatus.completed,
        note: 'Patient successfully admitted into district ICU.',
      );

      expect(updated.status, ReferralStatus.completed);
      expect(updated.statusHistory.length, initialHistoryLength + 1);
      expect(updated.statusHistory.last.note, 'Patient successfully admitted into district ICU.');
    });

    test('Referral serialization round-trip', () {
      final sample = MockClinicalData.sampleEmergencyReferral;
      final map = sample.toMap();
      final reconstructed = Referral.fromMap(map);

      expect(reconstructed.referralId, sample.referralId);
      expect(reconstructed.urgencyLevel, sample.urgencyLevel);
      expect(reconstructed.status, sample.status);
      expect(reconstructed.recommendedHospital?.name, sample.recommendedHospital?.name);
      expect(reconstructed.statusHistory.length, sample.statusHistory.length);
    });
  });

  group('Synthetic Mock Dataset Verification', () {
    test('All mock data contains explicit simulated markings', () {
      expect(MockClinicalData.datasetDisclaimer, contains('SYNTHETIC / SIMULATED'));
      for (final hospital in MockClinicalData.sampleHospitals) {
        expect(hospital.hospitalId, anyOf(startsWith('HOSP-SIM-'), startsWith('indore_')));
        expect(hospital.availability?.isSimulated, isTrue);
      }
      for (final patient in MockClinicalData.samplePatients) {
        expect(patient.patientId, startsWith('PAT-SIM-'));
      }
    });
  });
}
