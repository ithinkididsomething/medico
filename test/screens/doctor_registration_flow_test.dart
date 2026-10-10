import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_referral/models/doctor_registration.dart';
import 'package:smart_referral/screens/auth/doctor_registration_screen.dart';
import 'package:smart_referral/screens/auth/doctor_verification_status_screen.dart';
import 'package:smart_referral/screens/auth/login_screen.dart';
import 'package:smart_referral/services/auth_service.dart';
import 'package:smart_referral/services/doctor_registration_service.dart';
import 'package:smart_referral/services/sync/central_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDemoAuthService authService;
  late DoctorRegistrationService doctorService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authService = LocalDemoAuthService();
    doctorService = DoctorRegistrationService(
      apiClient: CentralApiClient(baseUrl: 'http://localhost:8000'),
      authService: authService,
    );
  });

  group('Doctor Registration & Login Integration Widget Tests', () {
    testWidgets('1. Login screen renders prominent "Register as a Doctor" button and navigates to DoctorRegistrationScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Register as a Doctor button is visible
      final regDoctorButton = find.text('Register as a Doctor');
      expect(regDoctorButton, findsOneWidget);

      // Verify badge icon is displayed
      expect(find.byIcon(Icons.badge_outlined), findsWidgets);

      // Tap the button
      await tester.tap(regDoctorButton);
      await tester.pumpAndSettle();

      // Verify DoctorRegistrationScreen is presented
      expect(find.text('Doctor Credential Registration'), findsOneWidget);
      expect(find.text('1. Personal & Contact Information'), findsOneWidget);
      expect(find.text('Already have an account? Log in'), findsOneWidget);
    });

    testWidgets('2. DoctorRegistrationScreen back button and "Already have an account? Log in" returns to Login',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register as a Doctor'));
      await tester.pumpAndSettle();

      expect(find.text('Doctor Credential Registration'), findsOneWidget);

      // Tap 'Already have an account? Log in'
      await tester.tap(find.text('Already have an account? Log in'));
      await tester.pumpAndSettle();

      // Returned back to Login Screen
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Registered Medical Email or Mobile'), findsOneWidget);
    });

    testWidgets('3. Step 1 Personal Info Form validation enforces name, mobile, and step progression',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorRegistrationScreen(service: doctorService),
        ),
      );
      await tester.pumpAndSettle();

      // Attempt to proceed without entering name and mobile
      final nextButton = find.text('Next: Step 2');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Validation errors must appear
      expect(find.text('Full legal name is required.'), findsOneWidget);
      expect(find.text('Enter valid 10-digit mobile number.'), findsOneWidget);

      // Enter valid name, phone and email
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Dr. Rajesh Patel');
      await tester.enterText(textFields.at(2), '9876543210');
      await tester.enterText(textFields.at(3), 'dr.rajesh@clinic.org');
      await tester.pumpAndSettle();

      // Next step progresses to Step 2
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
      expect(find.text('2. Medical Qualifications'), findsOneWidget);
    });

    testWidgets('4. Mobile OTP verification dialog simulates clinical regulatory verification',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorRegistrationScreen(service: doctorService),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Dr. Rajesh Patel');
      await tester.enterText(textFields.at(2), '9876543210');
      await tester.pumpAndSettle();

      // Tap 'Verify OTP' button
      final verifyOtpBtn = find.text('Verify OTP');
      expect(verifyOtpBtn, findsOneWidget);
      await tester.tap(verifyOtpBtn);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Verify Mobile Number'), findsOneWidget);
      expect(find.textContaining('Enter 6-digit verification code sent to'), findsOneWidget);

      // Enter OTP '123456'
      final otpField = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText?.contains('123456') == true),
      );
      expect(otpField, findsOneWidget);
      await tester.enterText(otpField, '123456');
      await tester.pumpAndSettle();

      // Find the dialog verify button (the elevated button inside dialog)
      final dialogVerifyBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Verify OTP'),
      );
      await tester.tap(dialogVerifyBtn);
      await tester.pumpAndSettle();

      // Verify OTP dialog closed and badge is now 'Verified'
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('5. Draft save and resume restores form data from local storage',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Pre-save draft in mock SharedPreferences
      final sampleDraft = DoctorRegistrationModel(
        fullName: 'Dr. Sunita Mehta',
        displayName: 'Dr. S. Mehta',
        phoneNumber: '9811223344',
        email: 'dr.sunita@hospital.in',
        isPhoneVerified: true,
        primaryQualificationType: 'postgraduate_md_ms_dnb',
        primaryQualificationName: 'MS General Surgery',
        awardingInstitution: 'Grant Medical College, Mumbai',
        completionYear: 2015,
        primarySpecialty: 'General Surgery',
        medicalRegNumber: 'MMC-2015-8899',
        councilName: 'Maharashtra Medical Council',
        registrationYear: 2015,
        primaryPracticeEnvironment: 'district_hospital',
        totalExperienceYears: 11,
        annualPatientVolume: 2400,
      );
      await doctorService.saveDraft(sampleDraft);

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorRegistrationScreen(service: doctorService),
        ),
      );
      await tester.pumpAndSettle();

      // Resume Saved Draft dialog should appear
      expect(find.text('Resume Saved Draft?'), findsOneWidget);
      expect(find.text('Resume Application'), findsOneWidget);

      // Tap Resume Application
      await tester.tap(find.text('Resume Application'));
      await tester.pumpAndSettle();

      // Form values are restored
      expect(find.text('Dr. Sunita Mehta'), findsOneWidget);
      expect(find.text('dr.sunita@hospital.in'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });
  });

  group('Doctor Capability Score & Verification Status Tests', () {
    test('6. Normalized 4-Pillar capability score scores clinic doctors fairly against hospital doctors', () {
      // Independent clinic doctor with high community workload
      final clinicModel = DoctorRegistrationModel(
        fullName: 'Dr. Vikram Rao',
        phoneNumber: '9822334455',
        email: 'dr.vikram@clinic.org',
        medicalRegNumber: 'KMC-12345',
        councilName: 'Karnataka Medical Council',
        primaryQualificationType: 'primary_mbbs',
        primaryQualificationName: 'MBBS',
        primarySpecialty: 'General Practice',
        primaryPracticeEnvironment: 'independent_clinic',
        totalExperienceYears: 12, // 12 * 1.5 = 18.0 (capped at 30)
        annualPatientVolume: 2200, // >= 2000 target for clinic = 25.0 full score
        associationMemberships: ['Indian Medical Association'], // 5 pts
        governmentSchemesSummary: 'Ayushman Bharat Arogya Mandir Doctor', // 5 pts
      );

      final clinicScore = clinicModel.calculateCapabilityScore();
      expect(clinicScore.baseExpertiseScore, 15.0); // Primary MBBS = 15.0
      expect(clinicScore.clinicalExperienceScore, 18.0);
      expect(clinicScore.clinicalVolumeScore, 25.0); // Full community clinic volume score!
      expect(clinicScore.professionalStandingScore, 10.0);
      expect(clinicScore.totalCapabilityScore, 68.0);
      expect(clinicScore.isProvisional, isTrue);

      // Hospital specialist
      final specialistModel = DoctorRegistrationModel(
        fullName: 'Dr. Priya Desai',
        phoneNumber: '9899887766',
        email: 'dr.priya@cardio.in',
        medicalRegNumber: 'MMC-65432',
        councilName: 'Maharashtra Medical Council',
        primaryQualificationType: 'super_specialty_dm_mch',
        primaryQualificationName: 'DM Cardiology',
        primarySpecialty: 'Cardiology',
        primaryPracticeEnvironment: 'tertiary_hospital',
        totalExperienceYears: 8,
        annualPatientVolume: 3500,
        associationMemberships: ['Cardiological Society of India', 'Indian Medical Association'],
        governmentSchemesSummary: 'PM-JAY Empaneled Specialist',
      );

      final specScore = specialistModel.calculateCapabilityScore();
      expect(specScore.baseExpertiseScore, 30.0); // Super-specialty = 30.0
      expect(specScore.clinicalExperienceScore, 12.0); // 8 * 1.5 = 12.0
      expect(specScore.clinicalVolumeScore, 25.0);
      expect(specScore.professionalStandingScore, 15.0); // 5 + 5 + 5 = 15.0
      expect(specScore.totalCapabilityScore, 82.0);
    });

    testWidgets('7. DoctorVerificationStatusScreen displays Pending status and 4-pillar breakdown',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final pendingDoctor = DoctorRegistrationModel(
        doctorId: 'doc_test_101',
        fullName: 'Dr. Ramesh Chandra',
        phoneNumber: '9800000001',
        email: 'dr.ramesh@test.org',
        primaryQualificationName: 'MD Medicine',
        primarySpecialty: 'Internal Medicine',
        councilName: 'Madhya Pradesh Medical Council',
        medicalRegNumber: 'MPMC-10293',
        verificationStatus: 'pending',
        capabilityScore: const DoctorCapabilityScore(
          baseExpertiseScore: 25.0,
          clinicalExperienceScore: 15.0,
          clinicalVolumeScore: 20.0,
          professionalStandingScore: 10.0,
          totalCapabilityScore: 70.0,
          isProvisional: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorVerificationStatusScreen(doctor: pendingDoctor),
        ),
      );
      await tester.pumpAndSettle();

      // Verify status heading
      expect(find.text('Pending Regulatory Council Verification'), findsOneWidget);
      expect(find.text('Dr. Ramesh Chandra'), findsOneWidget);
      expect(find.text('MPMC-10293'), findsOneWidget);

      // Verify 4-Pillar Score section
      expect(find.text('4-Pillar Fair Normalized Capability Score'), findsOneWidget);
      expect(find.text('PROVISIONAL SCORE'), findsOneWidget);
      expect(find.text('1. Base Medical Expertise'), findsOneWidget);
      expect(find.text('2. Clinical Experience'), findsOneWidget);
      expect(find.text('3. Clinical Volume & Impact'), findsOneWidget);
      expect(find.text('4. Professional Standing'), findsOneWidget);

      // Total score displayed
      expect(find.text('70.0 / 100'), findsOneWidget);
    });

    testWidgets('8. DoctorVerificationStatusScreen displays Verified status when officially approved',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final verifiedDoctor = DoctorRegistrationModel(
        doctorId: 'doc_test_102',
        fullName: 'Dr. Anita Roy',
        phoneNumber: '9800000002',
        email: 'dr.anita@test.org',
        primaryQualificationName: 'MD Pediatrics',
        primarySpecialty: 'Pediatrics',
        councilName: 'West Bengal Medical Council',
        medicalRegNumber: 'WBMC-44556',
        verificationStatus: 'verified',
        capabilityScore: const DoctorCapabilityScore(
          baseExpertiseScore: 25.0,
          clinicalExperienceScore: 18.0,
          clinicalVolumeScore: 25.0,
          professionalStandingScore: 15.0,
          totalCapabilityScore: 83.0,
          isProvisional: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorVerificationStatusScreen(doctor: verifiedDoctor),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Officially Verified Medical Practitioner'), findsOneWidget);
      expect(find.text('VERIFIED SCORE'), findsOneWidget);
      expect(find.text('83.0 / 100'), findsOneWidget);
      expect(find.text('Enter Doctor Clinical Dashboard'), findsOneWidget);
    });

    testWidgets('9. DoctorVerificationStatusScreen displays Rejected status with reviewer notes and Resubmit action',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final rejectedDoctor = DoctorRegistrationModel(
        doctorId: 'doc_test_103',
        fullName: 'Dr. Naveen Kumar',
        phoneNumber: '9800000003',
        email: 'dr.naveen@test.org',
        primaryQualificationName: 'MD Anesthesiology',
        primarySpecialty: 'Anesthesiology',
        councilName: 'Delhi Medical Council',
        medicalRegNumber: 'DMC-99881',
        verificationStatus: 'rejected',
        rejectionReason: 'Council certificate scan is unreadable. Please re-upload high-resolution PDF.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorVerificationStatusScreen(doctor: rejectedDoctor),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Application Requires Additional Verification'), findsOneWidget);
      expect(find.textContaining('Council certificate scan is unreadable'), findsOneWidget);
      expect(find.text('Update Credentials & Resubmit'), findsOneWidget);
    });
  });
}
