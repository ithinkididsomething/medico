import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Seven functional categories of medical equipment and technology.
enum ResourceCategory {
  diagnosticAndImaging,
  criticalCareAndLifeSupport,
  surgicalAndTheatre,
  emergencyAndTrauma,
  laboratoryAndPathology,
  specializedTreatment,
  telemedicineAndDigitalHealth;

  String get id {
    switch (this) {
      case ResourceCategory.diagnosticAndImaging:
        return 'diagnostic_and_imaging';
      case ResourceCategory.criticalCareAndLifeSupport:
        return 'critical_care_and_life_support';
      case ResourceCategory.surgicalAndTheatre:
        return 'surgical_and_theatre';
      case ResourceCategory.emergencyAndTrauma:
        return 'emergency_and_trauma';
      case ResourceCategory.laboratoryAndPathology:
        return 'laboratory_and_pathology';
      case ResourceCategory.specializedTreatment:
        return 'specialized_treatment';
      case ResourceCategory.telemedicineAndDigitalHealth:
        return 'telemedicine_and_digital_health';
    }
  }

  String get label {
    switch (this) {
      case ResourceCategory.diagnosticAndImaging:
        return 'Diagnostic & Imaging';
      case ResourceCategory.criticalCareAndLifeSupport:
        return 'Critical Care & Life Support';
      case ResourceCategory.surgicalAndTheatre:
        return 'Surgical & Theatre';
      case ResourceCategory.emergencyAndTrauma:
        return 'Emergency & Trauma';
      case ResourceCategory.laboratoryAndPathology:
        return 'Laboratory & Pathology';
      case ResourceCategory.specializedTreatment:
        return 'Specialized Treatment';
      case ResourceCategory.telemedicineAndDigitalHealth:
        return 'Telemedicine & Digital';
    }
  }

  IconData get icon {
    switch (this) {
      case ResourceCategory.diagnosticAndImaging:
        return Icons.biotech_outlined;
      case ResourceCategory.criticalCareAndLifeSupport:
        return Icons.monitor_heart_outlined;
      case ResourceCategory.surgicalAndTheatre:
        return Icons.medical_services_outlined;
      case ResourceCategory.emergencyAndTrauma:
        return Icons.emergency_outlined;
      case ResourceCategory.laboratoryAndPathology:
        return Icons.science_outlined;
      case ResourceCategory.specializedTreatment:
        return Icons.healing_outlined;
      case ResourceCategory.telemedicineAndDigitalHealth:
        return Icons.hub_outlined;
    }
  }

  Color get color {
    switch (this) {
      case ResourceCategory.diagnosticAndImaging:
        return AppColors.tealAccentDark;
      case ResourceCategory.criticalCareAndLifeSupport:
        return AppColors.urgencyEmergencyRed;
      case ResourceCategory.surgicalAndTheatre:
        return AppColors.urgencyUrgentOrange;
      case ResourceCategory.emergencyAndTrauma:
        return Colors.deepPurple;
      case ResourceCategory.laboratoryAndPathology:
        return AppColors.primaryGreen;
      case ResourceCategory.specializedTreatment:
        return Colors.indigo;
      case ResourceCategory.telemedicineAndDigitalHealth:
        return Colors.blueGrey;
    }
  }

  static ResourceCategory fromString(String? val) {
    if (val == null) return ResourceCategory.diagnosticAndImaging;
    final lower = val.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    for (final cat in ResourceCategory.values) {
      if (cat.id == lower || cat.name.toLowerCase() == lower) {
        return cat;
      }
    }
    if (lower.contains('imag') || lower.contains('diagnos') || lower.contains('xray') || lower.contains('ct')) {
      return ResourceCategory.diagnosticAndImaging;
    }
    if (lower.contains('care') || lower.contains('ventilat') || lower.contains('icu') || lower.contains('monitor')) {
      return ResourceCategory.criticalCareAndLifeSupport;
    }
    if (lower.contains('surg') || lower.contains('theatre') || lower.contains('theater') || lower.contains('ot')) {
      return ResourceCategory.surgicalAndTheatre;
    }
    if (lower.contains('emerg') || lower.contains('trauma')) {
      return ResourceCategory.emergencyAndTrauma;
    }
    if (lower.contains('lab') || lower.contains('path') || lower.contains('blood')) {
      return ResourceCategory.laboratoryAndPathology;
    }
    if (lower.contains('dialys') || lower.contains('cath') || lower.contains('chemo')) {
      return ResourceCategory.specializedTreatment;
    }
    if (lower.contains('tele') || lower.contains('digital') || lower.contains('emr')) {
      return ResourceCategory.telemedicineAndDigitalHealth;
    }
    return ResourceCategory.diagnosticAndImaging;
  }
}

/// Operational state of a piece of medical equipment.
enum ResourceOperationalStatus {
  operational,
  limitedCapacity,
  maintenance,
  decommissioned;

