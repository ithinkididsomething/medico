import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Item definition for FilterChipGroup.
class FilterChipItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final int? count;

  const FilterChipItem({
    required this.value,
    required this.label,
    this.icon,
    this.count,
  });
}

/// Horizontally scrollable or wrapping filter chip group with accessible touch targets.
class FilterChipGroup<T> extends StatelessWidget {
  final List<FilterChipItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final bool isScrollable;

  const FilterChipGroup({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.isScrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final chipWidgets = items.map((item) {
      final isSelected = item.value == selectedValue;

      return Padding(
        padding: const EdgeInsets.only(right: AppConstants.spacingSm),
        child: Semantics(
          selected: isSelected,
          button: true,
          label: 'Filter by ${item.label}${item.count != null ? ", ${item.count} items" : ""}',
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppConstants.minTouchTarget,
            ),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: item.icon != null
                  ? Icon(
                      item.icon,
                      size: 16,
                      color: isSelected ? AppColors.textWhite : AppColors.secondarySlateTeal,
                    )
                  : null,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.textWhite : AppColors.textNavyPrimary,
                    ),
                  ),
                  if (item.count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.surfaceMutedLight,
                        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                      ),
                      child: Text(
                        item.count.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.textWhite : AppColors.textNavyMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              backgroundColor: AppColors.surfaceLight,
              selectedColor: AppColors.primaryGreen,
              side: BorderSide(
                color: isSelected ? AppColors.primaryGreen : AppColors.borderLight,
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusPill),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: 10,
              ),
              onSelected: (_) => onSelected(item.value),
            ),
          ),
        ),
      );
    }).toList();

    if (isScrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: chipWidgets),
      );
    }

    return Wrap(
      spacing: AppConstants.spacingSm,
      runSpacing: AppConstants.spacingSm,
      children: chipWidgets,
    );
  }
}
