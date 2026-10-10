import 'dart:convert';

/// Clinical categories for emergency triage.
enum EmergencyCategory {
  stemiCardiac('Acute STEMI / Cardiac Arrest', 'Cardiology & Cath Lab', 'stemi_cardiac'),
  acuteStroke('Acute Ischemic Stroke / CVA', 'Neurology & Stroke Unit', 'acute_stroke'),
  polytrauma('Severe Polytrauma & Hemorrhage', 'Trauma Resuscitation Bay & OT', 'polytrauma'),
  severeRespiratory('Severe Acute Respiratory Distress', 'Pulmonology & Intensive Care', 'severe_respiratory'),
  septicShock('Septic Shock / Multi-organ Failure', 'Critical Care & Medical ICU', 'septic_shock'),
  postpartumHemorrhage('Severe Obstetric Emergency / PPH', 'Obstetrics & High-Dependency Unit', 'postpartum_hemorrhage'),
  pediatricEmergency('Pediatric / Neonatal Emergency', 'Pediatric ICU & Neonatal Care', 'pediatric_emergency'),
  acuteAbdomen('Acute Abdomen / Sepsis', 'Emergency General Surgery & OT', 'acute_abdomen'),
  generalEmergency('Unspecified Acute Emergency', 'Emergency Department & Triage', 'general_emergency');

  final String label;
  final String departmentTarget;
  final String key;
  const EmergencyCategory(this.label, this.departmentTarget, this.key);

  static EmergencyCategory fromKey(String? k) {
    if (k == null) return EmergencyCategory.generalEmergency;
    final clean = k.toLowerCase().replaceAll('-', '_');
    for (final c in EmergencyCategory.values) {
      if (c.key == clean || c.name.toLowerCase() == clean) return c;
    }
    return EmergencyCategory.generalEmergency;
  }
}

/// Status of the emergency ambulance response.
enum AmbulanceDispatchStatus {
  notDispatched('Not Dispatched', 'not_dispatched'),
  requested('Ambulance Requested (Awaiting Unit)', 'requested'),
  enRouteScene('En Route to Scene / Clinic', 'en_route_scene'),
  patientLoadedInTransit('Patient Loaded — En Route to Hospital', 'patient_loaded_in_transit'),
  arrived('Arrived at Destination Facility', 'arrived');

  final String label;
  final String key;
  const AmbulanceDispatchStatus(this.label, this.key);

  static AmbulanceDispatchStatus fromKey(String? k) {
    if (k == null) return AmbulanceDispatchStatus.notDispatched;
    for (final s in AmbulanceDispatchStatus.values) {
      if (s.key == k || s.name == k) return s;
    }
    return AmbulanceDispatchStatus.notDispatched;
  }
}

/// Status of the clinical referral workflow.
enum EmergencyWorkflowStatus {
  draft('Draft', 'draft'),
  emergencyCreated('Emergency Created', 'emergency_created'),
  initialSent('Initial Referral Sent', 'initial_sent'),
  inTransit('Patient in Transit', 'in_transit'),
  patientArrived('Patient Arrived at Hospital', 'patient_arrived'),
  handoverCompleted('Handover Completed', 'handover_completed'),
  closed('Closed', 'closed'),
  cancelled('Cancelled', 'cancelled');

  final String label;
  final String key;
  const EmergencyWorkflowStatus(this.label, this.key);

  static EmergencyWorkflowStatus fromKey(String? k) {
    if (k == null) return EmergencyWorkflowStatus.emergencyCreated;
    for (final s in EmergencyWorkflowStatus.values) {
      if (s.key == k || s.name == k) return s;
    }
    return EmergencyWorkflowStatus.emergencyCreated;
  }
}

/// Status of external notification delivery attempts.
enum EmergencyDeliveryStatus {
  notSent('Not Sent', 'not_sent'),
  queued('Queued (Offline / Retry)', 'queued'),
  sending('Sending...', 'sending'),
  sentToProvider('Sent to Provider', 'sent_to_provider'),
  delivered('Delivered to Recipient', 'delivered'),
  failed('Transmission Failed', 'failed'),
  retryRequired('Retry Required', 'retry_required');

  final String label;
  final String key;
  const EmergencyDeliveryStatus(this.label, this.key);

  static EmergencyDeliveryStatus fromKey(String? k) {
    if (k == null) return EmergencyDeliveryStatus.notSent;
    for (final s in EmergencyDeliveryStatus.values) {
      if (s.key == k || s.name == k) return s;
    }
    return EmergencyDeliveryStatus.notSent;
  }
}

