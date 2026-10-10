import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/app.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/screens/assessment/assessment_result_screen.dart';
import 'package:smart_referral/screens/recommendation/recommendation_screen.dart';
import 'package:smart_referral/screens/referral/referral_summary_screen.dart';
import 'package:smart_referral/services/assessment_service.dart';

void main() {
  testWidgets('Tapping back button on ReferralTrackingScreen at root safely redirects to Dashboard without crashing',
      (tester) async {
    await tester.pumpWidget(const SmartReferralApp());
    await tester.pumpAndSettle();

    // 1. Go to Referrals tab
    await tester.tap(find.text('Referrals'));
    await tester.pumpAndSettle();

    // 2. Find and tap back button
    final backBtn = find.byTooltip('Back to Dashboard');
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // 3. Verify app did NOT crash into an empty tree, and is on Dashboard
    expect(find.byType(SmartReferralApp), findsOneWidget);
    expect(find.text('MEDICO'), findsWidgets);
  });

  testWidgets('Tapping back button on ReferralSummaryScreen pops cleanly', (tester) async {
    final testReferral = MockClinicalData.sampleEmergencyReferral;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (ctx) => ReferralSummaryScreen(referral: testReferral),
                  ),
                );
              },
              child: const Text('Open Summary'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Summary'));
    await tester.pumpAndSettle();

    expect(find.text('Referral Summary'), findsOneWidget);

    final backBtn = find.byTooltip('Back');
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    expect(find.text('Open Summary'), findsOneWidget);
  });

  testWidgets('Tapping back button on RecommendationScreen pops cleanly', (tester) async {
    final patient = MockClinicalData.patientCompoundFracture;
    const service = RuleBasedAssessmentService();
    final assessment = service.evaluate(patient);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (ctx) => RecommendationScreen(
                      patient: patient,
                      assessment: assessment,
                    ),
                  ),
                );
              },
              child: const Text('Open Recommendation'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Recommendation'));
    await tester.pumpAndSettle();

    expect(find.text('Referral Recommendations'), findsOneWidget);

    final backBtn = find.byTooltip('Return to Assessment Result');
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    expect(find.text('Open Recommendation'), findsOneWidget);
  });

  testWidgets('Tapping back button on AssessmentResultScreen pops cleanly', (tester) async {
    final patient = MockClinicalData.patientCompoundFracture;
    const service = RuleBasedAssessmentService();
    final assessment = service.evaluate(patient);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (ctx) => AssessmentResultScreen(
                      patient: patient,
                      assessment: assessment,
                    ),
                  ),
                );
              },
              child: const Text('Open Result'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Result'));
    await tester.pumpAndSettle();

    expect(find.text('Assessment Result'), findsOneWidget);

    final backBtn = find.byTooltip('Return to entered information');
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    expect(find.text('Open Result'), findsOneWidget);
  });
}
