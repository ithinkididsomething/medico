/// Clinical and system enums for SMART Referral.
library;

/// Biological sex of the patient.
enum Sex {
  male,
  female,
  other;

  String get displayName {
    switch (this) {
      case Sex.male:
        return 'Male';
      case Sex.female:
        return 'Female';
      case Sex.other:
        return 'Other';
    }
  }

  static Sex fromString(String value) {
    return Sex.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => Sex.other,
    );
  }
}

/// Clinical referral urgency evaluation level.
enum UrgencyLevel {
  /// Low urgency, manageable with standard primary scheduling or observation.
  routine,

  /// High clinical risk, needs referral within hours (same day transfer).
  urgent,

  /// Life-threatening red flag, requires immediate emergency dispatch & stabilization.
  emergency;

  String get displayName {
    switch (this) {
      case UrgencyLevel.routine:
        return 'Routine';
      case UrgencyLevel.urgent:
        return 'Urgent';
      case UrgencyLevel.emergency:
        return 'Emergency';
    }
  }

  bool get isEmergency => this == UrgencyLevel.emergency;
  bool get isUrgent => this == UrgencyLevel.urgent;
  bool get isRoutine => this == UrgencyLevel.routine;

  static UrgencyLevel fromString(String value) {
    return UrgencyLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UrgencyLevel.routine,
    );
  }
}

/// Assistive decision-support recommended course of action.
enum RecommendedAction {
  /// Condition manageable within the primary rural clinic.
  manageLocally,

  /// Planned referral recommended to secondary healthcare facility.
  referralRecommended,

  /// Critical stabilization & emergency transit immediately required.
  immediateReferral;

  String get displayName {
    switch (this) {
      case RecommendedAction.manageLocally:
        return 'Manage Locally';
      case RecommendedAction.referralRecommended:
        return 'Referral Recommended';
      case RecommendedAction.immediateReferral:
        return 'Immediate Emergency Referral';
    }
  }

  bool get requiresTransfer => this != RecommendedAction.manageLocally;

  static RecommendedAction fromString(String value) {
    return RecommendedAction.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RecommendedAction.referralRecommended,
    );
  }
}

/// Lifecycle status of an initiated patient referral.
enum ReferralStatus {
  /// Created and saved, awaiting review or authorization.
  pending,

  /// Referral order generated and dispatched to destination hospital.
  referred,

  /// Destination hospital triage team has acknowledged and accepted.
  accepted,

  /// Patient is in transit / ambulance dispatched.
  transferred,

  /// Patient arrived, handed over, and admitted at receiving hospital.
  completed;

  String get displayName {
    switch (this) {
      case ReferralStatus.pending:
        return 'Pending';
      case ReferralStatus.referred:
        return 'Referred';
      case ReferralStatus.accepted:
        return 'Accepted';
      case ReferralStatus.transferred:
        return 'Transferred (In-Transit)';
      case ReferralStatus.completed:
        return 'Completed';
    }
  }

  bool get isActive => this != ReferralStatus.completed;

  static ReferralStatus fromString(String value) {
    return ReferralStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ReferralStatus.pending,
    );
  }
}

/// Filter tags for referral tracking and dashboard triage registry metrics.
enum ReferralFilterTag {
  all,
  emergency,
  inTransit,
  completed,
  pending,
  referred,
  accepted;

  String get displayName {
    switch (this) {
      case ReferralFilterTag.all:
        return 'All Referrals';
      case ReferralFilterTag.emergency:
        return 'Emergency';
      case ReferralFilterTag.inTransit:
        return 'In Transit';
      case ReferralFilterTag.completed:
        return 'Completed';
      case ReferralFilterTag.pending:
        return 'Pending';
      case ReferralFilterTag.referred:
        return 'Referred';
      case ReferralFilterTag.accepted:
        return 'Accepted';
    }
  }

  static ReferralFilterTag fromString(String value) {
    return ReferralFilterTag.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ReferralFilterTag.all,
    );
  }
}

/// Clinical condition categories for condition-specific hospital prioritization.
enum PatientConditionCategory {
  /// Priority 1: Life-saving capability | Priority 2: Immediate availability | Priority 3: Travel time | Priority 4: Required specialty
  criticalEmergency,

  /// Priority 1: Cardiac capability | Priority 2: Emergency and ICU availability | Priority 3: Travel time | Priority 4: Capacity
  suspectedCardiacEmergency,

  /// Priority 1: Stroke/neuro capability | Priority 2: Time to treatment | Priority 3: Availability | Priority 4: Travel time
  suspectedStroke,

  /// Priority 1: Trauma and operative capability | Priority 2: Blood availability and ICU capability | Priority 3: Travel time | Priority 4: Required specialty
  majorTrauma,

  /// Priority 1: Obstetric emergency capability | Priority 2: Blood bank, OT and ICU availability | Priority 3: Travel time | Priority 4: Capacity
  obstetricEmergency,

