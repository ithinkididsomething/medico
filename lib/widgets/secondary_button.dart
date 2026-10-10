import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Reusable secondary action button for secondary clinical flows, cancels, or alternate paths.
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double? width;
  final Color? borderColor;
  final Color? textColor;
  final Color? backgroundColor;
  final double borderRadius;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.height = AppConstants.buttonHeight,
    this.width,
    this.borderColor,
    this.textColor,
    this.backgroundColor,
    this.borderRadius = AppConstants.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? AppColors.borderLight;
    final effectiveText = textColor ?? AppColors.secondarySlateTeal;
    final effectiveBg = backgroundColor ?? Colors.transparent;

    final buttonContent = Row(
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
    );

    return Semantics(
      button: true,
      label: text,
      enabled: onPressed != null,
      child: SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: effectiveBg,
            foregroundColor: effectiveText,
            side: BorderSide(
              color: effectiveBorder,
              width: 1.5,
            ),
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
