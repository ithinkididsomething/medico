import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Reusable section title bar with optional subtitle, badge count, and action link.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? countBadge;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? customAction;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.countBadge,
    this.actionText,
    this.onAction,
    this.customAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      header: true,
      label: '$title section',
      child: Padding(
        padding: padding ??
            const EdgeInsets.symmetric(
              vertical: AppConstants.spacingSm,
            ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textNavyPrimary,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (countBadge != null) ...[
                        const SizedBox(width: AppConstants.spacingSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLightMint,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusPill,
                            ),
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            countBadge.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDarkGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textNavyMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (customAction != null)
              customAction!
            else if (actionText != null && onAction != null)
              Semantics(
                button: true,
                label: actionText,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppConstants.minTouchTarget,
                    minWidth: AppConstants.minTouchTarget,
                  ),
                  child: TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingSm,
                        vertical: AppConstants.spacingSm,
                      ),
                      foregroundColor: AppColors.primaryGreen,
                    ),
                    child: Text(
                      actionText!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
