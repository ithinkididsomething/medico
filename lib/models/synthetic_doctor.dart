import 'dart:convert';

/// Represents a Doctor Profile linked to healthcare facilities in the network.
/// Distinguishes real verified registrations from synthetic development profiles.
class DoctorProfile {
  final String doctorId;
  final String fullName;
  final String displayName;
  final String email;
  final String phoneNumber;
  final String preferredLanguage;
  final String? profilePhotoUrl;
  final String primaryPracticeEnvironment;
  final int totalExperienceYears;
  final String currentDesignation;
  final String department;
  final int yearsAtCurrentFacility;
  final String verificationStatus; // 'verified', 'pending', 'rejected', 'unverified_demo'
  final String? rejectionReason;
  final bool isSynthetic;
  final String recordSource; // 'registration', 'synthetic_demo'
  final String primarySpecialty;
  final List<String> secondarySpecialties;
  final List<String> clinicalCapabilities;
  final List<String> procedureCapabilities;
  final List<String> emergencyCapabilities;
  final List<String> criticalCareCapabilities;
  final List<String> diagnosticCapabilities;
  final double normalizedCapabilityScore;
  final Map<String, dynamic> scoreBreakdown;
  final List<String> facilityAffiliationIds;
  final String availabilityStatus; // 'available', 'unavailable', 'unknown', 'outdated'
  final String dutyShift; // 'day', 'night', 'on_call'
  final String? isSimulatedDataNotice;

  const DoctorProfile({
    required this.doctorId,
    required this.fullName,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    this.preferredLanguage = 'English',
    this.profilePhotoUrl,
    required this.primaryPracticeEnvironment,
    this.totalExperienceYears = 5,
    this.currentDesignation = 'Consultant',
    this.department = 'General Medicine',
    this.yearsAtCurrentFacility = 3,
    this.verificationStatus = 'unverified_demo',
    this.rejectionReason,
    this.isSynthetic = false,
    this.recordSource = 'registration',
    required this.primarySpecialty,
    this.secondarySpecialties = const [],
    this.clinicalCapabilities = const [],
    this.procedureCapabilities = const [],
    this.emergencyCapabilities = const [],
    this.criticalCareCapabilities = const [],
    this.diagnosticCapabilities = const [],
    this.normalizedCapabilityScore = 0.0,
    this.scoreBreakdown = const {},
    this.facilityAffiliationIds = const [],
    this.availabilityStatus = 'available',
    this.dutyShift = 'day',
    this.isSimulatedDataNotice,
  });

  bool get isDemoSynthetic => isSynthetic || recordSource == 'synthetic_demo';

  String get displayNotice => isDemoSynthetic
      ? (isSimulatedDataNotice ?? 'SIMULATED DATA — NOT FOR CLINICAL DECISIONS')
      : 'OFFICIAL REGISTERED CLINICIAN';

  factory DoctorProfile.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val == null) return const [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.isNotEmpty) {
        try {
          final decoded = json.decode(val);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return const [];
    }

    final isSynth = map['is_synthetic'] == 1 ||
        map['is_synthetic'] == true ||
        map['isSynthetic'] == true;

    // Extract affiliations
    final affilIds = <String>[];
    if (map['affiliations'] is List) {
      for (final a in (map['affiliations'] as List)) {
        if (a is Map && a['facility_id'] != null) {
          affilIds.add(a['facility_id'].toString());
        }
      }
    } else if (map['facility_affiliation_ids'] is List) {
      affilIds.addAll((map['facility_affiliation_ids'] as List).map((e) => e.toString()));
    }

    return DoctorProfile(
      doctorId: map['doctor_id'] as String? ?? map['doctorId'] as String? ?? '',
      fullName: map['full_name'] as String? ?? map['fullName'] as String? ?? 'Clinician',
      displayName: map['display_name'] as String? ?? map['displayName'] as String? ?? 'Dr. Clinician',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? map['phone_number'] as String? ?? '',
      preferredLanguage: map['preferred_language'] as String? ?? 'English',
      profilePhotoUrl: map['profile_photo_url'] as String?,
      primaryPracticeEnvironment: map['primary_practice_environment'] as String? ?? 'hospital',
      totalExperienceYears: (map['total_experience_years'] as num?)?.toInt() ?? (map['years_of_experience'] as num?)?.toInt() ?? 5,
      currentDesignation: map['current_designation'] as String? ?? 'Consultant',
      department: map['department'] as String? ?? 'Medicine',
      yearsAtCurrentFacility: (map['years_at_current_facility'] as num?)?.toInt() ?? 3,
      verificationStatus: map['verification_status'] as String? ?? 'unverified_demo',
      rejectionReason: map['rejection_reason'] as String?,
      isSynthetic: isSynth,
      recordSource: map['record_source'] as String? ?? (isSynth ? 'synthetic_demo' : 'registration'),
      primarySpecialty: map['primary_specialty'] as String? ?? 'General Medicine',
      secondarySpecialties: parseList(map['secondary_specialties']),
      clinicalCapabilities: parseList(map['clinical_capabilities']),
      procedureCapabilities: parseList(map['procedure_capabilities']),
      emergencyCapabilities: parseList(map['emergency_capabilities']),
      criticalCareCapabilities: parseList(map['critical_care_capabilities']),
      diagnosticCapabilities: parseList(map['diagnostic_capabilities']),
      normalizedCapabilityScore: (map['normalized_capability_score'] as num?)?.toDouble() ??
          (map['totalCapabilityScore'] as num?)?.toDouble() ??
          (map['capabilityScore']?['total_capability_score'] as num?)?.toDouble() ??
          0.0,
      scoreBreakdown: map['score_breakdown'] is Map<String, dynamic>
          ? map['score_breakdown'] as Map<String, dynamic>
          : (map['capabilityScore'] is Map<String, dynamic> ? map['capabilityScore'] as Map<String, dynamic> : const {}),
      facilityAffiliationIds: affilIds,
      availabilityStatus: map['availability_status'] as String? ?? map['duty_status'] as String? ?? 'available',
      dutyShift: map['duty_shift'] as String? ?? 'day',
      isSimulatedDataNotice: map['isSimulatedDataNotice'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'doctor_id': doctorId,
        'full_name': fullName,
        'display_name': displayName,
        'email': email,
        'phone_number': phoneNumber,
        'preferred_language': preferredLanguage,
        'profile_photo_url': profilePhotoUrl,
        'primary_practice_environment': primaryPracticeEnvironment,
        'total_experience_years': totalExperienceYears,
        'current_designation': currentDesignation,
        'department': department,
        'years_at_current_facility': yearsAtCurrentFacility,
        'verification_status': verificationStatus,
        'rejection_reason': rejectionReason,
        'is_synthetic': isSynthetic ? 1 : 0,
        'record_source': recordSource,
        'primary_specialty': primarySpecialty,
        'secondary_specialties': secondarySpecialties,
        'clinical_capabilities': clinicalCapabilities,
        'procedure_capabilities': procedureCapabilities,
        'emergency_capabilities': emergencyCapabilities,
        'critical_care_capabilities': criticalCareCapabilities,
        'diagnostic_capabilities': diagnosticCapabilities,
        'normalized_capability_score': normalizedCapabilityScore,
        'score_breakdown': scoreBreakdown,
        'facility_affiliation_ids': facilityAffiliationIds,
        'availability_status': availabilityStatus,
        'duty_shift': dutyShift,
        'isSimulatedDataNotice': displayNotice,
      };
}
