import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/doctor_profile_data.dart';
import '../../services/doctor_profile_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import 'edit_doctor_profile_dialog.dart';

/// Doctor Profile screen presenting the currently logged-in clinician's
/// qualifications, regulatory credentials, affiliated hospital/clinic, and contact info.
/// Fully operational offline with immediate session synchronization.
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = DoctorProfileService.instance;

    return ListenableBuilder(
      listenable: profileService,
      builder: (context, _) {
        final profile = profileService.currentProfile;

        return AppScaffold(
          title: 'Doctor Profile',
          subtitle: 'Active Clinical Session & Credentials',
          showClinicStatusBar: true,
          facilityName: profile.clinicOrHospital,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGreen),
              tooltip: 'Edit Profile',
              onPressed: () => _openEditDialog(context, profile),
            ),
          ],
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Doctor Hero Identity Card
                _buildDoctorHeroCard(context, profile),

                const SizedBox(height: AppConstants.spacingMd),

                // 2. Medical Credentials & Regulatory Registration Card
                _buildQualificationsCard(profile),

                const SizedBox(height: AppConstants.spacingMd),

                // 3. Affiliated Clinic & Practice Setting Card
                _buildFacilityCard(profile),

                const SizedBox(height: AppConstants.spacingMd),

                // 4. Contact & Telecommunications Card
                _buildContactCard(profile),

                const SizedBox(height: AppConstants.spacingMd),

                // 5. Clinical Certifications & Capabilities Card
                _buildCapabilitiesCard(profile),

                const SizedBox(height: AppConstants.spacingMd),

                // 6. Offline Data & Session Security Notice Card
                _buildOfflineSessionCard(profile),

                const SizedBox(height: AppConstants.spacingXl),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEditDialog(BuildContext context, DoctorProfileData profile) async {
    final updated = await EditDoctorProfileDialog.show(context, profile);
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Doctor profile updated successfully'),
            ],
          ),
          backgroundColor: AppColors.statusGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ===========================================================================
  // 1. HERO IDENTITY CARD
  // ===========================================================================
  Widget _buildDoctorHeroCard(BuildContext context, DoctorProfileData profile) {
    // Generate initials for avatar
    final initials = profile.fullName
        .replaceAll('Dr.', '')
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2B3C),
            Color(0xFF0F4C5C),
            Color(0xFF0D7A68),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2B3C).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Verification badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with doctor styling & online badge
              Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'DR',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verification pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Color(0xFF6EE7B7), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            profile.verificationStatus.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6EE7B7),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Doctor Name
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Designation
                    Text(
                      profile.designation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // Bottom quick info chips & Edit Profile Action Button
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildHeroBadge(Icons.medical_services_outlined, profile.specialization),
              _buildHeroBadge(Icons.badge_outlined, profile.medicalRegNumber),
              _buildHeroBadge(Icons.timelapse_rounded, '${profile.experienceYears} Years Exp.'),
            ],
          ),

          const SizedBox(height: 16),

          // Action Button: Edit Profile
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDarkGreen,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text(
                'Edit Doctor Profile',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              onPressed: () => _openEditDialog(context, profile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. QUALIFICATIONS & CREDENTIALS
  // ===========================================================================
  Widget _buildQualificationsCard(DoctorProfileData profile) {
    return AppCard(
      title: 'Medical Qualifications & Credentials',
      subtitle: 'Accredited degrees and statutory medical council registration',
      leadingIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryLightMint,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
        child: const Icon(
          Icons.school_rounded,
          color: AppColors.primaryGreen,
          size: 20,
        ),
      ),
      accentColor: AppColors.primaryGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Primary Qualifications', profile.qualifications, isBold: true),
          _buildDetailRow('Clinical Specialization', profile.specialization, isBold: true),
          _buildDetailRow('Registration Number', profile.medicalRegNumber, isCode: true),
          _buildDetailRow('State Medical Council', profile.councilName),
          _buildDetailRow('Clinical Experience', '${profile.experienceYears} Years Active Practice'),
          _buildDetailRow('Department', profile.department),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. AFFILIATED FACILITY & BASE
  // ===========================================================================
  Widget _buildFacilityCard(DoctorProfileData profile) {
    return AppCard(
      title: 'Facility & Practice Setting',
      subtitle: 'Current health post affiliation and clinical base',
      leadingIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryLightMint,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
        child: const Icon(
          Icons.local_hospital_rounded,
          color: AppColors.secondarySlateTeal,
          size: 20,
        ),
      ),
      accentColor: AppColors.secondarySlateTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Facility Name', profile.clinicOrHospital, isBold: true),
          _buildDetailRow('Clinical Cadre', profile.designation),
          _buildDetailRow('Facility Category', 'Primary Healthcare Centre (PHC) • Referral Origin'),
          _buildDetailRow('Geographic District', 'Indore District, Madhya Pradesh'),
          _buildDetailRow('Operating Shift', 'Day Shift & 24/7 Emergency Referral On-Call'),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. CONTACT & TELECOMMUNICATIONS
  // ===========================================================================
  Widget _buildContactCard(DoctorProfileData profile) {
    return AppCard(
      title: 'Contact Details',
      subtitle: 'Official channels for referral coordination & clinical handoff',
      leadingIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryLightMint,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
        child: const Icon(
          Icons.contact_phone_rounded,
          color: AppColors.primaryDarkGreen,
          size: 20,
        ),
      ),
      accentColor: AppColors.primaryGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Official Email', profile.email, isEmail: true),
          _buildDetailRow('Primary Mobile Number', profile.phoneNumber, isPhone: true),
          _buildDetailRow('Emergency On-Call Desk', profile.emergencyContact, isPhone: true),
          _buildDetailRow('Preferred Language', 'English / Hindi (Clinical Teleconsultation)'),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. CLINICAL CAPABILITIES & ACCREDITATIONS
  // ===========================================================================
  Widget _buildCapabilitiesCard(DoctorProfileData profile) {
    return AppCard(
      title: 'Clinical Certifications & Scope',
      subtitle: 'Verified emergency triage and clinical competencies',
      leadingIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryLightMint,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
        child: const Icon(
          Icons.verified_outlined,
          color: AppColors.tealAccentDark,
          size: 20,
        ),
      ),
      accentColor: AppColors.tealAccentDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.additionalCertifications.map((cert) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.primaryGreen, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      cert,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. OFFLINE READINESS & SESSION NOTICE
  // ===========================================================================
  Widget _buildOfflineSessionCard(DoctorProfileData profile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.statusGreenBg,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: const Icon(
              Icons.offline_pin_rounded,
              color: AppColors.statusGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Session Active',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textNavyPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Doctor credentials are saved on this device. The profile remains accessible and editable even when cellular or Wi-Fi connectivity is unavailable.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textNavyMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    bool isCode = false,
    bool isEmail = false,
    bool isPhone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textNavyMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                fontFamily: isCode ? 'monospace' : null,
                color: isEmail || isPhone ? AppColors.primaryGreen : AppColors.textNavyPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
