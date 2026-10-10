import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/disease_acuity.dart';
import '../../models/enums.dart';
import '../../models/indore_hospital_dataset.dart';
import '../../models/patient.dart';
import '../../models/referral.dart';
import '../../models/referral_status_history.dart';
import '../../repositories/referral_repository.dart';
import '../../services/assessment_service.dart';
import '../../services/condition_specific_ranking_service.dart';
import '../../services/hospital_matching_service.dart';
import '../../services/location_service.dart';
import '../../widgets/widgets.dart';
import '../../core/utils/navigation_utils.dart';
import '../hospital/hospital_details_screen.dart';
import '../recommendation/recommendation_screen.dart';
import '../referral/referral_summary_screen.dart';
import '../../models/symptom_analysis.dart';
import '../../services/offline_clinical_rule_engine.dart';
import '../../services/offline_assessment_storage_service.dart';
import 'patient_assessment_screen.dart';
import '../emergency/emergency_quick_referral_screen.dart';

/// Screen presenting the clinical decision-support triage results,
/// urgency level, recommended action, clinical rationale, and next steps.
class AssessmentResultScreen extends StatelessWidget {
  final Patient patient;
  final AssessmentResult assessment;
  final SymptomAnalysisResult? symptomAnalysis;
  final Map<String, bool>? clinicResources;

  const AssessmentResultScreen({
    super.key,
    required this.patient,
    required this.assessment,
    this.symptomAnalysis,
    this.clinicResources,
  });

  String get _recommendedActionText {
    switch (assessment.recommendedAction) {
      case RecommendedAction.manageLocally:
        return 'Manage Locally';
      case RecommendedAction.referralRecommended:
        return 'Referral Recommended';
      case RecommendedAction.immediateReferral:
        return 'Immediate Referral Required';
    }
  }

  Color get _urgencyColor {
    switch (assessment.urgencyLevel) {
      case UrgencyLevel.routine:
        return AppColors.statusGreen;
      case UrgencyLevel.urgent:
        return AppColors.statusAmber;
      case UrgencyLevel.emergency:
        return AppColors.statusRed;
    }
  }

  Color get _urgencyBgColor {
    switch (assessment.urgencyLevel) {
      case UrgencyLevel.routine:
        return AppColors.statusGreenBg;
      case UrgencyLevel.urgent:
        return AppColors.statusAmberBg;
      case UrgencyLevel.emergency:
        return AppColors.statusRedBg;
    }
  }

