import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_referral.dart';
import '../models/hospital.dart';
import '../models/indore_hospital_dataset.dart';
import 'distance_service.dart';

/// Recommendation wrapper detailing capability, availability, and transit metrics.
class EmergencyHospitalRecommendation {
  final Hospital hospital;
  final bool meetsMandatoryCapability;
  final int capabilityScore;
  final int availabilityScore;
  final double distanceKm;
  final int estimatedTransitMinutes;
  final String matchRationale;
  final List<String> matchedCapabilities;
  final List<String> missingCapabilities;

  const EmergencyHospitalRecommendation({
    required this.hospital,
    required this.meetsMandatoryCapability,
    required this.capabilityScore,
    required this.availabilityScore,
    required this.distanceKm,
    required this.estimatedTransitMinutes,
    required this.matchRationale,
    required this.matchedCapabilities,
    required this.missingCapabilities,
  });
}

/// Service orchestrating emergency communications, multi-channel payload formatting,
/// telecom dialer triggers, and 3-pillar hierarchical hospital recommendations.
class EmergencyReferralService {
  static const HaversineDistanceService _distanceService = HaversineDistanceService();

  // ---------------------------------------------------------------------------
  // 1. FORMATTED CLINICAL COMMUNICATIONS
  // ---------------------------------------------------------------------------

  /// Standardized clinical email subject line with high-priority markers.
  static String formatEmailSubject(EmergencyReferral ref) {
    return 'URGENT EMERGENCY REFERRAL — [${ref.referralId}] — ${ref.patientDisplayLabel}';
  }

  /// Full structured emergency clinical email body.
  static String formatEmailBody(EmergencyReferral ref) {
    final buffer = StringBuffer();
    buffer.writeln('===============================================================');
    buffer.writeln('             URGENT EMERGENCY REFERRAL NOTIFICATION            ');
    buffer.writeln('===============================================================');
    buffer.writeln('Referral ID      : ${ref.referralId} (Version ${ref.currentVersion})');
    buffer.writeln('Created At       : ${ref.createdAt.toIso8601String()}');
    buffer.writeln('Clinical Urgency : CRITICAL EMERGENCY / IMMEDIATE TRIAGE');
    buffer.writeln('Emergency Type   : ${ref.emergencyCategory.label}');
    buffer.writeln('Target Department: ${ref.receivingDepartment}');
    buffer.writeln('');
    buffer.writeln('--- PATIENT DEMOGRAPHICS ---');
    buffer.writeln('Identifier / ID  : ${ref.patientIdentifier}');
    buffer.writeln('Patient Name     : ${ref.patientName ?? "Unknown / Unidentified"}');
    buffer.writeln('Age / Sex        : ${ref.patientAge != null ? "${ref.patientAge} yrs" : "Unknown"} / ${ref.patientSex ?? "Unknown"}');
    buffer.writeln('');
    buffer.writeln('--- PRESENTING COMPLAINT & SYMPTOMS ---');
    buffer.writeln('Chief Complaint  : ${ref.presentingComplaint}');
    if (ref.symptomOnsetTime != null && ref.symptomOnsetTime!.isNotEmpty) {
      buffer.writeln('Onset Time       : ${ref.symptomOnsetTime}');
    }
    if (ref.redFlagSymptoms.isNotEmpty) {
      buffer.writeln('Red Flags        : ${ref.redFlagSymptoms.join(", ")}');
    }
    buffer.writeln('');
    buffer.writeln('--- VITAL SIGNS & NEUROLOGICAL STATUS ---');
    buffer.writeln('Vitals Summary   : ${ref.formattedVitals}');
    buffer.writeln('Consciousness    : AVPU Scale = ${ref.consciousnessLevel}');
    buffer.writeln('');
    buffer.writeln('--- FIRST AID & CLINICAL HISTORY ---');
    buffer.writeln('Pre-hospital Care: ${ref.immediateTreatmentGiven ?? "None recorded / Ongoing stabilization"}');
    buffer.writeln('Known Allergies  : ${ref.allergies ?? "Unknown"}');
    buffer.writeln('Current Meds     : ${ref.medicationsHistory ?? "Unknown"}');
    if (ref.clinicalNotes != null && ref.clinicalNotes!.isNotEmpty) {
      buffer.writeln('Clinician Notes  : ${ref.clinicalNotes}');
    }
    buffer.writeln('');
    buffer.writeln('--- AMBULANCE LOGISTICS ---');
    buffer.writeln('Ambulance Status : ${ref.ambulanceStatus.label}');
    buffer.writeln('Service Type     : ${ref.ambulanceServiceType}');
    if (ref.ambulanceVehicleNumber != null) {
      buffer.writeln('Vehicle Reg No.  : ${ref.ambulanceVehicleNumber}');
    }
    if (ref.ambulanceEtaMinutes != null) {
      buffer.writeln('Estimated ETA    : ~${ref.ambulanceEtaMinutes} minutes');
    }
    buffer.writeln('');
    buffer.writeln('--- REFERRING SOURCE ---');
    buffer.writeln('Clinician        : ${ref.referringClinicianName} (${ref.referringClinicianId})');
    buffer.writeln('Facility         : ${ref.referringFacilityName}');
    buffer.writeln('Urgent Callback  : ${ref.referringCallbackPhone}');
    buffer.writeln('');
    buffer.writeln('--- RECEIVING DESTINATION ---');
    buffer.writeln('Destination      : ${ref.receivingFacilityName}');
    if (ref.intendedDoctorName != null) {
      buffer.writeln('Intended Doctor  : ${ref.intendedDoctorName}');
    }
    if (ref.recommendationOverrideReason != null) {
      buffer.writeln('Routing Override : ${ref.recommendationOverrideReason}');
    }
    buffer.writeln('');
    buffer.writeln('===============================================================');
    buffer.writeln('CONFIDENTIAL HEALTHCARE COMMUNICATION');
    buffer.writeln('Ambulance dispatch and patient care must never be delayed.');
    buffer.writeln('Direct confirmation link: http://localhost:8000/api/v1/emergency-referrals/${ref.referralId}');
    buffer.writeln('===============================================================');
    return buffer.toString();
  }

