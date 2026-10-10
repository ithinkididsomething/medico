import 'package:flutter/material.dart';
import 'assessment/patient_assessment_screen.dart';

/// Assessment Screen for SMART Referral.
/// Hosts the complete 5-section PatientAssessmentScreen within the main application shell.
class AssessmentScreen extends StatelessWidget {
  const AssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PatientAssessmentScreen(showAppHeader: false);
  }
}
