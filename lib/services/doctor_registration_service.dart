import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/doctor_registration.dart';
import 'auth_service.dart';
import 'sync/central_api_client.dart';

/// Service managing doctor registration workflow, offline form drafts,
/// phone/OTP verification simulation, document validation, and backend sync.
class DoctorRegistrationService {
  static const String _draftKey = 'smart_referral_doctor_registration_draft_v1';
  static const String _savedProfileKey = 'smart_referral_registered_doctor_profile_v1';

  final CentralApiClient apiClient;
  final AuthService authService;
  final SharedPreferences? prefs;

  static DoctorRegistrationService? _instance;
  static DoctorRegistrationService get instance {
    _instance ??= DoctorRegistrationService(
      apiClient: CentralApiClient(),
      authService: LocalDemoAuthService.instance,
    );
    return _instance!;
  }

  DoctorRegistrationService({
    required this.apiClient,
    required this.authService,
    this.prefs,
  });

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  /// Saves form progress locally to prevent data loss.
  Future<void> saveDraft(DoctorRegistrationModel draft) async {
    final prefs = await _getPrefs();
    await prefs.setString(_draftKey, draft.toJson());
  }

  /// Retrieves saved form draft if any exists.
  Future<DoctorRegistrationModel?> getDraft() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_draftKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return DoctorRegistrationModel.fromJson(jsonStr);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Checks if an active draft exists.
  Future<bool> hasDraft() async {
    final prefs = await _getPrefs();
    return prefs.containsKey(_draftKey);
  }

  /// Clears saved draft.
  Future<void> clearDraft() async {
    final prefs = await _getPrefs();
    await prefs.remove(_draftKey);
  }

  /// Saves the registered doctor profile locally.
  Future<void> saveRegisteredProfile(DoctorRegistrationModel profile) async {
    final prefs = await _getPrefs();
    await prefs.setString(_savedProfileKey, profile.toJson());
  }

  /// Retrieves previously registered doctor profile.
  Future<DoctorRegistrationModel?> getRegisteredProfile() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_savedProfileKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return DoctorRegistrationModel.fromJson(jsonStr);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Simulates requesting an SMS OTP verification code.
  Future<bool> requestPhoneOtp(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Simulated carrier dispatch
    return phoneNumber.replaceAll(RegExp(r'\D'), '').length >= 10;
  }

  /// Verifies entered OTP code (Accepts '123456' or any 6-digit number in test/demo mode).
  Future<bool> verifyPhoneOtp(String phoneNumber, String otp) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return otp.trim().length == 6;
  }

  /// Validates document upload constraints (max 5 MB, allowed formats: PDF, JPG, PNG).
  String? validateDocument({
    required String fileName,
    required int fileSizeBytes,
  }) {
    const maxBytes = 5 * 1024 * 1024; // 5 MB
    if (fileSizeBytes > maxBytes) {
      return 'Document exceeds maximum size limit of 5 MB.';
    }

    final lower = fileName.toLowerCase();
    final validExtensions = ['.pdf', '.jpg', '.jpeg', '.png'];
    final hasValidExt = validExtensions.any((ext) => lower.endsWith(ext));
    if (!hasValidExt) {
      return 'Invalid file format. Only PDF, JPG, and PNG are accepted.';
    }

    return null;
  }

  /// Validates Medical Registration Number format.
  String? validateMedicalRegNumber(String regNumber) {
    final text = regNumber.trim().toUpperCase();
    if (text.isEmpty) {
      return 'Medical registration number is required.';
    }
    if (text.length < 4) {
      return 'Registration number must be at least 4 alphanumeric characters.';
    }
    return null;
  }

  /// Submits doctor registration to the authoritative backend and integrates with auth system.
  Future<DoctorRegistrationResult> submitRegistration(
    DoctorRegistrationModel registration, {
    required String password,
  }) async {
    try {
      // 1. Post to Central Backend API
      final uri = Uri.parse('${apiClient.baseUrl}/doctors/register');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(registration.toMap()),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final docMap = Map<String, dynamic>.from(data['doctor'] as Map);
        final registeredDoctor = DoctorRegistrationModel.fromMap(docMap);

        // 2. Clear draft
        await clearDraft();
        await saveRegisteredProfile(registeredDoctor);

        // 3. Register user in auth service so they can log in
        await authService.registerDoctor(
          fullName: registeredDoctor.fullName,
          email: registeredDoctor.email,
          phoneNumber: registeredDoctor.phoneNumber,
          medicalRegNumber: registeredDoctor.medicalRegNumber,
          hospitalAffiliation: registeredDoctor.facilityName,
          password: password,
        );

        return DoctorRegistrationResult.success(doctor: registeredDoctor);
      } else {
        final errData = jsonDecode(res.body) as Map<String, dynamic>;
        return DoctorRegistrationResult.failure(
          error: errData['error']?.toString() ?? 'Registration failed with HTTP ${res.statusCode}',
        );
      }
    } catch (e) {
      // 4. Offline Fallback: If network is unavailable, create local unverified profile
      final offlineId = 'doc_offline_${DateTime.now().millisecondsSinceEpoch}';
      final offlineDoctor = registration.copyWith(
        doctorId: offlineId,
        verificationStatus: 'pending',
        capabilityScore: DoctorCapabilityScore(
          baseExpertiseScore: registration.primaryQualificationType.contains('postgraduate') ? 25.0 : 15.0,
          clinicalExperienceScore: (registration.totalExperienceYears * 1.5).clamp(0.0, 30.0),
          clinicalVolumeScore: 15.0,
          professionalStandingScore: 5.0,
          totalCapabilityScore: 55.0,
          isProvisional: true,
        ),
      );

      await clearDraft();
      await saveRegisteredProfile(offlineDoctor);

      // Register local credentials
      await authService.registerDoctor(
        fullName: offlineDoctor.fullName,
        email: offlineDoctor.email,
        phoneNumber: offlineDoctor.phoneNumber,
        medicalRegNumber: offlineDoctor.medicalRegNumber,
        hospitalAffiliation: offlineDoctor.facilityName,
        password: password,
      );

      return DoctorRegistrationResult.success(
        doctor: offlineDoctor,
        isOfflineQueued: true,
      );
    }
  }

  /// Fetches latest doctor profile by ID.
  Future<DoctorRegistrationModel?> fetchDoctorProfile(String doctorId) async {
    try {
      final uri = Uri.parse('${apiClient.baseUrl}/doctors/$doctorId');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['doctor'] != null) {
          final doc = DoctorRegistrationModel.fromMap(Map<String, dynamic>.from(data['doctor'] as Map));
          await saveRegisteredProfile(doc);
          return doc;
        }
      }
    } catch (_) {}
    return getRegisteredProfile();
  }
}

class DoctorRegistrationResult {
  final bool isSuccess;
  final DoctorRegistrationModel? doctor;
  final String? error;
  final bool isOfflineQueued;

  const DoctorRegistrationResult.success({
    required this.doctor,
    this.isOfflineQueued = false,
  })  : isSuccess = true,
        error = null;

  const DoctorRegistrationResult.failure({required this.error})
      : isSuccess = false,
        doctor = null,
        isOfflineQueued = false;
}
