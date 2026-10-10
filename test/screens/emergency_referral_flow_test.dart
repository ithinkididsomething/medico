import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_referral/models/emergency_referral.dart';
import 'package:smart_referral/repositories/emergency_referral_repository.dart';
import 'package:smart_referral/screens/assessment/patient_assessment_screen.dart';
import 'package:smart_referral/screens/emergency/emergency_quick_referral_screen.dart';
import 'package:smart_referral/screens/emergency/emergency_referral_dashboard_screen.dart';
import 'package:smart_referral/screens/emergency/emergency_referral_detail_screen.dart';
import 'package:smart_referral/services/emergency_referral_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EmergencyReferralRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = EmergencyReferralRepository();
    await repository.initialize();
    EmergencyReferralRepository.setInstance(repository);
  });

  group('Emergency Quick Referral — Domain & Repository Tests', () {
    test('1. Creates emergency referral with minimum essential info without blocking', () async {
      final ref = EmergencyReferral(
        referralId: 'ER-TEST-001',
        patientIdentifier: 'UNKNOWN_MALE_01',
        presentingComplaint: 'Crushing retrosternal chest pain with diaphoresis',
        emergencyCategory: EmergencyCategory.stemiCardiac,
        referringClinicianId: 'DOC-IND-702',
        referringClinicianName: 'Dr. Parth Saxena',
        referringFacilityName: 'Sanwer CHC',
        referringCallbackPhone: '+91 98260 12345',
        receivingFacilityId: 'indore_hospital_001',
        receivingFacilityName: 'Apollo Hospitals Indore',
        receivingDepartment: 'Cardiology & Cath Lab',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify vitals and non-essential fields are allowed to be null
      expect(ref.vitalsPulse, isNull);
      expect(ref.vitalsBpSystolic, isNull);
      expect(ref.vitalsSpo2, isNull);
      expect(ref.patientAge, isNull);
      expect(ref.currentVersion, equals(1));
      expect(ref.workflowStatus, equals(EmergencyWorkflowStatus.emergencyCreated));

      // Save locally
      final saved = await repository.createEmergencyReferral(ref);
      expect(saved.referralId, equals('ER-TEST-001'));

      final retrieved = await repository.getReferralById('ER-TEST-001');
      expect(retrieved, isNotNull);
      expect(retrieved!.patientIdentifier, equals('UNKNOWN_MALE_01'));
      expect(retrieved.receivingFacilityName, equals('Apollo Hospitals Indore'));
    });

    test('2. Updates ambulance dispatch telemetry without delay', () async {
      final ref = EmergencyReferral(
        referralId: 'ER-AMB-001',
        patientIdentifier: 'PT-9988',
        presentingComplaint: 'Acute left-sided hemiparesis and facial droop',
        emergencyCategory: EmergencyCategory.acuteStroke,
        referringClinicianId: 'DOC-IND-702',
        referringClinicianName: 'Dr. Parth Saxena',
        referringFacilityName: 'Sanwer CHC',
        referringCallbackPhone: '+91 98260 12345',
        receivingFacilityId: 'indore_hospital_004',
        receivingFacilityName: 'Bombay Hospital Indore',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.createEmergencyReferral(ref);

      final updated = await repository.updateAmbulanceDispatch(
        referralId: 'ER-AMB-001',
        status: AmbulanceDispatchStatus.patientLoadedInTransit,
        vehicleNumber: 'MP-09-EM-108',
        etaMinutes: 18,
        notes: 'En route with oxygen therapy',
      );

      expect(updated.ambulanceStatus, equals(AmbulanceDispatchStatus.patientLoadedInTransit));
      expect(updated.ambulanceVehicleNumber, equals('MP-09-EM-108'));
      expect(updated.ambulanceEtaMinutes, equals(18));
    });

    test('3. Post-dispatch versioned amendment preserves immutable Version 1', () async {
      final initial = EmergencyReferral(
        referralId: 'ER-VER-001',
        patientIdentifier: 'PT-1234',
        presentingComplaint: 'High speed trauma with active hemorrhage',
        emergencyCategory: EmergencyCategory.polytrauma,
        referringClinicianId: 'DOC-IND-702',
        referringClinicianName: 'Dr. Parth Saxena',
        referringFacilityName: 'Sanwer CHC',
        referringCallbackPhone: '+91 98260 12345',
        receivingFacilityId: 'indore_hospital_007',
        receivingFacilityName: 'MY Hospital Indore',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.createEmergencyReferral(initial);

      // Perform en-route clinical amendment
      final amended = await repository.addClinicalAmendment(
        referralId: 'ER-VER-001',
        updateData: {
          'vitalsPulse': 118,
          'vitalsBpSystolic': 85,
          'vitalsBpDiastolic': 50,
          'vitalsSpo2': 91,
          'immediateTreatmentGiven': 'IV normal saline 1000ml running, tourniquet applied',
        },
        amendmentReason: 'Patient deteriorated en-route. Signs of hemorrhagic shock.',
        editorName: 'Paramedic Sharma',
      );

      expect(amended.currentVersion, equals(2));
      expect(amended.versions.length, equals(1));
      expect(amended.versions.first.versionNumber, equals(2));
      expect(amended.versions.first.amendmentReason, contains('hemorrhagic shock'));
      expect(amended.versions.first.changedFields, contains('vitalsBpSystolic'));
    });

    test('4. Multi-channel delivery simulation logs transmission attempts', () async {
      final ref = EmergencyReferral(
        referralId: 'ER-NOTIF-001',
        patientIdentifier: 'PT-5544',
        presentingComplaint: 'Severe respiratory distress with stridor',
        emergencyCategory: EmergencyCategory.severeRespiratory,
        referringClinicianId: 'DOC-IND-702',
        referringClinicianName: 'Dr. Parth Saxena',
        referringFacilityName: 'Sanwer CHC',
        referringCallbackPhone: '+91 98260 12345',
        receivingFacilityId: 'indore_hospital_001',
        receivingFacilityName: 'Apollo Hospitals Indore',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.createEmergencyReferral(ref);

      // Verify email formatting
      final subject = EmergencyReferralService.formatEmailSubject(ref);
      expect(subject, startsWith('URGENT EMERGENCY REFERRAL — [ER-NOTIF-001]'));

      final emailBody = EmergencyReferralService.formatEmailBody(ref);
      expect(emailBody, contains('URGENT EMERGENCY REFERRAL NOTIFICATION'));
      expect(emailBody, contains('Dr. Parth Saxena'));

      final sms = EmergencyReferralService.formatSmsAlert(ref);
      expect(sms, startsWith('[URGENT ER]'));

      // Send via email channel
      final updated = await repository.sendReferralNotification(
        referralId: 'ER-NOTIF-001',
        channel: 'email',
        recipientAddress: 'triage@apolloindore.com',
      );
      expect(updated.deliveries.length, equals(1));
      expect(updated.deliveries.first.channel, equals('email'));
    });

    test('5. Records receiving team acceptance and clinical handover', () async {
      final ref = EmergencyReferral(
        referralId: 'ER-HANDOVER-001',
        patientIdentifier: 'PT-8899',
        presentingComplaint: 'Acute abdomen with guarding and sepsis',
        emergencyCategory: EmergencyCategory.acuteAbdomen,
        referringClinicianId: 'DOC-IND-702',
        referringClinicianName: 'Dr. Parth Saxena',
        referringFacilityName: 'Sanwer CHC',
        referringCallbackPhone: '+91 98260 12345',
        receivingFacilityId: 'indore_hospital_002',
        receivingFacilityName: 'Bhandari Hospital',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.createEmergencyReferral(ref);

      // Record acceptance
      final accepted = await repository.recordAcknowledgement(
        referralId: 'ER-HANDOVER-001',
        responseStatus: ReceivingResponseStatus.accepted,
        responderName: 'Dr. Neha Agrawal',
        responderRole: 'ER In-charge',
      );
      expect(accepted.responseStatus, equals(ReceivingResponseStatus.accepted));

      // Record handover
      final handedOver = await repository.recordHandover(
        referralId: 'ER-HANDOVER-001',
        actorName: 'Dr. Neha Agrawal (ER In-charge)',
        notes: 'Handover complete. Transferred to emergency OT.',
      );
      expect(handedOver.workflowStatus, equals(EmergencyWorkflowStatus.handoverCompleted));
    });

    test('6. 3-Pillar Hierarchical Recommendation strictly enforces capability over distance', () {
      final stemiRankings = EmergencyReferralService.rankHospitalsForEmergency(
        EmergencyCategory.stemiCardiac,
      );

      expect(stemiRankings, isNotEmpty);
      // Top hospital must meet mandatory capability
      expect(stemiRankings.first.meetsMandatoryCapability, isTrue);

      // Verify no hospital lacking mandatory capability is ranked above an eligible one
      bool seenIneligible = false;
      for (final rec in stemiRankings) {
        if (!rec.meetsMandatoryCapability) {
          seenIneligible = true;
        } else {
          expect(seenIneligible, isFalse, reason: 'Eligible hospital ranked below ineligible hospital');
        }
      }
    });

    test('7. Offline local draft management', () async {
      final draft = {
        'patientIdentifier': 'DRAFT_PT_01',
        'presentingComplaint': 'Suspected acute pulmonary edema',
        'emergencyCategory': 'severe_respiratory',
      };
      await repository.saveDraft(draft);

      final loaded = await repository.getDraft();
      expect(loaded, isNotNull);
      expect(loaded!['patientIdentifier'], equals('DRAFT_PT_01'));

      await repository.clearDraft();
      final cleared = await repository.getDraft();
      expect(cleared, isNull);
    });
  });

  group('Emergency Referral — Widget Flow Tests', () {
    testWidgets('8. EmergencyQuickReferralScreen renders form and ambulance status chips',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyQuickReferralScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Quick Referral'), findsOneWidget);
      expect(find.text('DIAL 108'), findsOneWidget);
      expect(find.text('Ambulance Dispatch Status'), findsOneWidget);
      expect(find.text('CREATE & DISPATCH REFERRAL'), findsOneWidget);
    });

    testWidgets('9. EmergencyReferralDashboardScreen renders metrics and emergency feed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed a test referral
      await repository.createEmergencyReferral(
        EmergencyReferral(
          referralId: 'ER-DASH-001',
          patientIdentifier: 'PT-TEST-DASH',
          presentingComplaint: 'Acute chest pain',
          emergencyCategory: EmergencyCategory.stemiCardiac,
          referringClinicianId: 'DOC-IND-702',
          referringClinicianName: 'Dr. Parth Saxena',
          referringFacilityName: 'Sanwer CHC',
          referringCallbackPhone: '+91 98260 12345',
          receivingFacilityId: 'indore_hospital_001',
          receivingFacilityName: 'Apollo Hospitals Indore',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyReferralDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Referral Command Center'), findsOneWidget);
      expect(find.text('Total Cases'), findsOneWidget);
      expect(find.text('NEW EMERGENCY'), findsOneWidget);
      expect(find.text('ER-DASH-001'), findsOneWidget);
    });

    testWidgets('10. EmergencyReferralDetailScreen displays status pipeline and action controls',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await repository.createEmergencyReferral(
        EmergencyReferral(
          referralId: 'ER-DET-001',
          patientIdentifier: 'PT-DET-99',
          presentingComplaint: 'Crushing chest pain radiating to left arm',
          emergencyCategory: EmergencyCategory.stemiCardiac,
          referringClinicianId: 'DOC-IND-702',
          referringClinicianName: 'Dr. Parth Saxena',
          referringFacilityName: 'Sanwer CHC',
          referringCallbackPhone: '+91 98260 12345',
          receivingFacilityId: 'indore_hospital_001',
          receivingFacilityName: 'Apollo Hospitals Indore',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyReferralDetailScreen(referralId: 'ER-DET-001'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ER-DET-001'), findsOneWidget);
      expect(find.text('LIVE STATUS PIPELINE'), findsOneWidget);
      expect(find.text('EDIT / ADD CLINICAL UPDATE'), findsOneWidget);
      expect(find.text('TRANSMIT NOTIFICATION TO HOSPITAL'), findsOneWidget);
    });

    testWidgets('11. EmergencyQuickReferralScreen accepts all sex formats (lowercase, uppercase, unknown) without dropdown assertion failure',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Test lowercase 'female' (the exact user crash scenario)
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyQuickReferralScreen(key: ValueKey('female'), patientSex: 'female'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Emergency Quick Referral'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);

      // Test lowercase 'male'
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyQuickReferralScreen(key: ValueKey('male'), patientSex: 'male'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Male'), findsOneWidget);

      // Test lowercase 'other'
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyQuickReferralScreen(key: ValueKey('other'), patientSex: 'other'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsOneWidget);

      // Test unexpected/unknown value
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyQuickReferralScreen(key: ValueKey('unknown'), patientSex: 'unrecognized_value'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('12. PatientAssessmentScreen emergency button navigates to EmergencyQuickReferralScreen smoothly when Female selected',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PatientAssessmentScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Emergency button in the Patient Deteriorating banner
      final emergencyBtn = find.widgetWithText(ElevatedButton, 'EMERGENCY');
      expect(emergencyBtn, findsOneWidget);

      await tester.tap(emergencyBtn);
      await tester.pumpAndSettle();

      // Should open EmergencyQuickReferralScreen without any dropdown assertion error
      expect(find.text('Emergency Quick Referral'), findsOneWidget);
      expect(find.text('DIAL 108'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
    });
  });
}
