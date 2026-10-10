import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_exceptions.dart';

/// Centralized error handling and clinical user feedback utility.
class AppErrorHandler {
  AppErrorHandler._();

  /// Converts any exception or error into a clear, clinician-friendly message.
  static String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    } else if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    } else if (error != null) {
      return error.toString();
    }
    return 'An unexpected error occurred. Please verify local patient records.';
  }

  /// Displays a floating medical error SnackBar with clear contrast and optional retry.
  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    final message = getErrorMessage(error);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.textNavyPrimary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.statusRed, width: 1.5),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.statusRed,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: AppColors.tealAccent,
                onPressed: onRetry,
              )
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows an alert dialog for critical clinical workflow errors.
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surfaceLight,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.statusRedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.statusRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textNavyPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textNavySecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'DISMISS',
                style: TextStyle(
                  color: AppColors.textNavyMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRetry != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.textWhite,
                  elevation: 0,
                  minimumSize: const Size(88, 40),
                ),
                child: const Text('RETRY'),
              ),
          ],
        );
      },
    );
  }
}
