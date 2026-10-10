import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/hospital.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/models/patient.dart';
import 'package:smart_referral/screens/recommendations/hospital_recommendations_screen.dart';
import 'package:smart_referral/services/assessment_service.dart';
import 'package:smart_referral/services/hospital_matching_service.dart';

void main() {
  const matchingService = ClinicalHospitalMatchingService();
  const assessmentService = RuleBasedAssessmentService();

  late Patient testEmergencyPatient;
  late AssessmentResult assessmentResult;
  late HospitalRecommendationResult recommendationResult;

  setUp(() {
    testEmergencyPatient = MockClinicalData.patientPostpartumHemorrhage;
    assessmentResult = assessmentService.evaluate(testEmergencyPatient);
    recommendationResult = matchingService.evaluateRecommendations(
      patient: testEmergencyPatient,
      assessment: assessmentResult,
      availableHospitals: MockClinicalData.sampleHospitals,
      clinicLatitude: 12.9600,
      clinicLongitude: 77.5600,
    );
  });

  Widget buildTestWidget({
    List<Hospital>? hospitals,
    Patient? patient,
    AssessmentResult? assessment,
  }) {
    return MaterialApp(
      home: HospitalRecommendationsScreen(
        patient: patient ?? testEmergencyPatient,
        assessment: assessment ?? assessmentResult,
        matchingService: matchingService,
        hospitals: hospitals ?? MockClinicalData.sampleHospitals,
      ),
    );
  }

  group('HospitalRecommendationsScreen Widget Tests', () {
    testWidgets('Renders screen header, best match, alternatives and disclaimers', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify Screen Title
      expect(find.text('Hospital Recommendations'), findsOneWidget);

      // Verify Best Match section & Badge
      expect(find.text('BEST MATCH'), findsWidgets);
      expect(find.text(recommendationResult.bestMatch!.hospital.name), findsOneWidget);
      expect(find.textContaining('/100'), findsWidgets);

      // Verify 6 Capability checkmarks are rendered on Best Match
      expect(find.textContaining('Required Specialty'), findsWidgets);
      expect(find.textContaining('24/7 Emergency Care'), findsWidgets);
      expect(find.textContaining('Intensive Care Unit (ICU)'), findsWidgets);
      expect(find.textContaining('Required Diagnostics'), findsWidgets);
      expect(find.textContaining('Treatment Capability'), findsWidgets);
      expect(find.textContaining('Simulated Availability'), findsWidgets);

      // Verify Transit metrics
      expect(find.textContaining('km'), findsWidgets);
      expect(find.textContaining('mins'), findsWidgets);

      // Verify Alternatives section
      if (recommendationResult.alternatives.isNotEmpty) {
        expect(find.textContaining('Alternative'), findsWidgets);
      }

      // Verify Excluded Facilities section
      expect(find.textContaining('Excluded Facilities'), findsOneWidget);
    });

    testWidgets('Tapping score breakdown expands detailed weighted metrics', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find the Score Breakdown toggle
      final expansionFinder = find.text('View Score Breakdown');
      expect(expansionFinder, findsWidgets);

      // Scroll to it and tap
      await tester.ensureVisible(expansionFinder.first);
      await tester.tap(expansionFinder.first);
      await tester.pumpAndSettle();

      // Verify toggle changed to Hide Score Breakdown
      expect(find.text('Hide Score Breakdown'), findsWidgets);

      // Verify individual score component breakdowns are visible
      expect(find.text('Medical Capability (35%)'), findsWidgets);
      expect(find.text('Specialty Match (20%)'), findsWidgets);
      expect(find.text('Emergency / ICU (15%)'), findsWidgets);
      expect(find.text('Availability (15%)'), findsWidgets);
      expect(find.text('Travel Time (10%)'), findsWidgets);
      expect(find.text('Distance (5%)'), findsWidgets);
      expect(find.text('Total Suitability Score'), findsWidgets);
    });

    testWidgets('Displays excluded facilities and explicit clinical exclusion reasons', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Scroll down to the Excluded Facilities section
      final excludedHeaderFinder = find.textContaining('Excluded Facilities');
      await tester.ensureVisible(excludedHeaderFinder);
      await tester.pumpAndSettle();

      expect(excludedHeaderFinder, findsOneWidget);

      // Check that at least one exclusion reason is visible
      expect(find.textContaining('Excluded because'), findsWidgets);
      expect(find.text('Excluded'), findsWidgets);
    });

    testWidgets('Renders empty state message when no hospitals match requirements', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(hospitals: []));
      await tester.pumpAndSettle();

      expect(find.text('No Suitable Partner Hospitals Found'), findsOneWidget);
      expect(
        find.textContaining('All evaluated facilities in the simulated network were disqualified'),
        findsOneWidget,
      );
    });
  });
}