  /// Compact direct message format for in-app or chat consultation.
  static String formatClinicalMessage(EmergencyReferral ref) {
    return '🚨 *URGENT EMERGENCY REFERRAL* [${ref.referralId}]\n'
        '• *Patient:* ${ref.patientDisplayLabel} (${ref.patientAge != null ? "${ref.patientAge}y" : "Age ?"}, ${ref.patientSex ?? "Sex ?"})\n'
        '• *Condition:* ${ref.emergencyCategory.label}\n'
        '• *Chief Complaint:* ${ref.presentingComplaint}\n'
        '• *Vitals:* ${ref.formattedVitals}\n'
        '• *AVPU:* ${ref.consciousnessLevel}\n'
        '• *Ambulance:* ${ref.ambulanceStatus.label} (${ref.ambulanceServiceType})\n'
        '• *Destination:* ${ref.receivingFacilityName} - ${ref.receivingDepartment}\n'
        '• *Referring Doctor:* ${ref.referringClinicianName} (📞 ${ref.referringCallbackPhone})\n'
        '• *Version:* ${ref.currentVersion} | *Time:* ${ref.createdAt.hour.toString().padLeft(2, '0')}:${ref.createdAt.minute.toString().padLeft(2, '0')}';
  }

  /// Compact SMS alert suitable for 160-character cellular networks.
  static String formatSmsAlert(EmergencyReferral ref) {
    return '[URGENT ER] Ref:${ref.referralId} | Pt:${ref.patientDisplayLabel} | '
        'Dx:${ref.emergencyCategory.name} | Vitals:${ref.formattedVitals} | '
        'Amb:${ref.ambulanceStatus.key} | From:${ref.referringClinicianName} '
        '(${ref.referringCallbackPhone}) -> ${ref.receivingFacilityName}';
  }

  /// Handover completion clinical summary for shift logs.
  static String formatHandoverSummary(
    EmergencyReferral ref, {
    required String receivingDoctor,
    String? notes,
  }) {
    return 'CLINICAL HANDOVER COMPLETE\n'
        'Referral ID: ${ref.referralId}\n'
        'Patient: ${ref.patientDisplayLabel}\n'
        'Transferred From: ${ref.referringFacilityName} (${ref.referringClinicianName})\n'
        'Received By: $receivingDoctor at ${ref.receivingFacilityName}\n'
        'Handover Time: ${DateTime.now().toLocal()}\n'
        'Vitals at Transfer: ${ref.formattedVitals}\n'
        'Notes: ${notes ?? "Patient stabilized and handed over to emergency triage team."}';
  }

  // ---------------------------------------------------------------------------
  // 2. TELEPHONY & EXTERNAL URL LAUNCHERS
  // ---------------------------------------------------------------------------

  /// Initiates emergency call to 108 Emergency Medical Services.
  static Future<bool> launchAmbulanceCall() async {
    return launchPhoneCall('108');
  }

  /// Initiates emergency call to national emergency 112.
  static Future<bool> launchNationalEmergencyCall() async {
    return launchPhoneCall('112');
  }

