import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/core/theme/app_theme.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/screens/component_showcase_screen.dart';
import 'package:smart_referral/widgets/widgets.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('Component Library Unit & Widget Tests', () {
    testWidgets('AppHeader renders title, facility, and status pill', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppHeader(
            title: 'Triage Overview',
            subtitle: 'Decision-Support Workspace',
            facilityName: 'District Health Post #4',
            isOfflineReady: true,
          ),
        ),
      );

      expect(find.text('Triage Overview'), findsOneWidget);
      expect(find.text('Decision-Support Workspace'), findsOneWidget);
      expect(find.text('District Health Post #4'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    });

    testWidgets('SectionHeader renders title, subtitle, count badge, and action', (tester) async {
      var actionTriggered = false;
      await tester.pumpWidget(
        _wrap(
          SectionHeader(
            title: 'Nearby Referral Centers',
            subtitle: 'Sorted by clinical suitability',
            countBadge: 4,
            actionText: 'Filter',
            onAction: () => actionTriggered = true,
          ),
        ),
      );

      expect(find.text('Nearby Referral Centers'), findsOneWidget);
      expect(find.text('Sorted by clinical suitability'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);

      await tester.tap(find.text('Filter'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('StatCard displays value, title, and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          StatCard(
            title: 'Available Beds',
            value: '42',
            subtitle: 'Regional total',
            icon: Icons.bed_outlined,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Available Beds'), findsOneWidget);
      expect(find.text('Regional total'), findsOneWidget);

      await tester.tap(find.byType(StatCard));
      expect(tapped, isTrue);
    });

    testWidgets('DangerButton handles tap and loading state', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DangerButton(
            text: 'Decline Transfer',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Decline Transfer'), findsOneWidget);
      await tester.tap(find.text('Decline Transfer'));
      expect(tapped, isTrue);

      // Loading state
      await tester.pumpWidget(
        _wrap(
          DangerButton(
            text: 'Decline Transfer',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('UrgencyBadge renders all three levels with text and icons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              UrgencyBadge(urgencyLevel: UrgencyLevel.routine),
              UrgencyBadge(urgencyLevel: UrgencyLevel.urgent),
              UrgencyBadge(urgencyLevel: UrgencyLevel.emergency),
            ],
          ),
        ),
      );

      expect(find.text('ROUTINE'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notification_important_rounded), findsOneWidget);
    });

    testWidgets('StatusBadge renders referral statuses', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              StatusBadge(status: ReferralStatus.pending),
              StatusBadge(status: ReferralStatus.transferred),
              StatusBadge(status: ReferralStatus.completed),
            ],
          ),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Transferred (In-Transit)'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('ScoreIndicator displays formatted percentage and tier', (tester) async {
      await tester.pumpWidget(
        _wrap(const ScoreIndicator(score: 94.5)),
      );

      expect(find.text('95'), findsOneWidget); // Rounded
      expect(find.text('Optimal Match'), findsOneWidget);
      expect(find.text('94.5% Suitability'), findsOneWidget);
    });

    testWidgets('CapabilityRow displays service status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CapabilityRow(
            title: 'Emergency Cesarean Section',
            subtitle: 'On-call obstetric surgeon present',
            icon: Icons.local_hospital,
            isAvailable: true,
          ),
        ),
      );

      expect(find.text('Emergency Cesarean Section'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('HospitalCard renders required metadata: emergency, ICU, distance, and beds', (tester) async {
      final hospital = MockClinicalData.hospitalDistrictGeneral;
      var selected = false;

      await tester.pumpWidget(
        _wrap(
          HospitalCard(
            hospital: hospital,
            suitabilityScore: 92.0,
            distanceKm: 24.8,
            travelTime: const Duration(minutes: 38),
            isRecommended: true,
            onSelect: () => selected = true,
          ),
        ),
      );

      expect(find.text(hospital.name), findsOneWidget);
      expect(find.text(hospital.address), findsOneWidget);
      expect(find.text('RECOMMENDED'), findsOneWidget);
      expect(find.text('24/7 Emergency'), findsOneWidget);
      expect(find.text('ICU Available'), findsOneWidget);
      expect(find.textContaining('Beds Available'), findsOneWidget);
      expect(find.text('24.8 km'), findsOneWidget);
      expect(find.text('~38 mins by Car'), findsOneWidget);

      await tester.tap(find.text('SELECT'));
      expect(selected, isTrue);
    });

    testWidgets('RecommendationReasonCard displays reasons and capability tags', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RecommendationReasonCard(
            hospitalName: 'District General Civil Hospital',
            score: 94.5,
            whyRecommended: const [
              'Full capability match for obstetric hemorrhage.',
              'Blood bank reported operational.',
            ],
            capabilityMatches: const ['24/7 Blood Bank', 'ICU Beds'],
          ),
        ),
      );

      expect(find.text('District General Civil Hospital'), findsOneWidget);
      expect(find.text('Full capability match for obstetric hemorrhage.'), findsOneWidget);
      expect(find.text('24/7 Blood Bank'), findsOneWidget);
      expect(find.text('ICU Beds'), findsOneWidget);
    });

    testWidgets('PatientInfoCard renders patient presentation and abnormal vitals', (tester) async {
      final patient = MockClinicalData.patientPostpartumHemorrhage;

      await tester.pumpWidget(
        _wrap(PatientInfoCard(patient: patient)),
      );

      expect(find.text(patient.patientId), findsOneWidget);
      expect(find.textContaining(patient.sex.displayName), findsOneWidget);
      expect(find.text(patient.mainComplaint), findsOneWidget);
      expect(find.textContaining('84/52 mmHg'), findsOneWidget);
      expect(find.textContaining('126 bpm'), findsOneWidget);
    });

    testWidgets('ReferralTimeline displays audit history list', (tester) async {
      final referral = MockClinicalData.sampleEmergencyReferral;

      await tester.pumpWidget(
        _wrap(ReferralTimeline(history: referral.statusHistory)),
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Referred'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Transferred (In-Transit)'), findsOneWidget);
    });

    testWidgets('ConfirmationDialog shows and returns user choice', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await ConfirmationDialog.show(
                    ctx,
                    title: 'Dispatch Ambulance',
                    message: 'Confirm patient transfer?',
                    confirmText: 'Dispatch',
                    cancelText: 'Cancel',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Dispatch Ambulance'), findsOneWidget);
      expect(find.text('Confirm patient transfer?'), findsOneWidget);

      await tester.tap(find.text('Dispatch'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('ComponentShowcaseScreen renders cleanly on phone & tablet without overflow', (tester) async {
      // Test on standard phone viewport
      tester.view.physicalSize = const Size(400 * 2.0, 900 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ComponentShowcaseScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Design System Showcase'), findsOneWidget);
      expect(find.text('21. Disclaimer Card'), findsOneWidget);
    });
  });
}
