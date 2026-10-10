import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Visual clinical match score indicator displaying recommendation percentage and tier.
class ScoreIndicator extends StatelessWidget {
  final double score; // 0.0 to 100.0
  final bool showLabel;
  final double size;

  const ScoreIndicator({
    super.key,
    required this.score,
    this.showLabel = true,
    this.size = 52.0,
  });

  Color _getScoreColor(double val) {
    if (val >= 85.0) return AppColors.primaryGreen;
    if (val >= 70.0) return AppColors.tealAccentDark;
    if (val >= 50.0) return AppColors.statusAmber;
    return AppColors.statusRed;
  }

  String _getScoreLabel(double val) {
    if (val >= 85.0) return 'Optimal Match';
    if (val >= 70.0) return 'Strong Match';
    if (val >= 50.0) return 'Partial Match';
    return 'Sub-Optimal';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = _getScoreColor(score);
    final scoreLabel = _getScoreLabel(score);
    final normalized = (score / 100.0).clamp(0.0, 1.0);

    return Semantics(
      label: 'Suitability score: ${score.toStringAsFixed(1)} out of 100. $scoreLabel',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: normalized,
                  strokeWidth: 4.0,
                  backgroundColor: scoreColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
                Text(
                  score.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textNavyPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: AppConstants.spacingSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  scoreLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scoreColor,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${score.toStringAsFixed(1)}% Suitability',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textNavyMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
