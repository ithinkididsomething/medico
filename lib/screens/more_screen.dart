import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/disease_acuity.dart';
import '../repositories/hospital_repository.dart';
import '../repositories/offline_first_hospital_repository.dart';
import '../services/auth_service.dart';
import '../services/doctor_profile_service.dart';
import '../services/location_service.dart';
import '../widgets/app_card.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/danger_button.dart';
import '../widgets/medical_disclaimer.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/sync_status_indicator.dart';
import 'auth/login_screen.dart';
import 'hospital/clinic_location_dialog.dart';
import 'profile/doctor_profile_screen.dart';
import 'profile/edit_doctor_profile_dialog.dart';

/// Clinic Settings, Clinician Profile, Diagnostics, and Ethics Guidelines Screen.
class MoreScreen extends StatefulWidget {
  final LocationService? locationService;
  final HospitalRepository? hospitalRepository;

  const MoreScreen({
    super.key,
    this.locationService,
    this.hospitalRepository,
  });

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  late final LocationService _locationService;
  late final HospitalRepository _hospitalRepository;

  String _activeWorkerName = 'Dr. Parth Saxena';
  String _activeWorkerRole = 'Medical Officer (Triage Lead)';

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? DefaultLocationService();
    _hospitalRepository = widget.hospitalRepository ?? OfflineFirstHospitalRepository.instance;
  }

  void _showClinicLocationDialog() {
    ClinicLocationDialog.show(
      context,
      locationService: _locationService,
      onLocationChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _showDiagnosticsDialog() async {
    final curLoc = _locationService.currentClinicLocation;
    final hospitals = await _hospitalRepository.getAllHospitals();

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLightMint,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: const Icon(
                Icons.network_check_rounded,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'System Diagnostics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDiagRow(
                'Local Storage & Cache',
                'Connected (SharedPreferences / Offline)',
                Icons.check_circle_rounded,
                AppColors.statusGreen,
              ),
              _buildDiagRow(
                'Simulated Routing Engine',
                'Active (Haversine + 1.25 Rural Winding)',
                Icons.check_circle_rounded,
                AppColors.statusGreen,
              ),
              _buildDiagRow(
                'Central Backend Sync Engine',
                'Status: ${OfflineFirstHospitalRepository.instance.syncEngine.status.label} • Rev: ${OfflineFirstHospitalRepository.instance.syncEngine.status.localRevision}',
                Icons.cloud_sync_rounded,
                AppColors.statusGreen,
              ),
              _buildDiagRow(
                'Hospital Network Feed',
                '${hospitals.length} Healthcare Facilities Available',
                Icons.check_circle_rounded,
                AppColors.statusGreen,
              ),
              _buildDiagRow(
                'Active Base Location',
                '${curLoc.name} (${curLoc.latitude.toStringAsFixed(2)}, ${curLoc.longitude.toStringAsFixed(2)})',
                Icons.place_rounded,
                AppColors.secondarySlateTeal,
              ),
              _buildDiagRow(
                'Live Telemetry Status',
                'Operational Mode (Local Clinic Coordinates Active)',
                Icons.check_circle_outline_rounded,
                AppColors.statusGreen,
              ),
            ],
          ),
        ),
        actions: [
          PrimaryButton(
            text: 'Close Diagnostics',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String detail, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showShiftWorkerDialog() {
    final nameCtrl = TextEditingController(text: _activeWorkerName);
    final roleCtrl = TextEditingController(text: _activeWorkerRole);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        title: const Text(
          'Switch Clinician / Shift',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Healthcare Worker Name',
                hintText: 'e.g. Dr. Ramesh Kumar',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(
                labelText: 'Clinical Role / Cadre',
                hintText: 'e.g. Community Health Officer',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _activeWorkerName = nameCtrl.text.trim();
                  _activeWorkerRole = roleCtrl.text.trim();
                });
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Active shift updated: $_activeWorkerName'),
                ),
              );
            },
            child: const Text('Update Shift'),
          ),
        ],
      ),
    );
  }

  void _showEthicsDisclaimerDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.statusAmber, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Clinical Decision Support Scope',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppConstants.productPositioningHeadline,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textNavyPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppConstants.productPositioningDetail,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textNavySecondary,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.borderLight, height: 1),
              const SizedBox(height: 12),
              Text(
                AppConstants.medicalDisclaimerText,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textNavySecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          PrimaryButton(
            text: 'I Understand',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showDiseaseProtocolDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLightMint,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: const Icon(
                Icons.medical_information_outlined,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Disease Triage Matrix',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '4-Tier clinical disease classification protocol for primary health care & referral dispatch (gemini-code-1791532188800).',
                  style: TextStyle(fontSize: 12, color: AppColors.textNavySecondary),
                ),
                const SizedBox(height: 12),
                ...DiseaseAcuityDataset.allLevels.reversed.map((level) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: level.backgroundColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: level.color.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              level.level,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: level.color),
                            ),
                            Text(
                              'Sev. ${level.severity}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: level.color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          level.recommendation,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Action: ${level.typicalAction}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: level.color),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: level.examples
                              .map((ex) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: level.color.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      ex,
                                      style: const TextStyle(fontSize: 10, color: AppColors.textNavyPrimary),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          PrimaryButton(
            text: 'Close Guide',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _handleSignOut() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign Out Session',
      message:
          'Are you sure you want to log out of your clinical session? You will be returned to the Doctor / Clinic Sign In screen.',
      confirmText: 'Sign Out',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed && mounted) {
      await LocalDemoAuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final curLoc = _locationService.currentClinicLocation;
    final profileService = DoctorProfileService.instance;

    return ListenableBuilder(
      listenable: profileService,
      builder: (context, _) {
        final doctorProfile = profileService.currentProfile;
        final authUser = LocalDemoAuthService.instance.currentUser;
        final effectiveClinician = doctorProfile.fullName.isNotEmpty ? doctorProfile.fullName : (authUser?.fullName ?? _activeWorkerName);
        final effectiveRole = doctorProfile.designation.isNotEmpty ? doctorProfile.designation : (authUser?.roleLabel ?? _activeWorkerRole);
        final effectiveFacility = doctorProfile.clinicOrHospital.isNotEmpty ? doctorProfile.clinicOrHospital : (authUser?.facilityAffiliation ?? curLoc.name);
        final verificationStatus = doctorProfile.verificationStatus;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MedicalDisclaimer(),
              const SizedBox(height: AppConstants.spacingSm),
              AppCard(
                title: 'Clinician Account & Doctor Profile',
                subtitle: 'Active credentials, specialization and session management',
                leadingIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLightMint,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primaryDarkGreen,
                    size: 22,
                  ),
                ),
                accentColor: AppColors.primaryGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Doctor Name', effectiveClinician),
                    _buildInfoRow('Qualifications', doctorProfile.qualifications),
                    _buildInfoRow('Specialization', doctorProfile.specialization),
                    _buildInfoRow('Registration No.', doctorProfile.medicalRegNumber),
                    _buildInfoRow('Designation', effectiveRole),
                    _buildInfoRow('Affiliated Facility', effectiveFacility),
                    _buildInfoRow('Official Contact', doctorProfile.phoneNumber),
                    _buildInfoRow('Verification Status', verificationStatus),
                    const SizedBox(height: AppConstants.spacingMd),
                    PrimaryButton(
                      text: 'View Doctor Profile',
                      icon: Icons.person_outline_rounded,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DoctorProfileScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppConstants.spacingSm),
                    SecondaryButton(
                      text: 'Edit Profile Information',
                      icon: Icons.edit_note_rounded,
                      onPressed: () {
                        EditDoctorProfileDialog.show(
                          context,
                          DoctorProfileService.instance.currentProfile,
                        );
                      },
                    ),
                    const SizedBox(height: AppConstants.spacingSm),
                    DangerButton(
                      text: 'Sign Out / Switch Account',
                      icon: Icons.logout_rounded,
                      isOutlined: true,
                      onPressed: _handleSignOut,
                    ),
                  ],
                ),
              ),
          const SizedBox(height: AppConstants.spacingSm),
          AppCard(
            title: 'Clinic Profile & Configuration',
            subtitle: 'Offline sync settings, credentials & protocols',
            leadingIcon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLightMint,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: AppColors.primaryGreen,
                size: 22,
              ),
            ),
            accentColor: AppColors.secondarySlateTeal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Environment Information:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textNavyPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                _buildInfoRow('Application Version', AppConstants.appVersion),
                _buildInfoRow('Active Clinician', '$_activeWorkerName ($_activeWorkerRole)'),
                _buildInfoRow('Active Facility Base', curLoc.name),
                _buildInfoRow('Deployment Mode', 'Primary Health Post / Offline-First'),
                _buildInfoRow('Triage Protocol Guidelines', 'WHO / National Rural Referral 2026'),
                _buildInfoRow('Design System', 'Material 3 Healthcare Theme'),
                const SizedBox(height: AppConstants.spacingLg),
                PrimaryButton(
                  text: 'Central Registry Synchronization',
                  icon: Icons.cloud_sync_rounded,
                  onPressed: () => showSyncDetailsSheet(context),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                SecondaryButton(
                  text: 'Clinic Location & GPS Settings',
                  icon: Icons.place_outlined,
                  onPressed: _showClinicLocationDialog,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                SecondaryButton(
                  text: 'Test Diagnostics & Connectivity',
                  icon: Icons.network_check_rounded,
                  onPressed: _showDiagnosticsDialog,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                SecondaryButton(
                  text: 'Switch Clinic Shift / Worker',
                  icon: Icons.person_outline_rounded,
                  onPressed: _showShiftWorkerDialog,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                SecondaryButton(
                  text: 'Clinical Decision Support Scope & Ethics',
                  icon: Icons.shield_outlined,
                  onPressed: _showEthicsDisclaimerDialog,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                SecondaryButton(
                  text: 'Disease Triage Acuity Matrix (Levels 1-4)',
                  icon: Icons.medical_information_outlined,
                  onPressed: _showDiseaseProtocolDialog,
                ),
              ],
            ),
          ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textNavyMuted,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textNavyPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
