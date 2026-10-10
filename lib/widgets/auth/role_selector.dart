import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';

/// Segmented role selector for authenticating healthcare personnel.
/// Supports switching between Doctor and Clinic Staff with clear visual indicators.
class RoleSelector extends StatelessWidget {
  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleChanged;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMutedLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleTab(
              role: UserRole.doctor,
              label: 'Doctor',
              subtitle: 'Medical Officer',
              icon: Icons.medical_services_outlined,
              isSelected: selectedRole == UserRole.doctor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildRoleTab(
              role: UserRole.clinicStaff,
              label: 'Clinic Staff',
              subtitle: 'Health Post Desk',
              icon: Icons.local_hospital_outlined,
              isSelected: selectedRole == UserRole.clinicStaff,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab({
    required UserRole role,
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => onRoleChanged(role),
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          border: isSelected
              ? Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryLightMint
                    : AppColors.borderLight.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primaryDarkGreen : AppColors.textNavyMuted,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? AppColors.textNavyPrimary : AppColors.textNavySecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primaryDarkGreen : AppColors.textNavyMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
