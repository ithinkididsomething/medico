/// Global application constants for SMART Referral.
class AppConstants {
  AppConstants._();

  // Application Info
  static const String appName = 'MEDICO';
  static const String appTagline = 'Clinical Referral Decision-Support System';
  static const String appSubtitle = 'Rural & Resource-Constrained Healthcare Network';
  static const String appVersion = '1.0.0';

  // Navigation Labels
  static const String navDashboard = 'Dashboard';
  static const String navAssessment = 'Assessment';
  static const String navReferrals = 'Referrals';
  static const String navHospitals = 'Hospitals';
  static const String navResources = 'Resources';
  static const String navMore = 'More';

  // Responsive Breakpoints
  static const double tabletBreakpoint = 650.0;
  static const double desktopBreakpoint = 1100.0;

  // Spacing & Dimensions
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Border Radii
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusPill = 999.0;

  // Touch Target Minimums
  static const double minTouchTarget = 48.0;
  static const double buttonHeight = 52.0;

  // Product Positioning Core Truth
  static const String productPositioningHeadline = 'Nearest hospital ≠ best hospital.';
  static const String productPositioningDetail =
      'The system prioritizes:\nMedical capability + Availability + Urgency + Travel time + Distance';

  // Medical Disclaimer
  static const String disclaimerTitle = 'Clinical Decision Support Notice';
  static const String medicalDisclaimerText =
      'This application is a clinical decision-support system. It assists healthcare professionals with referral decisions and does not replace professional clinical judgment. Patient cases and hospital availability shown are for clinical decision support. Clinical rules and hospital data require appropriate validation and authorized integration before deployment.';
}
