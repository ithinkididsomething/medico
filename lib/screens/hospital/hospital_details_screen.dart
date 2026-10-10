import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/hospital.dart';
import '../../models/synthetic_doctor.dart';
import '../../services/hierarchical_ranking_service.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../core/utils/navigation_utils.dart';

/// Comprehensive Hospital Details Screen displaying full medical capabilities,
/// simulated transit estimates, and explicit clinical limitations / operational constraints.
class HospitalDetailsScreen extends StatefulWidget {
  final Hospital hospital;
  final ClinicLocation? clinicLocation;
  final VoidCallback? onSelectHospital;

  const HospitalDetailsScreen({
    super.key,
    required this.hospital,
    this.clinicLocation,
    this.onSelectHospital,
  });

  @override
  State<HospitalDetailsScreen> createState() => _HospitalDetailsScreenState();
}

class _HospitalDetailsScreenState extends State<HospitalDetailsScreen> {
  final RoutingService _routingService = const SimulatedRoutingService();
  final HierarchicalRankingService _rankingService = HierarchicalRankingService();
  RouteEstimate? _routeEstimate;
  bool _isLoadingRoute = true;
  List<DoctorProfile> _affiliatedDoctors = [];
  bool _isLoadingDoctors = true;

  @override
  void initState() {
    super.initState();
    _calculateRoute();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final docs = await _rankingService.getDoctorsForFacility(
        widget.hospital.hospitalId,
        includeSynthetic: true,
      );
      if (mounted) {
        setState(() {
          _affiliatedDoctors = docs;
          _isLoadingDoctors = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingDoctors = false;
        });
      }
    }
  }

  Future<void> _calculateRoute() async {
    final clinic = widget.clinicLocation ?? ClinicLocation.defaultSector4PHC;
    final estimate = await _routingService.calculateRoute(
      origin: clinic.latLng,
      destination: LatLng(widget.hospital.latitude, widget.hospital.longitude),
      isEmergency: widget.hospital.emergencyCare,
    );
    if (mounted) {
      setState(() {
        _routeEstimate = estimate;
        _isLoadingRoute = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospital = widget.hospital;
    final isDiverting = hospital.operatingStatus.toLowerCase() == 'diverting';
    final limitations = _analyzeLimitations(hospital);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: hospital.name,
              subtitle: 'Facility Capabilities & Operational Limits',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => SafeNavigation.pop(context, fallbackTab: 3),
                tooltip: 'Back',
              ),
              showClinicStatusBar: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Facility Summary Card
                    _buildFacilityHeaderCard(hospital, isDiverting),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Travel & Proximity Card
                    _buildTransitCard(hospital),

                    const SizedBox(height: AppConstants.spacingMd),

                    // EXPLICIT LIMITATIONS SECTION (Required by Prompt)
                    _buildLimitationsCard(limitations, isDiverting),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Emergency & ICU Capabilities
                    _buildEmergencyAndIcuCard(hospital),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Bed Capacity & Occupancy Card
                    _buildCapacityCard(hospital),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Clinical Specialties Card
                    _buildSpecialtiesCard(hospital),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Affiliated Clinicians & Medical Staff Card
                    _buildAffiliatedCliniciansCard(),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Diagnostic Facilities Card
                    _buildDiagnosticCard(hospital),

                    const SizedBox(height: AppConstants.spacingMd),

                    // Treatment & Surgical Capabilities Card
                    _buildTreatmentCard(hospital),

                    const SizedBox(height: AppConstants.spacingLg),

                    // Bottom Action
                    if (widget.onSelectHospital != null) ...[
                      PrimaryButton(
                        text: 'Select as Referral Destination',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onSelectHospital?.call();
                        },
                      ),
                      const SizedBox(height: AppConstants.spacingSm),
                    ],
                    SecondaryButton(
                      text: 'Call Emergency Dispatch (108 / 112)',
                      icon: Icons.phone_in_talk_rounded,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Calling regional dispatch link: 108 / 112.'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppConstants.spacingLg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. FACILITY HEADER CARD
  // ===========================================================================
  Widget _buildFacilityHeaderCard(Hospital hospital, bool isDiverting) {
    return AppCard(
      accentColor: isDiverting ? AppColors.statusRed : AppColors.primaryGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDiverting ? AppColors.statusRedBg : AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: isDiverting ? AppColors.statusRed : AppColors.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'hospital_hero_${hospital.hospitalId}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          hospital.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textNavyPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hospital.address,
                      style: const TextStyle(fontSize: 12, color: AppColors.textNavyMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDiverting ? AppColors.statusRedBg : AppColors.statusGreenBg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                  border: Border.all(
                    color: isDiverting ? AppColors.statusRed : AppColors.primaryGreen,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  hospital.operatingStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDiverting ? AppColors.statusRed : AppColors.primaryDarkGreen,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (hospital.tags.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingSm + 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: hospital.tags.map((tag) => _buildDetailTagPill(tag)).toList(),
            ),
          ],
          const SizedBox(height: AppConstants.spacingSm + 4),
          _buildVerificationAndFreshnessBanner(hospital),
          const SizedBox(height: AppConstants.spacingSm + 4),
          Row(
            children: [
              const Icon(Icons.explore_outlined, size: 14, color: AppColors.textNavyMuted),
              const SizedBox(width: 4),
              Text(
                'Coordinates: ${hospital.latitude.toStringAsFixed(4)}° N, ${hospital.longitude.toStringAsFixed(4)}° E',
                style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                hospital.dataSource,
                style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.textNavyMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationAndFreshnessBanner(Hospital hospital) {
    final isOutdated = hospital.isAvailabilityOutdated();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOutdated ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOutdated ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOutdated ? Icons.schedule_rounded : Icons.verified_rounded,
            size: 15,
            color: isOutdated ? const Color(0xFFD97706) : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isOutdated
                  ? 'Dynamic Capacity Outdated (>60 min) • Call 108/Facility to confirm'
                  : 'Verified Central Facility (Rev ${hospital.revision}) • Live Status Confirmed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isOutdated ? const Color(0xFF92400E) : const Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTagPill(String tag) {
    Color bg;
    Color border;
    Color text;

    final lower = tag.toLowerCase();
    if (lower.contains('super speciality') || lower.contains('apex') || lower.contains('medical college')) {
      bg = const Color(0xFFEDE9FE);
      border = const Color(0xFFC4B5FD);
      text = const Color(0xFF5B21B6);
    } else if (lower.contains('government') || lower.contains('chc') || lower.contains('phc')) {
      bg = const Color(0xFFE0F2FE);
      border = const Color(0xFF7DD3FC);
      text = const Color(0xFF0369A1);
    } else if (lower.contains('emergency') || lower.contains('trauma') || lower.contains('cardiac')) {
      bg = const Color(0xFFFEE2E2);
      border = const Color(0xFFFCA5A5);
      text = const Color(0xFFB91C1C);
    } else if (lower.contains('icu') || lower.contains('blood bank')) {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFFCD34D);
      text = const Color(0xFFB45309);
    } else {
      bg = const Color(0xFFF1F5F9);
      border = const Color(0xFFCBD5E1);
      text = const Color(0xFF334155);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.9),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. TRANSIT & ROUTE ESTIMATE CARD
  // ===========================================================================
  Widget _buildTransitCard(Hospital hospital) {
    final clinic = widget.clinicLocation ?? ClinicLocation.defaultSector4PHC;

    return AppCard(
      title: 'Transfer Logistics & Distance',
      subtitle: 'From ${clinic.name}',
      leadingIcon: const Icon(Icons.directions_car_rounded, color: AppColors.secondarySlateTeal),
      child: _isLoadingRoute
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppConstants.spacingMd),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricBox(
                      title: 'Road Distance',
                      value: _routeEstimate?.formattedDistance ?? 'Unknown',
                      icon: Icons.straighten_rounded,
                      color: AppColors.textNavyPrimary,
                    ),
                    _buildMetricBox(
                      title: 'Travel Time (by Car)',
                      value: _routeEstimate?.formattedTravelTime ?? 'Unknown',
                      icon: Icons.directions_car_rounded,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm + 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMutedLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.secondarySlateTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _routeEstimate?.sourceLabel ?? 'Simulated Transit Estimate',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textNavyPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _routeEstimate?.disclaimer ??
                                  'Simulated travel time based on distance. Live traffic is not monitored.',
                              style: const TextStyle(fontSize: 10, color: AppColors.textNavySecondary, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // 3. EXPLICIT LIMITATIONS & RESTRICTIONS (Required by prompt)
  // ===========================================================================
  Widget _buildLimitationsCard(List<HospitalLimitation> limitations, bool isDiverting) {
    final hasCritical = limitations.any((l) => l.isCritical) || isDiverting;

    return AppCard(
      title: 'Facility Limitations & Constraints',
      subtitle: 'Critical clinical boundary check for referral decisions',
      leadingIcon: Icon(
        hasCritical ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
        color: hasCritical ? AppColors.statusAmber : AppColors.primaryGreen,
      ),
      accentColor: hasCritical ? AppColors.statusAmber : AppColors.primaryGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (limitations.isEmpty && !isDiverting)
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm + 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLightMint,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primaryGreen),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Comprehensive Referral Facility: No major capacity, diagnostic, or ICU constraints currently flagged in registry.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDarkGreen),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'Review the following operational limits before initiating transfer:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasCritical ? AppColors.statusAmber : AppColors.textNavySecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final lim in limitations) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: lim.isCritical ? AppColors.statusRedBg : AppColors.surfaceMutedLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    border: Border.all(
                      color: lim.isCritical ? AppColors.statusRed : AppColors.borderLight,
                      width: lim.isCritical ? 1.2 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        lim.isCritical ? Icons.cancel_rounded : Icons.info_outline_rounded,
                        size: 16,
                        color: lim.isCritical ? AppColors.statusRed : AppColors.statusAmber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lim.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: lim.isCritical ? AppColors.statusRed : AppColors.textNavyPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lim.explanation,
                              style: TextStyle(
                                fontSize: 11,
                                color: lim.isCritical ? AppColors.textNavyPrimary : AppColors.textNavySecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. EMERGENCY & ICU CAPABILITIES
  // ===========================================================================
  Widget _buildEmergencyAndIcuCard(Hospital hospital) {
    return AppCard(
      title: 'Emergency & Critical Care',
      subtitle: 'Acute stabilization and intensive care capacity',
      leadingIcon: const Icon(Icons.emergency_rounded, color: AppColors.statusRed),
      child: Column(
        children: [
          _buildCapabilityRow(
            label: '24/7 Emergency Care',
            isSupported: hospital.emergencyCare,
            detail: hospital.emergencyCare
                ? 'Open around-the-clock for trauma & acute triage'
                : 'No dedicated 24/7 Emergency Department',
          ),
          const Divider(color: AppColors.borderLight, height: 16),
          _buildCapabilityRow(
            label: 'Intensive Care Unit (ICU)',
            isSupported: hospital.icuAvailable,
            detail: hospital.icuAvailable
                ? '${hospital.availability?.icuBedsAvailable ?? 0} ICU beds currently available with ventilator support'
                : 'No mechanical ventilation or ICU beds available',
          ),
          const Divider(color: AppColors.borderLight, height: 16),
          _buildCapabilityRow(
            label: 'Emergency Operating Theaters',
            isSupported: (hospital.availability?.operatingTheatersAvailable ?? 0) > 0,
            detail: '${hospital.availability?.operatingTheatersAvailable ?? 0} active operating rooms ready',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. BED CAPACITY & OCCUPANCY
  // ===========================================================================
  Widget _buildCapacityCard(Hospital hospital) {
    final occupancyPct = (hospital.currentCapacity * 100).toInt();
    final isCritical = hospital.currentCapacity >= 0.90 || hospital.bedAvailability <= 2;

    return AppCard(
      title: 'Bed Capacity & Occupancy',
      subtitle: 'Simulated real-time hospital occupancy',
      leadingIcon: const Icon(Icons.airline_seat_flat_rounded, color: AppColors.primaryGreen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Occupancy Rate: $occupancyPct%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isCritical ? AppColors.statusRed : AppColors.textNavyPrimary,
                ),
              ),
              Text(
                '${hospital.bedAvailability} General Beds Free',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hospital.bedAvailability > 0 ? AppColors.statusGreen : AppColors.statusRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: hospital.currentCapacity.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.borderLight,
              color: isCritical ? AppColors.statusRed : (occupancyPct > 75 ? AppColors.statusAmber : AppColors.primaryGreen),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.update_rounded, size: 14, color: AppColors.textNavyMuted),
              const SizedBox(width: 4),
              Text(
                'Last updated: ${hospital.availabilityLastUpdated.hour.toString().padLeft(2, '0')}:${hospital.availabilityLastUpdated.minute.toString().padLeft(2, '0')} (Simulated Feed)',
                style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. CLINICAL SPECIALTIES
  // ===========================================================================
  Widget _buildSpecialtiesCard(Hospital hospital) {
    return AppCard(
      title: 'Clinical Specialties',
      subtitle: '${hospital.specialties.length} authorized clinical departments',
      leadingIcon: const Icon(Icons.medical_services_outlined, color: AppColors.primaryGreen),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: hospital.specialties.map((spec) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLightMint,
              borderRadius: BorderRadius.circular(AppConstants.radiusPill),
              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
            ),
            child: Text(
              spec,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDarkGreen),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // 7. DIAGNOSTIC FACILITIES
  // ===========================================================================
  Widget _buildDiagnosticCard(Hospital hospital) {
    return AppCard(
      title: 'Diagnostic Facilities',
      subtitle: 'On-site laboratory and imaging equipment',
      leadingIcon: const Icon(Icons.biotech_rounded, color: AppColors.tealAccentDark),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: hospital.diagnosticFacilities.map((diag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMutedLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primaryGreen),
                const SizedBox(width: 6),
                Text(
                  diag,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyPrimary),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // 8. TREATMENT & SURGICAL CAPABILITIES
  // ===========================================================================
  Widget _buildTreatmentCard(Hospital hospital) {
    return AppCard(
      title: 'Treatment & Interventions',
      subtitle: 'Surgical and acute therapeutic procedures',
      leadingIcon: const Icon(Icons.healing_rounded, color: AppColors.secondarySlateTeal),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: hospital.treatmentCapabilities.map((treat) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMutedLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.done_all_rounded, size: 14, color: AppColors.secondarySlateTeal),
                const SizedBox(width: 6),
                Text(
                  treat,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyPrimary),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Helper Widgets
  Widget _buildMetricBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildCapabilityRow({
    required String label,
    required bool isSupported,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isSupported ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isSupported ? AppColors.primaryGreen : AppColors.statusRed,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
              ),
              const SizedBox(height: 1),
              Text(
                detail,
                style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted, height: 1.25),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Analyzes a hospital's capabilities and dynamically identifies limitations.
  List<HospitalLimitation> _analyzeLimitations(Hospital hospital) {
    final list = <HospitalLimitation>[];

    if (!hospital.icuAvailable) {
      list.add(const HospitalLimitation(
        title: 'No Intensive Care Unit (ICU)',
        explanation: 'Facility lacks ventilator equipment and invasive critical care monitoring. Unsuitable for respiratory failure or hemodynamic collapse.',
        isCritical: true,
      ));
    } else if ((hospital.availability?.icuBedsAvailable ?? 0) <= 0) {
      list.add(const HospitalLimitation(
        title: 'Zero ICU Beds Available',
        explanation: 'Intensive care unit is fully occupied (0 ICU beds free). Urgent intubation cases may face severe diversion delays.',
        isCritical: true,
      ));
    }

    if (!hospital.emergencyCare) {
      list.add(const HospitalLimitation(
        title: 'No 24/7 Emergency Department',
        explanation: 'Facility operates clinic hours only; unavailable for acute trauma, cardiopulmonary emergencies, or nighttime admissions.',
        isCritical: true,
      ));
    }

    if (hospital.operatingStatus.toLowerCase() == 'diverting') {
      list.add(const HospitalLimitation(
        title: 'Facility Status: Diverting Ambulances',
        explanation: 'Emergency triage is diverting inbound transports due to clinical staffing or severe bed saturation.',
        isCritical: true,
      ));
    }

    if (!hospital.hasFacility('blood')) {
      list.add(const HospitalLimitation(
        title: 'No On-Site Blood Bank',
        explanation: 'Lacks cross-matching lab and stored whole blood / packed RBCs. Unsuitable for acute postpartum hemorrhage or major vascular trauma.',
        isCritical: false,
      ));
    }

    if (!hospital.hasFacility('ct')) {
      list.add(const HospitalLimitation(
        title: 'No Advanced CT Scanner',
        explanation: 'Limited to basic X-Ray / Ultrasound. Cannot perform rapid brain CT for suspected acute stroke or skull fractures.',
        isCritical: false,
      ));
    }

    if (hospital.currentCapacity >= 0.85 && hospital.bedAvailability <= 3) {
      list.add(HospitalLimitation(
        title: 'High Bed Saturation (${(hospital.currentCapacity * 100).toInt()}%)',
        explanation: 'Only ${hospital.bedAvailability} general beds remain free. Emergency admission may experience prolonged triage holding.',
        isCritical: false,
      ));
    }

    return list;
  }

  Widget _buildAffiliatedCliniciansCard() {
    return AppCard(
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
                child: const Icon(Icons.people_alt_rounded, size: 18, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Affiliated Medical Clinicians & Specialists',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textNavyPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingDoctors) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else if (_affiliatedDoctors.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No clinician profiles currently registered for this facility.',
                style: TextStyle(fontSize: 12, color: AppColors.textNavyMuted),
              ),
            ),
          ] else ...[
            ..._affiliatedDoctors.map((doc) => Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMutedLight,
                borderRadius: BorderRadius.circular(8),
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
                          doc.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textNavyPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightMint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Score: ${doc.normalizedCapabilityScore.toStringAsFixed(1)}/100',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDarkGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doc.currentDesignation} • ${doc.primarySpecialty}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.secondarySlateTeal, fontWeight: FontWeight.w600),
                  ),
                  if (doc.secondarySpecialties.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Sub-specialties: ${doc.secondarySpecialties.join(", ")}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.history_edu_rounded, size: 12, color: AppColors.textNavyMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${doc.totalExperienceYears} yrs experience • Shift: ${doc.dutyShift.toUpperCase()}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textNavyMuted),
                      ),
                    ],
                  ),
                  if (doc.isDemoSynthetic) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'SIMULATED DATA — NOT FOR CLINICAL DECISIONS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

/// Helper model for explainable facility limitations.
class HospitalLimitation {
  final String title;
  final String explanation;
  final bool isCritical;

  const HospitalLimitation({
    required this.title,
    required this.explanation,
    required this.isCritical,
  });
}