/// Receiving team clinical response status.
enum ReceivingResponseStatus {
  noResponseYet('Awaiting Response', 'no_response_yet'),
  acknowledged('Acknowledged by Receiving Team', 'acknowledged'),
  accepted('Patient Formally Accepted', 'accepted'),
  declined('Declined by Facility', 'declined'),
  alternativeRequested('Alternative Facility Requested', 'alternative_destination_requested');

  final String label;
  final String key;
  const ReceivingResponseStatus(this.label, this.key);

  static ReceivingResponseStatus fromKey(String? k) {
    if (k == null) return ReceivingResponseStatus.noResponseYet;
    for (final s in ReceivingResponseStatus.values) {
      if (s.key == k || s.name == k) return s;
    }
    return ReceivingResponseStatus.noResponseYet;
  }
}

/// Strongly typed Emergency Referral Model with versioning, audit trail,
/// ambulance dispatch telemetry, and multi-channel delivery tracking.
class EmergencyReferral {
  final String referralId;
  final String patientIdentifier;
  final String? patientName;
  final int? patientAge;
  final String? patientSex;
  final String presentingComplaint;
  final EmergencyCategory emergencyCategory;
  final List<String> redFlagSymptoms;
  final String? symptomOnsetTime;

  // Available Vital Signs (allows unknown / null)
  final int? vitalsPulse;
  final int? vitalsBpSystolic;
  final int? vitalsBpDiastolic;
  final int? vitalsSpo2;
  final int? vitalsRespRate;
  final double? vitalsTemp;
  final String consciousnessLevel; // Alert, Voice, Pain, Unresponsive (AVPU)

  // Clinical History & First Aid
  final String? allergies;
  final String? medicationsHistory;
  final String? immediateTreatmentGiven;

  // Ambulance Logistics
  final AmbulanceDispatchStatus ambulanceStatus;
  final DateTime? ambulanceDispatchTime;
  final String? ambulanceVehicleNumber;
  final String ambulanceServiceType;
  final int? ambulanceEtaMinutes;

  // Referring Clinician
  final String referringClinicianId;
  final String referringClinicianName;
  final String referringFacilityName;
  final String referringCallbackPhone;

  // Receiving Destination
  final String receivingFacilityId;
  final String receivingFacilityName;
  final String receivingDepartment;
  final String? intendedDoctorId;
  final String? intendedDoctorName;
  final String? recommendationOverrideReason;
  final String? clinicalNotes;

  // Lifecycle & Status
  final int currentVersion;
  final EmergencyWorkflowStatus workflowStatus;
  final String? cancellationReason;
  final EmergencyDeliveryStatus deliveryStatus;
  final ReceivingResponseStatus responseStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOfflineSynced;

  // Associated collections
  final List<EmergencyReferralVersion> versions;
  final List<EmergencyDeliveryAttempt> deliveries;
  final List<AmbulanceDispatchRecord> dispatchRecords;
  final List<EmergencyReferralAuditEntry> auditLogs;

  const EmergencyReferral({
    required this.referralId,
    required this.patientIdentifier,
    this.patientName,
    this.patientAge,
    this.patientSex,
    required this.presentingComplaint,
    required this.emergencyCategory,
    this.redFlagSymptoms = const [],
    this.symptomOnsetTime,
    this.vitalsPulse,
    this.vitalsBpSystolic,
    this.vitalsBpDiastolic,
    this.vitalsSpo2,
    this.vitalsRespRate,
    this.vitalsTemp,
    this.consciousnessLevel = 'Alert',
    this.allergies,
    this.medicationsHistory,
    this.immediateTreatmentGiven,
    this.ambulanceStatus = AmbulanceDispatchStatus.notDispatched,
    this.ambulanceDispatchTime,
    this.ambulanceVehicleNumber,
    this.ambulanceServiceType = '108 EMTS',
    this.ambulanceEtaMinutes,
    required this.referringClinicianId,
    required this.referringClinicianName,
    required this.referringFacilityName,
    required this.referringCallbackPhone,
    required this.receivingFacilityId,
    required this.receivingFacilityName,
    this.receivingDepartment = 'Emergency Department',
    this.intendedDoctorId,
    this.intendedDoctorName,
    this.recommendationOverrideReason,
    this.clinicalNotes,
    this.currentVersion = 1,
    this.workflowStatus = EmergencyWorkflowStatus.emergencyCreated,
    this.cancellationReason,
    this.deliveryStatus = EmergencyDeliveryStatus.notSent,
    this.responseStatus = ReceivingResponseStatus.noResponseYet,
    required this.createdAt,
    required this.updatedAt,
    this.isOfflineSynced = true,
    this.versions = const [],
    this.deliveries = const [],
    this.dispatchRecords = const [],
    this.auditLogs = const [],
  });

