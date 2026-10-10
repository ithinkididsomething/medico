import 'dart:convert';

/// Breakdown of the 4-Pillar Fair Normalized Capability Score.
class DoctorCapabilityScore {
  final double baseExpertiseScore;      // Max 30.0%
  final double clinicalExperienceScore; // Max 30.0%
  final double clinicalVolumeScore;     // Max 25.0%
  final double professionalStandingScore;// Max 15.0%
  final double totalCapabilityScore;    // Max 100.0%
  final bool isProvisional;
  final String scoringVersion;
  final DateTime? calculatedAt;

  const DoctorCapabilityScore({
    required this.baseExpertiseScore,
    required this.clinicalExperienceScore,
    required this.clinicalVolumeScore,
    required this.professionalStandingScore,
    required this.totalCapabilityScore,
    this.isProvisional = true,
    this.scoringVersion = '1.0.0',
    this.calculatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'baseExpertiseScore': baseExpertiseScore,
      'clinicalExperienceScore': clinicalExperienceScore,
      'clinicalVolumeScore': clinicalVolumeScore,
      'professionalStandingScore': professionalStandingScore,
      'totalCapabilityScore': totalCapabilityScore,
      'isProvisional': isProvisional,
      'scoringVersion': scoringVersion,
      'calculatedAt': calculatedAt?.toIso8601String(),
    };
  }

  factory DoctorCapabilityScore.fromMap(Map<String, dynamic> map) {
    return DoctorCapabilityScore(
      baseExpertiseScore: (map['baseExpertiseScore'] as num?)?.toDouble() ??
          (map['base_expertise_score'] as num?)?.toDouble() ??
          0.0,
      clinicalExperienceScore: (map['clinicalExperienceScore'] as num?)?.toDouble() ??
          (map['clinical_experience_score'] as num?)?.toDouble() ??
          0.0,
      clinicalVolumeScore: (map['clinicalVolumeScore'] as num?)?.toDouble() ??
          (map['clinical_volume_score'] as num?)?.toDouble() ??
          0.0,
      professionalStandingScore: (map['professionalStandingScore'] as num?)?.toDouble() ??
          (map['professional_standing_score'] as num?)?.toDouble() ??
          0.0,
      totalCapabilityScore: (map['totalCapabilityScore'] as num?)?.toDouble() ??
          (map['total_capability_score'] as num?)?.toDouble() ??
          0.0,
      isProvisional: map['isProvisional'] == true || map['is_provisional'] == 1,
      scoringVersion: map['scoringVersion'] as String? ?? '1.0.0',
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.tryParse(map['calculatedAt'] as String)
          : null,
    );
  }
}

/// Comprehensive model for doctor registration, regulatory credentialing, and profile view.
class DoctorRegistrationModel {
  // A. Personal and Contact Information
  final String? doctorId;
  final String fullName;
  final String? displayName;
  final String phoneNumber;
  final String email;
  final String preferredLanguage;
  final String? profilePhotoUrl;
  final bool isPhoneVerified;
  final bool isEmailVerified;

  // B. Medical Qualifications
  final String primaryQualificationType; // 'primary_mbbs', 'postgraduate_md_ms_dnb', 'super_specialty_dm_mch'
  final String primaryQualificationName;
  final String awardingInstitution;
  final int completionYear;
  final String primarySpecialty;
  final List<String> additionalSpecialties;
  final List<String> certifications;

  // C. Medical Registration & Verification
  final String councilName; // e.g. 'National Medical Commission', 'Madhya Pradesh Medical Council'
  final String medicalRegNumber;
  final int registrationYear;
  final String registrationStatus; // 'active', 'provisional'
  final String? registrationCertificateName;
  final String? registrationCertificatePath;
  final String? degreeCertificateName;
  final String? degreeCertificatePath;
  final String verificationStatus; // 'pending', 'verified', 'rejected', 'needs_more_info'
  final String? rejectionReason;

