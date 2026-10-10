import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/enums.dart';
import '../../models/hospital.dart';
import '../../models/mock_data.dart';
import '../../models/patient.dart';
import '../../models/referral.dart';
import '../../models/referral_status_history.dart';
import '../../models/hierarchical_referral_result.dart';
import '../../models/indore_hospital_dataset.dart';
import '../../services/assessment_service.dart';
import '../../services/condition_specific_ranking_service.dart';
import '../../services/hierarchical_ranking_service.dart';
import '../../services/hospital_matching_service.dart';
import '../../services/location_service.dart';
import '../../widgets/widgets.dart';
import '../../core/utils/navigation_utils.dart';
import '../hospital/hospital_map_view.dart';
import '../referral/referral_summary_screen.dart';
import '../emergency/emergency_quick_referral_screen.dart';

/// Clinical Referral Recommendation Screen.
///
/// Connects triage assessment results to ranked facility recommendations,
/// explainable scoring, "Why this hospital?" justification, dynamic fallback
/// re-ranking, and explicit clinician confirmation workflows.
class RecommendationScreen extends StatefulWidget {
  final Patient patient;
  final AssessmentResult assessment;
  final HospitalMatchingService matchingService;
  final List<Hospital>? initialHospitals;
  final double? clinicLatitude;
  final double? clinicLongitude;

  const RecommendationScreen({
    super.key,
    required this.patient,
    required this.assessment,
    this.matchingService = const ClinicalHospitalMatchingService(),
    this.initialHospitals,
    this.clinicLatitude,
    this.clinicLongitude,
  });

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  late List<Hospital> _workingHospitals;
  late HospitalRecommendationResult _recommendations;

  /// Tracks dynamic fallback changes to explain shifts in recommendations.
  String? _dynamicFallbackNotice;
  String? _lastDivertedHospitalName;

  /// Tracks which cards have their score breakdowns toggled open.
  final Set<String> _expandedBreakdowns = {};

  /// Confirmed condition category applied for prioritization.
  PatientConditionCategory? _selectedCategory;

  /// Active tab for mobile/narrow viewports (0: Leaderboard, 1: Route Map & Facility Profile)
  int _mobileTabIndex = 0;

  /// Hospital currently inspected on map and in facility details panel.
  Hospital? _selectedMapHospital;

  double get _clinicLat =>
      widget.clinicLatitude ?? DefaultLocationService().currentClinicLocation.latitude;
  double get _clinicLng =>
      widget.clinicLongitude ?? DefaultLocationService().currentClinicLocation.longitude;

  ClinicLocation get _effectiveClinicLocation {
    final current = DefaultLocationService().currentClinicLocation;
    if (widget.clinicLatitude != null && widget.clinicLongitude != null) {
      if (widget.clinicLatitude == current.latitude &&
          widget.clinicLongitude == current.longitude) {
        return current;
      }
      return ClinicLocation(
        name: 'Referring Clinic',
        latitude: widget.clinicLatitude!,
        longitude: widget.clinicLongitude!,
        description: 'Referring Facility Coordinates',
      );
    }
    return current;
  }

  Hospital? get _effectiveSelectedHospital {
    if (_selectedMapHospital != null &&
        _workingHospitals.any((h) => h.hospitalId == _selectedMapHospital!.hospitalId)) {
      return _selectedMapHospital;
    }
    return _recommendations.bestMatch?.hospital ??
        (_workingHospitals.isNotEmpty ? _workingHospitals.first : null);
  }

  HospitalMatchResult? get _effectiveSelectedMatch {
    final hosp = _effectiveSelectedHospital;
    if (hosp == null) return null;
    return _recommendations.eligibleHospitals
        .cast<HospitalMatchResult?>()
        .firstWhere((m) => m?.hospital.hospitalId == hosp.hospitalId, orElse: () => null);
  }

