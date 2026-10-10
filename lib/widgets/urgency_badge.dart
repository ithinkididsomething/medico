import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/enums.dart';

/// Reusable badge displaying clinical urgency level.
///
/// ACCESSIBILITY NOTICE:
/// Does NOT rely solely on color. Incorporates distinctive icons, text,
/// high contrast ratios, and explicit semantic labels for screen readers.
class UrgencyBadge extends StatelessWidget {
  final UrgencyLevel urgencyLevel;
  final bool isCompact;

  const UrgencyBadge({
    super.key,
    required this.urgencyLevel,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Color bgColor;
    final Color borderColor;
    final IconData icon;
    final String label;

    switch (urgencyLevel) {
      case UrgencyLevel.routine:
        textColor = AppColors.statusGreen;
        bgColor = AppColors.statusGreenBg;
        borderColor = const Color(0xFF86EFAC);
        icon = Icons.check_circle_outline_rounded;
        label = 'Routine';
        break;
      case UrgencyLevel.urgent:
        textColor = AppColors.statusAmber;
        bgColor = AppColors.statusAmberBg;
        borderColor = const Color(0xFFFDE68A);
        icon = Icons.warning_amber_rounded;
        label = 'Urgent';
        break;
      case UrgencyLevel.emergency:
        textColor = AppColors.statusRed;
        bgColor = AppColors.statusRedBg;
        borderColor = const Color(0xFFFCA5A5);
        icon = Icons.notification_important_rounded;
        label = 'Emergency';
        break;
    }

    final semanticText = 'Clinical Urgency Level: $label';

    return Semantics(
      label: semanticText,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8.0 : 12.0,
          vertical: isCompact ? 4.0 : 6.0,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isCompact ? 14 : 16,
              color: textColor,
            ),
            const SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
