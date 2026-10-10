import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import 'primary_button.dart';

/// Reusable error state view for displaying network failures, timeouts, or system faults.
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryText;
  final IconData icon;

  const ErrorState({
    super.key,
    this.title = 'An Error Occurred',
    required this.message,
    this.onRetry,
    this.retryText = 'Retry Operation',
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Error alert: $title. $message',
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
                  color: AppColors.statusRedBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.statusRed.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 42,
                  color: AppColors.statusRed,
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
                  color: AppColors.textNavySecondary,
                  height: 1.45,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppConstants.spacingLg),
                PrimaryButton(
                  text: retryText,
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  width: 200,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