  /// Priority 1: Pediatric emergency capability | Priority 2: Pediatric ICU availability | Priority 3: Travel time | Priority 4: Capacity
  pediatricEmergency,

  /// Priority 1: Orthopaedic capability | Priority 2: Overall availability | Priority 3: Travel time | Priority 4: Distance
  stableFracture,

  /// Priority 1: Required medical specialty | Priority 2: Required diagnostic capability | Priority 3: Overall availability | Priority 4: Travel time
  stableMedicalCase;

  String get displayName {
    switch (this) {
      case PatientConditionCategory.criticalEmergency:
        return 'Critical Emergency';
      case PatientConditionCategory.suspectedCardiacEmergency:
        return 'Suspected Cardiac Emergency';
      case PatientConditionCategory.suspectedStroke:
        return 'Suspected Stroke';
      case PatientConditionCategory.majorTrauma:
        return 'Major Trauma';
      case PatientConditionCategory.obstetricEmergency:
        return 'Obstetric Emergency';
      case PatientConditionCategory.pediatricEmergency:
        return 'Pediatric Emergency';
      case PatientConditionCategory.stableFracture:
        return 'Stable Fracture';
      case PatientConditionCategory.stableMedicalCase:
        return 'Stable Medical Case';
    }
  }

  String get shortName {
    switch (this) {
      case PatientConditionCategory.criticalEmergency:
        return 'Critical';
      case PatientConditionCategory.suspectedCardiacEmergency:
        return 'Cardiac';
      case PatientConditionCategory.suspectedStroke:
        return 'Stroke';
      case PatientConditionCategory.majorTrauma:
        return 'Trauma';
      case PatientConditionCategory.obstetricEmergency:
        return 'Obstetric';
      case PatientConditionCategory.pediatricEmergency:
        return 'Pediatric';
      case PatientConditionCategory.stableFracture:
        return 'Fracture';
      case PatientConditionCategory.stableMedicalCase:
        return 'Medical';
    }
  }

  String get description {
    switch (this) {
      case PatientConditionCategory.criticalEmergency:
        return 'Immediate life threat requiring resuscitation and emergency life-saving capability.';
      case PatientConditionCategory.suspectedCardiacEmergency:
        return 'Suspected acute coronary syndrome, STEMI, or cardiogenic shock requiring cardiac care/Cath Lab.';
      case PatientConditionCategory.suspectedStroke:
        return 'Acute neurological deficit within golden hour requiring stroke/neuro care and urgent neuroimaging.';
      case PatientConditionCategory.majorTrauma:
        return 'Polytrauma, compound fracture, or hemorrhagic injury requiring trauma surgery and blood bank.';
      case PatientConditionCategory.obstetricEmergency:
        return 'Postpartum hemorrhage, eclampsia, or obstructed labor requiring emergent obstetric/C-section care.';
      case PatientConditionCategory.pediatricEmergency:
        return 'Severe respiratory distress, neonatal distress, or pediatric shock requiring specialized pediatric/PICU care.';
      case PatientConditionCategory.stableFracture:
        return 'Closed or stable fracture requiring orthopedic evaluation without acute neurovascular compromise.';
      case PatientConditionCategory.stableMedicalCase:
        return 'Non-critical medical illness requiring specialist consultation or secondary diagnostics.';
    }
  }

  bool get isEmergency =>
      this == PatientConditionCategory.criticalEmergency ||
      this == PatientConditionCategory.suspectedCardiacEmergency ||
      this == PatientConditionCategory.suspectedStroke ||
      this == PatientConditionCategory.majorTrauma ||
      this == PatientConditionCategory.obstetricEmergency ||
      this == PatientConditionCategory.pediatricEmergency;

  static PatientConditionCategory fromString(String value) {
    final normalized = value.toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
    for (final category in PatientConditionCategory.values) {
      final catNorm = category.name.toLowerCase().replaceAll('_', '');
      final dispNorm = category.displayName.toLowerCase().replaceAll(' ', '');
      if (normalized == catNorm || normalized == dispNorm) {
        return category;
      }
    }
    return PatientConditionCategory.stableMedicalCase;
  }
}

/// Verification status for clinical hospital capabilities.
/// Distinguishes confirmed capability, confirmed unavailability, and unverified/unknown data.
enum CapabilityStatus {
  confirmed,
  unavailable,
  unknown;

  bool get isConfirmed => this == CapabilityStatus.confirmed;
  bool get isUnavailable => this == CapabilityStatus.unavailable;
  bool get isUnknown => this == CapabilityStatus.unknown;

  String get displayName {
    switch (this) {
      case CapabilityStatus.confirmed:
        return 'Confirmed Available';
      case CapabilityStatus.unavailable:
        return 'Confirmed Unavailable';
      case CapabilityStatus.unknown:
        return 'Unknown / Unverified';
    }
  }
}

