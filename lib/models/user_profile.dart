import 'dart:convert';

/// Role cadre for authenticated healthcare professionals.
enum UserRole {
  doctor,
  clinicStaff;

  String get displayName {
    switch (this) {
      case UserRole.doctor:
        return 'Doctor';
      case UserRole.clinicStaff:
        return 'Clinic Staff';
    }
  }

  String get description {
    switch (this) {
      case UserRole.doctor:
        return 'Registered Medical Practitioner (MBBS / Specialist)';
      case UserRole.clinicStaff:
        return 'Health Worker / Nurse / Clinic Coordinator';
    }
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.doctor,
    );
  }
}

/// User profile representing an authenticated clinician or rural health post staff member.
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final UserRole role;
  final String? medicalRegNumber;
  final String? hospitalAffiliation;
  final String? clinicName;
  final String? clinicId;
  final bool isVerified;
  final String verificationStatus;
  final bool isDemo;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.medicalRegNumber,
    this.hospitalAffiliation,
    this.clinicName,
    this.clinicId,
    this.isVerified = false,
    this.verificationStatus = 'Pending Verification',
    this.isDemo = false,
    required this.createdAt,
  });

  /// Readable cadre label
  String get roleLabel => role.displayName;

  /// Effective facility or hospital affiliation
  String get facilityAffiliation {
    if (role == UserRole.doctor) {
      return hospitalAffiliation ?? 'Independent Medical Officer';
    } else {
      return clinicName ?? 'Rural Primary Health Center';
    }
  }

  /// Credential summary (Registration number or Clinic ID)
  String get credentialSummary {
    if (role == UserRole.doctor) {
      return medicalRegNumber != null && medicalRegNumber!.isNotEmpty
          ? 'Reg: $medicalRegNumber'
          : 'Reg: Pending Regulatory Verification';
    } else {
      return clinicId != null && clinicId!.isNotEmpty
          ? 'Clinic ID: $clinicId'
          : 'Clinic ID: Pending Facility Validation';
    }
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    UserRole? role,
    String? medicalRegNumber,
    String? hospitalAffiliation,
    String? clinicName,
    String? clinicId,
    bool? isVerified,
    String? verificationStatus,
    bool? isDemo,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      medicalRegNumber: medicalRegNumber ?? this.medicalRegNumber,
      hospitalAffiliation: hospitalAffiliation ?? this.hospitalAffiliation,
      clinicName: clinicName ?? this.clinicName,
      clinicId: clinicId ?? this.clinicId,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isDemo: isDemo ?? this.isDemo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'medicalRegNumber': medicalRegNumber,
      'hospitalAffiliation': hospitalAffiliation,
      'clinicName': clinicName,
      'clinicId': clinicId,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'isDemo': isDemo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String? ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
      fullName: map['fullName'] as String? ?? 'Clinician',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      role: UserRole.fromString(map['role'] as String? ?? 'doctor'),
      medicalRegNumber: map['medicalRegNumber'] as String?,
      hospitalAffiliation: map['hospitalAffiliation'] as String?,
      clinicName: map['clinicName'] as String?,
      clinicId: map['clinicId'] as String?,
      isVerified: map['isVerified'] as bool? ?? false,
      verificationStatus: map['verificationStatus'] as String? ?? 'Pending Verification',
      isDemo: map['isDemo'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
