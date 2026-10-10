import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Clinical decision-support disclaimer banner/card explicitly communicating
/// the non-diagnostic, assistive nature of SMART Referral in resource-limited clinics.
class DisclaimerCard extends StatefulWidget {
  final bool initiallyExpanded;
  final EdgeInsetsGeometry? margin;

  const DisclaimerCard({
    super.key,
    this.initiallyExpanded = true,
    this.margin,
  });

  @override
  State<DisclaimerCard> createState() => _DisclaimerCardState();
}

class _DisclaimerCardState extends State<DisclaimerCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Clinical Decision Support Notice: ${AppConstants.medicalDisclaimerText}',
      child: Container(
        margin: widget.margin ?? const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: AppColors.tealAccent.withValues(alpha: 0.35),
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
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: Row(
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
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textNavyPrimary,
                            ),
                          ),
                          const Text(
                            'Protocol-Assisted Decision Making • Rural Health Network',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textNavyMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textNavyMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded) ...[
              const Divider(color: AppColors.borderLight, height: 1),
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: Text(
                  AppConstants.medicalDisclaimerText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textNavySecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
