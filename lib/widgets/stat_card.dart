import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import 'animations/animated_counter.dart';
import 'animations/pressable_scale.dart';

/// Reusable metric / KPI card for displaying key clinical statistics.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = color ?? AppColors.primaryGreen;

    final numVal = num.tryParse(value);
    final valueStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.textNavyPrimary,
      letterSpacing: -0.5,
      height: 1.1,
    );

    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppConstants.spacingSm),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      ),
                      child: Icon(icon, color: primaryColor, size: 22),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textNavyMuted,
                      ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingMd),
                numVal != null
                    ? AnimatedCounter(
                        value: numVal,
                        style: valueStyle,
                      )
                    : Text(
                        value,
                        style: valueStyle,
                      ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textNavySecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textNavyMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: '$title: $value. ${subtitle ?? ""}',
      button: onTap != null,
      child: onTap != null ? PressableScale(onTap: onTap, child: card) : card,
    );
  }
}
