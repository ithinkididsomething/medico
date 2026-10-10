import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Clinical-grade primary action button with large touch target,
/// loading indicator, optional leading/trailing icons, and clear tactile feedback.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = AppConstants.buttonHeight,
    this.width,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = AppConstants.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppColors.primaryGreen;
    final effectiveText = textColor ?? AppColors.textWhite;

    final buttonContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: isLoading
          ? SizedBox(
              key: const ValueKey('primary_button_loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(effectiveText),
              ),
            )
          : Row(
              key: const ValueKey('primary_button_idle'),
              mainAxisSize: width == null ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: effectiveText),
                  const SizedBox(width: AppConstants.spacingSm),
                ],
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: effectiveText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
    );

    return Semantics(
      button: true,
      label: text,
      enabled: !isLoading && onPressed != null,
      child: SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveBg,
            foregroundColor: effectiveText,
            disabledBackgroundColor: effectiveBg.withValues(alpha: 0.45),
            disabledForegroundColor: effectiveText.withValues(alpha: 0.7),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
            ),
          ),
          child: buttonContent,
        ),
      ),
    );
  }
}
