import 'dart:convert';
import 'user_profile.dart';

/// Static and session-linked data model representing the currently logged-in doctor's profile.
class DoctorProfileData {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String qualifications;
  final String specialization;
  final String medicalRegNumber;
  final String councilName;
  final String clinicOrHospital;
  final String email;
  final String phoneNumber;
  final String designation;
  final String department;
  final int experienceYears;
  final String emergencyContact;
  final String verificationStatus;
  final List<String> additionalCertifications;
  final DateTime lastUpdated;

  const DoctorProfileData({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.qualifications,
    required this.specialization,
    required this.medicalRegNumber,
    required this.councilName,
    required this.clinicOrHospital,
    required this.email,
    required this.phoneNumber,
    this.designation = 'Senior Medical Officer & Triage Lead',
    this.department = 'General Medicine & Emergency Care',
    this.experienceYears = 8,
    this.emergencyContact = '+91 731 245 9901',
    this.verificationStatus = 'Verified Practitioner',
    this.additionalCertifications = const [
      'WHO Emergency Triage & Treatment (ETAT)',
      'Advanced Cardiovascular Life Support (ACLS)',
      'Basic Life Support (BLS)',
      'Rural Emergency Care Protocol (Indore Hub)',
    ],
    required this.lastUpdated,
  });

  /// Factory providing standard static placeholder data, linked dynamically
  /// to the currently authenticated clinician session.
  factory DoctorProfileData.defaultProfile({UserProfile? sessionUser}) {
    final docName = (sessionUser != null && sessionUser.fullName.trim().isNotEmpty)
        ? sessionUser.fullName.trim()
        : 'Dr. Parth Saxena';
    final regNum = (sessionUser != null && sessionUser.medicalRegNumber != null && sessionUser.medicalRegNumber!.isNotEmpty)
        ? sessionUser.medicalRegNumber!
        : 'MP-MED-2018-09428';
    final facility = (sessionUser != null && sessionUser.facilityAffiliation.trim().isNotEmpty)
        ? sessionUser.facilityAffiliation.trim()
        : 'Primary Health Centre Sector 4 • Central Indore Hub';
    final mail = (sessionUser != null && sessionUser.email.trim().isNotEmpty)
        ? sessionUser.email.trim()
        : 'dr.parth.saxena@gmail.com';
    final phone = (sessionUser != null && sessionUser.phoneNumber.trim().isNotEmpty)
        ? sessionUser.phoneNumber.trim()
        : '+91 98765 43210';

    return DoctorProfileData(
      id: sessionUser?.id ?? 'doc_101',
      fullName: docName,
      qualifications: 'MBBS, MD (General Medicine)',
      specialization: 'General Medicine & Emergency Triage',
      medicalRegNumber: regNum,
      councilName: 'Madhya Pradesh Medical Council (NMC)',
      clinicOrHospital: facility,
      email: mail,
      phoneNumber: phone,
      designation: 'Senior Medical Officer & Triage Lead',
      department: 'General Medicine & Emergency Care',
      experienceYears: 8,
      emergencyContact: '+91 731 245 9901',
      verificationStatus: sessionUser?.verificationStatus ?? 'Verified Practitioner',
      additionalCertifications: const [
        'WHO Emergency Triage & Treatment (ETAT)',
        'Advanced Cardiovascular Life Support (ACLS)',
        'Basic Life Support (BLS)',
        'Rural Emergency Care Protocol (Indore Hub)',
      ],
      lastUpdated: DateTime.now(),
    );
  }

  DoctorProfileData copyWith({
    String? id,
    String? fullName,
    String? avatarUrl,
    String? qualifications,
    String? specialization,
    String? medicalRegNumber,
    String? councilName,
    String? clinicOrHospital,
    String? email,
    String? phoneNumber,
    String? designation,
    String? department,
    int? experienceYears,
    String? emergencyContact,
    String? verificationStatus,
    List<String>? additionalCertifications,
    DateTime? lastUpdated,
  }) {
    return DoctorProfileData(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      qualifications: qualifications ?? this.qualifications,
      specialization: specialization ?? this.specialization,
      medicalRegNumber: medicalRegNumber ?? this.medicalRegNumber,
      councilName: councilName ?? this.councilName,
      clinicOrHospital: clinicOrHospital ?? this.clinicOrHospital,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      experienceYears: experienceYears ?? this.experienceYears,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      additionalCertifications: additionalCertifications ?? this.additionalCertifications,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'qualifications': qualifications,
      'specialization': specialization,
      'medicalRegNumber': medicalRegNumber,
      'councilName': councilName,
      'clinicOrHospital': clinicOrHospital,
      'email': email,
      'phoneNumber': phoneNumber,
      'designation': designation,
      'department': department,
      'experienceYears': experienceYears,
      'emergencyContact': emergencyContact,
      'verificationStatus': verificationStatus,
      'additionalCertifications': additionalCertifications,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory DoctorProfileData.fromMap(Map<String, dynamic> map) {
    return DoctorProfileData(
      id: map['id'] as String? ?? 'doc_101',
      fullName: map['fullName'] as String? ?? 'Dr. Parth Saxena',
      avatarUrl: map['avatarUrl'] as String?,
      qualifications: map['qualifications'] as String? ?? 'MBBS, MD (General Medicine)',
      specialization: map['specialization'] as String? ?? 'General Medicine & Emergency Triage',
      medicalRegNumber: map['medicalRegNumber'] as String? ?? 'MP-MED-2018-09428',
      councilName: map['councilName'] as String? ?? 'Madhya Pradesh Medical Council (NMC)',
      clinicOrHospital: map['clinicOrHospital'] as String? ?? 'Primary Health Centre Sector 4 • Central Indore Hub',
      email: map['email'] as String? ?? 'dr.parth.saxena@gmail.com',
      phoneNumber: map['phoneNumber'] as String? ?? '+91 98765 43210',
      designation: map['designation'] as String? ?? 'Senior Medical Officer & Triage Lead',
      department: map['department'] as String? ?? 'General Medicine & Emergency Care',
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 8,
      emergencyContact: map['emergencyContact'] as String? ?? '+91 731 245 9901',
      verificationStatus: map['verificationStatus'] as String? ?? 'Verified Practitioner',
      additionalCertifications: (map['additionalCertifications'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [
            'WHO Emergency Triage & Treatment (ETAT)',
            'Advanced Cardiovascular Life Support (ACLS)',
            'Basic Life Support (BLS)',
          ],
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DoctorProfileData.fromJson(String source) =>
      DoctorProfileData.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
