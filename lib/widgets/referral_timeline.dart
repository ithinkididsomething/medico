import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/referral_status_history.dart';
import 'status_badge.dart';

/// Chronological timeline widget representing the lifecycle transitions of a patient referral.
class ReferralTimeline extends StatelessWidget {
  final List<ReferralStatusHistory> history;

  const ReferralTimeline({
    super.key,
    required this.history,
  });

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppConstants.spacingMd),
        child: Text(
          'No lifecycle audit events recorded.',
          style: TextStyle(color: AppColors.textNavyMuted, fontSize: 13),
        ),
      );
    }

    return Semantics(
      label: 'Referral lifecycle timeline with ${history.length} stages',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(history.length, (index) {
          final item = history[index];
          final isLast = index == history.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline Line & Node Dot
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isLast ? AppColors.primaryGreen : AppColors.secondarySlateTeal,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowLight,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppColors.borderLight,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),

                // Content Column
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: isLast ? 0.0 : AppConstants.spacingLg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            StatusBadge(status: item.status, isCompact: true),
                            Text(
                              _formatTimestamp(item.timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textNavyMuted,
                              ),
                            ),
                          ],
                        ),
                        if (item.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.note,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textNavySecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
