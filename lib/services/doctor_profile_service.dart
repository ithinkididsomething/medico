import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/doctor_profile_data.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

/// Service managing the currently logged-in doctor's static/session profile.
/// Fully offline-capable using SharedPreferences, linked directly to the active
/// authentication session in AuthService.
class DoctorProfileService extends ChangeNotifier {
  static const String _storageKey = 'smart_referral_active_doctor_profile_v1';

  static DoctorProfileService? _instance;
  static DoctorProfileService get instance => _instance ??= DoctorProfileService();

  final AuthService _authService;
  DoctorProfileData _currentProfile;
  bool _isLoaded = false;

  DoctorProfileService({AuthService? authService})
      : _authService = authService ?? LocalDemoAuthService.instance,
        _currentProfile = DoctorProfileData.defaultProfile(
          sessionUser: (authService ?? LocalDemoAuthService.instance).currentUser,
        ) {
    _init();
  }

  DoctorProfileData get currentProfile => _currentProfile;
  bool get isLoaded => _isLoaded;

  Future<void> _init() async {
    await loadProfile();
    // Listen to session changes
    _authService.authStateChanges.listen((sessionUser) {
      if (sessionUser != null) {
        _syncWithSessionUser(sessionUser);
      }
    });
  }

  void _syncWithSessionUser(UserProfile user) {
    _currentProfile = _currentProfile.copyWith(
      id: user.id,
      fullName: user.fullName,
      email: user.email.isNotEmpty ? user.email : _currentProfile.email,
      phoneNumber: user.phoneNumber.isNotEmpty ? user.phoneNumber : _currentProfile.phoneNumber,
      medicalRegNumber: user.medicalRegNumber ?? _currentProfile.medicalRegNumber,
      clinicOrHospital: user.facilityAffiliation,
      verificationStatus: user.verificationStatus,
    );
    notifyListeners();
  }

  /// Loads stored doctor profile from offline local storage or seeds with session defaults.
  Future<DoctorProfileData> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_storageKey);
      final sessionUser = _authService.currentUser;

      if (storedJson != null && storedJson.isNotEmpty) {
        final parsed = DoctorProfileData.fromJson(storedJson);
        // Link with current session user if name or id matches or updates
        if (sessionUser != null) {
          _currentProfile = parsed.copyWith(
            id: sessionUser.id,
            fullName: parsed.fullName.isNotEmpty ? parsed.fullName : sessionUser.fullName,
            clinicOrHospital: parsed.clinicOrHospital.isNotEmpty ? parsed.clinicOrHospital : sessionUser.facilityAffiliation,
            medicalRegNumber: parsed.medicalRegNumber.isNotEmpty ? parsed.medicalRegNumber : sessionUser.medicalRegNumber,
          );
        } else {
          _currentProfile = parsed;
        }
      } else {
        _currentProfile = DoctorProfileData.defaultProfile(sessionUser: sessionUser);
      }
    } catch (_) {
      _currentProfile = DoctorProfileData.defaultProfile(sessionUser: _authService.currentUser);
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
    return _currentProfile;
  }

  /// Updates doctor profile locally and synchronizes the active session.
  Future<void> updateProfile(DoctorProfileData updated) async {
    _currentProfile = updated.copyWith(lastUpdated: DateTime.now());
    notifyListeners();

    // 1. Persist locally to SharedPreferences (works 100% offline)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _currentProfile.toJson());
    } catch (_) {}

    // 2. Synchronize active login session in AuthService
    final currentSession = _authService.currentUser;
    if (currentSession != null) {
      final updatedSession = currentSession.copyWith(
        fullName: _currentProfile.fullName,
        email: _currentProfile.email,
        phoneNumber: _currentProfile.phoneNumber,
        medicalRegNumber: _currentProfile.medicalRegNumber,
        hospitalAffiliation: _currentProfile.clinicOrHospital,
      );
      await _authService.updateCurrentUser(updatedSession);
    }
  }

  /// Reset profile back to defaults.
  Future<void> resetToDefaults() async {
    final defaultProf = DoctorProfileData.defaultProfile(sessionUser: _authService.currentUser);
    await updateProfile(defaultProf);
  }
}
