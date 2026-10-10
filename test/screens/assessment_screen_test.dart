import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/patient.dart';
import 'package:smart_referral/repositories/referral_repository.dart';
import 'package:smart_referral/screens/assessment/assessment_result_screen.dart';
import 'package:smart_referral/screens/assessment/patient_assessment_screen.dart';
import 'package:smart_referral/widgets/primary_button.dart';
import 'package:smart_referral/widgets/secondary_button.dart';
import 'package:smart_referral/widgets/urgency_badge.dart';
import 'package:smart_referral/screens/referral/referral_summary_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({Patient? initialPatient, bool showAppHeader = true}) {
    return MaterialApp(
      home: PatientAssessmentScreen(
        initialPatient: initialPatient,
        showAppHeader: showAppHeader,
      ),
    );
  }

  group('PatientAssessmentScreen Widget Tests', () {
    testWidgets('Renders all 5 sections and bottom action button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Section 1
      expect(find.textContaining('SECTION 1 — Patient Information'), findsOneWidget);
      expect(find.textContaining('Patient Identifier / Token *'), findsOneWidget);
      expect(find.textContaining('Age (Years) *'), findsOneWidget);
      expect(find.textContaining('Sex *'), findsOneWidget);
      expect(find.textContaining('Main Complaint *'), findsOneWidget);

      // Section 2
      expect(find.textContaining('SECTION 2 — Symptoms & Condition'), findsOneWidget);
      expect(find.text('Select Presenting Symptoms:'), findsOneWidget);
      expect(find.text('Breathing difficulty'), findsOneWidget);
      expect(find.text('High fever'), findsOneWidget);

      // Section 3
      expect(find.textContaining('SECTION 3 — Vital Signs'), findsOneWidget);
      expect(find.textContaining('Blood Pressure (mmHg):'), findsOneWidget);
      expect(find.textContaining('Heart Rate (bpm)'), findsOneWidget);
      expect(find.textContaining('Resp Rate (/min)'), findsOneWidget);
      expect(find.textContaining('SpO2 (% Oxygen)'), findsOneWidget);
      expect(find.textContaining('Temp (°C)'), findsOneWidget);

      // Section 4
      expect(find.textContaining('SECTION 4 — Referral Information'), findsOneWidget);
      expect(find.textContaining('Required Medical Specialty *'), findsOneWidget);

      // Section 5
      expect(find.textContaining('SECTION 5 — Current Clinic Resources'), findsOneWidget);
      expect(find.text('Basic Diagnostics'), findsOneWidget);
      expect(find.text('Emergency Stabilization Capability'), findsOneWidget);
      expect(find.text('Specialist Doctor Available On-Site'), findsOneWidget);
      expect(find.text('ICU / Advanced Life Support Support'), findsOneWidget);

      // Bottom Action
      expect(find.widgetWithText(PrimaryButton, 'Assess Patient'), findsOneWidget);
    });

    testWidgets('Empty required fields trigger validation errors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 4500 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Clear the prefilled patient token to trigger validation
      final tokenField = find.widgetWithText(TextFormField, 'Patient Identifier / Token *');
      await tester.enterText(tokenField, '');

      // Tap Assess Patient
      final assessButton = find.widgetWithText(PrimaryButton, 'Assess Patient');
      await tester.ensureVisible(assessButton);
      await tester.pumpAndSettle();
      await tester.tap(assessButton);
      await tester.pumpAndSettle();

      // Verify validation feedback
      expect(find.text('Please enter a patient identifier'), findsOneWidget);
      expect(find.text('Enter age'), findsOneWidget);
      expect(find.text('Please describe the main complaint'), findsOneWidget);
      expect(find.text('Please check highlighted required fields before assessing.'), findsOneWidget);
    });

    testWidgets('Can add custom symptoms via the symptom input row', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 3000 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final customField = find.widgetWithText(TextField, 'Add custom symptom/sign...');
      await tester.ensureVisible(customField);
      await tester.pumpAndSettle();

      await tester.enterText(customField, 'Bilateral leg edema');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Bilateral leg edema'), findsOneWidget);
    });

    testWidgets('Assessing an emergency patient navigates to AssessmentResultScreen and reviews back',
        (WidgetTester tester) async {
      final samplePatient = Patient(
        patientId: 'TEST-PPH-01',
        age: 26,
        sex: Sex.female,
        mainComplaint: 'Heavy vaginal bleeding after home delivery',
        symptoms: ['Excessive postpartum hemorrhage', 'Lethargy / Unconsciousness'],
        injuryOrIllnessDetails: 'Unattended home delivery 2 hours ago',
        clinicalFindings: 'Profuse bleeding, cold extremities, pallor',
        heartRate: 135,
        systolicBP: 75,
        diastolicBP: 45,
        respiratoryRate: 28,
        oxygenSaturation: 89,
        temperature: 36.1,
        requiredSpecialty: 'Obstetrics & Gynecology',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(initialPatient: samplePatient));
      await tester.pumpAndSettle();

      // Tap Assess Patient
      final assessButton = find.widgetWithText(PrimaryButton, 'Assess Patient');
      await tester.ensureVisible(assessButton);
      await tester.pumpAndSettle();
      await tester.tap(assessButton);
      await tester.pumpAndSettle();

      // Expect to be on AssessmentResultScreen
      expect(find.byType(AssessmentResultScreen), findsOneWidget);
      expect(find.text('Assessment Result'), findsOneWidget);

      // Verify Urgency and Recommended Action
      expect(find.text('Immediate Referral Required'), findsOneWidget);
      expect(find.byType(UrgencyBadge), findsWidgets);

      // Verify Disclaimers
      expect(
        find.textContaining('This is a clinical decision-support advisory and does not replace professional clinical judgment.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Rule-based clinical triage assessment following standard healthcare protocols.'),
        findsOneWidget,
      );

      // Verify reasons / rationale
      expect(find.text('Clinical Evaluation Reasons'), findsOneWidget);
      expect(find.text('Alerts & Danger Signs Detected:'), findsOneWidget);

      // Verify "Review Details" returns to the entered information
      final reviewButton = find.widgetWithText(SecondaryButton, 'Review Details');
      await tester.ensureVisible(reviewButton);
      await tester.pumpAndSettle();
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      // Back on PatientAssessmentScreen with entered information preserved
      expect(find.byType(AssessmentResultScreen), findsNothing);
      expect(find.text('TEST-PPH-01'), findsOneWidget);
      expect(find.text('Heavy vaginal bleeding after home delivery'), findsOneWidget);
    });

    testWidgets('Routine mild case evaluates to Manage Locally', (WidgetTester tester) async {
      final mildPatient = Patient(
        patientId: 'TEST-ROUTINE-01',
        age: 32,
        sex: Sex.male,
        mainComplaint: 'Mild rhinorrhea and sneezing for 2 days',
        symptoms: ['Mild nasal congestion'],
        injuryOrIllnessDetails: 'Symptoms began 2 days ago after exposure to cold weather',
        clinicalFindings: 'Throat clear, lungs clear, no red flag signs',
        heartRate: 72,
        systolicBP: 118,
        diastolicBP: 76,
        respiratoryRate: 16,
        oxygenSaturation: 99,
        temperature: 36.8,
        requiredSpecialty: 'General Medicine',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(initialPatient: mildPatient));
      await tester.pumpAndSettle();

      final assessButton = find.widgetWithText(PrimaryButton, 'Assess Patient');
      await tester.ensureVisible(assessButton);
      await tester.pumpAndSettle();
      await tester.tap(assessButton);
      await tester.pumpAndSettle();

      expect(find.byType(AssessmentResultScreen), findsOneWidget);
      expect(find.text('Manage Locally'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Save Local Care Observation'), findsOneWidget);
    });

    testWidgets('Loading sample clinical preset populates patient details into form',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(showAppHeader: true));
      await tester.pumpAndSettle();

      // Open Preset menu
      final presetMenu = find.byTooltip('Load Sample Presentation');
      expect(presetMenu, findsOneWidget);
      await tester.tap(presetMenu);
      await tester.pumpAndSettle();

      // Select Obstetric PPH preset
      final pphItem = find.text('Preset: Obstetric PPH (Emergency)');
      expect(pphItem, findsOneWidget);
      await tester.tap(pphItem);
      await tester.pumpAndSettle();

      // Check fields are populated
      expect(find.text('PAT-SIM-101'), findsOneWidget);
      expect(find.text('26'), findsOneWidget);
      expect(find.text('Heavy vaginal bleeding after home delivery (PPH)'), findsOneWidget);
    });

    testWidgets(
        'Saving Local Care Observation logs to repository and resets assessment form for next patient',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 4500 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mildPatient = Patient(
        patientId: 'TEST-LOCAL-99',
        age: 30,
        sex: Sex.male,
        mainComplaint: 'Mild seasonal coryza',
        symptoms: ['Mild nasal congestion'],
        injuryOrIllnessDetails: 'Onset yesterday',
        clinicalFindings: 'Vitals stable',
        heartRate: 70,
        systolicBP: 120,
        diastolicBP: 80,
        respiratoryRate: 16,
        oxygenSaturation: 99,
        temperature: 36.6,
        requiredSpecialty: 'General Medicine',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(initialPatient: mildPatient));
      await tester.pumpAndSettle();

      expect(find.text('TEST-LOCAL-99'), findsOneWidget);
      expect(find.text('Mild seasonal coryza'), findsOneWidget);

      final assessButton = find.widgetWithText(PrimaryButton, 'Assess Patient');
      await tester.ensureVisible(assessButton);
      await tester.pumpAndSettle();
      await tester.tap(assessButton);
      await tester.pumpAndSettle();

      expect(find.byType(AssessmentResultScreen), findsOneWidget);

      final saveObservationButton =
          find.widgetWithText(PrimaryButton, 'Save Local Care Observation');
      expect(saveObservationButton, findsOneWidget);
      await tester.ensureVisible(saveObservationButton);
      await tester.pumpAndSettle();
      await tester.tap(saveObservationButton);
      await tester.pumpAndSettle();

      // Should have returned to PatientAssessmentScreen
      expect(find.byType(AssessmentResultScreen), findsNothing);

      // Form should now be cleared of previous patient's details
      expect(find.text('TEST-LOCAL-99'), findsNothing);
      expect(find.text('Mild seasonal coryza'), findsNothing);

      // Repository should have saved an observation record
      final referrals = await LocalReferralRepository.instance.getAllReferrals();
      final savedObs = referrals.where((r) => r.patient.patientId == 'TEST-LOCAL-99');
      expect(savedObs.isNotEmpty, isTrue);
      expect(savedObs.first.status, equals(ReferralStatus.completed));
    });

    testWidgets('Tapping Clear & New Patient clears all entered patient fields',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 3000 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p = Patient(
        patientId: 'PAT-TO-CLEAR-01',
        age: 45,
        sex: Sex.male,
        mainComplaint: 'Fever and chills',
        symptoms: ['High fever'],
        injuryOrIllnessDetails: 'Duration 3 days',
        clinicalFindings: 'Febrile',
        heartRate: 98,
        systolicBP: 130,
        diastolicBP: 85,
        respiratoryRate: 20,
        oxygenSaturation: 97,
        temperature: 38.5,
        requiredSpecialty: 'General Medicine',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(initialPatient: p));
      await tester.pumpAndSettle();

      expect(find.text('PAT-TO-CLEAR-01'), findsOneWidget);
      expect(find.text('Fever and chills'), findsOneWidget);

      final clearButton =
          find.widgetWithText(SecondaryButton, 'Clear & New Patient');
      await tester.ensureVisible(clearButton);
      await tester.pumpAndSettle();
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.text('PAT-TO-CLEAR-01'), findsNothing);
      expect(find.text('Fever and chills'), findsNothing);
    });

    testWidgets('AssessmentResultScreen displays ranked referral hospitals and navigates to ReferralSummary',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 3000 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final emergencyPatient = Patient(
        patientId: 'TEST-RANK-01',
        age: 45,
        sex: Sex.male,
        mainComplaint: 'Crushing chest pain radiating to left arm',
        symptoms: ['Chest pain / Pressure', 'Shortness of breath'],
        injuryOrIllnessDetails: 'Onset 1 hour ago',
        clinicalFindings: 'Diaphoretic, pale',
        heartRate: 110,
        systolicBP: 90,
        diastolicBP: 60,
        respiratoryRate: 24,
        oxygenSaturation: 91,
        temperature: 36.8,
        requiredSpecialty: 'Cardiology',
        createdAt: DateTime.now(),
        conditionCategory: PatientConditionCategory.suspectedCardiacEmergency,
      );

      await tester.pumpWidget(buildTestWidget(initialPatient: emergencyPatient));
      await tester.pumpAndSettle();

      // Assess Patient
      final assessButton = find.widgetWithText(PrimaryButton, 'Assess Patient');
      await tester.ensureVisible(assessButton);
      await tester.pumpAndSettle();
      await tester.tap(assessButton);
      await tester.pumpAndSettle();

      // Verify on AssessmentResultScreen
      expect(find.byType(AssessmentResultScreen), findsOneWidget);
      expect(find.text('Ranked Referral Hospitals'), findsOneWidget);
      expect(find.textContaining('Prioritization Rule: Suspected Cardiac Emergency'), findsOneWidget);
      expect(find.text('#1 Recommended Destination'), findsOneWidget);
      expect(find.text('Select Destination'), findsWidgets);

      // Tap Select Destination on the top ranked hospital
      final selectButton = find.widgetWithText(ElevatedButton, 'Select Destination').first;
      await tester.ensureVisible(selectButton);
      await tester.pumpAndSettle();
      await tester.tap(selectButton);
      await tester.pumpAndSettle();

      // Expect ReferralSummaryScreen
      expect(find.byType(ReferralSummaryScreen), findsOneWidget);
      expect(find.text('Referral Summary'), findsOneWidget);
    });

    testWidgets('PatientAssessmentScreen displays live condition referral ranking preview in Section 4',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 3000 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find Section 4 preview header
      final previewHeader = find.textContaining('Live Condition Referral Ranking Preview');
      await tester.ensureVisible(previewHeader);
      await tester.pumpAndSettle();

      expect(previewHeader, findsOneWidget);
      expect(find.text('#1'), findsWidgets);
    });
  });
}
