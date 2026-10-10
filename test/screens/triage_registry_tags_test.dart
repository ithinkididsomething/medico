import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/navigation/app_navigation.dart';
import 'package:smart_referral/repositories/referral_repository.dart';
import 'package:smart_referral/screens/referral/referral_tracking_screen.dart';

void main() {
  late LocalReferralRepository testRepo;

  setUp(() {
    testRepo = LocalReferralRepository(usePersistentPrefs: false);
  });

  group('Active Clinical Triage Registry Squares Tag Navigation Tests', () {
    Widget buildApp() {
      return const MaterialApp(
        home: MainNavigationScreen(initialIndex: 0),
      );
    }

    testWidgets(
      '1. Tapping Emergency square opens Referrals page with Emergency tag active',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Verify on Dashboard
        expect(find.text('Active Clinical Triage Registry'), findsOneWidget);

        // Find the Emergency StatCard and tap it
        final emergencyCard = find.widgetWithText(InkWell, 'Emergency');
        expect(emergencyCard, findsOneWidget);
        await tester.tap(emergencyCard);
        await tester.pumpAndSettle();

        // Verify we navigated to Referral Tracking
        expect(find.text('Referral Tracking'), findsOneWidget);

        // Verify Emergency filter tag is active
        expect(find.textContaining('Filtered by: Emergency'), findsOneWidget);

        // Emergency patient P001 should be present, but routine P003 should NOT be present
        expect(find.text('P001'), findsOneWidget);
        expect(find.text('P003'), findsNothing);
      },
    );

    testWidgets(
      '2. Tapping In Transit square opens Referrals page with In Transit tag active',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Find the In Transit StatCard and tap it
        final inTransitCard = find.widgetWithText(InkWell, 'In Transit');
        expect(inTransitCard, findsOneWidget);
        await tester.tap(inTransitCard);
        await tester.pumpAndSettle();

        // Verify on Referral Tracking with In Transit filter tag
        expect(find.text('Referral Tracking'), findsOneWidget);
        expect(find.textContaining('Filtered by: In Transit'), findsOneWidget);

        // REF-SIM-901 (PAT-SIM-104) has status transferred (in-transit), whereas P001 is pending and P003 is completed
        expect(find.text('PAT-SIM-104'), findsOneWidget);
        expect(find.text('P001'), findsNothing);
        expect(find.text('P003'), findsNothing);
      },
    );

    testWidgets(
      '3. Tapping Completed square opens Referrals page with Completed tag active',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Find the Completed StatCard and tap it
        final completedCard = find.widgetWithText(InkWell, 'Completed');
        expect(completedCard, findsOneWidget);
        await tester.tap(completedCard);
        await tester.pumpAndSettle();

        // Verify on Referral Tracking with Completed filter tag
        expect(find.text('Referral Tracking'), findsOneWidget);
        expect(find.textContaining('Filtered by: Completed'), findsOneWidget);

        // P003 is completed, whereas P001 is pending and P002 is referred
        expect(find.text('P003'), findsOneWidget);
        expect(find.text('P001'), findsNothing);
        expect(find.text('P002'), findsNothing);
      },
    );

    testWidgets(
      '4. Tapping Total Referrals square opens Referrals page with all cases',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Find the Total Referrals StatCard and tap it
        final totalCard = find.widgetWithText(InkWell, 'Total Referrals');
        expect(totalCard, findsOneWidget);
        await tester.tap(totalCard);
        await tester.pumpAndSettle();

        // Verify on Referral Tracking showing all cases without single-tag banner
        expect(find.text('Referral Tracking'), findsOneWidget);
        expect(find.textContaining('Filtered by:'), findsNothing);

        // All patient cases are visible
        expect(find.text('P001'), findsOneWidget);
        expect(find.text('P002'), findsOneWidget);
        expect(find.text('P003'), findsOneWidget);
      },
    );

    testWidgets(
      '5. ReferralTrackingScreen directly supports switching between filter tags',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: ReferralTrackingScreen(
              repository: testRepo,
              initialFilterTag: ReferralFilterTag.emergency,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially filtered by Emergency
        expect(find.textContaining('Filtered by: Emergency'), findsOneWidget);
        expect(find.text('P001'), findsOneWidget);
        expect(find.text('P003'), findsNothing);

        // Tap "Show All" on the filter banner
        final showAllButton = find.text('Show All');
        expect(showAllButton, findsOneWidget);
        await tester.tap(showAllButton);
        await tester.pumpAndSettle();

        // Now banner is gone and P003 is visible
        expect(find.textContaining('Filtered by:'), findsNothing);
        expect(find.text('P003'), findsOneWidget);
      },
    );
  });
}
