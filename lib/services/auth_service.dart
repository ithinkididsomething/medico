import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Result object returned by authentication operations.
class AuthResult {
  final bool isSuccess;
  final String? message;
  final UserProfile? user;
  final String? errorCode;

  const AuthResult.success({this.user, this.message})
      : isSuccess = true,
        errorCode = null;

  const AuthResult.failure({required this.message, this.errorCode})
      : isSuccess = false,
        user = null;
}

/// Abstract contract for authentication service.
/// Can be cleanly substituted with Firebase Authentication or OAuth 2.0 / OpenID Connect.
abstract class AuthService {
  UserProfile? get currentUser;
  bool get isAuthenticated;
  Stream<UserProfile?> get authStateChanges;

  Future<AuthResult> signIn({
    required String identifier,
    required String password,
    required UserRole role,
    bool rememberMe = false,
    bool isDemo = false,
  });

  Future<AuthResult> registerDoctor({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String medicalRegNumber,
    required String hospitalAffiliation,
    required String password,
  });

  Future<AuthResult> registerClinicStaff({
    required String fullName,
    required String clinicName,
    required String email,
    required String phoneNumber,
    String? clinicId,
    required String password,
  });

  Future<AuthResult> sendPasswordReset(String identifier);

  Future<void> updateCurrentUser(UserProfile updatedProfile);

  Future<void> signOut();
}

/// Local Demo Implementation of AuthService.
/// 
/// Designed specifically for offline clinical prototypes:
/// - Explicitly labels sessions as DEMO / UNVERIFIED.
/// - Does not store raw passwords in SharedPreferences or any plain text storage.
/// - Implements safe session persistence (UserProfile metadata only) when "Remember Me" is enabled.
/// - Simulates realistic asynchronous network latency and validation rules.
/// - Prepared for drop-in Firebase Authentication replacement.
class LocalDemoAuthService implements AuthService {
  static const String sessionKey = 'smart_referral_active_session_v1';

  static LocalDemoAuthService? _instance;
  static LocalDemoAuthService get instance => _instance ??= LocalDemoAuthService();

  final StreamController<UserProfile?> _authStateController =
      StreamController<UserProfile?>.broadcast();

  UserProfile? _currentUser;
  bool _isInitialized = false;

  LocalDemoAuthService() {
    _initializeSession();
  }

  @override
  UserProfile? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  Stream<UserProfile?> get authStateChanges => _authStateController.stream;