  final HierarchicalRankingService _hierarchicalService = HierarchicalRankingService();
  HierarchicalReferralResponse? _hierarchicalResult;
  bool _includeSyntheticDoctors = false;
  Map<String, HierarchicalFacilityEntry> _hierarchicalMap = {};

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.assessment.conditionCategory ??
        widget.patient.conditionCategory;
    _resetHospitalsToDefault();
  }

  void _resetHospitalsToDefault() {
    final base = widget.initialHospitals ??
        (widget.patient.patientId.startsWith('PAT-SIM-')
            ? MockClinicalData.sampleHospitals
            : IndoreHospitalDataset.allFacilities);
    _workingHospitals = base.map((h) => h.copyWith()).toList();
    _dynamicFallbackNotice = null;
    _lastDivertedHospitalName = null;
    _recalculateRecommendations();
    _loadHierarchicalRanking();
  }

  void _recalculateRecommendations() {
    setState(() {
      _recommendations = widget.matchingService.evaluateRecommendations(
        patient: widget.patient,
        assessment: widget.assessment,
        availableHospitals: _workingHospitals,
        clinicLatitude: _clinicLat,
        clinicLongitude: _clinicLng,
        conditionCategory: _selectedCategory,
      );
    });
    _loadHierarchicalRanking();
  }

  Future<void> _loadHierarchicalRanking() async {
    final conditionKey = HierarchicalRankingService.mapCategoryToConditionKey(
      _selectedCategory,
      patientAgeYears: widget.patient.age,
    );
    try {
      final res = await _hierarchicalService.rankFacilities(
        conditionKey: conditionKey,
        latitude: _clinicLat,
        longitude: _clinicLng,
        includeSynthetic: _includeSyntheticDoctors,
      );
      if (mounted) {
        setState(() {
          _hierarchicalResult = res;
          _hierarchicalMap = {
            for (final f in res.rankedRecommendations) f.facilityId: f,
            for (final f in res.excludedFacilities) f.facilityId: f,
          };
        });
      }
    } catch (_) {}
  }

  /// Dynamic fallback simulation:
  /// Marks a hospital as diverting / 0 beds, triggers revalidation,
  /// re-ranks remaining hospitals, and displays an explicit clinical explanation.
  void _simulateHospitalUnavailable(Hospital hospital) {
    final previousBestName = _recommendations.bestMatch?.hospital.name;
    final index = _workingHospitals.indexWhere((h) => h.hospitalId == hospital.hospitalId);

    if (index != -1) {
      final divertedHospital = _workingHospitals[index].copyWith(
        operatingStatus: 'Diverting',
        bedAvailability: 0,
        currentCapacity: 1.0,
      );
      _workingHospitals[index] = divertedHospital;
      _lastDivertedHospitalName = hospital.name;

      _recalculateRecommendations();

      final newBest = _recommendations.bestMatch?.hospital;

      setState(() {
        if (hospital.name == previousBestName && newBest != null) {
          _dynamicFallbackNotice =
              'Dynamic Fallback Activated: Primary recommendation updated. "${hospital.name}" '
              'is diverting (0 available beds). The recommendation engine has re-validated and re-ranked '
              'remaining facilities. "${newBest.name}" is now the Primary Recommendation.';
        } else {
          _dynamicFallbackNotice =
              'Dynamic Fallback Activated: "${hospital.name}" reported diverting capacity and was moved to '
              'excluded facilities. Remaining eligible partner hospitals have been dynamically re-ranked.';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Simulated divert applied to ${hospital.name}. Re-ranked remaining facilities.'),
          backgroundColor: AppColors.statusAmber,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Opens the explicit "Confirm Referral Destination" workflow dialog.
  Future<void> _onSelectHospital(HospitalMatchResult match, String tierLabel) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildConfirmDestinationSheet(ctx, match, tierLabel),
    );

    if (confirmed == true && mounted) {
      _navigateToReferralSummary(match);
    }
  }

  Future<void> _navigateToReferralSummary(HospitalMatchResult match) async {
    final hosp = match.hospital;
    final now = DateTime.now();

    final referral = Referral(
      referralId: 'REF-${now.millisecondsSinceEpoch.toString().substring(7)}',
      patient: widget.patient,
      urgencyLevel: widget.assessment.urgencyLevel,
      referralReason: widget.assessment.clinicalRationale.isNotEmpty
          ? widget.assessment.clinicalRationale.first
          : 'Clinical referral recommended for specialist evaluation and higher-tier management.',
      requiredSpecialty: widget.assessment.requiredSpecialty,
      requiredFacilities: widget.assessment.requiredFacilities,
      recommendedHospital: hosp,
      alternativeHospitals: _recommendations.alternatives
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
          note: 'Destination facility (${hosp.name}) explicitly selected by clinician. Pre-dispatch transfer initiated.',
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

    if (completed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Opens the "View Hospital Details" profile modal.
  void _onViewHospitalDetails(Hospital hosp, {double? distanceKm, Duration? travelTime}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildHospitalDetailsSheet(ctx, hosp, distanceKm, travelTime),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            AppHeader(
              title: 'Referral Recommendations',
              subtitle: 'Ranked Facility Decision Support',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => SafeNavigation.pop(context, fallbackTab: 1),
                tooltip: 'Return to Assessment Result',
              ),
              showClinicStatusBar: false,
            ),

            // Main Content Area with Responsive Layout
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 960;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Pane: Scrollable Ranked Leaderboard
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppConstants.spacingMd),
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildLeaderboardWidgets(theme),
                            ),
                          ),
                        ),

                        // Subtle Vertical Divider
                        Container(
                          width: 1.2,
                          color: AppColors.borderLight,
                        ),

                        // Right Pane: Sticky Route Map & Selected Facility Profile Panel
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppConstants.spacingMd),
                            physics: const BouncingScrollPhysics(),
                            child: _buildMapAndDetailsPanel(isWide: true),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Mobile / Narrow Layout (< 960px)
                    return Column(
                      children: [
                        _buildMobileViewSwitcher(),
                        Expanded(
                          child: _mobileTabIndex == 0
                              ? SingleChildScrollView(
                                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildMobileMapPreviewBanner(),
                                      const SizedBox(height: AppConstants.spacingMd),
                                      ..._buildLeaderboardWidgets(theme),
                                    ],
                                  ),
                                )
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                                  physics: const BouncingScrollPhysics(),
                                  child: _buildMapAndDetailsPanel(isWide: false),
                                ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the leaderboard cards list: Urgency, Categorization, Recommendations, and Excluded
  List<Widget> _buildLeaderboardWidgets(ThemeData theme) {
    final bestMatch = _recommendations.bestMatch;
    final alternatives = _recommendations.alternatives;
    final excluded = _recommendations.excludedHospitals;

    return [
      // Dynamic Fallback Banner if triggered
      if (_dynamicFallbackNotice != null) ...[
        _buildDynamicFallbackAlertBanner(),
        const SizedBox(height: AppConstants.spacingMd),
      ],

      // Persistent Synthetic Clinicians Disclaimer Banner when active
      if (_includeSyntheticDoctors) ...[
        _buildSyntheticDoctorDisclaimerBanner(),
        const SizedBox(height: AppConstants.spacingMd),
      ],

      // 1. Patient Urgency & Referral Requirement Banner
      _buildPatientUrgencyAndRequirementCard(theme),

      const SizedBox(height: AppConstants.spacingMd),

      // Condition Category & Prioritization Sequence Banner
      _buildConditionCategoryCard(theme),

      const SizedBox(height: AppConstants.spacingMd),

      // Three-Level Clinical Hierarchy & Simulated Doctor Toggle
      _buildHierarchicalPriorityCard(theme),

      const SizedBox(height: AppConstants.spacingLg),

      // 2. PRIMARY RECOMMENDATION (Best Hospital)
      if (bestMatch != null) ...[
        SectionHeader(
          title: 'Primary Recommendation',
          subtitle: 'Top-ranked clinical destination meeting all mandatory criteria',
          customAction: _buildResetSimulationButton(),
        ),
        const SizedBox(height: 6),
        _buildHospitalCard(
          context,
          match: bestMatch,
          rankTitle: 'Primary Recommendation',
          isPrimary: true,
        ),
      ] else ...[
        // Empty state when no suitable facility exists
        _buildNoSuitableHospitalCard(),
      ],

      const SizedBox(height: AppConstants.spacingLg),

      // 3. ALTERNATIVE HOSPITALS (Alternative 1 & Alternative 2)
      if (alternatives.isNotEmpty) ...[
        SectionHeader(
          title: 'Alternative Hospitals (${alternatives.length})',
          subtitle: 'Secondary verified options if Primary Recommendation is at capacity',
        ),
        for (int i = 0; i < alternatives.length; i++) ...[
          _buildHospitalCard(
            context,
            match: alternatives[i],
            rankTitle: 'Alternative ${i + 1}',
            isPrimary: false,
          ),
          if (i < alternatives.length - 1)
            const SizedBox(height: AppConstants.spacingMd),
        ],
        const SizedBox(height: AppConstants.spacingLg),
      ],

      // 4. EXCLUDED HOSPITALS
      if (excluded.isNotEmpty) ...[
        SectionHeader(
          title: 'Excluded Hospitals (${excluded.length})',
          subtitle: 'Disqualified by mandatory clinical hard filters (ED closed, 0 beds, missing ICU/specialty)',
        ),
        _buildExcludedHospitalsSection(context, excluded),
        const SizedBox(height: AppConstants.spacingLg),
      ],

      // Return Button
      SecondaryButton(
        text: 'Return to Assessment Review',
        icon: Icons.assignment_outlined,
        onPressed: () => SafeNavigation.pop(context, fallbackTab: 1),
      ),

      const SizedBox(height: AppConstants.spacingXxl),
    ];
  }

  /// Mobile Tab Selector between Ranked Leaderboard and Route Map & Details
  Widget _buildMobileViewSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SegmentedButton<int>(
        segments: [
          ButtonSegment<int>(
            value: 0,
            icon: const Icon(Icons.format_list_numbered_rounded, size: 16),
            label: Text('Leaderboard (${_recommendations.eligibleHospitals.length})'),
          ),
          const ButtonSegment<int>(
            value: 1,
            icon: Icon(Icons.map_rounded, size: 16),
            label: Text('Route Map & Details'),
          ),
        ],
        selected: {_mobileTabIndex},
        onSelectionChanged: (newSelection) {
          setState(() {
            _mobileTabIndex = newSelection.first;
          });
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
          ),
        ),
      ),
    );
  }

  /// Compact helper banner shown on mobile in Leaderboard view to quickly view map
  Widget _buildMobileMapPreviewBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLightMint,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_rounded, size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Interactive Route Map available for regional facilities',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDarkGreen),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _mobileTabIndex = 1),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View Map', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDarkGreen)),
          ),
        ],
      ),
    );
  }

  /// The Map & Facility Capabilities Panel (fills right pane on desktop, or Tab 1 on mobile)
  Widget _buildMapAndDetailsPanel({bool isWide = true}) {
    final selectedHosp = _effectiveSelectedHospital;
    final selectedMatch = _effectiveSelectedMatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clinic & Transit Header Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_car_rounded, size: 18, color: AppColors.primaryDarkGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Referral Transit Route Map',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                    Text(
                      'Base: ${_effectiveClinicLocation.name}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textNavyMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMutedLight,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  '${_effectiveClinicLocation.latitude.toStringAsFixed(4)}, ${_effectiveClinicLocation.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondarySlateTeal,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.spacingSm),

        // Interactive Hospital Map Container
        Container(
          height: isWide ? 400 : 340,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: HospitalMapView(
            hospitals: _workingHospitals,
            clinicLocation: _effectiveClinicLocation,
            recommendedHospital: selectedHosp,
            onSelectHospital: (hospital) {
              setState(() {
                _selectedMapHospital = hospital;
              });
            },
          ),
        ),

        const SizedBox(height: AppConstants.spacingMd),

        // Detailed Facility Profile Card for Currently Selected Hospital
        if (selectedHosp != null)
          _buildSelectedFacilityDetailsPanel(selectedHosp, selectedMatch),
      ],
    );
  }

  /// Facility Capabilities & Operational Profile Card
  Widget _buildSelectedFacilityDetailsPanel(Hospital hospital, HospitalMatchResult? match) {
    final isTop = _recommendations.bestMatch?.hospital.hospitalId == hospital.hospitalId;
    final isDiverting = hospital.operatingStatus.toLowerCase() == 'diverting';
    final distanceKm = match?.distanceKm ?? 2.1;
    final travelMinutes = match?.travelTime.inMinutes ?? 12;
    final matchScore = match?.matchScore.round() ?? 85;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: isTop ? AppColors.primaryGreen : AppColors.borderLight,
          width: isTop ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Rank badge, Score badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isTop ? AppColors.primaryLightMint : AppColors.surfaceMutedLight,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(color: isTop ? AppColors.primaryGreen : AppColors.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTop ? Icons.stars_rounded : Icons.local_hospital_rounded,
                      size: 14,
                      color: isTop ? AppColors.primaryGreen : AppColors.secondarySlateTeal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isTop ? 'Primary Recommendation' : 'Candidate Facility Profile',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isTop ? AppColors.primaryDarkGreen : AppColors.textNavyPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDiverting
                      ? AppColors.statusRedBg
                      : (matchScore >= 85 ? AppColors.statusGreenBg : AppColors.statusAmberBg),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(
                    color: isDiverting
                        ? AppColors.statusRed
                        : (matchScore >= 85 ? AppColors.statusGreen : AppColors.statusAmber),
                  ),
                ),
                child: Text(
                  isDiverting ? 'Diverting (0 Beds)' : '$matchScore/100 Match',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDiverting
                        ? AppColors.statusRed
                        : (matchScore >= 85 ? AppColors.primaryDarkGreen : AppColors.textNavyPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hospital Name & Address
          Text(
            hospital.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textNavyPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hospital.address,
            style: const TextStyle(fontSize: 12, color: AppColors.textNavyMuted),
          ),
          const SizedBox(height: 12),

          // Operational metrics bar
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
                    const Icon(Icons.near_me_outlined, size: 14, color: AppColors.secondarySlateTeal),
                    const SizedBox(width: 4),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km (~${(distanceKm * 1000).round()} m)',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.secondarySlateTeal),
                    const SizedBox(width: 4),
                    Text(
                      '~$travelMinutes mins by Car',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.airline_seat_flat_rounded, size: 14, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${hospital.bedAvailability} beds',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryDarkGreen),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_hospital_outlined, size: 14, color: AppColors.statusAmber),
                    const SizedBox(width: 4),
                    Text(
                      '${hospital.availability?.icuBedsAvailable ?? (hospital.icuAvailable ? "Equipped" : 0)} ICU',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Key Capabilities & Specialties
          const Text(
            'Verified Clinical Capabilities:',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textNavySecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (hospital.emergencyCare)
                _buildCapabilityBadge('24/7 ED Open', Icons.emergency, AppColors.primaryGreen),
              if (hospital.icuAvailable)
                _buildCapabilityBadge('ICU Equipped', Icons.local_hospital, AppColors.secondarySlateTeal),
              ...hospital.specialties.take(3).map((s) => _buildCapabilityBadge(s, Icons.medical_services_outlined, AppColors.textNavySecondary)),
              ...hospital.diagnosticFacilities.take(2).map((d) => _buildCapabilityBadge(d, Icons.biotech, AppColors.secondarySlateTeal)),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons:
          // 1. Confirm Destination Button
          // 2. View Full Hospital Details Button
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (match != null)
                ElevatedButton.icon(
                  onPressed: () => _onSelectHospital(match, isTop ? 'Primary Recommendation' : 'Selected Facility'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTop ? AppColors.primaryGreen : AppColors.secondarySlateTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text(
                    'Confirm Destination',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _onViewHospitalDetails(
                  hospital,
                  distanceKm: match?.distanceKm,
                  travelTime: match?.travelTime,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondarySlateTeal,
                  side: const BorderSide(color: AppColors.borderLight),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                ),
                icon: const Icon(Icons.info_outline_rounded, size: 15),
                label: const Text(
                  'Full Profile',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EmergencyQuickReferralScreen(
                        initialComplaint: widget.patient.mainComplaint,
                        patientName: widget.patient.patientId,
                        patientAge: widget.patient.age,
                        patientSex: widget.patient.sex.displayName,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 15),
                label: const Text(
                  'Emergency 108',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityBadge(String label, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION WIDGETS
  // ===========================================================================

  Widget _buildDynamicFallbackAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.statusAmber, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_problem_rounded, size: 20, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Dynamic Fallback Activated',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
              TextButton(
                onPressed: _resetHospitalsToDefault,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Reset Network',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _dynamicFallbackNotice!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF78350F),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetSimulationButton() {
    if (_lastDivertedHospitalName == null) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: _resetHospitalsToDefault,
      icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.secondarySlateTeal),
      label: const Text(
        'Reset Statuses',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondarySlateTeal),
      ),
    );
  }

  Widget _buildPatientUrgencyAndRequirementCard(ThemeData theme) {
    return AppCard(
      accentColor: AppColors.secondarySlateTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PATIENT CLINICAL TRIAGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.secondarySlateTeal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Patient ID: ${widget.patient.patientId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              UrgencyBadge(
                urgencyLevel: widget.assessment.urgencyLevel,
                isCompact: false,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          const Divider(height: 1),
          const SizedBox(height: AppConstants.spacingMd),

          // Referral Requirement
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.assignment_late_outlined, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Referral Requirement:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Required Specialty: ${widget.assessment.requiredSpecialty}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                    if (widget.assessment.requiredFacilities.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Mandatory Capabilities: ${widget.assessment.requiredFacilities.join(", ")}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textNavySecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCategoryCard(ThemeData theme) {
    final category = _selectedCategory;
    final config = category != null
        ? ConditionSpecificRankingService.getConfiguration(category)
        : null;

    return AppCard(
      accentColor: AppColors.primaryGreen,
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
                    child: const Icon(Icons.rule_rounded, size: 18, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CONDITION PRIORITIZATION ENGINE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.primaryDarkGreen,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<PatientConditionCategory>(
                tooltip: 'Change Condition Category',
                icon: const Icon(Icons.tune_rounded, size: 20, color: AppColors.secondarySlateTeal),
                onSelected: (newCat) {
                  setState(() {
                    _selectedCategory = newCat;
                  });
                  _recalculateRecommendations();
                },
                itemBuilder: (ctx) {
                  return PatientConditionCategory.values.map((cat) {
                    return PopupMenuItem<PatientConditionCategory>(
                      value: cat,
                      child: Row(
                        children: [
                          if (_selectedCategory == cat)
                            const Icon(Icons.check, size: 16, color: AppColors.primaryGreen)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(
                            cat.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedCategory == cat ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  category != null ? category.displayName : 'Standard Referral Matching',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textNavyPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: category != null ? AppColors.primaryLightMint : AppColors.surfaceMutedLight,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(color: category != null ? AppColors.primaryGreen : AppColors.borderLight),
                ),
                child: Text(
                  category != null ? 'Clinician Confirmed' : 'Standard Formula',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: category != null ? AppColors.primaryDarkGreen : AppColors.textNavySecondary,
                  ),
                ),
              ),
            ],
          ),
          if (config != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'Applied Prioritization Sequence:',
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
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildPrioritySequenceChip('P1', config.priority1Name, true),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textNavyMuted),
                _buildPrioritySequenceChip('P2', config.priority2Name, false),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textNavyMuted),
                _buildPrioritySequenceChip('P3', config.priority3Name, false),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textNavyMuted),
                _buildPrioritySequenceChip('P4', config.priority4Name, false),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rules: Mandatory capabilities evaluated first. Lower-tier criteria break ties without overriding higher clinical priorities.',
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.textNavyMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrioritySequenceChip(String pNum, String name, bool isP1) {
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

  Widget _buildSyntheticDoctorDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIMULATED DATA — NOT FOR CLINICAL DECISIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Development Mode: 16 synthetic clinician profiles are active across 45 facilities for algorithm testing. All production referrals exclude synthetic profiles.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchicalPriorityCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.account_tree_rounded, size: 16, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'THREE-LEVEL CLINICAL RANKING HIERARCHY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkGreen,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Priority 1: Technical & Infrastructural Capability (Hard Gate)\n'
            'Priority 2: Current Availability (Operational & Bed Status)\n'
            'Priority 3: Travel Distance & Road Transit Time',
            style: TextStyle(fontSize: 11.5, color: AppColors.textNavyPrimary, fontWeight: FontWeight.w600, height: 1.4),
          ),
          if (_hierarchicalResult != null) ...[
            const SizedBox(height: 6),
            Text(
              'Hierarchical Engine: Evaluated ${_hierarchicalResult!.totalEvaluatedFacilities} facilities (${_hierarchicalResult!.rankedRecommendations.length} eligible, ${_hierarchicalResult!.excludedFacilities.length} excluded)',
              style: const TextStyle(fontSize: 10.5, color: AppColors.secondarySlateTeal, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulated Clinicians (Dev Mode)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                    ),
                    Text(
                      'Include 16 synthetic clinician profiles for capability testing',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textNavyMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _includeSyntheticDoctors,
                activeThumbColor: AppColors.primaryGreen,
                onChanged: (val) {
                  setState(() {
                    _includeSyntheticDoctors = val;
                  });
                  _loadHierarchicalRanking();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HOSPITAL CARD & "WHY THIS HOSPITAL?" CARD
  // ===========================================================================

  Widget _buildHospitalCard(
    BuildContext context, {
    required HospitalMatchResult match,
    required String rankTitle,
    required bool isPrimary,
  }) {
    final hosp = match.hospital;
    final score = match.matchScore.round();
    final isExpanded = _expandedBreakdowns.contains(hosp.hospitalId) || isPrimary;

    return AppCard(
      accentColor: isPrimary ? AppColors.primaryGreen : AppColors.secondarySlateTeal,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Rank Title & Total Score Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPrimary ? AppColors.primaryLightMint : AppColors.surfaceMutedLight,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(
                    color: isPrimary ? AppColors.primaryGreen : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPrimary ? Icons.stars_rounded : Icons.check_circle_outline,
                      size: 14,
                      color: isPrimary ? AppColors.primaryGreen : AppColors.textNavySecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rankTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isPrimary ? AppColors.primaryDarkGreen : AppColors.textNavyPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Total Score Pill (e.g. 92/100)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  '$score/100',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: score >= 85 ? AppColors.primaryDarkGreen : AppColors.textNavyPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingSm),

          // Hospital Name & Address
          Text(
            hosp.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textNavyPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hosp.address,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textNavyMuted,
            ),
          ),

          const SizedBox(height: 6),
          // Data confidence indicator & Source badge
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: hosp.isSimulatedData
                      ? AppColors.statusAmberBg
                      : AppColors.statusGreenBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: hosp.isSimulatedData
                        ? AppColors.statusAmber.withValues(alpha: 0.5)
                        : AppColors.statusGreen.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hosp.isSimulatedData
                          ? Icons.science_outlined
                          : Icons.verified_user_outlined,
                      size: 11,
                      color: hosp.isSimulatedData
                          ? AppColors.statusAmber
                          : AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hosp.isSimulatedData
                          ? 'Simulated Capacity (Prototype)'
                          : 'Verified Live Telemetry',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: hosp.isSimulatedData
                            ? const Color(0xFF92400E)
                            : AppColors.primaryDarkGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Source: ${hosp.dataSource}',
                style: const TextStyle(fontSize: 10, color: AppColors.textNavyMuted),
              ),
            ],
          ),

          // Hierarchical Condition Suitability Status Badge
          Builder(
            builder: (ctx) {
              final hEntry = _hierarchicalMap[hosp.hospitalId];
              final conditionStatusLabel = hEntry?.statusLabel ??
                  (match.hasRequiredSpecialty ? 'Suitable — availability confirmed' : 'Essential capability missing');
              final whyExplanation = hEntry?.whyRankedSummary ??
                  (match.matchingHighlights.isNotEmpty ? match.matchingHighlights.join(' • ') : null);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: conditionStatusLabel.contains('confirmed')
                          ? AppColors.primaryLightMint
                          : (conditionStatusLabel.contains('missing')
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFFEF3C7)),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: conditionStatusLabel.contains('confirmed')
                            ? AppColors.primaryGreen
                            : (conditionStatusLabel.contains('missing')
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF59E0B)),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          conditionStatusLabel.contains('confirmed')
                              ? Icons.check_circle_rounded
                              : (conditionStatusLabel.contains('missing')
                                  ? Icons.cancel_rounded
                                  : Icons.warning_amber_rounded),
                          size: 13,
                          color: conditionStatusLabel.contains('confirmed')
                              ? AppColors.primaryDarkGreen
                              : (conditionStatusLabel.contains('missing')
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFFB45309)),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            conditionStatusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: conditionStatusLabel.contains('confirmed')
                                  ? AppColors.primaryDarkGreen
                                  : (conditionStatusLabel.contains('missing')
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFFB45309)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (whyExplanation != null && whyExplanation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMutedLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderLight, width: 0.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: AppColors.secondarySlateTeal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              whyExplanation,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textNavySecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          if (_includeSyntheticDoctors) ...[
            const SizedBox(height: 5),
            const Text(
              'SIMULATED DATA — NOT FOR CLINICAL DECISIONS',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
                letterSpacing: 0.3,
              ),
            ),
          ],

          if (hosp.isSimulatedData) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 13, color: AppColors.statusAmber),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recency Warning: Capacity data is simulated prototype model. Verify directly by phone prior to emergency dispatch.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppConstants.spacingMd),

          // Transit metrics row (Distance & Travel Time)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceMutedLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_outlined, size: 16, color: AppColors.secondarySlateTeal),
                    const SizedBox(width: 6),
                    Text(
                      'Distance: ${match.distanceKm.toStringAsFixed(1)} km (~${(match.distanceKm * 1000).round()} m)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 16, color: AppColors.secondarySlateTeal),
                    const SizedBox(width: 6),
                    Text(
                      'Travel Time: ~${match.travelTime.inMinutes} mins by Car',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // ========================================================
          // "Why this hospital?" RECOMMENDATION EXPLANATION CARD
          // ========================================================
          _buildWhyThisHospitalCard(match),

          const SizedBox(height: AppConstants.spacingMd),

          // SCORE BREAKDOWN
          _buildScoreBreakdownSection(match, isExpanded),

          const SizedBox(height: AppConstants.spacingMd),

          // Action Buttons:
          // 1. "Select Hospital" (Primary)
          // 2. "View Hospital Details" (Outlined)
          // 3. "Inspect on Map"
          // 4. "Simulate Divert / Bed Shortage" (Dynamic fallback simulation trigger)
          PrimaryButton(
            text: 'Select Hospital',
            icon: Icons.check_circle_outline,
            onPressed: () => _onSelectHospital(match, rankTitle),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: 'View Hospital Details',
                  icon: Icons.info_outline_rounded,
                  onPressed: () => _onViewHospitalDetails(
                    hosp,
                    distanceKm: match.distanceKm,
                    travelTime: match.travelTime,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Inspect Route on Map Button
              IconButton.outlined(
                tooltip: 'Inspect Facility Route on Map',
                icon: const Icon(Icons.map_rounded, size: 20, color: AppColors.secondarySlateTeal),
                onPressed: () {
                  setState(() {
                    _selectedMapHospital = hosp;
                    _mobileTabIndex = 1;
                  });
                },
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderLight),
                  backgroundColor: AppColors.surfaceLight,
                ),
              ),
              const SizedBox(width: 8),
              // Simulation Button for Dynamic Fallback
              IconButton.outlined(
                tooltip: 'Simulate Facility Divert / Bed Shortage',
                icon: const Icon(Icons.flash_on_rounded, size: 20, color: AppColors.statusAmber),
                onPressed: () => _simulateHospitalUnavailable(hosp),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.statusAmber),
                  backgroundColor: AppColors.statusAmberBg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Why this hospital?" Card displaying the 7 specific clinical and operational rationales.
  Widget _buildWhyThisHospitalCard(HospitalMatchResult match) {
    final hosp = match.hospital;
    final isTravelTimeAcceptable = match.travelTime.inMinutes <= 90;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Gentle medical green tint
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.fact_check_outlined, size: 18, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 8),
              const Text(
                'Why this hospital?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDarkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Condition Priorities Breakdown (if condition-ranked)
          if (match.conditionRanking != null) ...[
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Condition Priorities (${match.conditionRanking!.conditionCategory.displayName}):',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final pe in match.conditionRanking!.priorityEvaluations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: pe.satisfied ? AppColors.primaryLightMint : AppColors.statusAmberBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'P${pe.priorityNumber}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: pe.satisfied ? AppColors.primaryDarkGreen : AppColors.statusAmber,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pe.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textNavyPrimary,
                                  ),
                                ),
                                Text(
                                  pe.explanation,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: pe.satisfied ? AppColors.textNavySecondary : AppColors.statusAmber,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${pe.score.round()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: pe.satisfied ? AppColors.primaryDarkGreen : AppColors.statusAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // 1. Required specialty available
          _buildRationaleCheckRow(
            label: 'Required specialty available (${widget.assessment.requiredSpecialty})',
            isSatisfied: match.hasRequiredSpecialty,
          ),

          // 2. Emergency capability available
          _buildRationaleCheckRow(
            label: 'Emergency capability available (24/7 ED)',
            isSatisfied: match.hasEmergencyCapability,
          ),

          // 3. ICU available
          _buildRationaleCheckRow(
            label: 'ICU available (${hosp.availability?.icuBedsAvailable ?? 0} active ICU beds)',
            isSatisfied: match.hasIcu,
          ),

          // 4. Required diagnostics available
          _buildRationaleCheckRow(
            label: 'Required diagnostics available (${hosp.diagnosticFacilities.take(3).join(", ")})',
            isSatisfied: match.hasRequiredDiagnostics,
          ),

          // 5. Treatment capability available
          _buildRationaleCheckRow(
            label: 'Treatment capability available (${hosp.treatmentCapabilities.take(2).join(", ")})',
            isSatisfied: match.hasRequiredTreatments,
          ),

          // 6. Capacity available
          _buildRationaleCheckRow(
            label: 'Capacity available (${hosp.bedAvailability} general beds • ${(hosp.currentCapacity * 100).toInt()}% occ)',
            isSatisfied: match.hasAvailableBeds,
          ),

          // 7. Travel time acceptable
          _buildRationaleCheckRow(
            label: 'Travel time acceptable (~${match.travelTime.inMinutes} mins by Car)',
            isSatisfied: isTravelTimeAcceptable,
          ),
        ],
      ),
    );
  }

  Widget _buildRationaleCheckRow({
    required String label,
    required bool isSatisfied,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSatisfied ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: isSatisfied ? AppColors.statusGreen : AppColors.statusRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSatisfied ? FontWeight.w500 : FontWeight.w600,
                color: isSatisfied ? AppColors.textNavyPrimary : AppColors.statusRed,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Score breakdown component formatted exactly with the specified 6 weighted categories.
  Widget _buildScoreBreakdownSection(HospitalMatchResult match, bool isExpanded) {
    final b = match.scoreBreakdown;
    final hospId = match.hospital.hospitalId;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMutedLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (_expandedBreakdowns.contains(hospId)) {
                  _expandedBreakdowns.remove(hospId);
                } else {
                  _expandedBreakdowns.add(hospId);
                }
              });
            },
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Score Breakdown',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textNavyPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${b.totalScore.round()}/100',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDarkGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.secondarySlateTeal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            const SizedBox(height: 6),
            const Divider(height: 8),
            const SizedBox(height: 4),

            _buildScoreRow('Specialty Match', b.specialtyMatchScore.round(), 20),
            _buildScoreRow('Medical Capability', b.medicalCapabilityScore.round(), 35),
            _buildScoreRow('Emergency/ICU', b.emergencyIcuScore.round(), 15),
            _buildScoreRow('Availability', b.availabilityScore.round(), 15),
            _buildScoreRow('Travel Time', b.travelTimeScore.round(), 10),
            _buildScoreRow('Distance', b.distanceScore.round(), 5),

            const SizedBox(height: 4),
            const Divider(height: 8),
            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textNavyPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${b.totalScore.round()}/100',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkGreen,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, int score, int max) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textNavySecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '$score/$max',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textNavyPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EXCLUDED HOSPITALS SECTION
  // ===========================================================================

  Widget _buildExcludedHospitalsSection(
    BuildContext context,
    List<UnsuitableHospitalResult> excluded,
  ) {
    return Column(
      children: excluded.map((unsuitable) {
        final hosp = unsuitable.hospital;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hosp.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textNavyPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.statusRedBg,
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Excluded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${unsuitable.distanceKm.toStringAsFixed(1)} km (~${(unsuitable.distanceKm * 1000).round()} m) away • ~${unsuitable.travelTime.inMinutes} mins by Car',
                  style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted),
                ),
                const SizedBox(height: 6),
                const Divider(height: 8),
                const SizedBox(height: 4),

                // Exclusion Reasons
                ...unsuitable.exclusionReasons.map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cancel_outlined, size: 14, color: AppColors.statusRed),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.statusRed,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _onViewHospitalDetails(
                      hosp,
                      distanceKm: unsuitable.distanceKm,
                      travelTime: unsuitable.travelTime,
                    ),
                    icon: const Icon(Icons.info_outline, size: 14, color: AppColors.secondarySlateTeal),
                    label: const Text(
                      'View Details',
                      style: TextStyle(fontSize: 11, color: AppColors.secondarySlateTeal),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // NO SUITABLE HOSPITALS STATE
  // ===========================================================================

  Widget _buildNoSuitableHospitalCard() {
    final missing = _recommendations.conditionRecommendation?.missingCapabilities ?? [];
    final escalation = _recommendations.conditionRecommendation?.escalationProtocol;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 32, color: AppColors.statusRed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No suitable hospital could be confirmed from the available data.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.statusRed,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'No suitable referral facility found in the current regional network dataset.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (missing.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Missing Mandatory Capabilities Across Candidate Hospitals:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusRed,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: missing.map((m) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusRedBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          m,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusRed,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          const Text(
            'Reasons: All partner facilities in the regional network failed mandatory criteria '
            '(diverting status, zero bed availability, lacking 24/7 ED, or missing required specialty/ICU care).',
            style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_phone_rounded, size: 18, color: AppColors.statusRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emergency Protocol Recommendation: Follow established local emergency escalation/transfer protocols. '
                        'Contact District Health Officer (DHO) or State Emergency Medical Dispatch (108/112) for emergency inter-facility triage coordination.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7F1D1D), height: 1.35),
                      ),
                      if (escalation != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          escalation,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Emergency Dispatch 108/112 auto-dial initiated.'),
                      backgroundColor: AppColors.statusRed,
                    ),
                  );
                },
                icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: AppColors.statusRed),
                label: const Text('Call Emergency Dispatch (108/112)', style: TextStyle(color: AppColors.statusRed)),
              ),
              TextButton.icon(
                onPressed: _resetHospitalsToDefault,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Network'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODALS & CONFIRMATION SHEETS
  // ===========================================================================

  Widget _buildConfirmDestinationSheet(
    BuildContext ctx,
    HospitalMatchResult match,
    String tierLabel,
  ) {
    final hosp = match.hospital;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Icon(Icons.send_rounded, color: AppColors.primaryGreen, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Confirm Referral Destination',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textNavyPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'You are about to initiate an inter-facility referral to:',
            style: TextStyle(fontSize: 13, color: AppColors.textNavySecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceMutedLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hosp.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLightMint,
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        tierLabel,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDarkGreen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(hosp.address, style: const TextStyle(fontSize: 12, color: AppColors.textNavyMuted)),
                const SizedBox(height: 6),
                Text(
                  'Transit: ~${match.travelTime.inMinutes} mins by Car (${match.distanceKm.toStringAsFixed(1)} km / ~${(match.distanceKm * 1000).round()} m) • Match Score: ${match.matchScore.round()}/100',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondarySlateTeal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Explicit Clinical Dispatch Notice (Do not claim automatic acceptance)
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB45309)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pre-Dispatch Verification Notice:\n'
                    'Do not automatically claim hospital acceptance. The healthcare worker must confirm bed availability '
                    'and specialist readiness via direct tele-handover before dispatching the patient transport.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Primary Confirmation Action
          PrimaryButton(
            text: 'Confirm Referral Destination',
            icon: Icons.check_circle_rounded,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),

          const SizedBox(height: 8),

          SecondaryButton(
            text: 'Cancel / Choose Another',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalDetailsSheet(
    BuildContext ctx,
    Hospital hosp,
    double? distanceKm,
    Duration? travelTime,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLightMint,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: AppColors.primaryGreen, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hosp.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
                      ),
                      Text(
                        'ID: ${hosp.hospitalId} • ${hosp.operatingStatus}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textNavyMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            Text('Address: ${hosp.address}', style: const TextStyle(fontSize: 12, color: AppColors.textNavySecondary)),
            if (distanceKm != null && travelTime != null) ...[
              const SizedBox(height: 4),
              Text(
                'Distance: ${distanceKm.toStringAsFixed(1)} km (~${(distanceKm * 1000).round()} m) • Transit Time: ~${travelTime.inMinutes} mins by Car',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondarySlateTeal),
              ),
            ],

            const SizedBox(height: 12),
            const Text(
              'Operating & Bed Capacity (Simulated):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '• General Beds Available: ${hosp.bedAvailability}\n'
              '• ICU Beds Available: ${hosp.availability?.icuBedsAvailable ?? (hosp.icuAvailable ? "Equipped" : 0)}\n'
              '• 24/7 Emergency Care: ${hosp.emergencyCare ? "Operational" : "Closed / Not available"}\n'
              '• Occupancy Level: ${(hosp.currentCapacity * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: AppColors.textNavySecondary, height: 1.4),
            ),

            const SizedBox(height: 12),
            const Text(
              'Specialties:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: hosp.specialties.map((s) => Chip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                backgroundColor: AppColors.surfaceMutedLight,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),

            const SizedBox(height: 12),
            const Text(
              'Diagnostic Facilities:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: hosp.diagnosticFacilities.map((d) => Chip(
                label: Text(d, style: const TextStyle(fontSize: 11)),
                backgroundColor: AppColors.surfaceMutedLight,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),

            const SizedBox(height: 12),
            const Text(
              'Treatment Capabilities:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: hosp.treatmentCapabilities.map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 11)),
                backgroundColor: AppColors.surfaceMutedLight,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),

            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Close Hospital Details',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
