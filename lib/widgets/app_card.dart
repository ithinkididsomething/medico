import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Reusable healthcare card widget with soft elevation, rounded corners,
/// high-contrast border, and optional clinical accent stripe.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final Color? accentColor;
  final Widget? leadingIcon;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.accentColor,
    this.leadingIcon,
    this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = BorderRadius.circular(borderRadius ?? AppConstants.radiusLg);
    final cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || leadingIcon != null || trailing != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                leadingIcon!,
                const SizedBox(width: AppConstants.spacingSm),
              ],
              if (title != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textNavyPrimary,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textNavyMuted,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
        ],
        child,
      ],
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceLight,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: borderColor ?? AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: Semantics(
          button: onTap != null,
          label: title,
          child: InkWell(
            onTap: onTap,
            borderRadius: effectiveRadius,
            child: ClipRRect(
              borderRadius: effectiveRadius,
              child: Stack(
                children: [
                  Padding(
                    padding: padding ?? const EdgeInsets.all(AppConstants.spacingMd),
                    child: Padding(
                      padding: EdgeInsets.only(left: accentColor != null ? 6.0 : 0.0),
                      child: cardContent,
                    ),
                  ),
                  if (accentColor != null)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: 5,
                      child: ColoredBox(color: accentColor!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
