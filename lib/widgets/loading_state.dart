import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Reusable accessible loading state with clinical progress indicator and message.
class LoadingState extends StatelessWidget {
  final String message;
  final String? subtitle;

  const LoadingState({
    super.key,
    this.message = 'Processing clinical information...',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$message. Please wait.',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryGreen,
                  ),
                  backgroundColor: AppColors.primaryLightMint,
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textNavyPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textNavyMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
