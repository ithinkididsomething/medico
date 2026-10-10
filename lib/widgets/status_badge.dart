import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/enums.dart';

/// Reusable badge displaying the lifecycle status of a patient referral.
class StatusBadge extends StatelessWidget {
  final ReferralStatus status;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Color bgColor;
    final IconData icon;

    switch (status) {
      case ReferralStatus.pending:
        textColor = AppColors.statusAmber;
        bgColor = AppColors.statusAmberBg;
        icon = Icons.schedule_rounded;
        break;
      case ReferralStatus.referred:
        textColor = AppColors.statusInfo;
        bgColor = AppColors.statusInfoBg;
        icon = Icons.forward_to_inbox_rounded;
        break;
      case ReferralStatus.accepted:
        textColor = AppColors.tealAccentDark;
        bgColor = AppColors.tealAccentLight;
        icon = Icons.check_circle_rounded;
        break;
      case ReferralStatus.transferred:
        textColor = const Color(0xFF4338CA); // Indigo
        bgColor = const Color(0xFFEEF2FF);
        icon = Icons.airport_shuttle_rounded;
        break;
      case ReferralStatus.completed:
        textColor = AppColors.statusGreen;
        bgColor = AppColors.statusGreenBg;
        icon = Icons.task_alt_rounded;
        break;
    }

    final semanticText = 'Referral status: ${status.displayName}';

    return Semantics(
      label: semanticText,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 7.0 : 9.0,
          vertical: isCompact ? 2.5 : 4.0,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
          border: Border.all(
            color: textColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isCompact ? 12 : 14,
              color: textColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                status.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isCompact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
