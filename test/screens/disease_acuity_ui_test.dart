import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/patient.dart';
import 'package:smart_referral/screens/assessment/assessment_result_screen.dart';
import 'package:smart_referral/screens/assessment/patient_assessment_screen.dart';
import 'package:smart_referral/screens/more_screen.dart';
import 'package:smart_referral/services/assessment_service.dart';
import 'package:smart_referral/widgets/primary_button.dart';

void main() {
  Widget buildAssessmentScreen({Patient? initialPatient}) {
    return MaterialApp(
      home: PatientAssessmentScreen(
        initialPatient: initialPatient,
      ),
    );
  }

  Widget buildMoreScreen() {
    return const MaterialApp(
      home: Scaffold(
        body: MoreScreen(),
      ),
    );
  }

  group('Disease Acuity & Triage Protocol UI Widget Tests', () {
    testWidgets('1. Acuity filter chips filter symptoms and show condition chips',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 3000 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildAssessmentScreen());
      await tester.pumpAndSettle();

      // Check Acuity filter chips
      expect(find.text('Common Symptoms (12)'), findsOneWidget);
      expect(find.text('Level 4: Emergency (11)'), findsOneWidget);
      expect(find.text('Level 3: Urgent (8)'), findsOneWidget);
      expect(find.text('Level 2: Clinic / PHC (8)'), findsOneWidget);
      expect(find.text('Level 1: Home Care (5)'), findsOneWidget);
      expect(find.text('All Diseases (32)'), findsOneWidget);

      // Tap Level 4: Emergency filter chip
      await tester.tap(find.text('Level 4: Emergency (11)'));
      await tester.pumpAndSettle();

      // Verify Level 4 disease conditions appear
      expect(find.text('Severe breathing difficulty'), findsOneWidget);
      expect(find.text('Chest pain with concerning features'), findsOneWidget);
      expect(find.text('Stroke symptoms'), findsOneWidget);
      expect(find.text('Unconsciousness'), findsOneWidget);

      // Tap Level 1: Home Care filter chip
      final level1Chip = find.text('Level 1: Home Care (5)');
      await tester.ensureVisible(level1Chip);
      await tester.pumpAndSettle();
      await tester.tap(level1Chip);
      await tester.pumpAndSettle();

      // Verify Level 1 disease conditions appear
      expect(find.text('Common cold'), findsOneWidget);
      expect(find.text('Mild headache'), findsOneWidget);
      expect(find.text('Mild diarrhea without dehydration'), findsOneWidget);
    });

    testWidgets('2. Tapping Triage Acuity Guide opens modal with all 4 levels and actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 2400 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildAssessmentScreen());
      await tester.pumpAndSettle();

      // Tap Triage Acuity Guide button
      final guideButton = find.text('Triage Acuity Guide');
      expect(guideButton, findsOneWidget);
      await tester.tap(guideButton);
      await tester.pumpAndSettle();

      // Verify modal content
      expect(find.text('Disease Triage Acuity Matrix'), findsOneWidget);
      expect(find.textContaining('LEVEL 4 — Emergency'), findsOneWidget);
      expect(find.textContaining('LEVEL 3 — Urgent Referral'), findsOneWidget);
      expect(find.textContaining('LEVEL 2 — Local Clinic / PHC'), findsOneWidget);
      expect(find.textContaining('LEVEL 1 — Home care / Observe'), findsOneWidget);

      // Tap an example in modal (Common cold)
      final commonColdChip = find.widgetWithText(ActionChip, 'Common cold');
      expect(commonColdChip, findsOneWidget);
      await tester.tap(commonColdChip);
      await tester.pumpAndSettle();

      // Verify toast feedback and symptom is added to assessment
      expect(find.textContaining('Added "Common cold" to clinical assessment.'), findsOneWidget);
    });

    testWidgets('3. AssessmentResultScreen displays Disease Acuity Protocol Card with guidelines',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 2400 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final patient = Patient(
        patientId: 'TEST-DIS-01',
        age: 62,
        sex: Sex.male,
        mainComplaint: 'Acute chest pain with concerning features',
        symptoms: const ['Severe breathing difficulty'],
        injuryOrIllnessDetails: 'Crushing retrosternal chest pain radiating to jaw',
        clinicalFindings: 'Sweating profusely, tachypneic, pale',
        heartRate: 115,
        systolicBP: 140,
        diastolicBP: 90,
        respiratoryRate: 26,
        oxygenSaturation: 91.0,
        temperature: 36.9,
        requiredSpecialty: 'Cardiology',
        createdAt: DateTime.now(),
      );

      const service = RuleBasedAssessmentService();
      final result = service.evaluate(patient);

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentResultScreen(
            patient: patient,
            assessment: result,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Disease Acuity Protocol Card
      expect(find.text('Disease Acuity Protocol'), findsOneWidget);
      expect(find.text('Severity 4 / 4'), findsOneWidget);
      expect(find.textContaining('LEVEL 4 — Emergency'), findsOneWidget);
      expect(find.textContaining('Life-threatening or needs specialist/emergency facilities'), findsOneWidget);
      expect(find.textContaining('Immediate emergency referral/ambulance'), findsWidgets);
      expect(find.text('Chest pain with concerning features'), findsOneWidget);
    });

    testWidgets('4. MoreScreen provides Disease Triage Acuity Matrix reference guide',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 2400 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildMoreScreen());
      await tester.pumpAndSettle();

      // Scroll to Disease Triage Matrix button
      final matrixButton = find.text('Disease Triage Acuity Matrix (Levels 1-4)');
      await tester.ensureVisible(matrixButton);
      await tester.pumpAndSettle();
      expect(matrixButton, findsOneWidget);

      // Tap button to open dialog
      await tester.tap(matrixButton);
      await tester.pumpAndSettle();

      // Verify dialog appears with 4 levels
      expect(find.text('Disease Triage Matrix'), findsOneWidget);
      expect(find.textContaining('4-Tier clinical disease classification protocol'), findsOneWidget);
      expect(find.textContaining('LEVEL 4 — Emergency'), findsOneWidget);
      expect(find.textContaining('LEVEL 1 — Home care'), findsOneWidget);

      // Close dialog
      final closeButton = find.widgetWithText(PrimaryButton, 'Close Guide');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.text('Disease Triage Matrix'), findsNothing);
    });
  });
}
