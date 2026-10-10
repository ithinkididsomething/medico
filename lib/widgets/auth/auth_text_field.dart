import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// Clean, hospital-grade input field for authentication screens.
/// Features rounded corners, subtle styling, clear focus states, and inline validation.
class AuthTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final String? helperText;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const AuthTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.helperText,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textNavyPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textNavyPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textNavyMuted,
            ),
            helperText: helperText,
            helperStyle: const TextStyle(
              fontSize: 11,
              color: AppColors.textNavyMuted,
            ),
            errorStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.statusRed,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    size: 20,
                    color: enabled ? AppColors.secondarySlateTeal : AppColors.textNavyMuted,
                  )
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? Colors.white : AppColors.surfaceMutedLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
              borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
              borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
              borderSide: const BorderSide(color: AppColors.statusRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
              borderSide: const BorderSide(color: AppColors.statusRed, width: 2.0),
            ),
          ),
        ),
      ],
    );
  }
}