  // D. Practice & Experience
  final String primaryPracticeEnvironment; // 'independent_clinic', 'small_clinic', 'private_hospital', etc.
  final int totalExperienceYears;
  final String? facilityId;
  final String facilityName;
  final String currentDesignation;
  final String department;
  final int yearsAtCurrentFacility;
  final int yearsIndependentPractice;
  final List<String> previousAffiliations;

  // E. Clinical Capabilities
  final List<String> capabilities;

  // F. Clinical Impact & Professional Standing
  final int annualPatientVolume;
  final String? followupExperienceSummary;
  final String? procedureExperienceSummary;
  final String? teachingResearchSummary;
  final List<String> associationMemberships;
  final String? governmentSchemesSummary;
  final String? evidenceDocumentName;

  // Scoring & Meta
  final DoctorCapabilityScore? capabilityScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DoctorRegistrationModel({
    this.doctorId,
    required this.fullName,
    this.displayName,
    required this.phoneNumber,
    required this.email,
    this.preferredLanguage = 'English',
    this.profilePhotoUrl,
    this.isPhoneVerified = true,
    this.isEmailVerified = true,
    this.primaryQualificationType = 'primary_mbbs',
    required this.primaryQualificationName,
    this.awardingInstitution = '',
    this.completionYear = 2018,
    required this.primarySpecialty,
    this.additionalSpecialties = const [],
    this.certifications = const [],
    required this.councilName,
    required this.medicalRegNumber,
    this.registrationYear = 2018,
    this.registrationStatus = 'active',
    this.registrationCertificateName,
    this.registrationCertificatePath,
    this.degreeCertificateName,
    this.degreeCertificatePath,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.primaryPracticeEnvironment = 'independent_clinic',
    this.totalExperienceYears = 5,
    this.facilityId,
    this.facilityName = '',
    this.currentDesignation = 'Medical Practitioner',
    this.department = 'General Medicine',
    this.yearsAtCurrentFacility = 3,
    this.yearsIndependentPractice = 0,
    this.previousAffiliations = const [],
    this.capabilities = const [],
    this.annualPatientVolume = 1200,
    this.followupExperienceSummary,
    this.procedureExperienceSummary,
    this.teachingResearchSummary,
    this.associationMemberships = const [],
    this.governmentSchemesSummary,
    this.evidenceDocumentName,
    this.capabilityScore,
    this.createdAt,
    this.updatedAt,
  });

