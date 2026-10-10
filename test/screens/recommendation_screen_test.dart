import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/hospital.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/models/patient.dart';
import 'package:smart_referral/screens/recommendation/recommendation_screen.dart';
import 'package:smart_referral/screens/referral/referral_summary_screen.dart';
import 'package:smart_referral/services/assessment_service.dart';
import 'package:smart_referral/services/hospital_matching_service.dart';
import 'package:smart_referral/widgets/primary_button.dart';
import 'package:smart_referral/widgets/urgency_badge.dart';

void main() {
  const matchingService = ClinicalHospitalMatchingService();
  const assessmentService = RuleBasedAssessmentService();

  late Patient emergencyPatient;
  late AssessmentResult emergencyAssessment;

  setUp(() {
    emergencyPatient = MockClinicalData.patientPostpartumHemorrhage;
    emergencyAssessment = assessmentService.evaluate(emergencyPatient);
  });

  Widget buildTestWidget({
    List<Hospital>? initialHospitals,
    Patient? patient,
    AssessmentResult? assessment,
  }) {
    return MaterialApp(
      home: RecommendationScreen(
        patient: patient ?? emergencyPatient,
        assessment: assessment ?? emergencyAssessment,
        matchingService: matchingService,
        initialHospitals: initialHospitals,
      ),
    );
  }

  group('RecommendationScreen Complete Decision-Support Tests', () {
    testWidgets('1. Displays patient urgency, referral requirement, primary recommendation, alternatives & transit info',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Screen Header
      expect(find.text('Referral Recommendations'), findsOneWidget);

      // Patient urgency & requirement
      expect(find.byType(UrgencyBadge), findsWidgets);
      expect(find.textContaining('PATIENT CLINICAL TRIAGE'), findsOneWidget);
      expect(find.textContaining('Referral Requirement:'), findsOneWidget);
      expect(find.textContaining('Obstetrics & Gynecology'), findsWidgets);

      // Primary Recommendation & Alternatives
      expect(find.text('Primary Recommendation'), findsWidgets);
      expect(find.textContaining('/100'), findsWidgets);

      // Distance and Estimated travel time
      expect(find.textContaining('Distance:'), findsWidgets);
      expect(find.textContaining('Travel Time:'), findsWidgets);
      expect(find.textContaining('km'), findsWidgets);
      expect(find.textContaining('mins'), findsWidgets);

      // Excluded Hospitals
      expect(find.textContaining('Excluded Hospitals'), findsOneWidget);
      expect(find.text('Excluded'), findsWidgets);
    });

    testWidgets('2. "Why this hospital?" card displays all 7 rationales and exact score breakdown',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Card Header
      expect(find.text('Why this hospital?'), findsWidgets);

      // 7 Required Rationales
      expect(find.textContaining('Required specialty available'), findsWidgets);
      expect(find.textContaining('Emergency capability available'), findsWidgets);
      expect(find.textContaining('ICU available'), findsWidgets);
      expect(find.textContaining('Required diagnostics available'), findsWidgets);
      expect(find.textContaining('Treatment capability available'), findsWidgets);
      expect(find.textContaining('Capacity available'), findsWidgets);
      expect(find.textContaining('Travel time acceptable'), findsWidgets);

      // Score Breakdown component categories
      expect(find.text('Specialty Match'), findsWidgets);
      expect(find.text('Medical Capability'), findsWidgets);
      expect(find.text('Emergency/ICU'), findsWidgets);
      expect(find.text('Availability'), findsWidgets);
      expect(find.text('Travel Time'), findsWidgets);
      expect(find.text('Distance'), findsWidgets);
      expect(find.text('TOTAL'), findsWidgets);
    });

    testWidgets('3. Dynamic Fallback: Diverting primary hospital triggers re-ranking, explanation banner & promotes alternative',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
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
      expect(find.textContaining('re-validated and re-ranked'), findsOneWidget);

      // Verify Reset Network button restores state
      final resetFinder = find.text('Reset Network');
      expect(resetFinder, findsOneWidget);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      // Alert banner should be dismissed
      expect(find.text('Dynamic Fallback Activated'), findsNothing);
    });

    testWidgets('4. Selection & Confirmation flow: "Select Hospital" -> "Confirm Referral Destination" -> ReferralSummaryScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find "Select Hospital" button
      final selectButtonFinder = find.widgetWithText(PrimaryButton, 'Select Hospital');
      expect(selectButtonFinder, findsWidgets);

      // Tap "Select Hospital"
      await tester.tap(selectButtonFinder.first);
      await tester.pumpAndSettle();

      // Verify "Confirm Referral Destination" modal sheet is presented
      expect(find.text('Confirm Referral Destination'), findsNWidgets(2));
      expect(find.textContaining('Do not automatically claim hospital acceptance'), findsOneWidget);
      expect(find.text('Cancel / Choose Another'), findsOneWidget);

      // Tap confirmation button inside modal
      final confirmButtonFinder = find.widgetWithText(PrimaryButton, 'Confirm Referral Destination');
      expect(confirmButtonFinder, findsOneWidget);
      await tester.tap(confirmButtonFinder);
      await tester.pumpAndSettle();

      // Verify navigated to ReferralSummaryScreen
      expect(find.byType(ReferralSummaryScreen), findsOneWidget);
      expect(find.text('Referral Summary'), findsOneWidget);
      expect(find.text('RECOMMENDED HOSPITAL'), findsOneWidget);
      expect(find.text('Save Referral'), findsOneWidget);
    });

    testWidgets('5. "View Hospital Details" button opens facility capability profile sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find "View Hospital Details" button
      final detailsButtonFinder = find.text('View Hospital Details');
      expect(detailsButtonFinder, findsWidgets);

      await tester.tap(detailsButtonFinder.first);
      await tester.pumpAndSettle();

      // Verify details sheet is opened
      expect(find.textContaining('Operating & Bed Capacity (Simulated):'), findsOneWidget);
      expect(find.text('Specialties:'), findsOneWidget);
      expect(find.text('Diagnostic Facilities:'), findsOneWidget);
      expect(find.text('Treatment Capabilities:'), findsOneWidget);
      expect(find.text('Close Hospital Details'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Close Hospital Details'));
      await tester.pumpAndSettle();
      expect(find.text('Close Hospital Details'), findsNothing);
    });

    testWidgets('6. When no partner hospitals match, shows explicit no suitable facility message and escalation protocols',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(initialHospitals: []));
      await tester.pumpAndSettle();

      expect(
        find.text('No suitable referral facility found in the current regional network dataset.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Emergency Protocol Recommendation: Follow established local emergency escalation/transfer protocols.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Contact District Health Officer (DHO) or State Emergency Medical Dispatch'),
        findsOneWidget,
      );
    });
  });
}
