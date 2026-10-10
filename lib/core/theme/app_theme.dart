import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../animations/app_motion.dart';
import 'app_colors.dart';

/// Professional Healthcare Theme with Material 3.
/// Designed for high legibility, tactile reliability, and clinical clarity.
class AppTheme {
  AppTheme._();

  /// Light Theme (Default & Primary Target)
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryGreen,
      onPrimary: AppColors.textWhite,
      primaryContainer: AppColors.primaryLightMint,
      onPrimaryContainer: AppColors.primaryDarkGreen,
      secondary: AppColors.secondarySlateTeal,
      onSecondary: AppColors.textWhite,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.secondarySlateTeal,
      tertiary: AppColors.tealAccentDark,
      onTertiary: AppColors.textWhite,
      tertiaryContainer: AppColors.tealAccentLight,
      onTertiaryContainer: AppColors.tealAccentDark,
      error: AppColors.statusRed,
      onError: AppColors.textWhite,
      errorContainer: AppColors.statusRedBg,
      onErrorContainer: AppColors.statusRed,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textNavyPrimary,
      surfaceContainerHighest: AppColors.surfaceMutedLight,
      onSurfaceVariant: AppColors.textNavySecondary,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.surfaceHoverLight,
      shadow: AppColors.shadowLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // High-legibility clinical typography with dark navy text
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.textNavyPrimary,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.textNavyPrimary,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textNavyPrimary,
          height: 1.35,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textNavyPrimary,
          letterSpacing: 0.1,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textNavySecondary,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textNavyMuted,
          letterSpacing: 0.2,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textNavyPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textNavySecondary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textNavyMuted,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textNavyPrimary,
          letterSpacing: 0.3,
        ),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textNavyPrimary,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textNavyPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(
          color: AppColors.secondarySlateTeal,
          size: 24,
        ),
      ),

      // Rounded Cards with clean border and soft elevation
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          side: const BorderSide(
            color: AppColors.borderLight,
            width: 1.2,
          ),
        ),
      ),

      // Large touch targets for buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.textWhite,
          minimumSize: const Size(64, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingMd,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondarySlateTeal,
          minimumSize: const Size(64, AppConstants.buttonHeight),
          side: const BorderSide(
            color: AppColors.borderLight,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingMd,
          ),
        ),
      ),

      // Material 3 Navigation Bar (Phone)
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: AppColors.surfaceLight,
        elevation: 2,
        indicatorColor: AppColors.primaryLightMint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textNavyMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.primaryGreen,
              size: 24,
            );
          }
          return const IconThemeData(
            color: AppColors.textNavyMuted,
            size: 24,
          );
        }),
      ),

      // Navigation Rail Theme (Tablet & Large Screens)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: 1,
        indicatorColor: AppColors.primaryLightMint,
        selectedIconTheme: const IconThemeData(
          color: AppColors.primaryGreen,
          size: 26,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.textNavyMuted,
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryGreen,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textNavyMuted,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),

      // SnackBar for clinical feedback
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textNavyPrimary,
        contentTextStyle: const TextStyle(
          color: AppColors.textWhite,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MedicoPageTransitionsBuilder(),
          TargetPlatform.iOS: MedicoPageTransitionsBuilder(),
          TargetPlatform.windows: MedicoPageTransitionsBuilder(),
          TargetPlatform.macOS: MedicoPageTransitionsBuilder(),
          TargetPlatform.linux: MedicoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Dark Theme Architecture (Pre-configured for future toggle)
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryTealDark,
      onPrimary: AppColors.backgroundDark,
      primaryContainer: AppColors.primaryContainerDark,
      onPrimaryContainer: AppColors.primaryTealDark,
      secondary: AppColors.tealAccentLight,
      onSecondary: AppColors.backgroundDark,
      secondaryContainer: AppColors.surfaceMutedDark,
      onSecondaryContainer: AppColors.textDarkPrimary,
      error: AppColors.statusRed,
      onError: AppColors.textWhite,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDarkPrimary,
      surfaceContainerHighest: AppColors.surfaceMutedDark,
      onSurfaceVariant: AppColors.textDarkSecondary,
      outline: AppColors.borderDark,
      shadow: Colors.black45,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textDarkPrimary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          side: const BorderSide(
            color: AppColors.borderDark,
            width: 1.2,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MedicoPageTransitionsBuilder(),
          TargetPlatform.iOS: MedicoPageTransitionsBuilder(),
          TargetPlatform.windows: MedicoPageTransitionsBuilder(),
          TargetPlatform.macOS: MedicoPageTransitionsBuilder(),
          TargetPlatform.linux: MedicoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
