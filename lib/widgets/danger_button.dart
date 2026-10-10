import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Button widget for high-risk, emergency override, or irreversible clinical actions.
class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;
  final bool isOutlined;
  final double borderRadius;

  const DangerButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = AppConstants.buttonHeight,
    this.width,
    this.isOutlined = false,
    this.borderRadius = AppConstants.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFg = isOutlined ? AppColors.statusRed : AppColors.textWhite;

    final buttonContent = Row(
      mainAxisSize: width == null ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: effectiveFg),
          const SizedBox(width: AppConstants.spacingSm),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: effectiveFg,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: 'Warning action: $text',
      enabled: !isLoading && onPressed != null,
      child: SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: isOutlined
            ? OutlinedButton(
                onPressed: isLoading ? null : onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusRed,
                  side: const BorderSide(color: AppColors.statusRed, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingLg,
                  ),
                ),
                child: buttonContent,
              )
            : ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusRed,
                  foregroundColor: AppColors.textWhite,
                  disabledBackgroundColor: AppColors.statusRed.withValues(alpha: 0.45),
                  elevation: 0,
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