  /// Formatted vitals string for rapid display.
  String get formattedVitals {
    final list = <String>[];
    if (vitalsPulse != null) list.add('HR: $vitalsPulse bpm');
    if (vitalsBpSystolic != null && vitalsBpDiastolic != null) {
      list.add('BP: $vitalsBpSystolic/$vitalsBpDiastolic');
    }
    if (vitalsSpo2 != null) list.add('SpO2: $vitalsSpo2%');
    if (vitalsRespRate != null) list.add('RR: $vitalsRespRate/m');
    if (vitalsTemp != null) list.add('T: $vitalsTemp°');
    if (consciousnessLevel.isNotEmpty) list.add('AVPU: $consciousnessLevel');
    return list.isEmpty ? 'Vitals pending en-route assessment' : list.join(' • ');
  }

  /// Formatted patient display label.
  String get patientDisplayLabel {
    final name = patientName?.trim();
    if (name != null && name.isNotEmpty) {
      final ageStr = patientAge != null ? ', $patientAge' : '';
      final sexStr = patientSex != null ? ' ($patientSex)' : '';
      return '$name$ageStr$sexStr';
    }
    return patientIdentifier;
  }

  /// Formatted ETA string.
  String get formattedEta {
    if (ambulanceEtaMinutes == null) return 'ETA: Calculating...';
    if (ambulanceEtaMinutes == 0) return 'Arrived at Destination';
    return 'ETA: $ambulanceEtaMinutes mins';
  }

