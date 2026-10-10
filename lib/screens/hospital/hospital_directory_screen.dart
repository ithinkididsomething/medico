import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/hospital.dart';
import '../../models/mock_data.dart';
import '../../repositories/hospital_repository.dart';
import '../../repositories/offline_first_hospital_repository.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/hospital_card.dart';
import '../../widgets/search_field.dart';
import '../../core/animations/app_motion.dart';
import '../../widgets/animations/animations.dart';
import 'clinic_location_dialog.dart';
import 'hospital_details_screen.dart';
import 'hospital_map_view.dart';
import '../../core/utils/navigation_utils.dart';

/// Interactive Hospital Directory Screen.
///
/// Implements:
/// - Searchable synthetic hospital directory
/// - Multi-dimensional filters (Specialty, Emergency, ICU, Diagnostics, Availability)
/// - Responsive List & OpenStreetMap view toggle
/// - Location permission state handling (Granted, Denied, Unavailable, Manual)
/// - Manual clinic location overrides
/// - Distance and simulated travel time calculations
class HospitalDirectoryScreen extends StatefulWidget {
  final HospitalRepository? repository;
  final LocationService? locationService;
  final void Function(Hospital hospital)? onSelectHospital;

  final bool showHeader;

  const HospitalDirectoryScreen({
    super.key,
    this.repository,
    this.locationService,
    this.onSelectHospital,
    this.showHeader = true,
  });

  @override
  State<HospitalDirectoryScreen> createState() => _HospitalDirectoryScreenState();
}

class _HospitalDirectoryScreenState extends State<HospitalDirectoryScreen> {
  late final HospitalRepository _repository;
  late final LocationService _locationService;

  List<Hospital> _allHospitals = [];
  List<Hospital> _filteredHospitals = [];
  bool _isLoading = true;

  // View Mode: 0 = List View, 1 = Map View
  int _viewMode = 0;

  // Search & Filter State
  String _searchQuery = '';
  String? _selectedSpecialty;
  String? _selectedTag;
  bool _emergencyOnly = false;
  bool _icuOnly = false;
  String? _selectedDiagnostic;
  bool _availableOnly = false;
  bool _operationalOnly = false;

