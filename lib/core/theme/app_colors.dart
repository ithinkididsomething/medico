import 'package:flutter/material.dart';

/// Clinical healthcare color palette tailored for rural & resource-constrained settings.
/// Features high contrast, calm healthcare greens, teal accents, and dark navy text.
class AppColors {
  AppColors._();

  // --- Healthcare Brand Colors (Light) ---
  /// Deep healthcare emerald/teal - conveys trust, safety, and medical authority
  static const Color primaryGreen = Color(0xFF0D7A68);
  static const Color primaryDarkGreen = Color(0xFF095649);
  static const Color primaryLightMint = Color(0xFFE6F5F2);

  /// Vibrant teal accent - for highlights, chips, and interactive focal points
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color tealAccentDark = Color(0xFF0F766E);
  static const Color tealAccentLight = Color(0xFFCCFBF1);

  /// Clinical Secondary slate-teal - for headers, cards, and secondary actions
  static const Color secondarySlateTeal = Color(0xFF1B4965);
  static const Color secondaryContainer = Color(0xFFE2EBF1);

  // --- Backgrounds & Surfaces (Light) ---
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFF1F5F9);
  static const Color surfaceHoverLight = Color(0xFFE2E8F0);

  // --- Typography (Dark Navy Hierarchy) ---
  /// High legibility dark navy text - easier on eyes than pure harsh black in bright sun
  static const Color textNavyPrimary = Color(0xFF0F172A);
  static const Color textNavySecondary = Color(0xFF334155);
  static const Color textNavyMuted = Color(0xFF64748B);
  static const Color textWhite = Color(0xFFFFFFFF);

  // --- Structural & Dividers ---
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF0D7A68);
  static const Color shadowLight = Color(0x0C0F172A); // Very soft navy shadow

  // --- Clinical Triage & Status Colors ---
  static const Color statusGreen = Color(0xFF16A34A);
  static const Color statusGreenBg = Color(0xFFDCFCE7);
  static const Color statusAmber = Color(0xFFD97706);
  static const Color statusAmberBg = Color(0xFFFEF3C7);
  static const Color statusRed = Color(0xFFDC2626);
  static const Color statusRedBg = Color(0xFFFEE2E2);
  static const Color statusInfo = Color(0xFF0284C7);
  static const Color statusInfoBg = Color(0xFFE0F2FE);

  // Urgency & text compatibility aliases
  static const Color urgencyEmergencyRed = statusRed;
  static const Color urgencyUrgentOrange = statusAmber;
  static const Color textGreyMuted = textNavyMuted;
  static const Color textGreyDark = textNavySecondary;

  // --- Dark Theme Palette (Prepared for future activation) ---
  static const Color backgroundDark = Color(0xFF0B132B);
  static const Color surfaceDark = Color(0xFF16203B);
  static const Color surfaceMutedDark = Color(0xFF1C2A4A);
  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF243354);
  static const Color primaryTealDark = Color(0xFF2DD4BF);
  static const Color primaryContainerDark = Color(0xFF134E4A);
}
