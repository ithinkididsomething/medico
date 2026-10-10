import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import 'primary_button.dart';

/// Reusable empty state view when no records, assessments, or hospitals match.
class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionText,
    this.onAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$title. $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingLg),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.tealAccent.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textNavyPrimary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textNavyMuted,
                  height: 1.45,
                ),
              ),
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: AppConstants.spacingLg),
                PrimaryButton(
                  text: actionText!,
                  icon: actionIcon,
                  onPressed: onAction,
                  width: 220,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
