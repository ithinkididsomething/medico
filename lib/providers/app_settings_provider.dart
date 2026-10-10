import 'package:flutter/material.dart';

/// AppSettingsProvider manages application-level preferences such as
/// theme mode (light/dark readiness) and rural clinic operating metadata.
class AppSettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _facilityName = 'Rural Health Post #4';
  bool _isOfflineMode = true;

  ThemeMode get themeMode => _themeMode;
  String get facilityName => _facilityName;
  bool get isOfflineMode => _isOfflineMode;

  /// Toggles between light and dark themes (architecture ready for future milestone).
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void updateFacilityName(String name) {
    _facilityName = name;
    notifyListeners();
  }

  void setOfflineMode(bool offline) {
    _isOfflineMode = offline;
    notifyListeners();
  }
}
