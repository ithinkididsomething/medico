import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_referral/models/doctor_profile_data.dart';
import 'package:smart_referral/models/user_profile.dart';
import 'package:smart_referral/services/auth_service.dart';
import 'package:smart_referral/services/doctor_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DoctorProfileData Model Tests', () {
    test('Default profile creates complete doctor profile with realistic placeholders', () {
      final defaultDoc = DoctorProfileData.defaultProfile();

      expect(defaultDoc.fullName, equals('Dr. Parth Saxena'));
      expect(defaultDoc.qualifications, contains('MBBS, MD'));
      expect(defaultDoc.specialization, contains('General Medicine'));
      expect(defaultDoc.medicalRegNumber, equals('MP-MED-2018-09428'));
      expect(defaultDoc.councilName, contains('Madhya Pradesh Medical Council'));
      expect(defaultDoc.clinicOrHospital, contains('Primary Health Centre Sector 4'));
      expect(defaultDoc.email, equals('dr.parth.saxena@gmail.com'));
      expect(defaultDoc.phoneNumber, equals('+91 98765 43210'));
      expect(defaultDoc.verificationStatus, equals('Verified Practitioner'));
      expect(defaultDoc.additionalCertifications.length, greaterThanOrEqualTo(3));
    });

    test('Default profile dynamically links with active session user', () {
      final sessionUser = UserProfile(
        id: 'doc_custom_99',
        fullName: 'Dr. Ananya Sharma',
        email: 'ananya.sharma@health.gov.in',
        phoneNumber: '+91 91234 56789',
        role: UserRole.doctor,
        medicalRegNumber: 'MP-MED-2020-5512',
        hospitalAffiliation: 'Community Health Centre Mhow',
        isVerified: true,
        verificationStatus: 'Council Verified Specialist',
        createdAt: DateTime.now(),
      );

      final doc = DoctorProfileData.defaultProfile(sessionUser: sessionUser);

      expect(doc.id, equals('doc_custom_99'));
      expect(doc.fullName, equals('Dr. Ananya Sharma'));
      expect(doc.email, equals('ananya.sharma@health.gov.in'));
      expect(doc.phoneNumber, equals('+91 91234 56789'));
      expect(doc.medicalRegNumber, equals('MP-MED-2020-5512'));
      expect(doc.clinicOrHospital, equals('Community Health Centre Mhow'));
      expect(doc.verificationStatus, equals('Council Verified Specialist'));
    });

    test('Serialization and deserialization preserve all doctor attributes', () {
      final original = DoctorProfileData.defaultProfile();
      final jsonStr = original.toJson();
      final recovered = DoctorProfileData.fromJson(jsonStr);

      expect(recovered.id, equals(original.id));
      expect(recovered.fullName, equals(original.fullName));
      expect(recovered.qualifications, equals(original.qualifications));
      expect(recovered.specialization, equals(original.specialization));
      expect(recovered.medicalRegNumber, equals(original.medicalRegNumber));
      expect(recovered.councilName, equals(original.councilName));
      expect(recovered.clinicOrHospital, equals(original.clinicOrHospital));
      expect(recovered.email, equals(original.email));
      expect(recovered.phoneNumber, equals(original.phoneNumber));
      expect(recovered.designation, equals(original.designation));
      expect(recovered.department, equals(original.department));
      expect(recovered.experienceYears, equals(original.experienceYears));
    });

    test('copyWith updates specified fields while keeping other fields intact', () {
      final original = DoctorProfileData.defaultProfile();
      final updated = original.copyWith(
        fullName: 'Dr. Parth S. Saxena',
        qualifications: 'MBBS, MD, DM (Cardiology)',
        specialization: 'Interventional Cardiology',
      );

      expect(updated.fullName, equals('Dr. Parth S. Saxena'));
      expect(updated.qualifications, equals('MBBS, MD, DM (Cardiology)'));
      expect(updated.specialization, equals('Interventional Cardiology'));
      expect(updated.medicalRegNumber, equals(original.medicalRegNumber));
      expect(updated.email, equals(original.email));
    });
  });

  group('DoctorProfileService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with default doctor profile and updates notify listeners', () async {
      final authService = LocalDemoAuthService.instance;
      final service = DoctorProfileService(authService: authService);
      await service.loadProfile();

      expect(service.currentProfile.fullName, isNotEmpty);
      expect(service.isLoaded, isTrue);

      bool listenerNotified = false;
      service.addListener(() {
        listenerNotified = true;
      });

      final modified = service.currentProfile.copyWith(
        fullName: 'Dr. Vikramaditya Joshi',
        specialization: 'Emergency Medicine',
      );

      await service.updateProfile(modified);

      expect(listenerNotified, isTrue);
      expect(service.currentProfile.fullName, equals('Dr. Vikramaditya Joshi'));
      expect(service.currentProfile.specialization, equals('Emergency Medicine'));
    });

    test('Persists doctor profile changes to offline storage and syncs active login session', () async {
      final authService = LocalDemoAuthService.instance;
      final service = DoctorProfileService(authService: authService);

      final modified = service.currentProfile.copyWith(
        fullName: 'Dr. Rajeshwari Sen',
        email: 'dr.rajeshwari@indore.in',
        phoneNumber: '+91 99887 76655',
        clinicOrHospital: 'District Hospital Indore',
      );

      await service.updateProfile(modified);

      // Verify offline reload from SharedPreferences
      final freshLoaded = await service.loadProfile();
      expect(freshLoaded.fullName, equals('Dr. Rajeshwari Sen'));
      expect(freshLoaded.email, equals('dr.rajeshwari@indore.in'));
      expect(freshLoaded.clinicOrHospital, equals('District Hospital Indore'));

      // Verify active session was updated if currentUser exists
      if (authService.currentUser != null) {
        expect(authService.currentUser!.fullName, equals('Dr. Rajeshwari Sen'));
        expect(authService.currentUser!.email, equals('dr.rajeshwari@indore.in'));
      }
    });
  });
}
