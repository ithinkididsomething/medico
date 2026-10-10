import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive_utils.dart';
import '../models/enums.dart';
import '../screens/assessment_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/hospitals_screen.dart';
import '../screens/more_screen.dart';
import '../screens/profile/doctor_profile_screen.dart';
import '../screens/referrals_screen.dart';
import '../screens/resources/facility_resources_screen.dart';
import '../widgets/app_scaffold.dart';

/// Navigation destination metadata for SMART Referral.
class NavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final String subtitle;

  const NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.subtitle,
  });
}

/// Root navigation screen managing bottom navigation bar (phone)
/// and navigation rail (tablet).
class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  ReferralFilterTag _referralFilterTag = ReferralFilterTag.all;

  static const List<NavigationItem> _navItems = [
    NavigationItem(
      label: AppConstants.navDashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      title: AppConstants.appName,
      subtitle: AppConstants.appTagline,
    ),
    NavigationItem(
      label: AppConstants.navAssessment,
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
      title: 'Clinical Assessment',
      subtitle: 'Triage & Symptom Evaluation',
    ),
    NavigationItem(
      label: AppConstants.navReferrals,
      icon: Icons.folder_shared_outlined,
      selectedIcon: Icons.folder_shared_rounded,
      title: 'Referral Logs',
      subtitle: 'Dispatched & Queued Transfers',
    ),
    NavigationItem(
      label: AppConstants.navHospitals,
      icon: Icons.local_hospital_outlined,
      selectedIcon: Icons.local_hospital_rounded,
      title: 'Partner Hospitals',
      subtitle: 'Emergency & Specialty Centers',
    ),
    NavigationItem(
      label: AppConstants.navResources,
      icon: Icons.domain_outlined,
      selectedIcon: Icons.domain_rounded,
      title: 'Facility Resources',
      subtitle: 'Infrastructure & Capabilities',
    ),
    NavigationItem(
      label: AppConstants.navMore,
      icon: Icons.more_horiz_outlined,
      selectedIcon: Icons.more_horiz_rounded,
      title: 'Clinic Settings',
      subtitle: 'Health Post Profile & Sync',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onSelectTab(int index) {
    if (index >= 0 && index < _navItems.length) {
      setState(() {
        _currentIndex = index;
        if (index == 2) {
          _referralFilterTag = ReferralFilterTag.all;
        }
      });
    }
  }

  void _onNavigateToReferrals([ReferralFilterTag? filterTag]) {
    setState(() {
      _currentIndex = 2;
      _referralFilterTag = filterTag ?? ReferralFilterTag.all;
    });
  }

  List<Widget> _buildScreens() {
    return [
      DashboardScreen(
        onStartAssessment: () => _onSelectTab(1),
        onViewReferrals: _onNavigateToReferrals,
        onViewHospitals: () => _onSelectTab(3),
      ),
      const AssessmentScreen(),
      ReferralsScreen(
        key: ValueKey('referrals_${_referralFilterTag.name}'),
        initialFilterTag: _referralFilterTag,
      ),
      const HospitalsScreen(),
      const FacilityResourcesScreen(),
      const MoreScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _navItems[_currentIndex];
    final isTablet = ResponsiveUtils.isTablet(context);
    final screens = _buildScreens();

    if (isTablet) {
      // Tablet layout: Side Navigation Rail + Body
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onSelectTab,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
                child: CircleAvatar(
                  backgroundColor: AppColors.primaryLightMint,
                  radius: 20,
                  child: const Icon(
                    Icons.local_hospital,
                    color: AppColors.primaryGreen,
                    size: 22,
                  ),
                ),
              ),
              destinations: _navItems.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                );
              }).toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.borderLight),
            Expanded(
              child: AppScaffold(
                title: currentItem.title,
                subtitle: currentItem.subtitle,
                showClinicStatusBar: true,
                actions: [
                  _buildDoctorProfileButton(context),
                ],
                body: IndexedStack(
                  index: _currentIndex,
                  children: screens,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Phone layout: Bottom Navigation Bar + Body
    return AppScaffold(
      title: currentItem.title,
      subtitle: currentItem.subtitle,
      showClinicStatusBar: true,
      actions: [
        _buildDoctorProfileButton(context),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onSelectTab,
        destinations: _navItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDoctorProfileButton(BuildContext context) {
    return Tooltip(
      message: 'Doctor Profile',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DoctorProfileScreen(),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryLightMint,
            borderRadius: BorderRadius.circular(AppConstants.radiusPill),
            border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primaryGreen,
                child: Icon(
                  Icons.person,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Doctor Profile',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDarkGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
