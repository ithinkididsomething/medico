import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/disease_acuity.dart';
import '../models/enums.dart';
import '../models/referral.dart';
import '../repositories/referral_repository.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/animations/animations.dart';
import '../widgets/sync_status_indicator.dart';
import 'emergency/emergency_quick_referral_screen.dart';
import 'emergency/emergency_referral_dashboard_screen.dart';
import '../services/doctor_profile_service.dart';
import 'profile/doctor_profile_screen.dart';

/// Professional, Graphic Clinical Command Dashboard for MEDICO.
///
/// Features:
/// - Real-time Regional Emergency Network Telemetry Banner
/// - Doctor Welcome & Active Health Center Identification (Dr. Parth Saxena)
/// - High-Impact Graphic Triage & Hospital Launchpads
/// - Active Clinical Triage Registry Counters (Live Case Distribution)
/// - 4-Tier Disease Acuity Matrix Visualizer
/// - Visual 4-Stage Patient Transit Workflow Pipeline
/// - Recent Active Transfers Registry Feed
class DashboardScreen extends StatefulWidget {
  final VoidCallback? onStartAssessment;
  final void Function([ReferralFilterTag? filterTag])? onViewReferrals;
  final VoidCallback? onViewHospitals;
  final ReferralRepository? repository;

  const DashboardScreen({
    super.key,
    this.onStartAssessment,
    this.onViewReferrals,
    this.onViewHospitals,
    this.repository,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ReferralRepository _repository;
  List<Referral> _recentReferrals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalReferralRepository.instance;
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final all = await _repository.getAllReferrals();
      if (mounted) {
        setState(() {
          _recentReferrals = all;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDiseaseProtocolGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.primaryGreen, size: 24),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Disease Triage Acuity Matrix',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textNavyPrimary,
                                ),
                              ),
                              Text(
                                'WHO-aligned 4-level triage & emergency dispatch protocol',
                                style: TextStyle(fontSize: 11, color: AppColors.textNavyMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppConstants.spacingMd),
                      itemCount: DiseaseAcuityDataset.allLevels.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spacingMd),
                      itemBuilder: (context, index) {
                        final level = DiseaseAcuityDataset.allLevels[DiseaseAcuityDataset.allLevels.length - 1 - index];
                        return Container(
                          decoration: BoxDecoration(
                            color: level.backgroundColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            border: Border.all(color: level.color.withValues(alpha: 0.4), width: 1.2),
                          ),
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(level.icon, size: 18, color: level.color),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      level.level,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: level.color),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: level.color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Severity ${level.severity}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                level.recommendation,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textNavyPrimary),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.directions_run_rounded, size: 14, color: level.color),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Action: ${level.typicalAction}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: level.color),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Conditions & Symptoms:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textNavyMuted),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: level.examples.map((ex) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: level.color.withValues(alpha: 0.25)),
                                    ),
                                    child: Text(
                                      ex,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: level.color,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _recentReferrals.where((r) => r.status == ReferralStatus.pending).length;
    final inTransitCount = _recentReferrals.where((r) => r.status == ReferralStatus.transferred).length;
    final emergencyCount = _recentReferrals.where((r) => r.urgencyLevel == UrgencyLevel.emergency).length;
    final completedCount = _recentReferrals.where((r) => r.status == ReferralStatus.completed).length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Graphic Medical Command Banner
          EntranceFader(
            delay: const Duration(milliseconds: 0),
            child: _buildHeroGraphicCommandBanner(),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // 2. High-Impact Graphic Action Launchpads
          EntranceFader(
            delay: const Duration(milliseconds: 60),
            child: _buildGraphicActionLaunchpads(),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // 3. Active Clinical Triage Registry Counters
          EntranceFader(
            delay: const Duration(milliseconds: 120),
            child: _buildMetricsGrid(
              total: _recentReferrals.length,
              emergency: emergencyCount,
              inTransit: inTransitCount,
              pending: pendingCount,
              completed: completedCount,
            ),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // 4. Quick Triage Actions Card (Secondary Trigger Bar)
          EntranceFader(
            delay: const Duration(milliseconds: 180),
            child: _buildQuickActionsCard(),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // 5. 4-Tier Clinical Acuity Protocol Visual Matrix
          EntranceFader(
            delay: const Duration(milliseconds: 240),
            child: _buildAcuityFrameworkCard(),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // 6. Visual 4-Stage Patient Transit Workflow Pipeline
          EntranceFader(
            delay: const Duration(milliseconds: 300),
            child: _buildWorkflowCard(),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // 7. Recent Active Transfers Registry Feed
          EntranceFader(
            delay: const Duration(milliseconds: 360),
            child: _buildRecentReferralsFeed(),
          ),

          const SizedBox(height: AppConstants.spacingXl),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. TOP GRAPHIC MEDICAL COMMAND BANNER
  // ===========================================================================
  Widget _buildHeroGraphicCommandBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F1E36), // Deep clinical navy
            Color(0xFF133E4A), // Rich teal slate
            Color(0xFF0F2B3C), // Dark cyan slate
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1E36).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Graphic ambient circles
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGreen.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Status Ribbon
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PulsingDot(color: Color(0xFF10B981), size: 7),
                        const SizedBox(width: 6),
                        const Text(
                          'REGIONAL NETWORK LIVE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                    ),
                    child: const Text(
                      '45 Facilities Connected',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6EE7B7),
                      ),
                    ),
                  ),
                  const SyncStatusPill(),
                ],
              ),
              const SizedBox(height: 16),

              // Doctor Greeting & Clinic Information
              ListenableBuilder(
                listenable: DoctorProfileService.instance,
                builder: (context, _) {
                  final docProfile = DoctorProfileService.instance.currentProfile;
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DoctorProfileScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF0F766E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.local_hospital_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        docProfile.fullName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Profile',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  docProfile.clinicOrHospital,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Emergency Dispatch Quick Callout Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.airport_shuttle_rounded,
                      color: Color(0xFFFBBF24),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Regional Emergency Ambulance Dispatch: 108',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '24/7 ACTIVE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFBBF24),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. HIGH-IMPACT GRAPHIC ACTION LAUNCHPADS
  // ===========================================================================
  Widget _buildGraphicActionLaunchpads() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Clinical Triage & Transfer Hub',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textNavyPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // 1. URGENT HERO ACTION: Emergency Quick Referral (Immediate 108 Ambulance Dispatch)
        PressableScale(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmergencyQuickReferralScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB91C1C), Color(0xFF991B1B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.flash_on_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Emergency Quick Referral',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '108 EMTS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Dispatch ambulance instantly • Transmit urgent clinical referral in seconds',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 2. HERO ACTION: New Patient Assessment
        PressableScale(
          onTap: widget.onStartAssessment ??
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigate to Assessment tab to begin.')),
                );
              },
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF047857), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Patient Assessment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Evaluate vitals, 4-tier disease acuity & match optimal hospital',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildAcuityMiniBadge('L1 Home', const Color(0xFF10B981)),
                          _buildAcuityMiniBadge('L2 PHC', const Color(0xFF3B82F6)),
                          _buildAcuityMiniBadge('L3 Urgent', const Color(0xFFF59E0B)),
                          _buildAcuityMiniBadge('L4 Emergency', const Color(0xFFEF4444)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Actions Row
        Row(
          children: [
            Expanded(
              child: _buildSecondaryActionCard(
                icon: Icons.local_hospital_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                title: 'Hospital Directory',
                subtitle: '45 Facilities',
                onTap: widget.onViewHospitals ?? () {},
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: _buildSecondaryActionCard(
                icon: Icons.assignment_outlined,
                iconColor: const Color(0xFF0F766E),
                iconBg: const Color(0xFFF0FDF4),
                title: 'Referral Registry',
                subtitle: 'Track Transfers',
                onTap: () {
                  if (widget.onViewReferrals != null) {
                    widget.onViewReferrals!(ReferralFilterTag.all);
                  }
                },
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: _buildSecondaryActionCard(
                icon: Icons.emergency_rounded,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEF2F2),
                title: 'ER Command',
                subtitle: 'Live 108 Cases',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EmergencyReferralDashboardScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcuityMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSecondaryActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingSm + 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textNavyPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textNavyMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. REFERRAL METRICS GRID
  // ===========================================================================
  Widget _buildMetricsGrid({
    required int total,
    required int emergency,
    required int inTransit,
    required int pending,
    required int completed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Clinical Triage Registry',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textNavyPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatCard(
                value: '$total',
                title: 'Total Referrals',
                subtitle: 'All tracked cases',
                icon: Icons.folder_shared_outlined,
                onTap: () => widget.onViewReferrals?.call(ReferralFilterTag.all),
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: StatCard(
                value: '$emergency',
                title: 'Emergency',
                subtitle: 'Immediate transit',
                icon: Icons.notification_important_rounded,
                color: AppColors.statusRed,
                onTap: () => widget.onViewReferrals?.call(ReferralFilterTag.emergency),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Row(
          children: [
            Expanded(
              child: StatCard(
                value: '$inTransit',
                title: 'In Transit',
                subtitle: 'Active ambulances',
                icon: Icons.airport_shuttle_rounded,
                color: AppColors.secondarySlateTeal,
                onTap: () => widget.onViewReferrals?.call(ReferralFilterTag.inTransit),
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: StatCard(
                value: '$completed',
                title: 'Completed',
                subtitle: 'Safe handover',
                icon: Icons.check_circle_rounded,
                color: AppColors.primaryGreen,
                onTap: () => widget.onViewReferrals?.call(ReferralFilterTag.completed),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. QUICK TRIAGE ACTIONS (SECONDARY TRIGGER BAR)
  // ===========================================================================
  Widget _buildQuickActionsCard() {
    return AppCard(
      title: 'Clinical Triage Actions',
      subtitle: 'Initiate new evaluation or review existing transfers',
      leadingIcon: const Icon(Icons.bolt_rounded, color: AppColors.primaryGreen),
      child: Column(
        children: [
          PrimaryButton(
            text: 'New Patient Assessment',
            icon: Icons.add_circle_outline_rounded,
            onPressed: widget.onStartAssessment ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigate to Assessment tab to begin.')),
                  );
                },
          ),
          const SizedBox(height: AppConstants.spacingSm),
          SecondaryButton(
            text: 'View Referral Registry & Tracking',
            icon: Icons.assignment_outlined,
            onPressed: () {
              if (widget.onViewReferrals != null) {
                widget.onViewReferrals!(ReferralFilterTag.all);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigate to Referrals tab to review records.')),
                );
              }
            },
          ),
          if (widget.onViewHospitals != null) ...[
            const SizedBox(height: AppConstants.spacingSm),
            SecondaryButton(
              text: 'Hospital Directory & Regional Map',
              icon: Icons.map_outlined,
              onPressed: widget.onViewHospitals!,
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. 4-TIER DISEASE ACUITY PROTOCOL VISUAL MATRIX
  // ===========================================================================
  Widget _buildAcuityFrameworkCard() {
    return AppCard(
      title: '4-Tier Clinical Acuity Protocol',
      subtitle: 'Standardized disease triage & referral routing matrix',
      leadingIcon: const Icon(Icons.shield_outlined, color: AppColors.primaryGreen),
      child: Column(
        children: [
          _buildAcuityRow(
            level: 'Level 4: Emergency / Hospital',
            severity: 'Severity 4',
            action: 'Immediate ambulance referral; bypass routine clinic wait',
            examples: 'Severe breathing, Shock, Chest pain, Stroke, Burns, Trauma',
            color: AppColors.statusRed,
            bgColor: AppColors.statusRedBg,
          ),
          const SizedBox(height: 8),
          _buildAcuityRow(
            level: 'Level 3: Urgent Referral',
            severity: 'Severity 3',
            action: 'Clinic stabilization then prompt hospital transfer',
            examples: 'Pneumonia, Fractures, Deep wound, Severe dehydration',
            color: AppColors.statusAmber,
            bgColor: AppColors.statusAmberBg,
          ),
          const SizedBox(height: 8),
          _buildAcuityRow(
            level: 'Level 2: Local Clinic / PHC',
            severity: 'Severity 2',
            action: 'Examine, test, and treat at local clinic / PHC',
            examples: 'Persistent fever, Malaria/Dengue, UTI, Simple wound',
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
          const SizedBox(height: 8),
          _buildAcuityRow(
            level: 'Level 1: Home Care / Observe',
            severity: 'Severity 1',
            action: 'Rest, fluids, supportive care; monitor outpatient',
            examples: 'Common cold, Mild headache, Minor superficial wound',
            color: AppColors.statusGreen,
            bgColor: AppColors.statusGreenBg,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text(
                'Open Complete Triage Acuity Matrix Guide',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: () => _showDiseaseProtocolGuide(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcuityRow({
    required String level,
    required String severity,
    required String action,
    required String examples,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severity,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            action,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textNavyPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Examples: $examples',
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textNavyMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. VISUAL 4-STAGE PATIENT TRANSIT WORKFLOW PIPELINE
  // ===========================================================================
  Widget _buildWorkflowCard() {
    const steps = [
      {'num': '1', 'title': 'Patient Assessment', 'desc': 'Vitals, symptoms & clinical danger signs'},
      {'num': '2', 'title': '4-Tier Acuity Triage', 'desc': 'Acuity stratification & local vs transfer determination'},
      {'num': '3', 'title': 'Capability-Based Matching', 'desc': 'Mandatory clinical capability check & transit ranking'},
      {'num': '4', 'title': 'Dispatch & Handover Audit', 'desc': 'Structured referral token, summary & status tracking'},
    ];

    return AppCard(
      title: 'Clinical Referral Workflow',
      subtitle: 'End-to-end patient transit pipeline',
      leadingIcon: const Icon(Icons.account_tree_outlined, color: AppColors.secondarySlateTeal),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryGreen, AppColors.primaryDarkGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          steps[i]['num']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 2,
                        height: 24,
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i]['title']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textNavyPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i]['desc']!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textNavySecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. RECENT ACTIVE REFERRALS FEED
  // ===========================================================================
  Widget _buildRecentReferralsFeed() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayList = _recentReferrals.take(3).toList();

    return AppCard(
      title: 'Recent Active Transfers',
      subtitle: '${_recentReferrals.length} referrals currently in local registry',
      leadingIcon: const Icon(Icons.history_edu_rounded, color: AppColors.primaryGreen),
      child: Column(
        children: [
          if (displayList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppConstants.spacingMd),
              child: Text(
                'No referrals recorded yet. Tap "New Patient Assessment" to begin.',
                style: TextStyle(fontSize: 12, color: AppColors.textNavyMuted),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            for (final ref in displayList) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => widget.onViewReferrals?.call(ReferralFilterTag.all),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMutedLight,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              ref.patient.patientId,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textNavyPrimary,
                              ),
                            ),
                            UrgencyBadge(urgencyLevel: ref.urgencyLevel, isCompact: true),
                            StatusBadge(status: ref.status, isCompact: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ref.recommendedHospital?.name ?? 'Local Treatment',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textNavySecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => widget.onViewReferrals?.call(ReferralFilterTag.all),
              child: const Text('View All Tracking Records →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}
