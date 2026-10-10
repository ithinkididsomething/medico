import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/doctor_registration.dart';
import '../../navigation/app_navigation.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import 'doctor_registration_screen.dart';
import 'login_screen.dart';

/// Screen displaying the real-time regulatory verification status of a doctor's profile.
/// Supports Pending Review, Verified Profile, and Rejected / Needs Information states.
class DoctorVerificationStatusScreen extends StatelessWidget {
  final DoctorRegistrationModel doctor;
  final bool isNewlySubmitted;

  const DoctorVerificationStatusScreen({
    super.key,
    required this.doctor,
    this.isNewlySubmitted = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = doctor.verificationStatus.toLowerCase();
    final isVerified = status == 'verified';
    final isRejected = status == 'rejected' || status == 'needs_more_info';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Doctor Credential Status',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => LoginScreen()),
              (r) => false,
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Status Banner Card
              _buildStatusBanner(context, isVerified, isRejected),

              const SizedBox(height: AppConstants.spacingMd),

              // Doctor Profile & Credential Summary
              _buildDoctorInfoCard(),

              const SizedBox(height: AppConstants.spacingMd),

              // 4-Pillar Normalized Capability Score Card
              if (doctor.capabilityScore != null)
                _buildCapabilityScoreCard(doctor.capabilityScore!),

              const SizedBox(height: AppConstants.spacingMd),

              // Clinical Affiliations & Capabilities
              _buildAffiliationCard(),

              const SizedBox(height: AppConstants.spacingLg),

              // Actions
              if (isVerified)
                PrimaryButton(
                  text: 'Enter Doctor Clinical Dashboard',
                  icon: Icons.dashboard_rounded,
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const MainNavigationScreen(),
                        settings: const RouteSettings(name: '/dashboard'),
                      ),
                      (r) => false,
                    );
                  },
                )
              else if (isRejected) ...[
                PrimaryButton(
                  text: 'Update Credentials & Resubmit',
                  icon: Icons.edit_note_rounded,
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const DoctorRegistrationScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  text: 'Return to Sign In',
                  icon: Icons.login_rounded,
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(builder: (_) => LoginScreen()),
                      (r) => false,
                    );
                  },
                ),
              ] else ...[
                PrimaryButton(
                  text: 'Return to Doctor Login',
                  icon: Icons.login_rounded,
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(builder: (_) => LoginScreen()),
                      (r) => false,
                    );
                  },
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  text: 'Explore Referral Network (Demo Mode)',
                  icon: Icons.explore_rounded,
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const MainNavigationScreen(),
                        settings: const RouteSettings(name: '/dashboard'),
                      ),
                      (r) => false,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, bool isVerified, bool isRejected) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String title;
    String description;

    if (isVerified) {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFBBF7D0);
      text = const Color(0xFF15803D);
      icon = Icons.verified_rounded;
      title = 'Officially Verified Medical Practitioner';
      description = 'Credentials validated against authoritative medical registry. Full referral dispatch and consultation authority active.';
    } else if (isRejected) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      text = const Color(0xFFB91C1C);
      icon = Icons.warning_amber_rounded;
      title = 'Application Requires Additional Verification';
      description = doctor.rejectionReason ??
          'The verifying authority requested updated registration documents or council renewal details.';
    } else {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFB45309);
      icon = Icons.hourglass_top_rounded;
      title = isNewlySubmitted
          ? 'Application Submitted for Verification'
          : 'Pending Regulatory Council Verification';
      description = 'Your credentials have been queued for authorized manual review by the District Health Authority / Medical Council. Estimated review turnaround: 24–48 hours.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: text, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: text),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 11.5, color: text.withValues(alpha: 0.9), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorInfoCard() {
    return AppCard(
      title: 'Doctor Credential Profile',
      subtitle: 'Council registration and clinical qualification summary',
      child: Column(
        children: [
          _buildDetailRow('Full Legal Name', doctor.fullName),
          _buildDetailRow('Medical Council', doctor.councilName),
          _buildDetailRow('Registration Number', doctor.medicalRegNumber),
          _buildDetailRow('Qualification', '${doctor.primaryQualificationName} (${doctor.awardingInstitution})'),
          _buildDetailRow('Primary Specialty', doctor.primarySpecialty),
          _buildDetailRow('Total Experience', '${doctor.totalExperienceYears} Years in clinical care'),
          _buildDetailRow('Registered Email', doctor.email),
          _buildDetailRow('Mobile Number', '+91 ${doctor.phoneNumber}'),
        ],
      ),
    );
  }

  Widget _buildCapabilityScoreCard(DoctorCapabilityScore score) {
    return AppCard(
      title: '4-Pillar Fair Normalized Capability Score',
      subtitle: score.isProvisional
          ? 'Provisional assessment pending credential verification'
          : 'Verified composite capability score',
      leadingIcon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primaryLightMint,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.analytics_rounded, color: AppColors.primaryGreen, size: 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Score Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${score.totalCapabilityScore.toStringAsFixed(1)} / 100',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textNavyPrimary,
                    ),
                  ),
                  Text(
                    score.isProvisional ? 'PROVISIONAL SCORE' : 'VERIFIED SCORE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: score.isProvisional ? AppColors.statusAmber : AppColors.statusGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'WHO / IMA Fair Framework',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryDarkGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4-Pillar Bars
          _buildPillarBar(
            '1. Base Medical Expertise',
            score.baseExpertiseScore,
            30.0,
            const Color(0xFF2563EB),
          ),
          _buildPillarBar(
            '2. Clinical Experience',
            score.clinicalExperienceScore,
            30.0,
            const Color(0xFF059669),
          ),
          _buildPillarBar(
            '3. Clinical Volume & Impact',
            score.clinicalVolumeScore,
            25.0,
            const Color(0xFFD97706),
          ),
          _buildPillarBar(
            '4. Professional Standing',
            score.professionalStandingScore,
            15.0,
            const Color(0xFF7C3AED),
          ),

          const SizedBox(height: 8),
          Text(
            'Normalized Scoring Note: Evaluates clinic continuity and hospital procedure caseloads equivalently so independent clinic doctors and hospital physicians are scored fairly.',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarBar(String title, double score, double maxScore, Color color) {
    final pct = (score / maxScore).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyPrimary)),
              Text(
                '${score.toStringAsFixed(1)} / ${maxScore.toInt()}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliationCard() {
    return AppCard(
      title: 'Practice & Clinical Capabilities',
      subtitle: 'Facility affiliation and clinical service scope',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Practice Environment', doctor.primaryPracticeEnvironment.replaceAll('_', ' ').toUpperCase()),
          _buildDetailRow('Affiliated Facility', doctor.facilityName),
          _buildDetailRow('Current Designation', doctor.currentDesignation),
          _buildDetailRow('Clinical Unit', doctor.department),
          const SizedBox(height: 10),
          const Text(
            'Claimed Capabilities:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: doctor.capabilities.map((cap) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Text(
                  cap,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primaryDarkGreen),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