  String get label {
    switch (this) {
      case ResourceOperationalStatus.operational:
        return 'Fully Operational';
      case ResourceOperationalStatus.limitedCapacity:
        return 'Degraded / Limited';
      case ResourceOperationalStatus.maintenance:
        return 'Under Maintenance';
      case ResourceOperationalStatus.decommissioned:
        return 'Decommissioned';
    }
  }

  Color get color {
    switch (this) {
      case ResourceOperationalStatus.operational:
        return AppColors.statusGreen;
      case ResourceOperationalStatus.limitedCapacity:
        return AppColors.urgencyUrgentOrange;
      case ResourceOperationalStatus.maintenance:
        return Colors.amber.shade800;
      case ResourceOperationalStatus.decommissioned:
        return AppColors.textGreyMuted;
    }
  }

  static ResourceOperationalStatus fromString(String? val) {
    if (val == null) return ResourceOperationalStatus.operational;
    final lower = val.toLowerCase();
    if (lower.contains('limit') || lower.contains('degrad')) return ResourceOperationalStatus.limitedCapacity;
    if (lower.contains('maint') || lower.contains('calibr')) return ResourceOperationalStatus.maintenance;
    if (lower.contains('decomm') || lower.contains('inactive')) return ResourceOperationalStatus.decommissioned;
    return ResourceOperationalStatus.operational;
  }
}

/// Ownership and delivery arrangement.
enum OwnershipType {
  inHouseOwned,
  leased,
  partnerOnsite,
  outsourcedOffsite;

  String get label {
    switch (this) {
      case OwnershipType.inHouseOwned:
        return 'In-House Owned';
      case OwnershipType.leased:
        return 'Leased';
      case OwnershipType.partnerOnsite:
        return 'Partner On-Site';
      case OwnershipType.outsourcedOffsite:
        return 'Outsourced Off-Site';
    }
  }

  static OwnershipType fromString(String? val) {
    if (val == null) return OwnershipType.inHouseOwned;
    final lower = val.toLowerCase();
    if (lower.contains('lease')) return OwnershipType.leased;
    if (lower.contains('partner')) return OwnershipType.partnerOnsite;
    if (lower.contains('outsource')) return OwnershipType.outsourcedOffsite;
    return OwnershipType.inHouseOwned;
  }
}

/// Audit verification state.
enum ResourceVerificationStatus {
  verified,
  pending,
  selfReported;

  String get label {
    switch (this) {
      case ResourceVerificationStatus.verified:
        return 'Verified Audit';
      case ResourceVerificationStatus.pending:
        return 'Pending Verification';
      case ResourceVerificationStatus.selfReported:
        return 'Self-Reported';
    }
  }

  Color get color {
    switch (this) {
      case ResourceVerificationStatus.verified:
        return AppColors.statusGreen;
      case ResourceVerificationStatus.pending:
        return AppColors.urgencyUrgentOrange;
      case ResourceVerificationStatus.selfReported:
        return AppColors.tealAccentDark;
    }
  }

  static ResourceVerificationStatus fromString(String? val) {
    if (val == null) return ResourceVerificationStatus.verified;
    final lower = val.toLowerCase();
    if (lower.contains('pend')) return ResourceVerificationStatus.pending;
    if (lower.contains('self') || lower.contains('unveri')) return ResourceVerificationStatus.selfReported;
    return ResourceVerificationStatus.verified;
  }
}

/// A piece of medical equipment or digital technology in a facility.
class FacilityResourceItem {
  final String id;
  final String facilityId;
  final String name;
  final ResourceCategory category;
  final String resourceType;
  final String modelSpec;
  final int quantityInstalled;
  final int quantityOperational;
  final int quantityOutOfService;
  final ResourceOperationalStatus operationalStatus;
  final String locationInFacility;
  final OwnershipType ownershipType;
  final String serviceDelivery;
  final int turnaroundTimeHours;
  final String availabilitySchedule;
  final String? lastMaintenanceDate;
  final String? nextMaintenanceDate;
  final String operatorRequirements;
  final ResourceVerificationStatus verificationStatus;
  final String verifiedBy;
  final String? evidenceDocumentName;
  final String? notes;
  final bool isPresent;
  final DateTime lastVerifiedAt;
  final DateTime updatedAt;

  const FacilityResourceItem({
    required this.id,
    required this.facilityId,
    required this.name,
    required this.category,
    this.resourceType = 'equipment',
    this.modelSpec = '',
    this.quantityInstalled = 1,
    this.quantityOperational = 1,
    this.quantityOutOfService = 0,
    this.operationalStatus = ResourceOperationalStatus.operational,
    this.locationInFacility = 'Main Clinical Block',
    this.ownershipType = OwnershipType.inHouseOwned,
    this.serviceDelivery = 'in_house',
    this.turnaroundTimeHours = 0,
    this.availabilitySchedule = '24/7',
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.operatorRequirements = 'Trained Clinical Staff',
    this.verificationStatus = ResourceVerificationStatus.verified,
    this.verifiedBy = 'Hospital Administrator',
    this.evidenceDocumentName,
    this.notes,
    this.isPresent = true,
    required this.lastVerifiedAt,
    required this.updatedAt,
  });

