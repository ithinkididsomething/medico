import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_navigation.dart';

import 'screens/auth/login_screen.dart';
import 'screens/profile/doctor_profile_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/auth_service.dart';

/// SMART Referral Application Root Widget.
/// Configures Material 3, light healthcare theme, prepared dark theme, and root navigation.
class SmartReferralApp extends StatelessWidget {
  final ThemeMode themeMode;
  final bool startAtLogin;
  final bool showSplash;
  final AuthService? authService;

  const SmartReferralApp({
    super.key,
    this.themeMode = ThemeMode.light,
    this.startAtLogin = false,
    this.showSplash = false,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Material 3 Themes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Entry point with optional splash & authentication gate
      home: showSplash
          ? SplashScreen(
              nextRoute: startAtLogin ? '/login' : '/dashboard',
              authService: authService,
            )
          : (startAtLogin
              ? LoginScreen(authService: authService)
              : const MainNavigationScreen()),
      routes: {
        '/splash': (_) => SplashScreen(
              nextRoute: startAtLogin ? '/login' : '/dashboard',
              authService: authService,
            ),
        '/login': (_) => LoginScreen(authService: authService),
        '/dashboard': (_) => const MainNavigationScreen(),
        '/doctor-profile': (_) => const DoctorProfileScreen(),
      },
    );
  }
}