  DoctorRegistrationModel copyWith({
    String? doctorId,
    String? fullName,
    String? displayName,
    String? phoneNumber,
    String? email,
    String? preferredLanguage,
    String? profilePhotoUrl,
    bool? isPhoneVerified,
    bool? isEmailVerified,
    String? primaryQualificationType,
    String? primaryQualificationName,
    String? awardingInstitution,
    int? completionYear,
    String? primarySpecialty,
    List<String>? additionalSpecialties,
    List<String>? certifications,
    String? councilName,
    String? medicalRegNumber,
    int? registrationYear,
    String? registrationStatus,
    String? registrationCertificateName,
    String? registrationCertificatePath,
    String? degreeCertificateName,
    String? degreeCertificatePath,
    String? verificationStatus,
    String? rejectionReason,
    String? primaryPracticeEnvironment,
    int? totalExperienceYears,
    String? facilityId,
    String? facilityName,
    String? currentDesignation,
    String? department,
    int? yearsAtCurrentFacility,
    int? yearsIndependentPractice,
    List<String>? previousAffiliations,
    List<String>? capabilities,
    int? annualPatientVolume,
    String? followupExperienceSummary,
    String? procedureExperienceSummary,
    String? teachingResearchSummary,
    List<String>? associationMemberships,
    String? governmentSchemesSummary,
    String? evidenceDocumentName,
    DoctorCapabilityScore? capabilityScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorRegistrationModel(
      doctorId: doctorId ?? this.doctorId,
      fullName: fullName ?? this.fullName,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      primaryQualificationType: primaryQualificationType ?? this.primaryQualificationType,
      primaryQualificationName: primaryQualificationName ?? this.primaryQualificationName,
      awardingInstitution: awardingInstitution ?? this.awardingInstitution,
      completionYear: completionYear ?? this.completionYear,
      primarySpecialty: primarySpecialty ?? this.primarySpecialty,
      additionalSpecialties: additionalSpecialties ?? this.additionalSpecialties,
      certifications: certifications ?? this.certifications,
      councilName: councilName ?? this.councilName,
      medicalRegNumber: medicalRegNumber ?? this.medicalRegNumber,
      registrationYear: registrationYear ?? this.registrationYear,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      registrationCertificateName: registrationCertificateName ?? this.registrationCertificateName,
      registrationCertificatePath: registrationCertificatePath ?? this.registrationCertificatePath,
      degreeCertificateName: degreeCertificateName ?? this.degreeCertificateName,
      degreeCertificatePath: degreeCertificatePath ?? this.degreeCertificatePath,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      primaryPracticeEnvironment: primaryPracticeEnvironment ?? this.primaryPracticeEnvironment,
      totalExperienceYears: totalExperienceYears ?? this.totalExperienceYears,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      currentDesignation: currentDesignation ?? this.currentDesignation,
      department: department ?? this.department,
      yearsAtCurrentFacility: yearsAtCurrentFacility ?? this.yearsAtCurrentFacility,
      yearsIndependentPractice: yearsIndependentPractice ?? this.yearsIndependentPractice,
      previousAffiliations: previousAffiliations ?? this.previousAffiliations,
      capabilities: capabilities ?? this.capabilities,
      annualPatientVolume: annualPatientVolume ?? this.annualPatientVolume,
      followupExperienceSummary: followupExperienceSummary ?? this.followupExperienceSummary,
      procedureExperienceSummary: procedureExperienceSummary ?? this.procedureExperienceSummary,
      teachingResearchSummary: teachingResearchSummary ?? this.teachingResearchSummary,
      associationMemberships: associationMemberships ?? this.associationMemberships,
      governmentSchemesSummary: governmentSchemesSummary ?? this.governmentSchemesSummary,
      evidenceDocumentName: evidenceDocumentName ?? this.evidenceDocumentName,
      capabilityScore: capabilityScore ?? this.capabilityScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculates the 4-Pillar Normalized Capability Score:
  /// 1. Base Expertise (30%): Primary MBBS 15, Diploma 20, MD/MS/DNB 25, DM/MCh 30
  /// 2. Clinical Experience (30%): 1.5 pts per year of clinical practice, capped at 30.0
  /// 3. Clinical Volume & Impact (25%): Normalized benchmark for clinic (2000) vs hospital (3000)
  /// 4. Professional Standing (15%): 5 pts per association + 5 pts for government scheme empaneled practice
  DoctorCapabilityScore calculateCapabilityScore() {
    double baseScore = 15.0;
    if (primaryQualificationType.contains('super_specialty')) {
      baseScore = 30.0;
    } else if (primaryQualificationType.contains('postgraduate')) {
      baseScore = 25.0;
    } else if (primaryQualificationType.contains('diploma')) {
      baseScore = 20.0;
    }

    final expScore = (totalExperienceYears * 1.5).clamp(0.0, 30.0);

    final targetVolume = primaryPracticeEnvironment.contains('clinic') ? 2000.0 : 3000.0;
    final volScore = (annualPatientVolume / targetVolume * 25.0).clamp(0.0, 25.0);

    double standingScore = 0.0;
    standingScore += (associationMemberships.length * 5.0);
    if (governmentSchemesSummary != null && governmentSchemesSummary!.trim().isNotEmpty) {
      standingScore += 5.0;
    }
    standingScore = standingScore.clamp(0.0, 15.0);

    final totalScore = (baseScore + expScore + volScore + standingScore).clamp(0.0, 100.0);

    return DoctorCapabilityScore(
      baseExpertiseScore: baseScore,
      clinicalExperienceScore: expScore,
      clinicalVolumeScore: volScore,
      professionalStandingScore: standingScore,
      totalCapabilityScore: totalScore,
      isProvisional: verificationStatus != 'verified',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (doctorId != null) 'doctorId': doctorId,
      'fullName': fullName,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'email': email,
      'preferredLanguage': preferredLanguage,
      'profilePhotoUrl': profilePhotoUrl,
      'isPhoneVerified': isPhoneVerified,
      'isEmailVerified': isEmailVerified,
      'primaryQualificationType': primaryQualificationType,
      'primaryQualificationName': primaryQualificationName,
      'awardingInstitution': awardingInstitution,
      'completionYear': completionYear,
      'primarySpecialty': primarySpecialty,
      'additionalSpecialties': additionalSpecialties,
      'certifications': certifications,
      'councilName': councilName,
      'medicalRegNumber': medicalRegNumber,
      'registrationYear': registrationYear,
      'registrationStatus': registrationStatus,
      'registrationCertificateName': registrationCertificateName,
      'registrationCertificatePath': registrationCertificatePath,
      'degreeCertificateName': degreeCertificateName,
      'degreeCertificatePath': degreeCertificatePath,
      'verificationStatus': verificationStatus,
      'rejectionReason': rejectionReason,
      'primaryPracticeEnvironment': primaryPracticeEnvironment,
      'totalExperienceYears': totalExperienceYears,
      'facilityId': facilityId,
      'facilityName': facilityName,
      'currentDesignation': currentDesignation,
      'department': department,
      'yearsAtCurrentFacility': yearsAtCurrentFacility,
      'yearsIndependentPractice': yearsIndependentPractice,
      'previousAffiliations': previousAffiliations,
      'capabilities': capabilities,
      'annualPatientVolume': annualPatientVolume,
      'followupExperienceSummary': followupExperienceSummary,
      'procedureExperienceSummary': procedureExperienceSummary,
      'teachingResearchSummary': teachingResearchSummary,
      'associationMemberships': associationMemberships,
      'governmentSchemesSummary': governmentSchemesSummary,
      'evidenceDocumentName': evidenceDocumentName,
      'capabilityScore': capabilityScore?.toMap(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory DoctorRegistrationModel.fromMap(Map<String, dynamic> map) {
    // Parse nested qualification if present
    String qualType = map['primaryQualificationType'] as String? ?? 'primary_mbbs';
    String qualName = map['primaryQualificationName'] as String? ?? '';
    String institution = map['awardingInstitution'] as String? ?? '';
    int compYear = (map['completionYear'] as num?)?.toInt() ?? 2018;
    String specialty = map['primarySpecialty'] as String? ?? '';
    List<String> addSpecs = (map['additionalSpecialties'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    List<String> certs = (map['certifications'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    if (map['qualifications'] != null && (map['qualifications'] as List).isNotEmpty) {
      final firstQ = Map<String, dynamic>.from((map['qualifications'] as List).first as Map);
      qualType = firstQ['qualification_type'] as String? ?? qualType;
      qualName = firstQ['qualification_name'] as String? ?? qualName;
      institution = firstQ['institution'] as String? ?? institution;
      compYear = (firstQ['completion_year'] as num?)?.toInt() ?? compYear;
      specialty = firstQ['primary_specialty'] as String? ?? specialty;
    }

    // Parse nested registration if present
    String council = map['councilName'] as String? ?? '';
    String regNum = map['medicalRegNumber'] as String? ?? '';
    int regYear = (map['registrationYear'] as num?)?.toInt() ?? 2018;
    if (map['registration'] != null) {
      final regMap = Map<String, dynamic>.from(map['registration'] as Map);
      council = regMap['council_name'] as String? ?? council;
      regNum = regMap['registration_number'] as String? ?? regNum;
      regYear = (regMap['registration_year'] as num?)?.toInt() ?? regYear;
    }

    // Parse nested affiliations
    String facId = map['facilityId'] as String? ?? '';
    String facName = map['facilityName'] as String? ?? '';
    if (map['affiliations'] != null && (map['affiliations'] as List).isNotEmpty) {
      final firstAff = Map<String, dynamic>.from((map['affiliations'] as List).first as Map);
      facId = firstAff['facility_id'] as String? ?? facId;
      facName = firstAff['facility_name'] as String? ?? facName;
    }

    // Parse capabilities
    List<String> caps = (map['capabilities'] as List<dynamic>?)
            ?.map((e) => e is Map ? (e['capability_label'] ?? e['capability_key'] ?? '').toString() : e.toString())
            .toList() ??
        [];

    // Parse score
    DoctorCapabilityScore? score;
    if (map['capabilityScore'] != null) {
      score = DoctorCapabilityScore.fromMap(Map<String, dynamic>.from(map['capabilityScore'] as Map));
    }

    return DoctorRegistrationModel(
      doctorId: map['doctorId'] as String? ?? map['doctor_id'] as String?,
      fullName: map['fullName'] as String? ?? map['full_name'] as String? ?? '',
      displayName: map['displayName'] as String? ?? map['display_name'] as String?,
      phoneNumber: map['phoneNumber'] as String? ?? map['phone_number'] as String? ?? '',
      email: map['email'] as String? ?? '',
      preferredLanguage: map['preferredLanguage'] as String? ?? map['preferred_language'] as String? ?? 'English',
      profilePhotoUrl: map['profilePhotoUrl'] as String? ?? map['profile_photo_url'] as String?,
      isPhoneVerified: map['isPhoneVerified'] as bool? ?? true,
      isEmailVerified: map['isEmailVerified'] as bool? ?? true,
      primaryQualificationType: qualType,
      primaryQualificationName: qualName,
      awardingInstitution: institution,
      completionYear: compYear,
      primarySpecialty: specialty,
      additionalSpecialties: addSpecs,
      certifications: certs,
      councilName: council,
      medicalRegNumber: regNum,
      registrationYear: regYear,
      registrationStatus: map['registrationStatus'] as String? ?? map['registration_status'] as String? ?? 'active',
      registrationCertificateName: map['registrationCertificateName'] as String?,
      registrationCertificatePath: map['registrationCertificatePath'] as String?,
      degreeCertificateName: map['degreeCertificateName'] as String?,
      degreeCertificatePath: map['degreeCertificatePath'] as String?,
      verificationStatus: map['verificationStatus'] as String? ?? map['verification_status'] as String? ?? 'pending',
      rejectionReason: map['rejectionReason'] as String? ?? map['rejection_reason'] as String?,
      primaryPracticeEnvironment: map['primaryPracticeEnvironment'] as String? ?? map['primary_practice_environment'] as String? ?? 'independent_clinic',
      totalExperienceYears: (map['totalExperienceYears'] as num?)?.toInt() ?? (map['total_experience_years'] as num?)?.toInt() ?? 0,
      facilityId: facId.isNotEmpty ? facId : null,
      facilityName: facName,
      currentDesignation: map['currentDesignation'] as String? ?? map['current_designation'] as String? ?? 'Medical Officer',
      department: map['department'] as String? ?? 'General Medicine',
      yearsAtCurrentFacility: (map['yearsAtCurrentFacility'] as num?)?.toInt() ?? (map['years_at_current_facility'] as num?)?.toInt() ?? 0,
      yearsIndependentPractice: (map['yearsIndependentPractice'] as num?)?.toInt() ?? (map['years_independent_practice'] as num?)?.toInt() ?? 0,
      previousAffiliations: (map['previousAffiliations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      capabilities: caps,
      annualPatientVolume: (map['annualPatientVolume'] as num?)?.toInt() ?? (map['annual_patient_volume'] as num?)?.toInt() ?? 0,
      followupExperienceSummary: map['followupExperienceSummary'] as String? ?? map['followup_experience_summary'] as String?,
      procedureExperienceSummary: map['procedureExperienceSummary'] as String? ?? map['procedure_experience_summary'] as String?,
      teachingResearchSummary: map['teachingResearchSummary'] as String? ?? map['teaching_research_summary'] as String?,
      associationMemberships: (map['associationMemberships'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      governmentSchemesSummary: map['governmentSchemesSummary'] as String? ?? map['government_schemes_summary'] as String?,
      evidenceDocumentName: map['evidenceDocumentName'] as String?,
      capabilityScore: score,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : null,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory DoctorRegistrationModel.fromJson(String source) =>
      DoctorRegistrationModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