  bool get isOperational => operationalStatus == ResourceOperationalStatus.operational && isPresent;
  bool get isVerified => verificationStatus == ResourceVerificationStatus.verified;
  bool get isInHouse => ownershipType != OwnershipType.outsourcedOffsite && serviceDelivery != 'external_outsourced';

  FacilityResourceItem copyWith({
    String? id,
    String? facilityId,
    String? name,
    ResourceCategory? category,
    String? resourceType,
    String? modelSpec,
    int? quantityInstalled,
    int? quantityOperational,
    int? quantityOutOfService,
    ResourceOperationalStatus? operationalStatus,
    String? locationInFacility,
    OwnershipType? ownershipType,
    String? serviceDelivery,
    int? turnaroundTimeHours,
    String? availabilitySchedule,
    String? lastMaintenanceDate,
    String? nextMaintenanceDate,
    String? operatorRequirements,
    ResourceVerificationStatus? verificationStatus,
    String? verifiedBy,
    String? evidenceDocumentName,
    String? notes,
    bool? isPresent,
    DateTime? lastVerifiedAt,
    DateTime? updatedAt,
  }) {
    return FacilityResourceItem(
      id: id ?? this.id,
      facilityId: facilityId ?? this.facilityId,
      name: name ?? this.name,
      category: category ?? this.category,
      resourceType: resourceType ?? this.resourceType,
      modelSpec: modelSpec ?? this.modelSpec,
      quantityInstalled: quantityInstalled ?? this.quantityInstalled,
      quantityOperational: quantityOperational ?? this.quantityOperational,
      quantityOutOfService: quantityOutOfService ?? this.quantityOutOfService,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      locationInFacility: locationInFacility ?? this.locationInFacility,
      ownershipType: ownershipType ?? this.ownershipType,
      serviceDelivery: serviceDelivery ?? this.serviceDelivery,
      turnaroundTimeHours: turnaroundTimeHours ?? this.turnaroundTimeHours,
      availabilitySchedule: availabilitySchedule ?? this.availabilitySchedule,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      operatorRequirements: operatorRequirements ?? this.operatorRequirements,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      evidenceDocumentName: evidenceDocumentName ?? this.evidenceDocumentName,
      notes: notes ?? this.notes,
      isPresent: isPresent ?? this.isPresent,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FacilityResourceItem.fromJson(Map<String, dynamic> json) {
    return FacilityResourceItem(
      id: json['resource_id']?.toString() ?? json['id']?.toString() ?? 'res_${json['inventory_id'] ?? ''}',
      facilityId: json['facility_id']?.toString() ?? json['facilityId']?.toString() ?? '',
      name: json['resource_name']?.toString() ?? json['name']?.toString() ?? 'Equipment',
      category: ResourceCategory.fromString(json['resource_category']?.toString() ?? json['category']?.toString()),
      resourceType: json['resource_type']?.toString() ?? 'equipment',
      modelSpec: json['model_spec']?.toString() ?? json['modelSpec']?.toString() ?? '',
      quantityInstalled: (json['quantity_installed'] ?? json['quantityInstalled'] ?? 1) as int,
      quantityOperational: (json['quantity_operational'] ?? json['quantityOperational'] ?? 1) as int,
      quantityOutOfService: (json['quantity_out_of_service'] ?? json['quantityOutOfService'] ?? 0) as int,
      operationalStatus: ResourceOperationalStatus.fromString(json['operational_status']?.toString()),
      locationInFacility: json['location_in_facility']?.toString() ?? 'Main Block',
      ownershipType: OwnershipType.fromString(json['ownership_type']?.toString()),
      serviceDelivery: json['service_delivery']?.toString() ?? 'in_house',
      turnaroundTimeHours: (json['turnaround_time_hours'] ?? json['turnaroundTimeHours'] ?? 0) as int,
      availabilitySchedule: json['availability_schedule']?.toString() ?? '24/7',
      lastMaintenanceDate: json['last_maintenance_date']?.toString(),
      nextMaintenanceDate: json['next_maintenance_date']?.toString(),
      operatorRequirements: json['operator_requirements']?.toString() ?? 'Trained Clinical Staff',
      verificationStatus: ResourceVerificationStatus.fromString(json['verification_status']?.toString()),
      verifiedBy: json['verified_by']?.toString() ?? 'Hospital Administrator',
      evidenceDocumentName: json['evidence_document_name']?.toString(),
      notes: json['notes']?.toString(),
      isPresent: json['is_present'] == 1 || json['is_present'] == true || json['isPresent'] == true,
      lastVerifiedAt: DateTime.tryParse(json['last_verified_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resource_id': id,
      'facility_id': facilityId,
      'resource_name': name,
      'resource_category': category.id,
      'resource_type': resourceType,
      'model_spec': modelSpec,
      'quantity_installed': quantityInstalled,
      'quantity_operational': quantityOperational,
      'quantity_out_of_service': quantityOutOfService,
      'operational_status': operationalStatus.name,
      'location_in_facility': locationInFacility,
      'ownership_type': ownershipType.name,
      'service_delivery': serviceDelivery,
      'turnaround_time_hours': turnaroundTimeHours,
      'availability_schedule': availabilitySchedule,
      'last_maintenance_date': lastMaintenanceDate,
      'next_maintenance_date': nextMaintenanceDate,
      'operator_requirements': operatorRequirements,
      'verification_status': verificationStatus.name,
      'verified_by': verifiedBy,
      'evidence_document_name': evidenceDocumentName,
      'notes': notes,
      'is_present': isPresent ? 1 : 0,
      'last_verified_at': lastVerifiedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Operational bed, unit, or theatre capacity record.
class FacilityCapacityRecord {
  final String capacityId;
  final String facilityId;
  final String category;
  final String categoryLabel;
  final int installedCapacity;
  final int operationalCapacity;
  final int occupiedCapacity;
  final int availableCapacity;
  final String source;
  final DateTime lastUpdatedAt;

  const FacilityCapacityRecord({
    required this.capacityId,
    required this.facilityId,
    required this.category,
    required this.categoryLabel,
    required this.installedCapacity,
    required this.operationalCapacity,
    required this.occupiedCapacity,
    required this.availableCapacity,
    this.source = 'Daily Census',
    required this.lastUpdatedAt,
  });

  double get occupancyRate => operationalCapacity > 0 ? (occupiedCapacity / operationalCapacity).clamp(0.0, 1.0) : 0.0;

  FacilityCapacityRecord copyWith({
    String? capacityId,
    String? facilityId,
    String? category,
    String? categoryLabel,
    int? installedCapacity,
    int? operationalCapacity,
    int? occupiedCapacity,
    int? availableCapacity,
    String? source,
    DateTime? lastUpdatedAt,
  }) {
    return FacilityCapacityRecord(
      capacityId: capacityId ?? this.capacityId,
      facilityId: facilityId ?? this.facilityId,
      category: category ?? this.category,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      installedCapacity: installedCapacity ?? this.installedCapacity,
      operationalCapacity: operationalCapacity ?? this.operationalCapacity,
      occupiedCapacity: occupiedCapacity ?? this.occupiedCapacity,
      availableCapacity: availableCapacity ?? this.availableCapacity,
      source: source ?? this.source,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  factory FacilityCapacityRecord.fromJson(Map<String, dynamic> json) {
    final inst = (json['installed_capacity'] ?? json['installedCapacity'] ?? 0) as int;
    final oper = (json['operational_capacity'] ?? json['operationalCapacity'] ?? inst) as int;
    final occ = (json['occupied_capacity'] ?? json['occupiedCapacity'] ?? 0) as int;
    final avail = (json['available_capacity'] ?? json['availableCapacity'] ?? (oper - occ).clamp(0, 9999)) as int;

    return FacilityCapacityRecord(
      capacityId: json['capacity_id']?.toString() ?? json['capacityId']?.toString() ?? '',
      facilityId: json['facility_id']?.toString() ?? json['facilityId']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general_inpatient',
      categoryLabel: json['category_label']?.toString() ?? json['categoryLabel']?.toString() ?? 'General Inpatient',
      installedCapacity: inst,
      operationalCapacity: oper,
      occupiedCapacity: occ,
      availableCapacity: avail,
      source: json['source']?.toString() ?? 'Census Update',
      lastUpdatedAt: DateTime.tryParse(json['last_updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'capacity_id': capacityId,
      'facility_id': facilityId,
      'category': category,
      'category_label': categoryLabel,
      'installed_capacity': installedCapacity,
      'operational_capacity': operationalCapacity,
      'occupied_capacity': occupiedCapacity,
      'available_capacity': availableCapacity,
      'source': source,
      'last_updated_at': lastUpdatedAt.toIso8601String(),
    };
  }
}

/// Supporting infrastructure including O2, power, blood bank, ambulance.
class FacilitySupportingInfrastructure {
  final String facilityId;
  final String ambulanceArrangements;
  final String bloodBankAccess;
  final String pharmacyAvailable;
  final String oxygenInfrastructure;
  final String powerBackup;
  final String isolationCapability;
  final String infectionControl;
  final String referralPartnerships;
  final String telemedicineCapability;
  final DateTime updatedAt;

  const FacilitySupportingInfrastructure({
    required this.facilityId,
    this.ambulanceArrangements = '108 Ambulance Linkage',
    this.bloodBankAccess = 'District Blood Bank Linkage',
    this.pharmacyAvailable = '24/7 Registered In-House Pharmacy',
    this.oxygenInfrastructure = 'Central Pipeline + Concentrators',
    this.powerBackup = 'Auto-Switching Generator + UPS',
    this.isolationCapability = 'Dedicated Isolation Beds',
    this.infectionControl = 'NABH Infection Control Certified',
    this.referralPartnerships = 'Ayushman Bharat PM-JAY Empaneled',
    this.telemedicineCapability = 'Tele-Consultation Link Available',
    required this.updatedAt,
  });

  factory FacilitySupportingInfrastructure.fromJson(Map<String, dynamic> json) {
    return FacilitySupportingInfrastructure(
      facilityId: json['facility_id']?.toString() ?? json['facilityId']?.toString() ?? '',
      ambulanceArrangements: json['ambulance_arrangements']?.toString() ?? '108 Ambulance Stationed on Site',
      bloodBankAccess: json['blood_bank_access']?.toString() ?? '24/7 Blood Bank Access',
      pharmacyAvailable: json['pharmacy_available']?.toString() ?? '24/7 Registered Pharmacy',
      oxygenInfrastructure: json['oxygen_infrastructure']?.toString() ?? 'Liquid Medical Oxygen + Pipeline',
      powerBackup: json['power_backup']?.toString() ?? 'Dual Generator Backup + UPS',
      isolationCapability: json['isolation_capability']?.toString() ?? 'Negative Pressure Isolation Ward',
      infectionControl: json['infection_control']?.toString() ?? 'NABH Certified HICC',
      referralPartnerships: json['referral_partnerships']?.toString() ?? 'PM-JAY Empaneled',
      telemedicineCapability: json['telemedicine_capability']?.toString() ?? 'Tele-ICU Video Terminal',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facility_id': facilityId,
      'ambulance_arrangements': ambulanceArrangements,
      'blood_bank_access': bloodBankAccess,
      'pharmacy_available': pharmacyAvailable,
      'oxygen_infrastructure': oxygenInfrastructure,
      'power_backup': powerBackup,
      'isolation_capability': isolationCapability,
      'infection_control': infectionControl,
      'referral_partnerships': referralPartnerships,
      'telemedicine_capability': telemedicineCapability,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Clinical or technical personnel affiliated with a facility.
class FacilityStaffAffiliation {
  final String affiliationId;
  final String facilityId;
  final String? doctorId;
  final String staffName;
  final String staffRole;
  final String department;
  final String designation;
  final String? primarySpecialty;
  final List<String> qualifications;
  final List<String> capabilities;
  final String workingDays;
  final String shiftTiming;
  final bool emergencyDutyParticipating;
  final bool isCurrentlyPractising;
  final String verificationStatus;

  const FacilityStaffAffiliation({
    required this.affiliationId,
    required this.facilityId,
    this.doctorId,
    required this.staffName,
    required this.staffRole,
    required this.department,
    required this.designation,
    this.primarySpecialty,
    this.qualifications = const [],
    this.capabilities = const [],
    this.workingDays = 'Mon-Sat',
    this.shiftTiming = 'Day (09:00 - 17:00)',
    this.emergencyDutyParticipating = true,
    this.isCurrentlyPractising = true,
    this.verificationStatus = 'verified',
  });

  factory FacilityStaffAffiliation.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return FacilityStaffAffiliation(
      affiliationId: json['affiliation_id']?.toString() ?? json['affiliationId']?.toString() ?? '',
      facilityId: json['facility_id']?.toString() ?? json['facilityId']?.toString() ?? '',
      doctorId: json['doctor_id']?.toString() ?? json['doctorId']?.toString(),
      staffName: json['staff_name']?.toString() ?? json['staffName']?.toString() ?? 'Clinical Staff',
      staffRole: json['staff_role']?.toString() ?? json['staffRole']?.toString() ?? 'doctor',
      department: json['department']?.toString() ?? 'General Medicine',
      designation: json['designation']?.toString() ?? 'Staff Physician',
      primarySpecialty: json['primary_specialty']?.toString() ?? json['primarySpecialty']?.toString(),
      qualifications: parseList(json['qualifications'] ?? json['qualifications_json']),
      capabilities: parseList(json['capabilities'] ?? json['capabilities_json']),
      workingDays: json['working_days']?.toString() ?? 'Mon-Sat',
      shiftTiming: json['shift_timing']?.toString() ?? 'Day (09:00 - 17:00)',
      emergencyDutyParticipating: json['emergency_duty_participating'] == 1 || json['emergency_duty_participating'] == true,
      isCurrentlyPractising: json['is_currently_practising'] == 1 || json['is_currently_practising'] == true,
      verificationStatus: json['verification_status']?.toString() ?? 'verified',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'affiliation_id': affiliationId,
      'facility_id': facilityId,
      'doctor_id': doctorId,
      'staff_name': staffName,
      'staff_role': staffRole,
      'department': department,
      'designation': designation,
      'primary_specialty': primarySpecialty,
      'qualifications': qualifications,
      'capabilities': capabilities,
      'working_days': workingDays,
      'shift_timing': shiftTiming,
      'emergency_duty_participating': emergencyDutyParticipating ? 1 : 0,
      'is_currently_practising': isCurrentlyPractising ? 1 : 0,
      'verification_status': verificationStatus,
    };
  }
}

/// Detailed facility administrative profile.
class FacilityDetailedProfile {
  final String facilityId;
  final String contactNumber;
  final String officialEmail;
  final String openingHours;
  final String operatingDays;
  final String licenseNumber;
  final String registrationAuthority;
  final String adminName;
  final String emergencyServicesDetail;
  final List<String> departments;
  final int profileCompletionPercentage;
  final String verificationStatus;

  const FacilityDetailedProfile({
    required this.facilityId,
    this.contactNumber = '+91 731 2894000',
    this.officialEmail = 'admin@mp.health.gov.in',
    this.openingHours = '24 Hours',
    this.operatingDays = 'All Days (Mon-Sun)',
    this.licenseNumber = 'MP-DHS-REG-2026',
    this.registrationAuthority = 'Directorate of Health Services / NABH',
    this.adminName = 'Medical Superintendent',
    this.emergencyServicesDetail = '24/7 Resuscitation & Acute Care',
    this.departments = const [],
    this.profileCompletionPercentage = 94,
    this.verificationStatus = 'verified',
  });

  factory FacilityDetailedProfile.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return FacilityDetailedProfile(
      facilityId: json['facility_id']?.toString() ?? json['facilityId']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '+91 731 2894000',
      officialEmail: json['official_email']?.toString() ?? 'admin@mp.health.gov.in',
      openingHours: json['opening_hours']?.toString() ?? '24 Hours',
      operatingDays: json['operating_days']?.toString() ?? 'All Days',
      licenseNumber: json['license_number']?.toString() ?? 'MP-DHS-2026',
      registrationAuthority: json['registration_authority']?.toString() ?? 'MP Health Department',
      adminName: json['admin_name']?.toString() ?? 'Medical Superintendent',
      emergencyServicesDetail: json['emergency_services_detail']?.toString() ?? '24/7 Triage & Acute Care',
      departments: parseList(json['departments']),
      profileCompletionPercentage: (json['profile_completion_percentage'] ?? 90) as int,
      verificationStatus: json['verification_status']?.toString() ?? 'verified',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facility_id': facilityId,
      'contact_number': contactNumber,
      'official_email': officialEmail,
      'opening_hours': openingHours,
      'operating_days': operatingDays,
      'license_number': licenseNumber,
      'registration_authority': registrationAuthority,
      'admin_name': adminName,
      'emergency_services_detail': emergencyServicesDetail,
      'departments': departments,
      'profile_completion_percentage': profileCompletionPercentage,
      'verification_status': verificationStatus,
    };
  }
}

/// Audit verification record.
class FacilityResourceVerificationRecord {
  final String verificationId;
  final String facilityId;
  final String resourceId;
  final String reviewedBy;
  final String reviewerRole;
  final String decision;
  final String? evidenceNotes;
  final DateTime verifiedAt;
  final String? reverificationDueDate;

  const FacilityResourceVerificationRecord({
    required this.verificationId,
    required this.facilityId,
    required this.resourceId,
    required this.reviewedBy,
    required this.reviewerRole,
    required this.decision,
    this.evidenceNotes,
    required this.verifiedAt,
    this.reverificationDueDate,
  });

  factory FacilityResourceVerificationRecord.fromJson(Map<String, dynamic> json) {
    return FacilityResourceVerificationRecord(
      verificationId: json['verification_id']?.toString() ?? '',
      facilityId: json['facility_id']?.toString() ?? '',
      resourceId: json['resource_id']?.toString() ?? '',
      reviewedBy: json['reviewed_by']?.toString() ?? 'Administrator',
      reviewerRole: json['reviewer_role']?.toString() ?? 'admin',
      decision: json['decision']?.toString() ?? 'approved',
      evidenceNotes: json['evidence_notes']?.toString(),
      verifiedAt: DateTime.tryParse(json['verified_at']?.toString() ?? '') ?? DateTime.now(),
      reverificationDueDate: json['reverification_due_date']?.toString(),
    );
  }
}

/// Clinical department and specialized service within a healthcare facility.
class FacilityDepartment {
  final String departmentId;
  final String facilityId;
  final String departmentName;
  final List<String> specialties;
  final List<String> services;
  final String operationalDays;
  final String operatingHours;
  final String appointmentMode; // 'Walk-in & Appointment', 'Appointment Only', 'Walk-in Only'
  final bool emergencyAvailable;
  final String specialistCoverage; // 'on_site', 'on_call', 'not_available'
  final List<String> careLevels; // 'outpatient', 'inpatient', 'day_care', 'emergency'
  final String headOfDepartment;
  final bool isOperational;
  final String? temporaryClosureReason;
  final DateTime lastUpdatedAt;

  const FacilityDepartment({
    required this.departmentId,
    required this.facilityId,
    required this.departmentName,
    this.specialties = const [],
    this.services = const [],
    this.operationalDays = 'Mon-Sun',
    this.operatingHours = '24 Hours',
    this.appointmentMode = 'Walk-in & Appointment',
    this.emergencyAvailable = true,
    this.specialistCoverage = 'on_site',
    this.careLevels = const ['outpatient', 'inpatient', 'emergency'],
    this.headOfDepartment = 'Head of Department',
    this.isOperational = true,
    this.temporaryClosureReason,
    required this.lastUpdatedAt,
  });

  factory FacilityDepartment.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return FacilityDepartment(
      departmentId: json['department_id']?.toString() ?? json['departmentId']?.toString() ?? '',
      facilityId: json['facility_id']?.toString() ?? json['facilityId']?.toString() ?? '',
      departmentName: json['department_name']?.toString() ?? json['departmentName']?.toString() ?? 'General Clinical Department',
      specialties: parseList(json['specialties'] ?? json['specialties_json']),
      services: parseList(json['services'] ?? json['services_json']),
      operationalDays: json['operational_days']?.toString() ?? 'Mon-Sun',
      operatingHours: json['operating_hours']?.toString() ?? '24 Hours',
      appointmentMode: json['appointment_mode']?.toString() ?? 'Walk-in & Appointment',
      emergencyAvailable: json['emergency_available'] == 1 || json['emergency_available'] == true,
      specialistCoverage: json['specialist_coverage']?.toString() ?? 'on_site',
      careLevels: parseList(json['care_levels'] ?? json['care_levels_json'] ?? ['outpatient', 'inpatient', 'emergency']),
      headOfDepartment: json['head_of_department']?.toString() ?? 'Department Lead',
      isOperational: json['is_operational'] == 1 || json['is_operational'] == true,
      temporaryClosureReason: json['temporary_closure_reason']?.toString(),
      lastUpdatedAt: DateTime.tryParse(json['last_updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'department_id': departmentId,
      'facility_id': facilityId,
      'department_name': departmentName,
      'specialties': specialties,
      'services': services,
      'operational_days': operationalDays,
      'operating_hours': operatingHours,
      'appointment_mode': appointmentMode,
      'emergency_available': emergencyAvailable ? 1 : 0,
      'specialist_coverage': specialistCoverage,
      'care_levels': careLevels,
      'head_of_department': headOfDepartment,
      'is_operational': isOperational ? 1 : 0,
      if (temporaryClosureReason != null) 'temporary_closure_reason': temporaryClosureReason,
      'last_updated_at': lastUpdatedAt.toIso8601String(),
    };
  }

  FacilityDepartment copyWith({
    String? departmentName,
    List<String>? specialties,
    List<String>? services,
    String? operationalDays,
    String? operatingHours,
    String? appointmentMode,
    bool? emergencyAvailable,
    String? specialistCoverage,
    List<String>? careLevels,
    String? headOfDepartment,
    bool? isOperational,
    String? temporaryClosureReason,
    DateTime? lastUpdatedAt,
  }) {
    return FacilityDepartment(
      departmentId: departmentId,
      facilityId: facilityId,
      departmentName: departmentName ?? this.departmentName,
      specialties: specialties ?? this.specialties,
      services: services ?? this.services,
      operationalDays: operationalDays ?? this.operationalDays,
      operatingHours: operatingHours ?? this.operatingHours,
      appointmentMode: appointmentMode ?? this.appointmentMode,
      emergencyAvailable: emergencyAvailable ?? this.emergencyAvailable,
      specialistCoverage: specialistCoverage ?? this.specialistCoverage,
      careLevels: careLevels ?? this.careLevels,
      headOfDepartment: headOfDepartment ?? this.headOfDepartment,
      isOperational: isOperational ?? this.isOperational,
      temporaryClosureReason: temporaryClosureReason ?? this.temporaryClosureReason,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

/// Complete aggregated facility resources bundle.
class FacilityCompleteResources {
  final String facilityId;
  final String facilityName;
  final String facilityType;
  final String address;
  final double latitude;
  final double longitude;
  final bool emergencyCare;
  final bool icuAvailable;
  final int totalBeds;
  final int availableBeds;
  final int availableIcuBeds;
  final FacilityDetailedProfile profile;
  final FacilitySupportingInfrastructure supportingInfrastructure;
  final List<FacilityCapacityRecord> capacity;
  final List<FacilityResourceItem> inventory;
  final List<FacilityStaffAffiliation> staff;
  final List<FacilityDepartment> departments;
  final List<FacilityResourceVerificationRecord> verificationRecords;
  final Map<String, dynamic> summary;

  const FacilityCompleteResources({
    required this.facilityId,
    required this.facilityName,
    required this.facilityType,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.emergencyCare,
    required this.icuAvailable,
    required this.totalBeds,
    required this.availableBeds,
    required this.availableIcuBeds,
    required this.profile,
    required this.supportingInfrastructure,
    required this.capacity,
    required this.inventory,
    required this.staff,
    this.departments = const [],
    required this.verificationRecords,
    required this.summary,
  });

  factory FacilityCompleteResources.fromJson(Map<String, dynamic> json) {
    final fac = (json['facility'] as Map<String, dynamic>?) ?? {};
    final prof = (json['profile'] as Map<String, dynamic>?) ?? {};
    final supp = (json['supporting_infrastructure'] as Map<String, dynamic>?) ?? {};
    final summ = (json['summary'] as Map<String, dynamic>?) ?? {};

    final capList = (json['capacity'] as List<dynamic>? ?? [])
        .map((e) => FacilityCapacityRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    final invList = (json['inventory'] as List<dynamic>? ?? [])
        .map((e) => FacilityResourceItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final staffList = (json['staff'] as List<dynamic>? ?? [])
        .map((e) => FacilityStaffAffiliation.fromJson(e as Map<String, dynamic>))
        .toList();

    final deptList = (json['departments'] as List<dynamic>? ?? [])
        .map((e) => FacilityDepartment.fromJson(e as Map<String, dynamic>))
        .toList();

    final verList = (json['verification_records'] as List<dynamic>? ?? [])
        .map((e) => FacilityResourceVerificationRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    return FacilityCompleteResources(
      facilityId: json['facility_id']?.toString() ?? fac['hospitalId']?.toString() ?? '',
      facilityName: fac['name']?.toString() ?? 'Healthcare Facility',
      facilityType: fac['facilityType']?.toString() ?? 'Hospital',
      address: fac['address']?.toString() ?? '',
      latitude: (fac['latitude'] ?? 22.7196) as double,
      longitude: (fac['longitude'] ?? 75.8577) as double,
      emergencyCare: fac['emergencyCare'] == true,
      icuAvailable: fac['icuAvailable'] == true,
      totalBeds: (summ['total_beds'] ?? fac['bedAvailability'] ?? 30) as int,
      availableBeds: (summ['available_beds'] ?? fac['bedAvailability'] ?? 10) as int,
      availableIcuBeds: (summ['available_icu_beds'] ?? 2) as int,
      profile: FacilityDetailedProfile.fromJson(prof),
      supportingInfrastructure: FacilitySupportingInfrastructure.fromJson(supp),
      capacity: capList,
      inventory: invList,
      staff: staffList,
      departments: deptList,
      verificationRecords: verList,
      summary: summ,
    );
  }

  FacilityCompleteResources copyWith({
    String? facilityId,
    String? facilityName,
    String? facilityType,
    String? address,
    double? latitude,
    double? longitude,
    bool? emergencyCare,
    bool? icuAvailable,
    int? totalBeds,
    int? availableBeds,
    int? availableIcuBeds,
    FacilityDetailedProfile? profile,
    FacilitySupportingInfrastructure? supportingInfrastructure,
    List<FacilityCapacityRecord>? capacity,
    List<FacilityResourceItem>? inventory,
    List<FacilityStaffAffiliation>? staff,
    List<FacilityDepartment>? departments,
    List<FacilityResourceVerificationRecord>? verificationRecords,
    Map<String, dynamic>? summary,
  }) {
    return FacilityCompleteResources(
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      facilityType: facilityType ?? this.facilityType,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      emergencyCare: emergencyCare ?? this.emergencyCare,
      icuAvailable: icuAvailable ?? this.icuAvailable,
      totalBeds: totalBeds ?? this.totalBeds,
      availableBeds: availableBeds ?? this.availableBeds,
      availableIcuBeds: availableIcuBeds ?? this.availableIcuBeds,
      profile: profile ?? this.profile,
      supportingInfrastructure: supportingInfrastructure ?? this.supportingInfrastructure,
      capacity: capacity ?? this.capacity,
      inventory: inventory ?? this.inventory,
      staff: staff ?? this.staff,
      departments: departments ?? this.departments,
      verificationRecords: verificationRecords ?? this.verificationRecords,
      summary: summary ?? this.summary,
    );
  }
}
