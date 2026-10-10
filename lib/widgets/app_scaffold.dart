import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import 'sync_status_indicator.dart';

/// Reusable application scaffold providing consistent clinical header,
/// facility context badge, connectivity indicator, and tablet-adaptive constraints.
class AppScaffold extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showClinicStatusBar;
  final String facilityName;
  final bool isOfflineReady;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  const AppScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    required this.body,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showClinicStatusBar = true,
    this.facilityName = 'Rural Health Post • Triage Desk',
    this.isOfflineReady = true,
    this.contentPadding,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.backgroundLight,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: (title != null || titleWidget != null)
          ? AppBar(
              leading: leading,
              title: titleWidget ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title ?? AppConstants.appName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textNavyPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textNavyMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
              actions: [
                ...?actions,
                const SizedBox(width: AppConstants.spacingSm),
              ],
              bottom: showClinicStatusBar
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(28),
                      child: Container(
                        height: 28,
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
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      facilityName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryDarkGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SyncStatusPill(),
                          ],
                        ),
                      ),
                    )
                  : null,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: contentPadding ??
              const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingMd,
              ),
          child: body,
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
