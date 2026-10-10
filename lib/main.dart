import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system overlay styling for Android-first healthcare interface
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surfaceLight,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const SmartReferralApp(startAtLogin: true, showSplash: true));
}
