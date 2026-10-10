import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import 'danger_button.dart';
import 'primary_button.dart';

/// Reusable modal dialog for verifying clinical actions, referral dispatch, or cancellations.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;
  final IconData? icon;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
    this.icon,
  });

  /// Helper static method to display the confirmation dialog.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIcon = icon ??
        (isDestructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded);
    final iconColor = isDestructive ? AppColors.statusRed : AppColors.primaryGreen;
    final iconBg = isDestructive ? AppColors.statusRedBg : AppColors.primaryLightMint;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      backgroundColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(effectiveIcon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textNavyPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textNavySecondary,
          height: 1.45,
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: Text(
                  cancelText,
                  style: const TextStyle(
                    color: AppColors.textNavyMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: isDestructive
                  ? DangerButton(
                      text: confirmText,
                      height: 44,
                      onPressed: () => Navigator.of(context).pop(true),
                    )
                  : PrimaryButton(
                      text: confirmText,
                      height: 44,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