  IconData get _actionIcon {
    switch (assessment.recommendedAction) {
      case RecommendedAction.manageLocally:
        return Icons.medical_services_outlined;
      case RecommendedAction.referralRecommended:
        return Icons.forward_to_inbox_rounded;
      case RecommendedAction.immediateReferral:
        return Icons.notification_important_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conditionCat = assessment.conditionCategory ?? patient.conditionCategory;
    final clinicLoc = DefaultLocationService().currentClinicLocation;
    final recommendations = const ClinicalHospitalMatchingService().evaluateRecommendations(
      patient: patient,
      assessment: assessment,
      availableHospitals: IndoreHospitalDataset.allFacilities,
      clinicLatitude: clinicLoc.latitude,
      clinicLongitude: clinicLoc.longitude,
      conditionCategory: conditionCat,
    );

    final effectiveAnalysis = symptomAnalysis ??
        OfflineClinicalRuleEngine.evaluate(
          freeText: patient.clinicalFindings.isNotEmpty
              ? patient.clinicalFindings
              : (patient.injuryOrIllnessDetails.isNotEmpty
                  ? patient.injuryOrIllnessDetails
                  : patient.mainComplaint),
          patientId: patient.patientId,
          systolicBP: patient.systolicBP,
          diastolicBP: patient.diastolicBP,
          heartRate: patient.heartRate,
          oxygenSaturation: patient.oxygenSaturation,
          temperature: patient.temperature,
          respiratoryRate: patient.respiratoryRate,
          selectedTags: patient.symptoms,
          age: patient.age,
          sex: patient.sex.displayName,
        );

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            AppHeader(
              title: 'Assessment Result',
              subtitle: 'Clinical Decision-Support Evaluation',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => SafeNavigation.pop(context, fallbackTab: 1),
                tooltip: 'Return to entered information',
              ),
              showClinicStatusBar: false,
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clinical Advisory Notice
                    _buildClinicalAdvisoryNotice(),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Primary Urgency & Recommended Action Card
                    AppCard(
                      accentColor: _urgencyColor,
                      padding: const EdgeInsets.all(AppConstants.spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Triage Urgency Level',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textNavyPrimary,
                                ),
                              ),
                              UrgencyBadge(urgencyLevel: assessment.urgencyLevel),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spacingMd),
                          Container(
                            padding: const EdgeInsets.all(AppConstants.spacingMd),
                            decoration: BoxDecoration(
                              color: _urgencyBgColor,
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                              border: Border.all(
                                color: _urgencyColor.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _actionIcon,
                                    size: 24,
                                    color: _urgencyColor,
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spacingMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Recommended Action',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textNavyMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _recommendedActionText,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: _urgencyColor,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Clinical AI & Offline Decision Support Card
                    _buildGeminiAndOfflineAnalysisCard(context, theme, effectiveAnalysis),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Disease Acuity Protocol Card
                    _buildDiseaseProtocolCard(theme),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Reasons & Clinical Rationale Card
                    AppCard(
                      title: 'Clinical Evaluation Reasons',
                      subtitle: 'Protocol-based rationale derived from symptoms & vitals',
                      leadingIcon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightMint,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        child: const Icon(
                          Icons.rule_folder_outlined,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (assessment.dangerSignsDetected.isNotEmpty) ...[
                            Text(
                              'Alerts & Danger Signs Detected:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.statusRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...assessment.dangerSignsDetected.map(
                              (danger) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: AppColors.statusRed,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        danger,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.statusRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingMd),
                          ],
                          Text(
                            'Decision Rationale:',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.textNavyPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...assessment.clinicalRationale.map(
                            (reason) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      reason,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textNavySecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingMd),
                          const Divider(color: AppColors.borderLight, height: 1),
                          const SizedBox(height: AppConstants.spacingMd),
                          Row(
                            children: [
                              const Icon(
                                Icons.medical_information_outlined,
                                size: 16,
                                color: AppColors.secondarySlateTeal,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Matched Specialty: ${assessment.requiredSpecialty}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textNavyPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (assessment.requiredFacilities.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.local_hospital_outlined,
                                  size: 16,
                                  color: AppColors.secondarySlateTeal,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Recommended Facilities: ${assessment.requiredFacilities.join(", ")}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textNavySecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (assessment.conditionCategory != null || patient.conditionCategory != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.category_outlined,
                                  size: 16,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Condition Category: ${(assessment.conditionCategory ?? patient.conditionCategory)!.displayName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDarkGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Ranked Referral Hospitals Section
                    _buildRankedReferralHospitalsSection(context, theme, recommendations),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Patient Summary Review Card
                    const SectionHeader(
                      title: 'Patient Record Summary',
                      subtitle: 'Information entered for this assessment',
                    ),
                    PatientInfoCard(
                      patient: patient,
                      trailingBadge: UrgencyBadge(
                        urgencyLevel: assessment.urgencyLevel,
                        isCompact: true,
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingLg),

                    // ⚡ High-Visibility Emergency Quick Referral Action
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flash_on, color: Colors.white),
                        label: const Text(
                          '⚡ EMERGENCY QUICK REFERRAL (108 AMBULANCE)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EmergencyQuickReferralScreen(
                                initialComplaint: patient.mainComplaint,
                                patientName: patient.patientId,
                                patientAge: patient.age,
                                patientSex: patient.sex.displayName,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingSm),

                    // Action Buttons
                    PrimaryButton(
                      text: assessment.recommendedAction == RecommendedAction.manageLocally
                          ? 'Save Local Care Observation'
                          : 'Proceed to Hospital Recommendations',
                      icon: assessment.recommendedAction == RecommendedAction.manageLocally
                          ? Icons.save_outlined
                          : Icons.near_me_outlined,
                      onPressed: () async {
                        if (assessment.recommendedAction == RecommendedAction.manageLocally) {
                          final now = DateTime.now();
                          final observation = Referral(
                            referralId: 'OBS-${now.millisecondsSinceEpoch.toString().substring(5)}',
                            patient: patient,
                            urgencyLevel: assessment.urgencyLevel,
                            referralReason: assessment.clinicalRationale.isNotEmpty
                                ? assessment.clinicalRationale.first
                                : 'Local clinic observation and outpatient management protocol.',
                            requiredSpecialty: assessment.requiredSpecialty,
                            requiredFacilities: assessment.requiredFacilities,
                            status: ReferralStatus.completed,
                            statusHistory: [
                              ReferralStatusHistory(
                                status: ReferralStatus.completed,
                                timestamp: now,
                                note: 'Observation plan saved in local clinic registry. Outpatient care protocol active.',
                              ),
                            ],
                            createdAt: now,
                            updatedAt: now,
                            referringClinic: 'Primary Health Center Sector 4',
                          );

                          await LocalReferralRepository.instance.saveReferral(observation);
                          await OfflineAssessmentStorageService.instance.saveAssessmentLocally(effectiveAnalysis);
                          await OfflineAssessmentStorageService.instance.updateLifecycleState(
                            observation.referralId,
                            ReferralLifecycleState.assessmentSaved,
                          );
                          PatientAssessmentScreen.requestFormReset();

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.primaryGreen,
                              content: Text('Observation plan ${observation.referralId} saved in local clinic registry.'),
                            ),
                          );

                          Navigator.of(context).pop(true);
                        } else {
                          final completed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (ctx) => RecommendationScreen(
                                patient: patient,
                                assessment: assessment,
                                clinicLatitude: clinicLoc.latitude,
                                clinicLongitude: clinicLoc.longitude,
                                initialHospitals: IndoreHospitalDataset.allFacilities,
                              ),
                            ),
                          );

                          if (completed == true && context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        }
                      },
                    ),

                    const SizedBox(height: AppConstants.spacingSm),

                    // Required Action: "Review Details"
                    SecondaryButton(
                      text: 'Review Details',
                      icon: Icons.edit_note_rounded,
                      onPressed: () => SafeNavigation.pop(context, fallbackTab: 1),
                    ),

                    const SizedBox(height: AppConstants.spacingXxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiAndOfflineAnalysisCard(
    BuildContext context,
    ThemeData theme,
    SymptomAnalysisResult res,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      accentColor: res.urgencyLevel.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLightMint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Clinical AI & Decision Support',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textNavyPrimary,
                    ),
                  ),
                ],
              ),
              _buildAnalysisSourceBadge(res),
            ],
          ),
          const SizedBox(height: 10),

          // Red Flags Banner
          if (res.redFlags.isNotEmpty || res.urgencyLevel == ClinicalUrgencyTier.level1ImmediateEmergency) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF87171), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 6),
                      Text(
                        'MANDATORY CLINICAL RED FLAGS DETECTED',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...res.redFlags.map(
                    (rf) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• $rf',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7F1D1D)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Dual Badges Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: res.urgencyLevel.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: res.urgencyLevel.color.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Triage Urgency Tier', style: TextStyle(fontSize: 10, color: AppColors.textNavyMuted, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        res.isUndetermined
                            ? 'Urgency undetermined — clinician assessment required'
                            : res.urgencyLevel.title,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: res.urgencyLevel.color),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMutedLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondarySlateTeal.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recommended Referral Level', style: TextStyle(fontSize: 10, color: AppColors.textNavyMuted, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        res.referralLevel.title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.secondarySlateTeal),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Transparent Reasoning
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clinical Rationale & Transparent Reasoning:',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.secondarySlateTeal),
                ),
                const SizedBox(height: 3),
                Text(
                  res.reasoning,
                  style: const TextStyle(fontSize: 11, color: AppColors.textNavyPrimary),
                ),
              ],
            ),
          ),

          // Lifecycle Tracking Note
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.save_as_outlined, size: 14, color: Color(0xFF15803D)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Offline Truthfulness: Record will be stored in offline-first vault and queued for centralized sync.',
                    style: TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSourceBadge(SymptomAnalysisResult res) {
    switch (res.source) {
      case AssessmentSource.gemini:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF38BDF8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 11, color: Color(0xFF0284C7)),
              const SizedBox(width: 4),
              Text(
                'AI suggestion (${res.modelVersion})',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
              ),
            ],
          ),
        );
      case AssessmentSource.offlineRules:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.shield_outlined, size: 11, color: Color(0xFF475569)),
              SizedBox(width: 4),
              Text(
                'Offline rule-based',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ],
          ),
        );
      case AssessmentSource.clinicianOverride:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC084FC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.verified_user_outlined, size: 11, color: Color(0xFF7E22CE)),
              SizedBox(width: 4),
              Text(
                'Clinician Overridden',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8)),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildClinicalAdvisoryNotice() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Soft warm amber
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: AppColors.statusAmber.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.statusAmberBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  size: 18,
                  color: AppColors.statusAmber,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              const Expanded(
                child: Text(
                  'Clinical Decision-Support Advisory',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This is a clinical decision-support advisory and does not replace professional clinical judgment.\n'
            'Rule-based clinical triage assessment following standard healthcare protocols.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF78350F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseProtocolCard(ThemeData theme) {
    final diseaseLevel = assessment.matchedDiseaseLevel;
    if (diseaseLevel == null && assessment.matchedDiseases.isEmpty) {
      return const SizedBox.shrink();
    }

    final level = diseaseLevel ?? DiseaseAcuityDataset.level4;
    return AppCard(
      accentColor: level.color,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: level.backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(level.icon, size: 18, color: level.color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Disease Acuity Protocol',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textNavyPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: level.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: level.color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Severity ${level.severity} / 4',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: level.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            level.level,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: level.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            level.recommendation,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textNavySecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: level.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: level.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.directions_run_rounded, size: 16, color: level.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Protocol Action: ${level.typicalAction}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textNavyPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (assessment.matchedDiseases.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Matched Presentation from Acuity Protocol:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textNavyMuted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assessment.matchedDiseases.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: level.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    d,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textNavyPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // RANKED REFERRAL HOSPITALS SECTION
  // ===========================================================================

  Widget _buildRankedReferralHospitalsSection(
    BuildContext context,
    ThemeData theme,
    HospitalRecommendationResult recommendations,
  ) {
    final conditionCat = assessment.conditionCategory ?? patient.conditionCategory;
    final config = conditionCat != null
        ? ConditionSpecificRankingService.getConfiguration(conditionCat)
        : null;
    final eligible = recommendations.eligibleHospitals;
    final excluded = recommendations.excludedHospitals;
    final isLocal = assessment.recommendedAction == RecommendedAction.manageLocally;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: isLocal
              ? 'Nearby Referral Hospitals (Standby Transfer)'
              : 'Ranked Referral Hospitals',
          subtitle: isLocal
              ? 'Standby regional facilities if patient condition deteriorates'
              : 'Condition-prioritized destinations evaluated for capacity, specialty, and travel time',
          customAction: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryLightMint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${eligible.length} Suitable',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDarkGreen,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        if (conditionCat != null && config != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Prioritization Rule: ${conditionCat.displayName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDarkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  config.summaryDescription,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textNavySecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildPriorityTag('P1', config.priority1Name, true),
                    _buildPriorityTag('P2', config.priority2Name, false),
                    _buildPriorityTag('P3', config.priority3Name, false),
                    _buildPriorityTag('P4', config.priority4Name, false),
                  ],
                ),
              ],
            ),
          ),

        if (eligible.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.statusRed, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Verified Suitable Facility Found',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusRed,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'All regional network partner hospitals currently lack mandatory capabilities, bed availability, or emergency care.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...eligible.take(3).toList().asMap().entries.map((entry) {
            return _buildRankedHospitalCard(
              context,
              theme,
              entry.value,
              entry.key,
              recommendations,
            );
          }),
        ],

        if (excluded.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceMutedLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, size: 14, color: AppColors.textNavyMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${excluded.length} facilities excluded by clinical hard filters (0 beds, missing specialty/ICU, or emergency status)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textNavyMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRankedHospitalCard(
    BuildContext context,
    ThemeData theme,
    HospitalMatchResult match,
    int rankIndex,
    HospitalRecommendationResult recommendations,
  ) {
    final hosp = match.hospital;
    final score = match.matchScore.round();
    final isTop = rankIndex == 0;

    final rankBadgeColor = isTop
        ? AppColors.primaryGreen
        : (rankIndex == 1 ? AppColors.secondarySlateTeal : AppColors.textNavySecondary);
    final rankBgColor = isTop
        ? AppColors.primaryLightMint
        : (rankIndex == 1 ? const Color(0xFFE6FFFA) : AppColors.surfaceMutedLight);

    final rankTitle = isTop
        ? '#1 Recommended Destination'
        : (rankIndex == 1 ? '#2 Alternative Option' : '#3 Backup Facility');

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: isTop ? AppColors.primaryGreen.withValues(alpha: 0.4) : AppColors.borderLight,
          width: isTop ? 1.5 : 1.0,
        ),
        boxShadow: isTop
            ? [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Rank badge & Match score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: rankBgColor,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(color: rankBadgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTop ? Icons.stars_rounded : Icons.check_circle_outline,
                      size: 14,
                      color: rankBadgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rankTitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: rankBadgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: score >= 85
                      ? AppColors.statusGreenBg
                      : (score >= 70 ? AppColors.statusAmberBg : AppColors.surfaceMutedLight),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(
                    color: score >= 85 ? AppColors.statusGreen : AppColors.statusAmber,
                  ),
                ),
                child: Text(
                  '$score/100 Match',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: score >= 85 ? AppColors.primaryDarkGreen : AppColors.textNavyPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hospital Name & Address
          Text(
            hosp.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textNavyPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hosp.address,
            style: const TextStyle(fontSize: 12, color: AppColors.textNavyMuted),
          ),
          const SizedBox(height: 10),

          // Operational metrics chip container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceMutedLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.secondarySlateTeal),
                    const SizedBox(width: 4),
                    Text(
                      '~${match.travelTime.inMinutes}m (${match.distanceKm.toStringAsFixed(1)}km / ~${(match.distanceKm * 1000).round()}m)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.airline_seat_flat_rounded, size: 14, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${hosp.bedAvailability} beds',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDarkGreen),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_hospital_outlined, size: 14, color: AppColors.statusAmber),
                    const SizedBox(width: 4),
                    Text(
                      '${hosp.availability?.icuBedsAvailable ?? (hosp.icuAvailable ? "Equipped" : 0)} ICU',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emergency_outlined, size: 14, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      hosp.emergencyCare ? '24/7 ED' : 'No ED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hosp.emergencyCare ? AppColors.primaryDarkGreen : AppColors.statusRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Clinical Justification summary
          if (match.conditionRanking != null &&
              match.conditionRanking!.priorityEvaluations.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: match.conditionRanking!.priorityEvaluations.take(2).map((pe) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: pe.satisfied ? AppColors.primaryLightMint : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: pe.satisfied ? AppColors.primaryGreen : AppColors.borderLight,
                    ),
                  ),
                  child: Text(
                    'P${pe.priorityNumber}: ${pe.name}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: pe.satisfied ? AppColors.primaryDarkGreen : AppColors.textNavySecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ] else ...[
            Text(
              'Matched Specialty: ${hosp.specialties.contains(assessment.requiredSpecialty) ? assessment.requiredSpecialty : hosp.specialties.first}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textNavySecondary,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Card Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToReferralSummary(context, match, recommendations),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTop ? AppColors.primaryGreen : AppColors.secondarySlateTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text(
                    'Select Destination',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => HospitalDetailsScreen(hospital: hosp),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondarySlateTeal,
                  side: const BorderSide(color: AppColors.borderLight),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                ),
                icon: const Icon(Icons.info_outline, size: 15),
                label: const Text(
                  'Details',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityTag(String pNum, String name, bool isP1) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isP1 ? AppColors.primaryLightMint : AppColors.surfaceMutedLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isP1 ? AppColors.primaryGreen : AppColors.borderLight,
        ),
      ),
      child: Text(
        '$pNum: $name',
        style: TextStyle(
          fontSize: 10,
          fontWeight: isP1 ? FontWeight.w800 : FontWeight.w600,
          color: isP1 ? AppColors.primaryDarkGreen : AppColors.textNavyPrimary,
        ),
      ),
    );
  }

  Future<void> _navigateToReferralSummary(
    BuildContext context,
    HospitalMatchResult match,
    HospitalRecommendationResult recommendations,
  ) async {
    final hosp = match.hospital;
    final now = DateTime.now();

    final referral = Referral(
      referralId: 'REF-${now.millisecondsSinceEpoch.toString().substring(7)}',
      patient: patient,
      urgencyLevel: assessment.urgencyLevel,
      referralReason: assessment.clinicalRationale.isNotEmpty
          ? assessment.clinicalRationale.first
          : 'Clinical referral recommended for specialist evaluation and higher-tier management.',
      requiredSpecialty: assessment.requiredSpecialty,
      requiredFacilities: assessment.requiredFacilities,
      recommendedHospital: hosp,
      alternativeHospitals: recommendations.eligibleHospitals
          .where((alt) => alt.hospital.hospitalId != hosp.hospitalId)
          .map((alt) => alt.hospital)
          .toList(),
      estimatedDistance: match.distanceKm,
      estimatedTravelTime: match.travelTime,
      recommendationScore: match.matchScore,
      status: ReferralStatus.pending,
      statusHistory: [
        ReferralStatusHistory(
          status: ReferralStatus.pending,
          timestamp: now,
          note: 'Destination facility (${hosp.name}) selected directly from clinical assessment triage.',
        ),
      ],
      createdAt: now,
      updatedAt: now,
      referringClinic: 'Primary Health Center Sector 4',
    );

    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (ctx) => ReferralSummaryScreen(referral: referral),
      ),
    );

    if (completed == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
