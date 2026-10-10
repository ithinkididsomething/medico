import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import 'app_card.dart';
import 'score_indicator.dart';

/// Decision-support card clearly explaining why a specific facility is recommended,
/// with clinical score, clinical rationale, and capability matches.
class RecommendationReasonCard extends StatelessWidget {
  final String hospitalName;
  final double score;
  final List<String> whyRecommended;
  final List<String> capabilityMatches;
  final List<String>? caveats;
  final String? distanceText;
  final String? travelTimeText;
  final VoidCallback? onAccept;
  final VoidCallback? onAlternatives;

  const RecommendationReasonCard({
    super.key,
    required this.hospitalName,
    required this.score,
    required this.whyRecommended,
    required this.capabilityMatches,
    this.caveats,
    this.distanceText,
    this.travelTimeText,
    this.onAccept,
    this.onAlternatives,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Recommended referral facility: $hospitalName. Score: ${score.toStringAsFixed(1)}%.',
      child: AppCard(
        accentColor: AppColors.primaryGreen,
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: "RECOMMENDED FACILITY" & Score
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightMint,
                          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                          border: Border.all(color: AppColors.primaryGreen, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 14, color: AppColors.primaryGreen),
                            SizedBox(width: 4),
                            Text(
                              'RECOMMENDED REFERRAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDarkGreen,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hospitalName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textNavyPrimary,
                        ),
                      ),
                      if (distanceText != null || travelTimeText != null) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            if (distanceText != null)
                              Text(
                                distanceText!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textNavyMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (distanceText != null && travelTimeText != null)
                              const Text('•', style: TextStyle(color: AppColors.borderDark)),
                            if (travelTimeText != null) ...[
                              const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.secondarySlateTeal),
                              Text(
                                travelTimeText!.contains('Car') ? travelTimeText! : '$travelTimeText (by Car)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textNavyMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                ScoreIndicator(score: score, size: 48, showLabel: false),
              ],
            ),

            const SizedBox(height: AppConstants.spacingMd),
            const Divider(color: AppColors.borderLight, height: 1),
            const SizedBox(height: AppConstants.spacingMd),

            // Section: Why Recommended (Clinical Rationale)
            Text(
              'Why Recommended:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textNavyPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ...whyRecommended.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textNavySecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppConstants.spacingMd),

            // Section: Capability Matches
            Text(
              'Capability Matches:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textNavyPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: capabilityMatches.map((cap) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tealAccentLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    border: Border.all(
                      color: AppColors.tealAccentDark.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.done_all_rounded, size: 14, color: AppColors.tealAccentDark),
                      const SizedBox(width: 4),
                      Text(
                        cap,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealAccentDark,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // Caveats if any
            if (caveats != null && caveats!.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingMd),
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingSm + 2),
                decoration: BoxDecoration(
                  color: AppColors.statusAmberBg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: caveats!.map(
                    (c) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: AppColors.statusAmber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.statusAmber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).toList(),
                ),
              ),
            ],

            // Action Buttons
            if (onAccept != null || onAlternatives != null) ...[
              const SizedBox(height: AppConstants.spacingLg),
              Row(
                children: [
                  if (onAlternatives != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onAlternatives,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          side: const BorderSide(color: AppColors.borderLight),
                        ),
                        child: const Text('Alternatives'),
                      ),
                    ),
                  if (onAccept != null && onAlternatives != null)
                    const SizedBox(width: AppConstants.spacingSm),
                  if (onAccept != null)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.textWhite,
                          minimumSize: const Size(0, 44),
                          elevation: 0,
                        ),
                        child: const Text('Proceed with Referral'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