  EmergencyReferral copyWith({
    String? referralId,
    String? patientIdentifier,
    String? patientName,
    int? patientAge,
    String? patientSex,
    String? presentingComplaint,
    EmergencyCategory? emergencyCategory,
    List<String>? redFlagSymptoms,
    String? symptomOnsetTime,
    int? vitalsPulse,
    int? vitalsBpSystolic,
    int? vitalsBpDiastolic,
    int? vitalsSpo2,
    int? vitalsRespRate,
    double? vitalsTemp,
    String? consciousnessLevel,
    String? allergies,
    String? medicationsHistory,
    String? immediateTreatmentGiven,
    AmbulanceDispatchStatus? ambulanceStatus,
    DateTime? ambulanceDispatchTime,
    String? ambulanceVehicleNumber,
    String? ambulanceServiceType,
    int? ambulanceEtaMinutes,
    String? referringClinicianId,
    String? referringClinicianName,
    String? referringFacilityName,
    String? referringCallbackPhone,
    String? receivingFacilityId,
    String? receivingFacilityName,
    String? receivingDepartment,
    String? intendedDoctorId,
    String? intendedDoctorName,
    String? recommendationOverrideReason,
    String? clinicalNotes,
    int? currentVersion,
    EmergencyWorkflowStatus? workflowStatus,
    String? cancellationReason,
    EmergencyDeliveryStatus? deliveryStatus,
    ReceivingResponseStatus? responseStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOfflineSynced,
    List<EmergencyReferralVersion>? versions,
    List<EmergencyDeliveryAttempt>? deliveries,
    List<AmbulanceDispatchRecord>? dispatchRecords,
    List<EmergencyReferralAuditEntry>? auditLogs,
  }) {
    return EmergencyReferral(
      referralId: referralId ?? this.referralId,
      patientIdentifier: patientIdentifier ?? this.patientIdentifier,
      patientName: patientName ?? this.patientName,
      patientAge: patientAge ?? this.patientAge,
      patientSex: patientSex ?? this.patientSex,
      presentingComplaint: presentingComplaint ?? this.presentingComplaint,
      emergencyCategory: emergencyCategory ?? this.emergencyCategory,
      redFlagSymptoms: redFlagSymptoms ?? this.redFlagSymptoms,
      symptomOnsetTime: symptomOnsetTime ?? this.symptomOnsetTime,
      vitalsPulse: vitalsPulse ?? this.vitalsPulse,
      vitalsBpSystolic: vitalsBpSystolic ?? this.vitalsBpSystolic,
      vitalsBpDiastolic: vitalsBpDiastolic ?? this.vitalsBpDiastolic,
      vitalsSpo2: vitalsSpo2 ?? this.vitalsSpo2,
      vitalsRespRate: vitalsRespRate ?? this.vitalsRespRate,
      vitalsTemp: vitalsTemp ?? this.vitalsTemp,
      consciousnessLevel: consciousnessLevel ?? this.consciousnessLevel,
      allergies: allergies ?? this.allergies,
      medicationsHistory: medicationsHistory ?? this.medicationsHistory,
      immediateTreatmentGiven: immediateTreatmentGiven ?? this.immediateTreatmentGiven,
      ambulanceStatus: ambulanceStatus ?? this.ambulanceStatus,
      ambulanceDispatchTime: ambulanceDispatchTime ?? this.ambulanceDispatchTime,
      ambulanceVehicleNumber: ambulanceVehicleNumber ?? this.ambulanceVehicleNumber,
      ambulanceServiceType: ambulanceServiceType ?? this.ambulanceServiceType,
      ambulanceEtaMinutes: ambulanceEtaMinutes ?? this.ambulanceEtaMinutes,
      referringClinicianId: referringClinicianId ?? this.referringClinicianId,
      referringClinicianName: referringClinicianName ?? this.referringClinicianName,
      referringFacilityName: referringFacilityName ?? this.referringFacilityName,
      referringCallbackPhone: referringCallbackPhone ?? this.referringCallbackPhone,
      receivingFacilityId: receivingFacilityId ?? this.receivingFacilityId,
      receivingFacilityName: receivingFacilityName ?? this.receivingFacilityName,
      receivingDepartment: receivingDepartment ?? this.receivingDepartment,
      intendedDoctorId: intendedDoctorId ?? this.intendedDoctorId,
      intendedDoctorName: intendedDoctorName ?? this.intendedDoctorName,
      recommendationOverrideReason: recommendationOverrideReason ?? this.recommendationOverrideReason,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      currentVersion: currentVersion ?? this.currentVersion,
      workflowStatus: workflowStatus ?? this.workflowStatus,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      responseStatus: responseStatus ?? this.responseStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOfflineSynced: isOfflineSynced ?? this.isOfflineSynced,
      versions: versions ?? this.versions,
      deliveries: deliveries ?? this.deliveries,
      dispatchRecords: dispatchRecords ?? this.dispatchRecords,
      auditLogs: auditLogs ?? this.auditLogs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'referralId': referralId,
      'patientIdentifier': patientIdentifier,
      'patientName': patientName,
      'patientAge': patientAge,
      'patientSex': patientSex,
      'presentingComplaint': presentingComplaint,
      'emergencyCategory': emergencyCategory.key,
      'redFlagSymptoms': redFlagSymptoms,
      'symptomOnsetTime': symptomOnsetTime,
      'vitalsPulse': vitalsPulse,
      'vitalsBpSystolic': vitalsBpSystolic,
      'vitalsBpDiastolic': vitalsBpDiastolic,
      'vitalsSpo2': vitalsSpo2,
      'vitalsRespRate': vitalsRespRate,
      'vitalsTemp': vitalsTemp,
      'consciousnessLevel': consciousnessLevel,
      'allergies': allergies,
      'medicationsHistory': medicationsHistory,
      'immediateTreatmentGiven': immediateTreatmentGiven,
      'ambulanceStatus': ambulanceStatus.key,
      'ambulanceDispatchTime': ambulanceDispatchTime?.toIso8601String(),
      'ambulanceVehicleNumber': ambulanceVehicleNumber,
      'ambulanceServiceType': ambulanceServiceType,
      'ambulanceEtaMinutes': ambulanceEtaMinutes,
      'referringClinicianId': referringClinicianId,
      'referringClinicianName': referringClinicianName,
      'referringFacilityName': referringFacilityName,
      'referringCallbackPhone': referringCallbackPhone,
      'receivingFacilityId': receivingFacilityId,
      'receivingFacilityName': receivingFacilityName,
      'receivingDepartment': receivingDepartment,
      'intendedDoctorId': intendedDoctorId,
      'intendedDoctorName': intendedDoctorName,
      'recommendationOverrideReason': recommendationOverrideReason,
      'clinicalNotes': clinicalNotes,
      'currentVersion': currentVersion,
      'workflowStatus': workflowStatus.key,
      'cancellationReason': cancellationReason,
      'deliveryStatus': deliveryStatus.key,
      'responseStatus': responseStatus.key,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isOfflineSynced': isOfflineSynced,
      'versions': versions.map((v) => v.toMap()).toList(),
      'deliveries': deliveries.map((d) => d.toMap()).toList(),
      'dispatchRecords': dispatchRecords.map((r) => r.toMap()).toList(),
      'auditLogs': auditLogs.map((a) => a.toMap()).toList(),
    };
  }

