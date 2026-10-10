import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/models/referral.dart';
import 'package:smart_referral/repositories/referral_repository.dart';
import 'package:smart_referral/screens/referral/referral_summary_screen.dart';
import 'package:smart_referral/screens/referral/referral_tracking_screen.dart';
import 'package:smart_referral/widgets/primary_button.dart';
import 'package:smart_referral/widgets/secondary_button.dart';
import 'package:smart_referral/widgets/status_badge.dart';
import 'package:smart_referral/widgets/urgency_badge.dart';

void main() {
  late InMemoryReferralRepository testRepo;
  late Referral testReferral;

  setUp(() {
    testRepo = InMemoryReferralRepository(preloadMockData: true);
    testReferral = MockClinicalData.sampleEmergencyReferral;
  });

  group('Referral Repository Unit & Persistence Tests', () {
    test('1. Preloaded seed referrals include sample tracking cases', () async {
      final all = await testRepo.getAllReferrals();
      expect(all.length, greaterThanOrEqualTo(3));

      // Verify seed case P001, P002, P003, and replaced duplicate PAT-SIM-101
      expect(all.any((r) => r.patient.patientId == 'P001'), isTrue);
      expect(all.any((r) => r.patient.patientId == 'P002'), isTrue);
      expect(all.any((r) => r.patient.patientId == 'P003'), isTrue);
      expect(all.any((r) => r.patient.patientId == 'PAT-SIM-101'), isFalse);
      expect(all.any((r) => r.patient.patientId == 'PAT-SIM-104'), isTrue);
    });

    test('2. Manual status update records new status, timestamp, and audit note', () async {
      final initial = (await testRepo.getAllReferrals()).firstWhere((r) => r.patient.patientId == 'P001');
      expect(initial.status, equals(ReferralStatus.pending));

      final updatedTime = DateTime.now();
      final updated = await testRepo.updateStatus(
        initial.referralId,
        ReferralStatus.referred,
        'Outbound ambulance order confirmed by rural clinic lead.',
        timestamp: updatedTime,
      );

      expect(updated, isNotNull);
      expect(updated!.status, equals(ReferralStatus.referred));
      expect(updated.statusHistory.last.note, contains('Outbound ambulance order'));
      expect(updated.statusHistory.last.status, equals(ReferralStatus.referred));

      // Re-fetch from repo
      final fetched = await testRepo.getReferralById(initial.referralId);
      expect(fetched?.status, equals(ReferralStatus.referred));
    });

    test('3. Save and filter by status', () async {
      final pendingList = await testRepo.getReferralsByStatus(ReferralStatus.pending);
      for (final r in pendingList) {
        expect(r.status, equals(ReferralStatus.pending));
      }
    });
  });

  group('ReferralSummaryScreen Widget Tests', () {
    Widget buildSummaryWidget({Referral? referral}) {
      return MaterialApp(
        home: ReferralSummaryScreen(
          referral: referral ?? testReferral,
          repository: testRepo,
        ),
      );
    }

    testWidgets('1. Displays all structured clinical and logistics fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSummaryWidget());
      await tester.pumpAndSettle();

      // Referral ID & Title
      expect(find.text('Referral Summary'), findsOneWidget);
      expect(find.text(testReferral.referralId), findsWidgets);

      // Patient ID, Age/Sex, Main Complaint
      expect(find.text(testReferral.patient.patientId), findsWidgets);
      expect(find.textContaining('${testReferral.patient.age} years'), findsOneWidget);
      expect(find.text(testReferral.patient.mainComplaint), findsOneWidget);

      // Clinical findings & Vital signs snapshot
      expect(find.text(testReferral.patient.clinicalFindings), findsOneWidget);
      expect(find.text('Vital Signs Snapshot:'), findsOneWidget);
      expect(find.text('HR'), findsOneWidget);
      expect(find.text('BP'), findsOneWidget);
      expect(find.text('SpO2'), findsOneWidget);

      // Urgency & Reason for referral
      expect(find.byType(UrgencyBadge), findsWidgets);
      expect(find.text(testReferral.referralReason), findsOneWidget);

      // Required specialty & facilities
      expect(find.text(testReferral.requiredSpecialty), findsWidgets);
      expect(find.textContaining('Required Facilities'), findsWidgets);

      // Recommended Hospital & Alternative Hospital
      expect(find.text(testReferral.recommendedHospital!.name), findsWidgets);
      if (testReferral.alternativeHospitals.isNotEmpty) {
        expect(find.text(testReferral.alternativeHospitals.first.name), findsWidgets);
      }

      // Distance & Estimated Travel Time
      expect(find.textContaining('Distance:'), findsWidgets);
      expect(find.textContaining('Travel Time:'), findsWidgets);

      // Referring clinic & Date/Time
      expect(find.textContaining(testReferral.referringClinic), findsWidgets);
      expect(find.textContaining('Date/Time:'), findsWidgets);
    });

    testWidgets('2. Renders all 5 required action buttons (Save, PDF, Share, Print, Back to Dashboard)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSummaryWidget());
      await tester.pumpAndSettle();

      // Verify Buttons exist
      expect(find.widgetWithText(PrimaryButton, 'Save Referral'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Generate PDF'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Share'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Print'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Back to Dashboard'), findsOneWidget);

      // Tap Save Referral button
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save Referral'));
      await tester.pumpAndSettle();

      // Verifies saved state and feedback
      expect(find.text('Referral Saved to Local Registry'), findsOneWidget);

      // Tap Generate PDF button
      await tester.tap(find.widgetWithText(SecondaryButton, 'Generate PDF'));
      await tester.pumpAndSettle();
      expect(find.text('Generate Referral PDF'), findsOneWidget);
      expect(find.text('Save PDF to Device'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Tap Share button
      await tester.tap(find.widgetWithText(SecondaryButton, 'Share'));
      await tester.pumpAndSettle();
      expect(find.text('Share Transfer Handover Brief'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Tap Print button
      await tester.tap(find.widgetWithText(SecondaryButton, 'Print'));
      await tester.pumpAndSettle();
      expect(find.text('Print Transfer Handover Order'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('ReferralTrackingScreen Widget Tests', () {
    Widget buildTrackingWidget() {
      return MaterialApp(
        home: ReferralTrackingScreen(repository: testRepo),
      );
    }

    testWidgets('1. Displays clean cards with required format (P001 | Emergency | Hospital B | Pending)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTrackingWidget());
      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(find.text('Referral Tracking'), findsOneWidget);

      // Verify sample items formatted: P001 | Emergency | District General | Pending
      expect(find.text('P001'), findsOneWidget);
      expect(find.text('P002'), findsOneWidget);
      expect(find.text('P003'), findsOneWidget);

      // Status badges
      expect(find.byType(StatusBadge), findsWidgets);
      expect(find.byType(UrgencyBadge), findsWidgets);
    });

    testWidgets('2. Expands visual timeline showing: Pending ↓ Referred ↓ Accepted ↓ Transferred ↓ Completed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTrackingWidget());
      await tester.pumpAndSettle();

      // Find Visual Timeline toggle
      final timelineToggle = find.textContaining('View Visual Transfer Timeline');
      expect(timelineToggle, findsWidgets);

      // Tap to expand timeline
      await tester.tap(timelineToggle.first);
      await tester.pumpAndSettle();

      // Verify the 5 sequential stages are rendered in the visual timeline
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Referred'), findsWidgets);
      expect(find.text('Accepted'), findsWidgets);
      expect(find.text('Transferred (In-Transit)'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('3. Manual Status Update flow records transition and updates tracking list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTrackingWidget());
      await tester.pumpAndSettle();

      // Tap "Update Status" on first referral (P001)
      final updateButtons = find.widgetWithText(PrimaryButton, 'Update Status');
      expect(updateButtons, findsWidgets);
      await tester.tap(updateButtons.first);
      await tester.pumpAndSettle();

      // Verify Manual Update modal is presented
      expect(find.text('Update Referral Status'), findsOneWidget);
      expect(find.text('Select New Status (Manual Entry Only):'), findsOneWidget);

      // Confirm manual update
      final confirmUpdateBtn = find.widgetWithText(PrimaryButton, 'Confirm Manual Status Update');
      expect(confirmUpdateBtn, findsOneWidget);
      await tester.tap(confirmUpdateBtn);
      await tester.pumpAndSettle();

      // Verify modal closed and snackbar confirms status change
      expect(find.textContaining('updated to'), findsWidgets);
    });

    testWidgets('4. Selecting explicit status card updates status and appends audit note',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTrackingWidget());
      await tester.pumpAndSettle();

      // Tap "Update Status" on first referral (P001)
      final updateButtons = find.widgetWithText(PrimaryButton, 'Update Status');
      expect(updateButtons, findsWidgets);
      await tester.tap(updateButtons.first);
      await tester.pumpAndSettle();

      // Tap the "Accepted" status selection card inside the modal
      final acceptedCard = find.byKey(const ValueKey('status_option_accepted'));
      expect(acceptedCard, findsOneWidget);
      await tester.tap(acceptedCard);
      await tester.pumpAndSettle();

      // Enter a custom audit memo note
      final textField = find.byType(TextField).last;
      await tester.enterText(textField, 'Verified ICU bed with receiving resident Dr. Verma.');
      await tester.pumpAndSettle();

      // Confirm update
      final confirmUpdateBtn = find.widgetWithText(PrimaryButton, 'Confirm Manual Status Update');
      expect(confirmUpdateBtn, findsOneWidget);
      await tester.ensureVisible(confirmUpdateBtn);
      await tester.pumpAndSettle();
      await tester.tap(confirmUpdateBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar confirmation and repository state
      expect(find.textContaining('updated to Accepted'), findsOneWidget);
      final ref001 = await testRepo.getReferralById('REF-001');
      expect(ref001?.status, ReferralStatus.accepted);
      expect(ref001?.statusHistory.last.note, 'Verified ICU bed with receiving resident Dr. Verma.');
    });
  });
}
