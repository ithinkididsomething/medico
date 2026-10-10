import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/hospital_availability.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/repositories/hospital_repository.dart';
import 'package:smart_referral/repositories/patient_repository.dart';
import 'package:smart_referral/repositories/referral_repository.dart';

void main() {
  group('PatientRepository Unit Tests', () {
    test('CRUD operations on InMemoryPatientRepository', () async {
      final repo = InMemoryPatientRepository(preloadMockData: false);

      expect(await repo.getAllPatients(), isEmpty);

      final patient = MockClinicalData.patientPostpartumHemorrhage;
      await repo.savePatient(patient);

      final retrieved = await repo.getPatientById(patient.patientId);
      expect(retrieved, isNotNull);
      expect(retrieved!.patientId, patient.patientId);

      final all = await repo.getAllPatients();
      expect(all.length, 1);

      final deleted = await repo.deletePatient(patient.patientId);
      expect(deleted, isTrue);
      expect(await repo.getPatientById(patient.patientId), isNull);
    });
  });

  group('HospitalRepository Unit Tests', () {
    test('Filter by specialty and update hospital availability', () async {
      final repo = InMemoryHospitalRepository(preloadMockData: true);

      final all = await repo.getAllHospitals();
      expect(all.length, greaterThanOrEqualTo(4));

      final obgynHospitals = await repo.getHospitalsBySpecialty('Obstetrics');
      expect(obgynHospitals, isNotEmpty);
      for (final h in obgynHospitals) {
        expect(h.hasSpecialty('Obstetrics'), isTrue);
      }

      // Update availability
      final hospitalId = MockClinicalData.hospitalTalukCommunity.hospitalId;
      final newAvailability = HospitalAvailability(
        hospitalId: hospitalId,
        icuBedsAvailable: 1,
        generalBedsAvailable: 8,
        emergencyDepartmentOpen: true,
        operatingTheatersAvailable: 1,
        currentCapacity: 0.60,
        operatingStatus: 'Operational',
        availabilityLastUpdated: DateTime.now(),
        isSimulated: true,
      );

      await repo.updateHospitalAvailability(hospitalId, newAvailability);
      final updated = await repo.getHospitalById(hospitalId);

      expect(updated?.bedAvailability, 9);
      expect(updated?.icuAvailable, isTrue);
    });
  });

  group('ReferralRepository Unit Tests', () {
    test('Save, query by status, and updateStatus', () async {
      final repo = InMemoryReferralRepository(preloadMockData: false);

      final sample = MockClinicalData.sampleEmergencyReferral;
      await repo.saveReferral(sample);

      final retrieved = await repo.getReferralById(sample.referralId);
      expect(retrieved, isNotNull);

      final pending = await repo.getReferralsByStatus(ReferralStatus.pending);
      expect(pending, isEmpty); // Sample has status: transferred

      final transferred = await repo.getReferralsByStatus(ReferralStatus.transferred);
      expect(transferred.length, 1);

      final updated = await repo.updateStatus(
        sample.referralId,
        ReferralStatus.completed,
        'Admission completed.',
      );

      expect(updated?.status, ReferralStatus.completed);
      expect(updated?.statusHistory.last.note, 'Admission completed.');
    });
  });
}
