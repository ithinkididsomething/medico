import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Reusable clinical disclaimer widget highlighting the assistive,
/// decision-support nature of SMART Referral in rural health settings.
class MedicalDisclaimer extends StatelessWidget {
  final bool isCompact;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onLearnMore;

  const MedicalDisclaimer({
    super.key,
    this.isCompact = false,
    this.margin,
    this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryLightMint,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: AppColors.tealAccent.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.health_and_safety_outlined,
              size: 18,
              color: AppColors.primaryDarkGreen,
            ),
            const SizedBox(width: AppConstants.spacingSm),
            const Expanded(
              child: Text(
                'Clinical Decision Support • Non-diagnostic assistive system',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDarkGreen,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (onLearnMore != null)
              GestureDetector(
                onTap: onLearnMore,
                child: const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.primaryDarkGreen,
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: AppColors.tealAccent.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.disclaimerTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textNavyPrimary,
                          ),
                    ),
                    const Text(
                      'Protocol-Assisted Decision Making',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textNavyMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                ),
                child: const Text(
                  'CLINICAL CDS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondarySlateTeal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          const Text(
            AppConstants.medicalDisclaimerText,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textNavySecondary,
            ),
          ),
        ],
      ),
    );
  }
}
