import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/hospital.dart';
import 'app_card.dart';
import 'score_indicator.dart';
import 'animations/pressable_scale.dart';

/// Reusable card displaying comprehensive hospital referral destination information.
///
/// Features:
/// - Hospital Name & Location
/// - Suitability Score & Recommendation badge
/// - Specialties list
/// - Emergency & ICU availability indicators
/// - Real-time bed availability
/// - Road distance & estimated travel duration
class HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final double? suitabilityScore;
  final double? distanceKm;
  final Duration? travelTime;
  final bool isRecommended;
  final VoidCallback? onTap;
  final VoidCallback? onSelect;
  final String? matchingSpecialty;
  final int? rank;
  final String? statusLabel;
  final String? whyRankedSummary;
  final String? dataNotice;

  const HospitalCard({
    super.key,
    required this.hospital,
    this.suitabilityScore,
    this.distanceKm,
    this.travelTime,
    this.isRecommended = false,
    this.onTap,
    this.onSelect,
    this.matchingSpecialty,
    this.rank,
    this.statusLabel,
    this.whyRankedSummary,
    this.dataNotice,
  });

  String get _formattedTravelTime {
    if (travelTime == null) return 'Calculated on dispatch';
    final mins = travelTime!.inMinutes;
    if (mins < 60) return '~$mins mins by Car';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem > 0 ? '~$hrs hr $rem mins by Car' : '~$hrs hr by Car';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final card = AppCard(
      onTap: onTap,
      accentColor: isRecommended ? AppColors.primaryGreen : null,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Section: Recommendation Pill & Suitability Score
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rank != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: rank == 1 ? AppColors.primaryLightMint : AppColors.surfaceMutedLight,
                          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                          border: Border.all(
                            color: rank == 1 ? AppColors.primaryGreen : AppColors.borderLight,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              rank == 1 ? Icons.star_rounded : Icons.format_list_numbered_rounded,
                              size: 13,
                              color: rank == 1 ? AppColors.primaryGreen : AppColors.textNavySecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'RANK #$rank',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: rank == 1 ? AppColors.primaryDarkGreen : AppColors.textNavyPrimary,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isRecommended)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightMint,
                          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                          border: Border.all(color: AppColors.primaryGreen, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 13, color: AppColors.primaryGreen),
                            SizedBox(width: 4),
                            Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDarkGreen,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Hero(
                      tag: 'hospital_hero_${hospital.hospitalId}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          hospital.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textNavyPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textNavyMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hospital.address,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textNavyMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (statusLabel != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusLabel!.contains('confirmed')
                              ? AppColors.primaryLightMint
                              : (statusLabel!.contains('missing')
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFFEF3C7)),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: statusLabel!.contains('confirmed')
                                ? AppColors.primaryGreen
                                : (statusLabel!.contains('missing')
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFF59E0B)),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusLabel!.contains('confirmed')
                                  ? Icons.check_circle_rounded
                                  : (statusLabel!.contains('missing')
                                      ? Icons.cancel_rounded
                                      : Icons.warning_amber_rounded),
                              size: 13,
                              color: statusLabel!.contains('confirmed')
                                  ? AppColors.primaryDarkGreen
                                  : (statusLabel!.contains('missing')
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFFB45309)),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                statusLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusLabel!.contains('confirmed')
                                      ? AppColors.primaryDarkGreen
                                      : (statusLabel!.contains('missing')
                                          ? const Color(0xFFB91C1C)
                                          : const Color(0xFFB45309)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (whyRankedSummary != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(7),
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
                                whyRankedSummary!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textNavySecondary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (dataNotice != null && dataNotice!.contains('SIMULATED DATA')) ...[
                      const SizedBox(height: 4),
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
                  ],
                ),
              ),
                if (suitabilityScore != null) ...[
                  const SizedBox(width: AppConstants.spacingSm),
                  ScoreIndicator(score: suitabilityScore!, size: 44, showLabel: false),
                ],
              ],
            ),

            if (hospital.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: hospital.tags
                    .where((t) =>
                        !t.toLowerCase().contains('24/7 emergency') &&
                        !t.toLowerCase().contains('icu available'))
                    .take(3)
                    .map((tag) => _buildTagPill(tag))
                    .toList(),
              ),
            ],

            const SizedBox(height: AppConstants.spacingMd),

            // Middle Badges: Emergency, ICU & Availability
            Wrap(
              spacing: AppConstants.spacingSm,
              runSpacing: 6,
              children: [
                _buildCapabilityBadge(
                  icon: Icons.emergency_rounded,
                  label: hospital.emergencyCare ? '24/7 Emergency' : 'No Emergency',
                  isAvailable: hospital.emergencyCare,
                ),
                _buildCapabilityBadge(
                  icon: Icons.airline_seat_flat_rounded,
                  label: hospital.icuAvailable ? 'ICU Available' : 'No ICU',
                  isAvailable: hospital.icuAvailable,
                ),
                _buildAvailabilityBadge(hospital.bedAvailability),
                _buildCapabilityBadge(
                  icon: Icons.pie_chart_outline_rounded,
                  label: 'Capacity: ${(hospital.currentCapacity * 100).toInt()}%',
                  isAvailable: hospital.currentCapacity < 0.9,
                ),
              ],
            ),

            const SizedBox(height: AppConstants.spacingSm + 4),

            // Specialties List
            Text(
              'Specialties: ${hospital.specialties.join(", ")}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textNavySecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: AppConstants.spacingMd),
            const Divider(color: AppColors.borderLight, height: 1),
            const SizedBox(height: AppConstants.spacingSm),

            // Footer: Distance, Travel Time & Select Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.straighten_rounded,
                            size: 15,
                            color: AppColors.secondarySlateTeal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distanceKm != null
                                ? (distanceKm! < 10.0
                                    ? '${distanceKm!.toStringAsFixed(1)} km (~${(distanceKm! * 1000).round()} m)'
                                    : '${distanceKm!.toStringAsFixed(1)} km')
                                : 'Proximity unknown',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textNavyPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightMint,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.directions_car_rounded,
                              size: 13,
                              color: AppColors.primaryDarkGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formattedTravelTime,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDarkGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (onSelect != null) ...[
                  const SizedBox(width: AppConstants.spacingSm),
                  ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRecommended
                          ? AppColors.primaryGreen
                          : AppColors.secondarySlateTeal,
                      foregroundColor: AppColors.textWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(80, 36),
                      elevation: 0,
                    ),
                    child: const Text(
                      'SELECT',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );

    return Semantics(
      label: 'Hospital: ${hospital.name}. Location: ${hospital.address}. Distance: ${distanceKm?.toStringAsFixed(1) ?? "unknown"} kilometers.',
      button: onTap != null,
      child: onTap != null ? PressableScale(onTap: onTap, child: card) : card,
    );
  }

  Widget _buildCapabilityBadge({
    required IconData icon,
    required String label,
    required bool isAvailable,
  }) {
    final color = isAvailable ? AppColors.primaryGreen : AppColors.textNavyMuted;
    final bg = isAvailable ? AppColors.primaryLightMint : AppColors.surfaceMutedLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityBadge(int beds) {
    final bool hasBeds = beds > 0;
    final color = hasBeds ? AppColors.statusGreen : AppColors.statusAmber;
    final bg = hasBeds ? AppColors.statusGreenBg : AppColors.statusAmberBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bed_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            hasBeds ? '$beds Beds Available' : 'Bed Availability Critical',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagPill(String tag) {
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
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
