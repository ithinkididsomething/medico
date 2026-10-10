import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/enums.dart';
import '../models/mock_data.dart';
import '../widgets/widgets.dart';

/// Temporary showcase screen visually verifying all 22 reusable design system components.
class ComponentShowcaseScreen extends StatefulWidget {
  const ComponentShowcaseScreen({super.key});

  @override
  State<ComponentShowcaseScreen> createState() => _ComponentShowcaseScreenState();
}

class _ComponentShowcaseScreenState extends State<ComponentShowcaseScreen> {
  String _selectedFilter = 'All Facilities';
  bool _primaryLoading = false;
  String _lastConfirmedAction = 'None';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // 1. AppHeader
            AppHeader(
              title: 'Design System Showcase',
              subtitle: 'Visual validation of all 22 clinical components',
              facilityName: 'District Health Post • QA Sandbox',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                tooltip: 'Back',
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Component Showcase — All widgets responsive & accessible'),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Scrollable Component Gallery
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: Disclaimer
                    const SectionHeader(title: '21. Disclaimer Card'),
                    const DisclaimerCard(),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Urgency Badges
                    const SectionHeader(
                      title: '14. Urgency Badges (Multi-modal Accessibility)',
                      subtitle: 'Color + Icon + Text + Semantics (No color-only dependency)',
                    ),
                    const AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Standard Badges:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              UrgencyBadge(urgencyLevel: UrgencyLevel.routine),
                              UrgencyBadge(urgencyLevel: UrgencyLevel.urgent),
                              UrgencyBadge(urgencyLevel: UrgencyLevel.emergency),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text('Compact Badges:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              UrgencyBadge(urgencyLevel: UrgencyLevel.routine, isCompact: true),
                              UrgencyBadge(urgencyLevel: UrgencyLevel.urgent, isCompact: true),
                              UrgencyBadge(urgencyLevel: UrgencyLevel.emergency, isCompact: true),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Status Badges
                    const SectionHeader(
                      title: '15. Status Badges',
                      subtitle: 'Referral lifecycle stage indicators',
                    ),
                    const AppCard(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusBadge(status: ReferralStatus.pending),
                          StatusBadge(status: ReferralStatus.referred),
                          StatusBadge(status: ReferralStatus.accepted),
                          StatusBadge(status: ReferralStatus.transferred),
                          StatusBadge(status: ReferralStatus.completed),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: KPI Stat Cards
                    const SectionHeader(title: '4. Stat Cards (Clinical KPIs)'),
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isTablet = constraints.maxWidth > 550;
                        final cardWidth = isTablet ? (constraints.maxWidth - 12) / 2 : double.infinity;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: const StatCard(
                                title: 'Active Referrals',
                                value: '4',
                                subtitle: '2 emergency, 2 urgent',
                                icon: Icons.folder_shared_outlined,
                                color: AppColors.statusRed,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: const StatCard(
                                title: 'Regional Bed Pool',
                                value: '142',
                                subtitle: 'Across 4 partner centers',
                                icon: Icons.local_hospital_outlined,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Interactive Buttons
                    const SectionHeader(title: '5, 6, 7. Button Styles (Touch Target >= 48dp)'),
                    AppCard(
                      child: Column(
                        children: [
                          PrimaryButton(
                            text: 'Primary Button (Standard)',
                            icon: Icons.check_circle_outline,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('PrimaryButton tapped')),
                              );
                            },
                          ),
                          const SizedBox(height: AppConstants.spacingSm),
                          PrimaryButton(
                            text: 'Primary Button (Loading State)',
                            isLoading: _primaryLoading,
                            onPressed: () async {
                              setState(() => _primaryLoading = true);
                              await Future<void>.delayed(const Duration(seconds: 2));
                              if (mounted) setState(() => _primaryLoading = false);
                            },
                          ),
                          const SizedBox(height: AppConstants.spacingSm),
                          SecondaryButton(
                            text: 'Secondary Action Button',
                            icon: Icons.tune_rounded,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('SecondaryButton tapped')),
                              );
                            },
                          ),
                          const SizedBox(height: AppConstants.spacingSm),
                          DangerButton(
                            text: 'Danger / Emergency Action',
                            icon: Icons.warning_amber_rounded,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('DangerButton tapped')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Form & Filters
                    const SectionHeader(title: '11 & 12. SearchField & FilterChipGroup'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SearchField(
                            hintText: 'Search partner hospitals by specialty...',
                            onChanged: (val) {},
                          ),
                          const SizedBox(height: AppConstants.spacingMd),
                          FilterChipGroup<String>(
                            selectedValue: _selectedFilter,
                            items: const [
                              FilterChipItem(value: 'All Facilities', label: 'All', count: 4),
                              FilterChipItem(value: 'Emergency', label: 'Emergency', count: 3),
                              FilterChipItem(value: 'ICU Capable', label: 'ICU Beds', count: 3),
                              FilterChipItem(value: 'Obstetrics', label: 'Maternity', count: 2),
                            ],
                            onSelected: (val) => setState(() => _selectedFilter = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Score Indicator & Capability Row
                    const SectionHeader(title: '16 & 17. ScoreIndicator & CapabilityRow'),
                    const AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceAround,
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              ScoreIndicator(score: 94.5),
                              ScoreIndicator(score: 74.0),
                              ScoreIndicator(score: 48.0),
                            ],
                          ),
                          Divider(color: AppColors.borderLight, height: 28),
                          CapabilityRow(
                            title: 'Adult Intensive Care Unit (ICU)',
                            subtitle: '4 ventilator beds available',
                            icon: Icons.airline_seat_flat_rounded,
                            isAvailable: true,
                          ),
                          CapabilityRow(
                            title: '24/7 Blood Bank & Cross-match',
                            subtitle: 'O-Negative units in stock',
                            icon: Icons.bloodtype_outlined,
                            isAvailable: true,
                          ),
                          CapabilityRow(
                            title: 'Pediatric Subspecialty Surgery',
                            subtitle: 'Service on planned divert',
                            icon: Icons.child_care_rounded,
                            isAvailable: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Patient Info Card
                    const SectionHeader(title: '19. Patient Info Card (Demographics & Vitals)'),
                    PatientInfoCard(
                      patient: MockClinicalData.patientPostpartumHemorrhage,
                      trailingBadge: const UrgencyBadge(
                        urgencyLevel: UrgencyLevel.emergency,
                        isCompact: true,
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Hospital Card
                    const SectionHeader(
                      title: '13. Hospital Card',
                      subtitle: 'Comprehensive referral destination preview',
                    ),
                    HospitalCard(
                      hospital: MockClinicalData.hospitalDistrictGeneral,
                      suitabilityScore: 94.5,
                      distanceKm: 24.8,
                      travelTime: const Duration(minutes: 38),
                      isRecommended: true,
                      onSelect: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Selected District General Hospital')),
                        );
                      },
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Recommendation Reason Card
                    const SectionHeader(
                      title: '18. Recommendation Reason Card',
                      subtitle: 'Clinical decision rationale & match highlights',
                    ),
                    RecommendationReasonCard(
                      hospitalName: MockClinicalData.hospitalDistrictGeneral.name,
                      score: 94.5,
                      distanceText: '24.8 km',
                      travelTimeText: '~38 mins by Car',
                      whyRecommended: const [
                        'Full capability match for emergency obstetric hemorrhage.',
                        '24/7 Blood bank unit actively reported operational.',
                        'Surgical theater and ICU ventilator beds verified available.',
                      ],
                      capabilityMatches: const [
                        'Obstetrics & Gynecology',
                        '24/7 Blood Bank',
                        'ICU Beds',
                        'Emergency C-Section',
                      ],
                      caveats: const [
                        'Rural highway sector currently experiencing moderate road work delay.'
                      ],
                      onAccept: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Accepted recommendation')),
                        );
                      },
                      onAlternatives: () {},
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Referral Timeline
                    const SectionHeader(title: '20. Referral Timeline (Audit Trail)'),
                    AppCard(
                      child: ReferralTimeline(
                        history: MockClinicalData.sampleEmergencyReferral.statusHistory,
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Section: Feedback States
                    const SectionHeader(title: '8, 9, 10. Feedback States & Confirmation Dialog'),
                    AppCard(
                      child: Column(
                        children: [
                          const LoadingState(
                            message: 'Evaluating triage urgency protocols...',
                            subtitle: 'Comparing vital signs against IMAI thresholds',
                          ),
                          const Divider(color: AppColors.borderLight, height: 28),
                          const ErrorState(
                            title: 'Network Sync Pending',
                            message: 'Operating offline. 1 referral queued in local device storage.',
                          ),
                          const Divider(color: AppColors.borderLight, height: 28),
                          const EmptyState(
                            title: 'No Historical Records',
                            message: 'Patient assessments saved today will be logged here.',
                          ),
                          const Divider(color: AppColors.borderLight, height: 28),
                          Text(
                            '22. Confirmation Dialog (Last action: $_lastConfirmedAction)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          PrimaryButton(
                            text: 'Open Confirmation Dialog',
                            icon: Icons.help_outline_rounded,
                            onPressed: () async {
                              final confirmed = await ConfirmationDialog.show(
                                context,
                                title: 'Dispatch Emergency Ambulance?',
                                message: 'This will notify District General Hospital of incoming emergency transfer P001.',
                                confirmText: 'Dispatch 108 Service',
                                cancelText: 'Review First',
                              );
                              setState(() {
                                _lastConfirmedAction = confirmed ? 'Confirmed Dispatch' : 'Cancelled';
                              });
                            },
                          ),
                        ],
                      ),
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
}
