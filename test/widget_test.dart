import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/app.dart';
import 'package:smart_referral/core/constants/app_constants.dart';
import 'package:smart_referral/widgets/primary_button.dart';

void main() {
  group('SMART Referral Foundation Tests', () {
    testWidgets('App renders dashboard and command hub on launch',
        (WidgetTester tester) async {
      await tester.pumpWidget(const SmartReferralApp());
      await tester.pumpAndSettle();

      // Check app title and doctor hub
      expect(find.text(AppConstants.appName), findsWidgets);
      expect(find.text('Dr. Parth Saxena'), findsOneWidget);
      expect(
        find.text('New Patient Assessment'),
        findsWidgets,
      );

      // Check all 5 bottom navigation labels are present
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Assessment'), findsWidgets);
      expect(find.text('Referrals'), findsWidgets);
      expect(find.text('Hospitals'), findsWidgets);
      expect(find.text('More'), findsWidgets);
    });

    testWidgets('Navigating through all bottom bar tabs switches screens cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const SmartReferralApp());
      await tester.pumpAndSettle();

      // 1. Assessment Tab
      await tester.tap(find.text('Assessment'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('SECTION 1 — Patient Information'),
        findsOneWidget,
      );

      // 2. Referrals Tab
      await tester.tap(find.text('Referrals'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Referral Tracking'),
        findsOneWidget,
      );

      // 3. Hospitals Tab
      await tester.tap(find.text('Hospitals'));
      await tester.pumpAndSettle();
      expect(
        find.text('List View'),
        findsOneWidget,
      );

      // 4. More Tab
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Clinic Location & GPS Settings'),
        findsOneWidget,
      );

      // 5. Back to Dashboard Tab
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('MEDICO'),
        findsWidgets,
      );
    });

    testWidgets('Buttons trigger callbacks and show interactive feedback',
        (WidgetTester tester) async {
      await tester.pumpWidget(const SmartReferralApp());
      await tester.pumpAndSettle();

      // Tap New Patient Assessment button from Dashboard
      final newAssessmentButton = find.widgetWithText(PrimaryButton, 'New Patient Assessment');
      expect(newAssessmentButton, findsOneWidget);
      await tester.ensureVisible(newAssessmentButton);
      await tester.pumpAndSettle();
      await tester.tap(newAssessmentButton);
      await tester.pumpAndSettle();

      // Verify that navigation switched to Assessment screen
      expect(
        find.textContaining('SECTION 1 — Patient Information'),
        findsOneWidget,
      );

      // Verify Assess Patient button is present on the assessment screen
      expect(find.widgetWithText(PrimaryButton, 'Assess Patient'), findsOneWidget);
    });

    testWidgets('Tablet layout displays NavigationRail', (WidgetTester tester) async {
      // Set tablet screen size (width 800 x height 1200)
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SmartReferralApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });
}