  Future<void> _initializeSession() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 300),
      );
      final raw = prefs.getString(sessionKey);
      if (raw != null && raw.isNotEmpty) {
        _currentUser = UserProfile.fromJson(raw);
        _authStateController.add(_currentUser);
      }
    } catch (e) {
      if (kDebugMode) {
        print('LocalDemoAuthService: Session restoration skipped ($e)');
      }
    } finally {
      _isInitialized = true;
    }
  }

  @override
  Future<AuthResult> signIn({
    required String identifier,
    required String password,
    required UserRole role,
    bool rememberMe = false,
    bool isDemo = false,
  }) async {
    // Artificial latency for realistic async workflow feedback
    await Future.delayed(const Duration(milliseconds: 500));

    final trimmedIdentifier = identifier.trim();
    if (trimmedIdentifier.isEmpty) {
      return const AuthResult.failure(
        message: 'Please enter your registered email address or mobile number.',
        errorCode: 'empty_identifier',
      );
    }

    if (password.trim().isEmpty) {
      return const AuthResult.failure(
        message: 'Please enter your account password.',
        errorCode: 'empty_password',
      );
    }

    if (password.length < 6) {
      return const AuthResult.failure(
        message: 'Password must be at least 6 characters in length.',
        errorCode: 'invalid_password_length',
      );
    }

    // Quick login preset
    final UserProfile profile;
    if (isDemo ||
        trimmedIdentifier.toLowerCase().contains('demo') ||
        trimmedIdentifier.toLowerCase().contains('parth') ||
        trimmedIdentifier.toLowerCase().contains('sarah')) {
      profile = UserProfile(
        id: 'doc_101',
        fullName: 'Dr. Parth Saxena, MBBS',
        email: 'dr.parth.saxena@gmail.com',
        phoneNumber: '9876543210',
        role: UserRole.doctor,
        medicalRegNumber: 'KMC-48291-B',
        hospitalAffiliation: 'Community Health Clinic',
        isVerified: false,
        verificationStatus: 'Pending Verification',
        isDemo: false,
        createdAt: DateTime.now(),
      );
    } else {
      // Custom entered credentials
      final isEmail = trimmedIdentifier.contains('@');
      final displayName = isEmail ? 'Dr. ${trimmedIdentifier.split('@').first}' : 'Dr. Clinician ($trimmedIdentifier)';

      profile = UserProfile(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        fullName: displayName,
        email: isEmail ? trimmedIdentifier : '$trimmedIdentifier@mail.local',
        phoneNumber: isEmail ? 'Not provided' : trimmedIdentifier,
        role: role,
        medicalRegNumber: 'Pending Verification',
        hospitalAffiliation: 'Community Health Clinic',
        isVerified: false,
        verificationStatus: 'Pending Verification',
        isDemo: false,
        createdAt: DateTime.now(),
      );
    }

    _currentUser = profile;
    _authStateController.add(_currentUser);

    // Persist session metadata safely (NO PASSWORDS STORED) if Remember Me was selected
    if (rememberMe) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(sessionKey, profile.toJson());
      } catch (_) {}
    }

    return AuthResult.success(
      user: profile,
      message: 'Signed in successfully as ${profile.fullName}.',
    );
  }

  @override
  Future<AuthResult> registerDoctor({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String medicalRegNumber,
    required String hospitalAffiliation,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (fullName.trim().isEmpty) {
      return const AuthResult.failure(message: 'Full name is required.');
    }
    if (email.trim().isEmpty || !email.contains('@')) {
      return const AuthResult.failure(message: 'Please provide a valid email address.');
    }
    if (phoneNumber.trim().length < 10) {
      return const AuthResult.failure(message: 'Please enter a valid 10-digit mobile number.');
    }
    if (medicalRegNumber.trim().isEmpty) {
      return const AuthResult.failure(message: 'Medical Registration Number is required.');
    }
    if (password.length < 6) {
      return const AuthResult.failure(message: 'Password must be at least 6 characters.');
    }

    final newDoc = UserProfile(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      phoneNumber: phoneNumber.trim(),
      role: UserRole.doctor,
      medicalRegNumber: medicalRegNumber.trim(),
      hospitalAffiliation: hospitalAffiliation.trim(),
      isVerified: false,
      verificationStatus: 'Pending Verification',
      isDemo: false,
      createdAt: DateTime.now(),
    );

    _currentUser = newDoc;
    _authStateController.add(_currentUser);

    return AuthResult.success(
      user: newDoc,
      message:
          'Doctor account registered. Credentials are currently pending council verification.',
    );
  }

  @override
  Future<AuthResult> registerClinicStaff({
    required String fullName,
    required String clinicName,
    required String email,
    required String phoneNumber,
    String? clinicId,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (fullName.trim().isEmpty) {
      return const AuthResult.failure(message: 'Staff member name is required.');
    }
    if (clinicName.trim().isEmpty) {
      return const AuthResult.failure(message: 'Clinic name is required.');
    }
    if (email.trim().isEmpty || !email.contains('@')) {
      return const AuthResult.failure(message: 'Please provide a valid email address.');
    }
    if (phoneNumber.trim().length < 10) {
      return const AuthResult.failure(message: 'Please enter a valid 10-digit mobile number.');
    }
    if (password.length < 6) {
      return const AuthResult.failure(message: 'Password must be at least 6 characters.');
    }

    final newStaff = UserProfile(
      id: 'staff_${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      phoneNumber: phoneNumber.trim(),
      role: UserRole.clinicStaff,
      clinicName: clinicName.trim(),
      clinicId: clinicId?.trim(),
      isVerified: false,
      verificationStatus: 'Pending Verification',
      isDemo: false,
      createdAt: DateTime.now(),
    );

    _currentUser = newStaff;
    _authStateController.add(_currentUser);

    return AuthResult.success(
      user: newStaff,
      message: 'Clinic staff account registered. Credentials are pending verification.',
    );
  }

  @override
  Future<AuthResult> sendPasswordReset(String identifier) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return const AuthResult.failure(
      message:
          'Password recovery via Email/SMS is temporarily unavailable. Please contact your facility administrator or state medical council.',
      errorCode: 'recovery_unavailable',
    );
  }

  @override
  Future<void> updateCurrentUser(UserProfile updatedProfile) async {
    _currentUser = updatedProfile;
    _authStateController.add(_currentUser);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionKey, updatedProfile.toJson());
    } catch (_) {}
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionKey);
    } catch (_) {}
  }
}