  /// Initiates phone call to specific facility or physician.
  static Future<bool> launchPhoneCall(String rawPhone) async {
    final sanitized = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$sanitized');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Emergency phone dialer trigger error: $e');
    }
    return false;
  }

  /// Opens default email client with pre-populated urgent referral payload.
  static Future<bool> launchEmailClient({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: toEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Emergency email client launcher error: $e');
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // 3. THREE-PILLAR CLINICAL HIERARCHICAL RECOMMENDATION ALGORITHM
  // Priority 1: Technical & Infrastructural Capability
  // Priority 2: Current Bed & Service Availability
  // Priority 3: Travel Distance & Transit Time
  // ---------------------------------------------------------------------------

  /// Ranks facilities from the 45 preloaded healthcare facilities in Indore
  /// based on strict clinical triage rules.
  static List<EmergencyHospitalRecommendation> rankHospitalsForEmergency(
    EmergencyCategory category, {
    double userLat = 22.7196,
    double userLon = 75.8577,
  }) {
    final all = IndoreHospitalDataset.allFacilities;
    final results = <EmergencyHospitalRecommendation>[];

    for (final hospital in all) {
      final matchedCaps = <String>[];
      final missingCaps = <String>[];
      int capScore = 0;

      // 1. PRIORITY 1: Clinical Capability Matching
      switch (category) {
        case EmergencyCategory.stemiCardiac:
          _checkCapability(hospital, 'Cardiology', matchedCaps, missingCaps, weight: 35);
          _checkCapability(hospital, 'Cath Lab / Cardiac', matchedCaps, missingCaps, weight: 35, checkTags: true);
          _checkCapability(hospital, 'ICU', matchedCaps, missingCaps, weight: 15, checkTags: true);
          _checkCapability(hospital, 'Emergency Resuscitation & Triage', matchedCaps, missingCaps, weight: 15, checkCapabilities: true);
          break;

        case EmergencyCategory.acuteStroke:
          _checkCapability(hospital, 'Neurology', matchedCaps, missingCaps, weight: 35);
          _checkCapability(hospital, '16-Slice CT Scanner', matchedCaps, missingCaps, weight: 30, checkDiagnostics: true);
          _checkCapability(hospital, 'Emergency Resuscitation & Triage', matchedCaps, missingCaps, weight: 20, checkCapabilities: true);
          _checkCapability(hospital, 'ICU Mechanical Ventilation', matchedCaps, missingCaps, weight: 15, checkCapabilities: true);
          break;

        case EmergencyCategory.polytrauma:
          _checkCapability(hospital, 'Trauma Care', matchedCaps, missingCaps, weight: 35, checkTags: true);
          _checkCapability(hospital, '24/7 Blood Bank', matchedCaps, missingCaps, weight: 25, checkDiagnostics: true);
          _checkCapability(hospital, '16-Slice CT Scanner', matchedCaps, missingCaps, weight: 20, checkDiagnostics: true);
          _checkCapability(hospital, 'Emergency Resuscitation & Triage', matchedCaps, missingCaps, weight: 20, checkCapabilities: true);
          break;

        case EmergencyCategory.severeRespiratory:
          _checkCapability(hospital, 'Pulmonology', matchedCaps, missingCaps, weight: 35);
          _checkCapability(hospital, 'ICU Mechanical Ventilation', matchedCaps, missingCaps, weight: 35, checkCapabilities: true);
          _checkCapability(hospital, 'Emergency Resuscitation & Triage', matchedCaps, missingCaps, weight: 30, checkCapabilities: true);
          break;

        case EmergencyCategory.septicShock:
          _checkCapability(hospital, 'ICU Mechanical Ventilation', matchedCaps, missingCaps, weight: 40, checkCapabilities: true);
          _checkCapability(hospital, 'Pathology & Biochemistry Lab', matchedCaps, missingCaps, weight: 30, checkDiagnostics: true);
          _checkCapability(hospital, 'Emergency Resuscitation & Triage', matchedCaps, missingCaps, weight: 30, checkCapabilities: true);
          break;

        case EmergencyCategory.postpartumHemorrhage:
          _checkCapability(hospital, 'Obstetrics/gynaecology', matchedCaps, missingCaps, weight: 40, alternative: 'Gynaecology');
          _checkCapability(hospital, '24/7 Blood Bank', matchedCaps, missingCaps, weight: 30, checkDiagnostics: true);
          _checkCapability(hospital, 'Emergency Resuscitation & Triage', matchedCaps, missingCaps, weight: 30, checkCapabilities: true);
          break;

        case EmergencyCategory.pediatricEmergency:
          _checkCapability(hospital, 'Paediatrics', matchedCaps, missingCaps, weight: 45, checkTags: true);
          _checkCapability(hospital, 'Emergency Resuscitation & Triage', matchedCaps, missingCaps, weight: 30, checkCapabilities: true);
          _checkCapability(hospital, 'ICU', matchedCaps, missingCaps, weight: 25, checkTags: true);
          break;

        case EmergencyCategory.acuteAbdomen:
          _checkCapability(hospital, 'General surgery', matchedCaps, missingCaps, weight: 40);
          _checkCapability(hospital, '16-Slice CT Scanner', matchedCaps, missingCaps, weight: 30, checkDiagnostics: true);
          _checkCapability(hospital, 'Emergency Resuscitation & Triage', matchedCaps, missingCaps, weight: 30, checkCapabilities: true);
          break;

        case EmergencyCategory.generalEmergency:
          if (hospital.emergencyCare) matchedCaps.add('Emergency Care');
          if (hospital.icuAvailable) matchedCaps.add('ICU Availability');
          break;
      }

      // Compute capability score
      if (category == EmergencyCategory.generalEmergency) {
        capScore = hospital.emergencyCare ? (hospital.icuAvailable ? 95 : 75) : 20;
      } else {
        capScore = (matchedCaps.length * 100 ~/ (matchedCaps.length + missingCaps.length)).clamp(10, 100);
      }

      final meetsMandatory = hospital.emergencyCare &&
          (category == EmergencyCategory.generalEmergency || capScore >= 60);

      // 2. PRIORITY 2: Availability Score
      int availScore = 50;
      if (hospital.operatingStatus.toLowerCase() == 'operational') {
        availScore += 30;
      } else if (hospital.operatingStatus.toLowerCase().contains('divert')) {
        availScore -= 40;
      }
      if (hospital.icuAvailable) availScore += 10;
      if (hospital.bedAvailability > 10) availScore += 10;
      availScore = availScore.clamp(0, 100);

      // 3. PRIORITY 3: Travel Distance & Transit Duration
      final distKm = _distanceService.calculateDistanceKm(
        userLat,
        userLon,
        hospital.latitude,
        hospital.longitude,
      );
      final estMinutes = (distKm / 35.0 * 60.0).round().clamp(5, 180);

      // Rationale formulation
      final rationale = meetsMandatory
          ? 'Meets essential ${category.label} clinical capabilities ($capScore%), $availScore% capacity operational, ~${distKm.toStringAsFixed(1)} km transit.'
          : 'Lacks mandatory critical infrastructure for ${category.label}. Missing: ${missingCaps.take(2).join(", ")}.';

      results.add(
        EmergencyHospitalRecommendation(
          hospital: hospital,
          meetsMandatoryCapability: meetsMandatory,
          capabilityScore: capScore,
          availabilityScore: availScore,
          distanceKm: distKm,
          estimatedTransitMinutes: estMinutes,
          matchRationale: rationale,
          matchedCapabilities: matchedCaps,
          missingCapabilities: missingCaps,
        ),
      );
    }

    // Strict 3-pillar hierarchical sorting:
    // P1: Meets capability (compliant facilities MUST precede non-compliant)
    // P2: Availability score (operational facilities precede overcrowded/diverted)
    // P3: Travel distance (closest facilities first among equally capable)
    results.sort((a, b) {
      if (a.meetsMandatoryCapability != b.meetsMandatoryCapability) {
        return a.meetsMandatoryCapability ? -1 : 1;
      }
      if (a.meetsMandatoryCapability) {
        // Both capable: compare availability tier
        final availTierA = a.availabilityScore ~/ 20;
        final availTierB = b.availabilityScore ~/ 20;
        if (availTierA != availTierB) {
          return availTierB.compareTo(availTierA);
        }
        // Then sort by distance
        return a.distanceKm.compareTo(b.distanceKm);
      } else {
        // Neither meets mandatory: sort by capability score then distance
        if (a.capabilityScore != b.capabilityScore) {
          return b.capabilityScore.compareTo(a.capabilityScore);
        }
        return a.distanceKm.compareTo(b.distanceKm);
      }
    });

    return results;
  }

  static void _checkCapability(
    Hospital hospital,
    String requiredName,
    List<String> matched,
    List<String> missing, {
    int weight = 25,
    bool checkTags = false,
    bool checkDiagnostics = false,
    bool checkCapabilities = false,
    String? alternative,
  }) {
    final lowerReq = requiredName.toLowerCase();
    final lowerAlt = alternative?.toLowerCase();

    bool hasSpec = hospital.specialties.any(
      (s) => s.toLowerCase().contains(lowerReq) || (lowerAlt != null && s.toLowerCase().contains(lowerAlt)),
    );

    bool hasDiag = checkDiagnostics &&
        hospital.diagnosticFacilities.any((d) => d.toLowerCase().contains(lowerReq));

    bool hasCap = checkCapabilities &&
        hospital.treatmentCapabilities.any((c) => c.toLowerCase().contains(lowerReq));

    bool hasTag = checkTags &&
        hospital.tags.any((t) => t.toLowerCase().contains(lowerReq));

    if (hasSpec || hasDiag || hasCap || hasTag) {
      matched.add(requiredName);
    } else {
      missing.add(requiredName);
    }
  }
}
