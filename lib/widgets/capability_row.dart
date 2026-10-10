import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Row widget presenting a hospital service capability with status indicator and detail.
class CapabilityRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isAvailable;
  final String? customStatusText;
  final Color? customStatusColor;

  const CapabilityRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isAvailable,
    this.customStatusText,
    this.customStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = customStatusColor ??
        (isAvailable ? AppColors.statusGreen : AppColors.statusRed);
    final statusText = customStatusText ??
        (isAvailable ? 'Available' : 'Unavailable');

    return Semantics(
      label: '$title capability is $statusText. ${subtitle ?? ""}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Icon(icon, size: 18, color: statusColor),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textNavyPrimary,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textNavyMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