  factory EmergencyReferral.fromMap(Map<String, dynamic> map) {
    // Red flags parsing
    List<String> redFlags = [];
    final rawFlags = map['redFlagSymptoms'] ?? map['red_flag_symptoms'];
    if (rawFlags is List) {
      redFlags = rawFlags.map((e) => e.toString()).toList();
    } else if (rawFlags is String && rawFlags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawFlags);
        if (decoded is List) redFlags = decoded.map((e) => e.toString()).toList();
      } catch (_) {
        redFlags = [rawFlags];
      }
    }

    // Versions parsing
    List<EmergencyReferralVersion> verList = [];
    final rawVersions = map['versions'];
    if (rawVersions is List) {
      verList = rawVersions
          .map((v) => EmergencyReferralVersion.fromMap(Map<String, dynamic>.from(v as Map)))
          .toList();
    }

    // Deliveries parsing
    List<EmergencyDeliveryAttempt> delList = [];
    final rawDel = map['deliveries'];
    if (rawDel is List) {
      delList = rawDel
          .map((d) => EmergencyDeliveryAttempt.fromMap(Map<String, dynamic>.from(d as Map)))
          .toList();
    }

    // Dispatch records
    List<AmbulanceDispatchRecord> dispList = [];
    final rawDisp = map['dispatchRecords'] ?? map['dispatch_records'];
    if (rawDisp is List) {
      dispList = rawDisp
          .map((r) => AmbulanceDispatchRecord.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    }

    // Audit logs
    List<EmergencyReferralAuditEntry> auditList = [];
    final rawAudit = map['auditLogs'] ?? map['audit_logs'];
    if (rawAudit is List) {
      auditList = rawAudit
          .map((a) => EmergencyReferralAuditEntry.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList();
    }

    final catRaw = map['emergencyCategory'] ?? map['emergency_category'];
    final ambStatRaw = map['ambulanceStatus'] ?? map['ambulance_status'];
    final wfStatRaw = map['workflowStatus'] ?? map['workflow_status'];
    final delStatRaw = map['deliveryStatus'] ?? map['delivery_status'];
    final respStatRaw = map['responseStatus'] ?? map['response_status'];

    final dispTimeStr = map['ambulanceDispatchTime'] ?? map['ambulance_dispatch_time'];
    final createdStr = map['createdAt'] ?? map['created_at'];
    final updatedStr = map['updatedAt'] ?? map['updated_at'];

    return EmergencyReferral(
      referralId: (map['referralId'] ?? map['referral_id'] ?? '').toString(),
      patientIdentifier: (map['patientIdentifier'] ?? map['patient_identifier'] ?? 'Unknown').toString(),
      patientName: map['patientName'] ?? map['patient_name'],
      patientAge: (map['patientAge'] ?? map['patient_age']) as int?,
      patientSex: map['patientSex'] ?? map['patient_sex'],
      presentingComplaint: (map['presentingComplaint'] ?? map['presenting_complaint'] ?? 'Acute Presentation').toString(),
      emergencyCategory: EmergencyCategory.fromKey(catRaw?.toString()),
      redFlagSymptoms: redFlags,
      symptomOnsetTime: map['symptomOnsetTime'] ?? map['symptom_onset_time'],
      vitalsPulse: (map['vitalsPulse'] ?? map['vitals_pulse']) as int?,
      vitalsBpSystolic: (map['vitalsBpSystolic'] ?? map['vitals_bp_systolic']) as int?,
      vitalsBpDiastolic: (map['vitalsBpDiastolic'] ?? map['vitals_bp_diastolic']) as int?,
      vitalsSpo2: (map['vitalsSpo2'] ?? map['vitals_spo2']) as int?,
      vitalsRespRate: (map['vitalsRespRate'] ?? map['vitals_resp_rate']) as int?,
      vitalsTemp: (map['vitalsTemp'] ?? map['vitals_temp']) != null
          ? double.tryParse((map['vitalsTemp'] ?? map['vitals_temp']).toString())
          : null,
      consciousnessLevel: (map['consciousnessLevel'] ?? map['consciousness_level'] ?? 'Alert').toString(),
      allergies: map['allergies'],
      medicationsHistory: map['medicationsHistory'] ?? map['medications_history'],
      immediateTreatmentGiven: map['immediateTreatmentGiven'] ?? map['immediate_treatment_given'],
      ambulanceStatus: AmbulanceDispatchStatus.fromKey(ambStatRaw?.toString()),
      ambulanceDispatchTime: dispTimeStr != null ? DateTime.tryParse(dispTimeStr.toString()) : null,
      ambulanceVehicleNumber: map['ambulanceVehicleNumber'] ?? map['ambulance_vehicle_number'],
      ambulanceServiceType: (map['ambulanceServiceType'] ?? map['ambulance_service_type'] ?? '108 EMTS').toString(),
      ambulanceEtaMinutes: (map['ambulanceEtaMinutes'] ?? map['ambulance_eta_minutes']) as int?,
      referringClinicianId: (map['referringClinicianId'] ?? map['referring_clinician_id'] ?? 'doc_clinician').toString(),
      referringClinicianName: (map['referringClinicianName'] ?? map['referring_clinician_name'] ?? 'Dr. Parth Saxena').toString(),
      referringFacilityName: (map['referringFacilityName'] ?? map['referring_facility_name'] ?? 'Primary Health Centre').toString(),
      referringCallbackPhone: (map['referringCallbackPhone'] ?? map['referring_callback_phone'] ?? '+91 98260 12345').toString(),
      receivingFacilityId: (map['receivingFacilityId'] ?? map['receiving_facility_id'] ?? 'indore_hospital_001').toString(),
      receivingFacilityName: (map['receivingFacilityName'] ?? map['receiving_facility_name'] ?? 'Apex Hospital').toString(),
      receivingDepartment: (map['receivingDepartment'] ?? map['receiving_department'] ?? 'Emergency Department').toString(),
      intendedDoctorId: map['intendedDoctorId'] ?? map['intended_doctor_id'],
      intendedDoctorName: map['intendedDoctorName'] ?? map['intended_doctor_name'],
      recommendationOverrideReason: map['recommendationOverrideReason'] ?? map['recommendation_override_reason'],
      clinicalNotes: map['clinicalNotes'] ?? map['clinical_notes'],
      currentVersion: (map['currentVersion'] ?? map['current_version'] ?? 1) as int,
      workflowStatus: EmergencyWorkflowStatus.fromKey(wfStatRaw?.toString()),
      cancellationReason: map['cancellationReason'] ?? map['cancellation_reason'],
      deliveryStatus: EmergencyDeliveryStatus.fromKey(delStatRaw?.toString()),
      responseStatus: ReceivingResponseStatus.fromKey(respStatRaw?.toString()),
      createdAt: createdStr != null ? DateTime.tryParse(createdStr.toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: updatedStr != null ? DateTime.tryParse(updatedStr.toString()) ?? DateTime.now() : DateTime.now(),
      isOfflineSynced: map['isOfflineSynced'] ?? map['is_offline_synced'] ?? true,
      versions: verList,
      deliveries: delList,
      dispatchRecords: dispList,
      auditLogs: auditList,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory EmergencyReferral.fromJson(String source) => EmergencyReferral.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Traceable version amendment snapshot.
class EmergencyReferralVersion {
  final int? versionId;
  final String referralId;
  final int versionNumber;
  final DateTime createdAt;
  final String createdById;
  final String createdByName;
  final String amendmentReason;
  final List<String> changedFields;
  final Map<String, dynamic> snapshotData;
  final bool sentToReceivingTeam;
  final DateTime? sentAt;

  const EmergencyReferralVersion({
    this.versionId,
    required this.referralId,
    required this.versionNumber,
    required this.createdAt,
    required this.createdById,
    required this.createdByName,
    required this.amendmentReason,
    this.changedFields = const [],
    this.snapshotData = const {},
    this.sentToReceivingTeam = false,
    this.sentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'versionId': versionId,
      'referralId': referralId,
      'versionNumber': versionNumber,
      'createdAt': createdAt.toIso8601String(),
      'createdById': createdById,
      'createdByName': createdByName,
      'amendmentReason': amendmentReason,
      'changedFields': changedFields,
      'snapshotData': snapshotData,
      'sentToReceivingTeam': sentToReceivingTeam,
      'sentAt': sentAt?.toIso8601String(),
    };
  }

  factory EmergencyReferralVersion.fromMap(Map<String, dynamic> map) {
    List<String> fields = [];
    final rawFields = map['changedFields'] ?? map['changed_fields'];
    if (rawFields is List) {
      fields = rawFields.map((e) => e.toString()).toList();
    } else if (rawFields is String && rawFields.isNotEmpty) {
      try {
        final dec = jsonDecode(rawFields);
        if (dec is List) fields = dec.map((e) => e.toString()).toList();
      } catch (_) {
        fields = [rawFields];
      }
    }

    Map<String, dynamic> snap = {};
    final rawSnap = map['snapshotData'] ?? map['snapshot_data'];
    if (rawSnap is Map) {
      snap = Map<String, dynamic>.from(rawSnap);
    } else if (rawSnap is String && rawSnap.isNotEmpty) {
      try {
        snap = Map<String, dynamic>.from(jsonDecode(rawSnap) as Map);
      } catch (_) {}
    }

    final createdStr = map['createdAt'] ?? map['created_at'];
    final sentStr = map['sentAt'] ?? map['sent_at'];

    return EmergencyReferralVersion(
      versionId: (map['versionId'] ?? map['version_id']) as int?,
      referralId: (map['referralId'] ?? map['referral_id'] ?? '').toString(),
      versionNumber: (map['versionNumber'] ?? map['version_number'] ?? 1) as int,
      createdAt: createdStr != null ? DateTime.tryParse(createdStr.toString()) ?? DateTime.now() : DateTime.now(),
      createdById: (map['createdById'] ?? map['created_by_id'] ?? '').toString(),
      createdByName: (map['createdByName'] ?? map['created_by_name'] ?? '').toString(),
      amendmentReason: (map['amendmentReason'] ?? map['amendment_reason'] ?? '').toString(),
      changedFields: fields,
      snapshotData: snap,
      sentToReceivingTeam: (map['sentToReceivingTeam'] ?? map['sent_to_receiving_team'] ?? 0) == 1 ||
          (map['sentToReceivingTeam'] ?? map['sent_to_receiving_team']) == true,
      sentAt: sentStr != null ? DateTime.tryParse(sentStr.toString()) : null,
    );
  }
}

/// External notification delivery attempt (Email, Message, SMS).
class EmergencyDeliveryAttempt {
  final int? deliveryId;
  final String referralId;
  final int versionNumber;
  final String channel; // 'email', 'clinical_message', 'sms_alert', 'whatsapp_direct'
  final String recipientAddress;
  final String? recipientName;
  final String subjectOrPreview;
  final String messageBody;
  final String deliveryStatus;
  final String? providerMessageId;
  final String? errorMessage;
  final DateTime attemptedAt;
  final DateTime? deliveredAt;

  const EmergencyDeliveryAttempt({
    this.deliveryId,
    required this.referralId,
    this.versionNumber = 1,
    required this.channel,
    required this.recipientAddress,
    this.recipientName,
    required this.subjectOrPreview,
    required this.messageBody,
    required this.deliveryStatus,
    this.providerMessageId,
    this.errorMessage,
    required this.attemptedAt,
    this.deliveredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'deliveryId': deliveryId,
      'referralId': referralId,
      'versionNumber': versionNumber,
      'channel': channel,
      'recipientAddress': recipientAddress,
      'recipientName': recipientName,
      'subjectOrPreview': subjectOrPreview,
      'messageBody': messageBody,
      'deliveryStatus': deliveryStatus,
      'providerMessageId': providerMessageId,
      'errorMessage': errorMessage,
      'attemptedAt': attemptedAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
    };
  }

  factory EmergencyDeliveryAttempt.fromMap(Map<String, dynamic> map) {
    final attStr = map['attemptedAt'] ?? map['attempted_at'];
    final delStr = map['deliveredAt'] ?? map['delivered_at'];
    return EmergencyDeliveryAttempt(
      deliveryId: (map['deliveryId'] ?? map['delivery_id']) as int?,
      referralId: (map['referralId'] ?? map['referral_id'] ?? '').toString(),
      versionNumber: (map['versionNumber'] ?? map['version_number'] ?? 1) as int,
      channel: (map['channel'] ?? 'email').toString(),
      recipientAddress: (map['recipientAddress'] ?? map['recipient_address'] ?? '').toString(),
      recipientName: map['recipientName'] ?? map['recipient_name'],
      subjectOrPreview: (map['subjectOrPreview'] ?? map['subject_or_preview'] ?? '').toString(),
      messageBody: (map['messageBody'] ?? map['message_body'] ?? '').toString(),
      deliveryStatus: (map['deliveryStatus'] ?? map['delivery_status'] ?? 'sent_to_provider').toString(),
      providerMessageId: map['providerMessageId'] ?? map['provider_message_id'],
      errorMessage: map['errorMessage'] ?? map['error_message'],
      attemptedAt: attStr != null ? DateTime.tryParse(attStr.toString()) ?? DateTime.now() : DateTime.now(),
      deliveredAt: delStr != null ? DateTime.tryParse(delStr.toString()) : null,
    );
  }
}

/// Ambulance dispatch milestone record.
class AmbulanceDispatchRecord {
  final int? dispatchId;
  final String referralId;
  final String dispatchStatus;
  final String serviceType;
  final String? vehicleNumber;
  final String? driverContact;
  final String? paramedicContact;
  final DateTime dispatchedAt;
  final int? estimatedArrivalMinutes;
  final DateTime? actualArrivalAt;
  final String? notes;

  const AmbulanceDispatchRecord({
    this.dispatchId,
    required this.referralId,
    required this.dispatchStatus,
    this.serviceType = '108 EMTS',
    this.vehicleNumber,
    this.driverContact,
    this.paramedicContact,
    required this.dispatchedAt,
    this.estimatedArrivalMinutes,
    this.actualArrivalAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'dispatchId': dispatchId,
      'referralId': referralId,
      'dispatchStatus': dispatchStatus,
      'serviceType': serviceType,
      'vehicleNumber': vehicleNumber,
      'driverContact': driverContact,
      'paramedicContact': paramedicContact,
      'dispatchedAt': dispatchedAt.toIso8601String(),
      'estimatedArrivalMinutes': estimatedArrivalMinutes,
      'actualArrivalAt': actualArrivalAt?.toIso8601String(),
      'notes': notes,
    };
  }

  factory AmbulanceDispatchRecord.fromMap(Map<String, dynamic> map) {
    final dispStr = map['dispatchedAt'] ?? map['dispatched_at'];
    final actStr = map['actualArrivalAt'] ?? map['actual_arrival_at'];
    return AmbulanceDispatchRecord(
      dispatchId: (map['dispatchId'] ?? map['dispatch_id']) as int?,
      referralId: (map['referralId'] ?? map['referral_id'] ?? '').toString(),
      dispatchStatus: (map['dispatchStatus'] ?? map['dispatch_status'] ?? 'requested').toString(),
      serviceType: (map['serviceType'] ?? map['service_type'] ?? '108 EMTS').toString(),
      vehicleNumber: map['vehicleNumber'] ?? map['vehicle_number'],
      driverContact: map['driverContact'] ?? map['driver_contact'],
      paramedicContact: map['paramedicContact'] ?? map['paramedic_contact'],
      dispatchedAt: dispStr != null ? DateTime.tryParse(dispStr.toString()) ?? DateTime.now() : DateTime.now(),
      estimatedArrivalMinutes: (map['estimatedArrivalMinutes'] ?? map['estimated_arrival_minutes']) as int?,
      actualArrivalAt: actStr != null ? DateTime.tryParse(actStr.toString()) : null,
      notes: map['notes'],
    );
  }
}

/// Audit log entry for immutable tracking.
class EmergencyReferralAuditEntry {
  final int? logId;
  final String referralId;
  final String actorId;
  final String actorName;
  final String action;
  final String details;
  final DateTime timestamp;

  const EmergencyReferralAuditEntry({
    this.logId,
    required this.referralId,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'referralId': referralId,
      'actorId': actorId,
      'actorName': actorName,
      'action': action,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory EmergencyReferralAuditEntry.fromMap(Map<String, dynamic> map) {
    final tsStr = map['timestamp'];
    return EmergencyReferralAuditEntry(
      logId: (map['logId'] ?? map['log_id']) as int?,
      referralId: (map['referralId'] ?? map['referral_id'] ?? '').toString(),
      actorId: (map['actorId'] ?? map['actor_id'] ?? '').toString(),
      actorName: (map['actorName'] ?? map['actor_name'] ?? '').toString(),
      action: (map['action'] ?? '').toString(),
      details: (map['details'] ?? '').toString(),
      timestamp: tsStr != null ? DateTime.tryParse(tsStr.toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
