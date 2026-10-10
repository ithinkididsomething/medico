import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Reusable application header widget providing clinical context,
/// facility badge, connectivity status, and optional action buttons.
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? facilityName;
  final bool isOfflineReady;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showClinicStatusBar;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.facilityName = 'Rural Health Post • Triage Desk',
    this.isOfflineReady = true,
    this.leading,
    this.actions,
    this.showClinicStatusBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      header: true,
      label: '$title. $subtitle. Facility: $facilityName',
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: const Border(
            bottom: BorderSide(color: AppColors.borderLight, width: 1.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Primary Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm + 4,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppConstants.spacingSm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textNavyPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textNavyMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...[
                    const SizedBox(width: AppConstants.spacingSm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),

            // Secondary Clinic Status Strip
            if (showClinicStatusBar && facilityName != null)
              Container(
                height: 30,
                color: AppColors.primaryLightMint,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.primaryDarkGreen,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              facilityName!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDarkGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
