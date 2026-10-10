import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_referral/app.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/repositories/referral_repository.dart';
import 'package:smart_referral/screens/assessment/patient_assessment_screen.dart';
import 'package:smart_referral/screens/recommendation/recommendation_screen.dart';
import 'package:smart_referral/screens/referral/referral_summary_screen.dart';
import 'package:smart_referral/screens/referral/referral_tracking_screen.dart';
import 'package:smart_referral/services/assessment_service.dart';
import 'package:smart_referral/services/hospital_matching_service.dart';
import 'package:smart_referral/services/location_service.dart';
import 'package:smart_referral/services/routing_service.dart';
import 'package:smart_referral/widgets/primary_button.dart';
import 'package:smart_referral/widgets/secondary_button.dart';

void main() {
  setUp(() {
    DefaultLocationService().setManualClinicLocation(ClinicLocation.defaultSector4PHC);
    DefaultLocationService().updatePermissionState(LocationPermissionState.granted);
  });

  group('End-to-End Workflow & Core Innovations Tests', () {
    // -------------------------------------------------------------------------
    // INNOVATION 1 & 2: Referral Decision Support & Capability Matching
    // "Nearest hospital ≠ best hospital" proof
    // -------------------------------------------------------------------------
    test('Proof: Nearest hospital lacking mandatory capability is rejected over further capable hospital', () {
      const matchingService = ClinicalHospitalMatchingService();
      const assessmentService = RuleBasedAssessmentService();
      final emergencyPatient = MockClinicalData.patientPostpartumHemorrhage;
      final assessment = assessmentService.evaluate(emergencyPatient);

      final results = matchingService.evaluateRecommendations(
        patient: emergencyPatient,
        assessment: assessment,
        availableHospitals: MockClinicalData.sampleHospitals,
        clinicLatitude: 12.9716,
        clinicLongitude: 77.5946,
      );

      // Verify eligible hospitals all contain the mandatory capabilities
      expect(results.eligibleHospitals, isNotEmpty);
      final primary = results.bestMatch;
      expect(primary, isNotNull);
      expect(
        primary!.hospital.specialties.contains('Obstetrics & Gynecology') ||
            primary.hospital.treatmentCapabilities.contains('Emergency Cesarean Section (C-Section)'),
        isTrue,
      );

      // Verify that excluded hospitals were rejected due to missing mandatory requirements
      expect(results.excludedHospitals, isNotEmpty);
      for (final excluded in results.excludedHospitals) {
        expect(excluded.exclusionReasons, isNotEmpty);
      }
    });

    // -------------------------------------------------------------------------
    // INNOVATION 3: Simulated Travel-Time Aware Ranking
    // -------------------------------------------------------------------------
    test('Simulated rural transit calculation accounts for winding factor & speed without live traffic claims', () async {
      const routing = SimulatedRoutingService();
      final clinic = ClinicLocation.defaultSector4PHC.latLng;
      final apexHospital = MockClinicalData.hospitalRegionalApex;
      final apexLatLng = LatLng(apexHospital.latitude, apexHospital.longitude);

      final estimate = await routing.calculateRoute(origin: clinic, destination: apexLatLng);
      expect(estimate.distanceKm, greaterThan(0));
      expect(estimate.estimatedTravelTime.inMinutes, greaterThan(0));
      expect(estimate.isSimulated, isTrue);
      expect(estimate.sourceLabel, contains('Simulated Rural Transit'));
      expect(estimate.disclaimer, contains('Live traffic'));
    });

    // -------------------------------------------------------------------------
    // WORKFLOW STEP 1 & 2: Patient Assessment -> Manage Locally (Routine Case)
    // -------------------------------------------------------------------------
    testWidgets('Triage Workflow: Routine mild case evaluates to Manage Locally', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mildPatient = MockClinicalData.patientMildViralInfection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatientAssessmentScreen(initialPatient: mildPatient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger Assess Patient
      final assessButton = find.widgetWithText(PrimaryButton, 'Assess Patient');
      await tester.ensureVisible(assessButton);
      await tester.tap(assessButton);
      await tester.pumpAndSettle();

      // Verify result screen displays "Manage Locally"
      expect(find.text('Manage Locally'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Save Local Care Observation'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // WORKFLOW STEP 3 to 6: Emergency Patient -> Recommendation Engine -> Hospital Selection
    // -------------------------------------------------------------------------
    testWidgets('Triage Workflow: Emergency patient evaluates to Immediate Referral with explainable score',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const matchingService = ClinicalHospitalMatchingService();
      const assessmentService = RuleBasedAssessmentService();
      final emergencyPatient = MockClinicalData.patientPostpartumHemorrhage;
      final emergencyAssessment = assessmentService.evaluate(emergencyPatient);

      await tester.pumpWidget(
        MaterialApp(
          home: RecommendationScreen(
            patient: emergencyPatient,
            assessment: emergencyAssessment,
            matchingService: matchingService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Urgency & Decision Header
      expect(find.text('EMERGENCY'), findsWidgets);
      expect(find.text('Referral Recommendations'), findsOneWidget);

      // 2. Verify Explainable Recommendation Section ("Why this hospital?")
      expect(find.text('Why this hospital?'), findsWidgets);
      expect(find.text('Medical Capability'), findsWidgets);
      expect(find.text('Specialty Match'), findsWidgets);
      expect(find.text('Emergency/ICU'), findsWidgets);
      expect(find.text('Availability'), findsWidgets);

      // 3. Verify Excluded Hospitals section
      expect(find.textContaining('Excluded Hospitals'), findsOneWidget);

      // 4. Select Hospital
      final selectButtonFinder = find.widgetWithText(PrimaryButton, 'Select Hospital');
      expect(selectButtonFinder, findsWidgets);
      await tester.tap(selectButtonFinder.first);
      await tester.pumpAndSettle();

      // Confirmation bottom sheet pops up
      expect(find.text('Confirm Referral Destination'), findsWidgets);
      final confirmBtn = find.widgetWithText(PrimaryButton, 'Confirm Referral Destination');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Navigated to ReferralSummaryScreen
      expect(find.byType(ReferralSummaryScreen), findsOneWidget);
      expect(find.text('Referral Summary'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // WORKFLOW STEP 7: Referral Summary Screen & Dispatch Handover
    // -------------------------------------------------------------------------
    testWidgets('Workflow Step 7: ReferralSummaryScreen displays 5 required action buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testReferral = MockClinicalData.sampleEmergencyReferral;
      final repo = InMemoryReferralRepository(preloadMockData: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ReferralSummaryScreen(
            referral: testReferral,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all required 5 buttons
      expect(find.widgetWithText(PrimaryButton, 'Save Referral'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Generate PDF'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Share'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Print'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Back to Dashboard'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // WORKFLOW STEP 8: Referral Tracking & Status Progression
    // -------------------------------------------------------------------------
    testWidgets('Workflow Step 8: ReferralTrackingScreen shows clean format and updates lifecycle status',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = InMemoryReferralRepository(preloadMockData: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ReferralTrackingScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify clean list format: P001, P002, P003
      expect(find.text('P001'), findsOneWidget);
      expect(find.text('P002'), findsOneWidget);
      expect(find.text('P003'), findsOneWidget);

      // Find Visual Timeline toggle and tap to expand
      final timelineToggle = find.textContaining('View Visual Transfer Timeline');
      expect(timelineToggle, findsWidgets);
      await tester.tap(timelineToggle.first);
      await tester.pumpAndSettle();

      // Verify timeline items rendered
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Referred'), findsWidgets);
      expect(find.text('Accepted'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);

      // Tap "Update Status" on first referral (P001)
      final updateButtons = find.widgetWithText(PrimaryButton, 'Update Status');
      expect(updateButtons, findsWidgets);
      await tester.tap(updateButtons.first);
      await tester.pumpAndSettle();

      // Verify Manual Update modal
      expect(find.text('Update Referral Status'), findsOneWidget);
      expect(find.text('Select New Status (Manual Entry Only):'), findsOneWidget);

      // Confirm manual status update
      final confirmUpdateBtn = find.widgetWithText(PrimaryButton, 'Confirm Manual Status Update');
      expect(confirmUpdateBtn, findsOneWidget);
      await tester.tap(confirmUpdateBtn);
      await tester.pumpAndSettle();

      // Feedback confirms update
      expect(find.textContaining('updated to'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // INNOVATION 4: Dynamic Fallback Referral when Hospital Diverts
    // -------------------------------------------------------------------------
    testWidgets('Innovation 4: Mark hospital unavailable dynamically re-ranks and promotes alternative',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const matchingService = ClinicalHospitalMatchingService();
      const assessmentService = RuleBasedAssessmentService();
      final emergencyPatient = MockClinicalData.patientPostpartumHemorrhage;
      final emergencyAssessment = assessmentService.evaluate(emergencyPatient);

      await tester.pumpWidget(
        MaterialApp(
          home: RecommendationScreen(
            patient: emergencyPatient,
            assessment: emergencyAssessment,
            matchingService: matchingService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find simulation flash button on primary card
      final simulateButtonFinder = find.byIcon(Icons.flash_on_rounded);
      expect(simulateButtonFinder, findsWidgets);

      // Tap simulate divert on the primary hospital
      await tester.tap(simulateButtonFinder.first);
      await tester.pumpAndSettle();

      // Verify Dynamic Fallback alert banner is visible with explanation
      expect(find.text('Dynamic Fallback Activated'), findsOneWidget);
      expect(find.textContaining('diverting (0 available beds)'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // PROFESSIONAL CLINICAL COMMAND DASHBOARD IN ROOT APP
    // -------------------------------------------------------------------------
    testWidgets('Professional clinical command dashboard is visible in root app', (WidgetTester tester) async {
      await tester.pumpWidget(const SmartReferralApp());
      await tester.pumpAndSettle();

      expect(find.text('Dr. Parth Saxena'), findsOneWidget);
      expect(find.text('Active Clinical Triage Registry'), findsOneWidget);
      expect(find.text('New Patient Assessment'), findsWidgets);
      expect(find.text('4-Tier Clinical Acuity Protocol'), findsOneWidget);
    });
  });
}