  // Pre-calculated distances & travel estimates for fast UI display
  final Map<String, double> _hospitalDistances = {};
  final Map<String, Duration> _hospitalTravelTimes = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OfflineFirstHospitalRepository.instance;
    _locationService = widget.locationService ?? DefaultLocationService();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() => _isLoading = true);
    final list = await _repository.getAllHospitals();
    _allHospitals = list;
    _recalculateDistances();
    _applyFilters();
  }

  void _recalculateDistances() {
    final clinic = _locationService.currentClinicLocation;
    _hospitalDistances.clear();
    _hospitalTravelTimes.clear();

    for (final hospital in _allHospitals) {
      final straight = _haversineKm(
        clinic.latitude,
        clinic.longitude,
        hospital.latitude,
        hospital.longitude,
      );
      final roadKm = straight * SimulatedRoutingService.ruralRoadCurvatureFactor;
      final speed = hospital.emergencyCare
          ? SimulatedRoutingService.emergencyAmbulanceSpeedKmh
          : SimulatedRoutingService.standardRuralSpeedKmh;
      final mins = (roadKm / speed * 60).round().clamp(5, 480);

      _hospitalDistances[hospital.hospitalId] = roadKm;
      _hospitalTravelTimes[hospital.hospitalId] = Duration(minutes: mins);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredHospitals = _allHospitals.where((hospital) {
        // 1. Text Query (Name, Address, Specialties, Tags, Diagnostic/Treatment Facilities)
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.trim().toLowerCase();
          final matchesName = hospital.name.toLowerCase().contains(q);
          final matchesAddress = hospital.address.toLowerCase().contains(q);
          final matchesSpec = hospital.specialties.any((s) => s.toLowerCase().contains(q));
          final matchesTag = hospital.tags.any((t) => t.toLowerCase().contains(q));
          final matchesFacility = hospital.diagnosticFacilities.any((d) => d.toLowerCase().contains(q)) ||
              hospital.treatmentCapabilities.any((t) => t.toLowerCase().contains(q));
          if (!matchesName && !matchesAddress && !matchesSpec && !matchesTag && !matchesFacility) {
            return false;
          }
        }

        // 2. Tag Filter
        if (_selectedTag != null && _selectedTag != 'All') {
          if (!hospital.hasTag(_selectedTag!)) {
            return false;
          }
        }

        // 3. Specialty Filter
        if (_selectedSpecialty != null && _selectedSpecialty != 'All') {
          if (!hospital.hasSpecialty(_selectedSpecialty!)) {
            return false;
          }
        }

        // 3. Emergency Filter
        if (_emergencyOnly && !hospital.emergencyCare) {
          return false;
        }

        // 4. ICU Filter
        if (_icuOnly && (!hospital.icuAvailable || (hospital.availability?.icuBedsAvailable ?? 0) <= 0)) {
          return false;
        }

        // 5. Diagnostics Filter
        if (_selectedDiagnostic != null && _selectedDiagnostic != 'All') {
          if (!hospital.hasFacility(_selectedDiagnostic!)) {
            return false;
          }
        }

        // 6. Availability Filter
        if (_availableOnly && hospital.bedAvailability <= 0) {
          return false;
        }

        // 7. Operational Filter
        if (_operationalOnly && hospital.operatingStatus.toLowerCase() == 'diverting') {
          return false;
        }

        return true;
      }).toList();

      // Sort by proximity to current clinic
      _filteredHospitals.sort((a, b) {
        final distA = _hospitalDistances[a.hospitalId] ?? 999.0;
        final distB = _hospitalDistances[b.hospitalId] ?? 999.0;
        return distA.compareTo(distB);
      });

      _isLoading = false;
    });
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedTag != null && _selectedTag != 'All') count++;
    if (_selectedSpecialty != null && _selectedSpecialty != 'All') count++;
    if (_emergencyOnly) count++;
    if (_icuOnly) count++;
    if (_selectedDiagnostic != null && _selectedDiagnostic != 'All') count++;
    if (_availableOnly) count++;
    if (_operationalOnly) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _selectedTag = null;
      _selectedSpecialty = null;
      _emergencyOnly = false;
      _icuOnly = false;
      _selectedDiagnostic = null;
      _availableOnly = false;
      _operationalOnly = false;
      _searchQuery = '';
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final clinic = _locationService.currentClinicLocation;
    final permState = _locationService.permissionState;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            if (widget.showHeader)
              AppHeader(
                title: 'Hospital Directory',
                subtitle: 'Regional Secondary & Tertiary Referral Centers',
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => SafeNavigation.pop(context, fallbackTab: 0),
                  tooltip: 'Back',
                ),
                showClinicStatusBar: true,
              ),

            // Clinic Location Bar & GPS Permission Status
            _buildClinicLocationBar(clinic, permState),

            // Search Bar & Filter Strip
            _buildSearchAndFilterStrip(),

            // View Mode Toggle (List View | Map View)
            _buildViewModeToggle(),

            // Main Content: List View or Map View
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.durationMedium,
                child: _isLoading
                    ? ListView(
                        key: const ValueKey('hospital_shimmer_list'),
                        children: const [
                          HospitalCardSkeleton(),
                          HospitalCardSkeleton(),
                          HospitalCardSkeleton(),
                        ],
                      )
                    : _viewMode == 0
                        ? KeyedSubtree(
                            key: const ValueKey('hospital_list_view'),
                            child: _buildHospitalListView(),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('hospital_map_view'),
                            child: _buildHospitalMapView(clinic),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CLINIC LOCATION STRIP
  // ===========================================================================

  Widget _buildClinicLocationBar(ClinicLocation clinic, LocationPermissionState permState) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: 8),
      child: Row(
        children: [
          Icon(_getPermIcon(permState), size: 16, color: _getPermColor(permState)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      clinic.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textNavyPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 6),
                    _buildPermPill(permState),
                  ],
                ),
                Text(
                  'Base Coordinates: ${clinic.latitude.toStringAsFixed(3)}° N, ${clinic.longitude.toStringAsFixed(3)}° E',
                  style: const TextStyle(fontSize: 10, color: AppColors.textNavyMuted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              ClinicLocationDialog.show(
                context,
                locationService: _locationService,
                onLocationChanged: () {
                  setState(() {
                    _recalculateDistances();
                    _applyFilters();
                  });
                },
              );
            },
            icon: const Icon(Icons.tune_rounded, size: 14),
            label: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(50, 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermPill(LocationPermissionState state) {
    final label = state == LocationPermissionState.granted
        ? 'GPS'
        : (state == LocationPermissionState.manual ? 'Manual' : 'Offline/PHC');
    final color = _getPermColor(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  // ===========================================================================
  // SEARCH & FILTER STRIP
  // ===========================================================================

  Widget _buildSearchAndFilterStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Search hospitals, specialties, diagnostics...',
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterButton(),
            ],
          ),
          const SizedBox(height: 6),
          // Horizontal Quick Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilterChip(
                  label: 'Super Speciality',
                  icon: Icons.domain_rounded,
                  isActive: _selectedTag == 'Super Speciality',
                  onToggle: () {
                    setState(() {
                      _selectedTag = _selectedTag == 'Super Speciality' ? null : 'Super Speciality';
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterChip(
                  label: 'Govt / CHC',
                  icon: Icons.account_balance_rounded,
                  isActive: _selectedTag == 'Government',
                  onToggle: () {
                    setState(() {
                      _selectedTag = _selectedTag == 'Government' ? null : 'Government';
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterChip(
                  label: 'Trauma Care',
                  icon: Icons.healing_rounded,
                  isActive: _selectedTag == 'Trauma Care',
                  onToggle: () {
                    setState(() {
                      _selectedTag = _selectedTag == 'Trauma Care' ? null : 'Trauma Care';
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterChip(
                  label: '24/7 Emergency',
                  icon: Icons.emergency_rounded,
                  isActive: _emergencyOnly,
                  onToggle: () {
                    setState(() => _emergencyOnly = !_emergencyOnly);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterChip(
                  label: 'ICU Available',
                  icon: Icons.airline_seat_flat_rounded,
                  isActive: _icuOnly,
                  onToggle: () {
                    setState(() => _icuOnly = !_icuOnly);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterChip(
                  label: 'Free Beds Only',
                  icon: Icons.check_circle_outline_rounded,
                  isActive: _availableOnly,
                  onToggle: () {
                    setState(() => _availableOnly = !_availableOnly);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterChip(
                  label: 'Exclude Diverting',
                  icon: Icons.block_rounded,
                  isActive: _operationalOnly,
                  onToggle: () {
                    setState(() => _operationalOnly = !_operationalOnly);
                    _applyFilters();
                  },
                ),
                if (_activeFilterCount > 0) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.clear_rounded, size: 14),
                    label: const Text('Reset', style: TextStyle(fontSize: 11)),
                    onPressed: _resetFilters,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    final count = _activeFilterCount;
    return Stack(
      children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.filter_list_rounded, size: 20),
          tooltip: 'Detailed Filters',
          onPressed: _showDetailedFilterModal,
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.statusRed,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onToggle,
  }) {
    return FilterChip(
      avatar: Icon(icon, size: 14, color: isActive ? AppColors.primaryDarkGreen : AppColors.textNavyMuted),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isActive,
      onSelected: (_) => onToggle(),
    );
  }

  // ===========================================================================
  // VIEW MODE TOGGLE (List View | Map View)
  // ===========================================================================

  Widget _buildViewModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: 4),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment<int>(
            value: 0,
            icon: Icon(Icons.list_alt_rounded, size: 16),
            label: Text('List View', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment<int>(
            value: 1,
            icon: Icon(Icons.map_rounded, size: 16),
            label: Text('OpenStreetMap', style: TextStyle(fontSize: 12)),
          ),
        ],
        selected: {_viewMode},
        onSelectionChanged: (set) {
          setState(() {
            _viewMode = set.first;
          });
        },
      ),
    );
  }

  // ===========================================================================
  // LIST VIEW BUILDER
  // ===========================================================================

  Widget _buildHospitalListView() {
    if (_filteredHospitals.isEmpty) {
      return _buildEmptyState();
    }

    final recommended = MockClinicalData.hospitalDistrictGeneral;

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      itemCount: _filteredHospitals.length,
      itemBuilder: (context, index) {
        final hospital = _filteredHospitals[index];
        final distance = _hospitalDistances[hospital.hospitalId];
        final travelTime = _hospitalTravelTimes[hospital.hospitalId];
        final isRec = hospital.hospitalId == recommended.hospitalId;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
          child: EntranceFader(
            delay: Duration(milliseconds: (index * 40).clamp(0, 280)),
            child: HospitalCard(
              hospital: hospital,
              distanceKm: distance,
              travelTime: travelTime,
              isRecommended: isRec,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (ctx) => HospitalDetailsScreen(
                      hospital: hospital,
                      clinicLocation: _locationService.currentClinicLocation,
                      onSelectHospital: widget.onSelectHospital != null
                          ? () => widget.onSelectHospital!(hospital)
                          : null,
                    ),
                  ),
                );
              },
              onSelect: widget.onSelectHospital != null
                  ? () => widget.onSelectHospital!(hospital)
                  : null,
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // MAP VIEW BUILDER
  // ===========================================================================

  Widget _buildHospitalMapView(ClinicLocation clinic) {
    return HospitalMapView(
      hospitals: _filteredHospitals,
      clinicLocation: clinic,
      recommendedHospital: MockClinicalData.hospitalDistrictGeneral,
      onSelectHospital: widget.onSelectHospital,
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.domain_disabled_rounded, size: 48, color: AppColors.textNavyMuted),
            const SizedBox(height: 12),
            const Text(
              'No Matching Hospitals Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'No facilities matched your current search filters. Try widening specialty or diagnostic criteria.',
              style: TextStyle(fontSize: 12, color: AppColors.textNavyMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DETAILED FILTER MODAL
  // ===========================================================================

  void _showDetailedFilterModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final allSpecialties = [
              'All',
              'Obstetrics & Gynecology',
              'Pediatrics',
              'Cardiology',
              'Orthopedics',
              'General Surgery',
              'General Medicine',
            ];

            final allDiagnostics = [
              'All',
              'Digital X-Ray',
              'Ultrasound',
              'CT Scanner',
              'Blood Bank',
              'Basic Clinical Lab',
            ];

            return Padding(
              padding: EdgeInsets.only(
                left: AppConstants.spacingLg,
                right: AppConstants.spacingLg,
                top: AppConstants.spacingLg,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppConstants.spacingLg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Hospital Network',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedTag = null;
                              _selectedSpecialty = null;
                              _emergencyOnly = false;
                              _icuOnly = false;
                              _selectedDiagnostic = null;
                              _availableOnly = false;
                              _operationalOnly = false;
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Facility Tag Dropdown
                    const Text('Facility Category / Tag:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTag ?? 'All',
                      isExpanded: true,
                      items: const [
                        'All',
                        'Super Speciality',
                        'Tertiary Care',
                        'Medical College & Hospital',
                        'Multi-Specialty',
                        'Government',
                        'CHC',
                        'Community Health Centre',
                        'Primary Health Centre',
                        'Trauma Care',
                        'Blood Bank',
                        'Multispecialty Clinic',
                      ]
                          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) => setModalState(() => _selectedTag = val),
                    ),
                    const SizedBox(height: 14),

                    // Specialty Dropdown
                    const Text('Required Clinical Specialty:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSpecialty ?? 'All',
                      isExpanded: true,
                      items: allSpecialties
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) => setModalState(() => _selectedSpecialty = val),
                    ),
                    const SizedBox(height: 14),

                    // Diagnostic Facility Dropdown
                    const Text('Required Diagnostic Capability:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDiagnostic ?? 'All',
                      isExpanded: true,
                      items: allDiagnostics
                          .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) => setModalState(() => _selectedDiagnostic = val),
                    ),
                    const SizedBox(height: 14),

                    // Toggles
                    SwitchListTile(
                      dense: true,
                      title: const Text('24/7 Emergency Care Required', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      value: _emergencyOnly,
                      onChanged: (v) => setModalState(() => _emergencyOnly = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Intensive Care Unit (ICU) Required', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      value: _icuOnly,
                      onChanged: (v) => setModalState(() => _icuOnly = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Available Beds Only (> 0)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      value: _availableOnly,
                      onChanged: (v) => setModalState(() => _availableOnly = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Exclude Diverting Hospitals', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      value: _operationalOnly,
                      onChanged: (v) => setModalState(() => _operationalOnly = v),
                    ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _applyFilters();
                      },
                      child: const Text('Apply Filter Settings', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Color _getPermColor(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.granted:
        return AppColors.primaryGreen;
      case LocationPermissionState.denied:
        return AppColors.statusAmber;
      case LocationPermissionState.unavailable:
        return AppColors.textNavyMuted;
      case LocationPermissionState.manual:
        return const Color(0xFF2563EB);
    }
  }

  IconData _getPermIcon(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.granted:
        return Icons.my_location_rounded;
      case LocationPermissionState.denied:
        return Icons.location_disabled_rounded;
      case LocationPermissionState.unavailable:
        return Icons.location_off_rounded;
      case LocationPermissionState.manual:
        return Icons.edit_location_alt_rounded;
    }
  }
}
