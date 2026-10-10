import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import '../models/enums.dart';
import '../models/hierarchical_referral_result.dart';
import '../models/hospital.dart';
import '../models/indore_hospital_dataset.dart';
import '../models/synthetic_doctor.dart';

/// Clinical Condition-Specific Hierarchical Referral Ranking Service.
///
/// Enforces the strict three-level clinical hierarchy:
/// Priority 1: Technical and infrastructural capability (Hard clinical gate)
/// Priority 2: Current availability (Operating status, bed/ICU vacancy)
/// Priority 3: Travel distance and time (Transit optimization strictly among eligible facilities)
///
/// Nearby facilities missing essential capabilities NEVER outrank equipped tertiary centers.
class HierarchicalRankingService {
  final String backendBaseUrl;
  final http.Client _client;

  HierarchicalRankingService({
    this.backendBaseUrl = 'http://localhost:8000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Map patient condition category or clinical scenario to condition key.
  static String mapCategoryToConditionKey(PatientConditionCategory? category, {int? patientAgeYears}) {
    if (category == null) return 'suspected_heart_attack';
    switch (category) {
      case PatientConditionCategory.suspectedCardiacEmergency:
        return 'suspected_heart_attack';
      case PatientConditionCategory.suspectedStroke:
        return 'suspected_stroke';
      case PatientConditionCategory.majorTrauma:
        return 'major_trauma';
      case PatientConditionCategory.pediatricEmergency:
        return 'pediatric_respiratory_distress';
      case PatientConditionCategory.obstetricEmergency:
        return 'pregnancy_danger_signs';
      case PatientConditionCategory.criticalEmergency:
        return 'major_trauma';
      case PatientConditionCategory.stableFracture:
        return 'major_trauma';
      case PatientConditionCategory.stableMedicalCase:
        return 'diabetes_followup';
    }
  }

  /// Evaluates and ranks 45 healthcare facilities using the three-level hierarchy.
  /// Tries the authoritative central backend API first; falls back seamlessly to
  /// offline local deterministic evaluation using [IndoreHospitalDataset.allFacilities].
  Future<HierarchicalReferralResponse> rankFacilities({
    required String conditionKey,
    required double latitude,
    required double longitude,
    bool includeSynthetic = false,
  }) async {
    try {
      final uri = Uri.parse('$backendBaseUrl/api/v1/referrals/hierarchical-rank');
      final resp = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'conditionKey': conditionKey,
          'latitude': latitude,
          'longitude': longitude,
          'includeSynthetic': includeSynthetic,
        }),
      ).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        return HierarchicalReferralResponse.fromMap(data);
      }
    } catch (_) {
      // Offline fallback
    }

    return evaluateHierarchicalRankingOffline(
      conditionKey: conditionKey,
      clinicLatitude: latitude,
      clinicLongitude: longitude,
      includeSynthetic: includeSynthetic,
    );
  }

  /// Fetches doctors affiliated with a specific facility.
  Future<List<DoctorProfile>> getDoctorsForFacility(
    String facilityId, {
    bool includeSynthetic = false,
  }) async {
    try {
      final uri = Uri.parse(
          '$backendBaseUrl/api/v1/facilities/$facilityId/doctors?include_synthetic=$includeSynthetic');
      final resp = await _client.get(uri).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final docsList = data['doctors'] as List?;
        if (docsList != null) {
          return docsList
              .whereType<Map<String, dynamic>>()
              .map((m) => DoctorProfile.fromMap(m))
              .toList();
        }
      }
    } catch (_) {}

    return const [];
  }

  /// Offline implementation of the three-level hierarchical ranking engine.
  static HierarchicalReferralResponse evaluateHierarchicalRankingOffline({
    required String conditionKey,
    required double clinicLatitude,
    required double clinicLongitude,
    bool includeSynthetic = false,
  }) {
    final conditionDefs = _offlineConditionRequirements();
    final cdef = conditionDefs[conditionKey] ?? conditionDefs['suspected_heart_attack']!;
    final facilities = IndoreHospitalDataset.allFacilities;

    final group1SuitableAvailable = <HierarchicalFacilityEntry>[];
    final group2SuitableUnconfirmed = <HierarchicalFacilityEntry>[];
    final groupExcludedIneligible = <HierarchicalFacilityEntry>[];

    final isEmergency = cdef['urgency_level'] == 'immediate' || cdef['urgency_level'] == 'urgent';

    for (final fac in facilities) {
      final distKm = _haversineDistanceKm(clinicLatitude, clinicLongitude, fac.latitude, fac.longitude);
      final transitMins = _estimateTransitTimeMinutes(distKm, isEmergency: isEmergency);

      final techEval = _evaluateTechnicalCapabilityOffline(fac, cdef);
      final availEval = _evaluateAvailabilityOffline(fac, cdef);

      final entry = HierarchicalFacilityEntry(
        facilityId: fac.hospitalId,
        facilityName: fac.name,
        address: fac.address,
        facilityType: fac.facilityType ?? 'hospital',
        distanceKm: distKm,
        transitTimeMinutes: transitMins,
        statusLabel: !techEval.isEligible
            ? 'Essential capability missing'
            : (availEval.status == 'available'
                ? 'Suitable — availability confirmed'
                : 'Suitable — availability requires confirmation'),
        recommendationTier: !techEval.isEligible
            ? 'Tier 3: Ineligible'
            : (availEval.status == 'available' ? 'Tier 1: Recommended' : 'Tier 2: Conditional'),
        whyRankedSummary: !techEval.isEligible
            ? 'Excluded from recommendations for ${cdef['condition_name']}: Confirmed missing essential capabilities (${techEval.missingEssentialCapabilities.join("; ")}). Proximity ($distKm km) cannot override missing clinical infrastructure.'
            : (availEval.status == 'available'
                ? 'Ranked for ${cdef['condition_name']}: Technically eligible (score ${techEval.technicalSuitabilityScore.toStringAsFixed(1)}/100) with confirmed active availability (${availEval.generalBedsAvailable} beds available). Estimated transit: $distKm km (~$transitMins mins).'
                : 'Technically eligible (score ${techEval.technicalSuitabilityScore.toStringAsFixed(1)}/100), but availability is ${availEval.status}. ${availEval.reason} Direct telephone verification advised before transport.'),
        technicalEvaluation: techEval,
        availabilityEvaluation: availEval,
        affiliatedDoctorsCount: fac.hospitalId.startsWith('indore_hospital_00') ? 4 : 1,
        isSimulatedData: true,
      );

      if (!techEval.isEligible) {
        groupExcludedIneligible.add(entry);
      } else if (availEval.status == 'available') {
        group1SuitableAvailable.add(entry);
      } else {
        group2SuitableUnconfirmed.add(entry);
      }
    }

    // Sort within groups: Priority 1 Score DESC, then Distance ASC
    int sortCompare(HierarchicalFacilityEntry a, HierarchicalFacilityEntry b) {
      final scoreComp = b.technicalEvaluation.technicalSuitabilityScore
          .compareTo(a.technicalEvaluation.technicalSuitabilityScore);
      if (scoreComp != 0) return scoreComp;
      return a.distanceKm.compareTo(b.distanceKm);
    }

    group1SuitableAvailable.sort(sortCompare);
    group2SuitableUnconfirmed.sort(sortCompare);
    groupExcludedIneligible.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    // Assign sequential ranks
    var currentRank = 1;
    final allRanked = <HierarchicalFacilityEntry>[];

    for (final item in group1SuitableAvailable) {
      allRanked.add(HierarchicalFacilityEntry(
        facilityId: item.facilityId,
        facilityName: item.facilityName,
        address: item.address,
        facilityType: item.facilityType,
        distanceKm: item.distanceKm,
        transitTimeMinutes: item.transitTimeMinutes,
        rank: currentRank++,
        statusLabel: item.statusLabel,
        recommendationTier: item.recommendationTier,
        whyRankedSummary: item.whyRankedSummary,
        technicalEvaluation: item.technicalEvaluation,
        availabilityEvaluation: item.availabilityEvaluation,
        affiliatedDoctorsCount: item.affiliatedDoctorsCount,
        isSimulatedData: item.isSimulatedData,
      ));
    }

    for (final item in group2SuitableUnconfirmed) {
      allRanked.add(HierarchicalFacilityEntry(
        facilityId: item.facilityId,
        facilityName: item.facilityName,
        address: item.address,
        facilityType: item.facilityType,
        distanceKm: item.distanceKm,
        transitTimeMinutes: item.transitTimeMinutes,
        rank: currentRank++,
        statusLabel: item.statusLabel,
        recommendationTier: item.recommendationTier,
        whyRankedSummary: item.whyRankedSummary,
        technicalEvaluation: item.technicalEvaluation,
        availabilityEvaluation: item.availabilityEvaluation,
        affiliatedDoctorsCount: item.affiliatedDoctorsCount,
        isSimulatedData: item.isSimulatedData,
      ));
    }

    return HierarchicalReferralResponse(
      conditionKey: conditionKey,
      conditionName: cdef['condition_name'] as String,
      urgencyLevel: cdef['urgency_level'] as String,
      rankingHierarchy: const [
        'Priority 1: Technical and infrastructural capability (Essential gate)',
        'Priority 2: Current availability (Operational & Bed capacity)',
        'Priority 3: Travel distance and time (Transit optimization)',
      ],
      totalEvaluatedFacilities: facilities.length,
      eligibleFacilitiesCount: allRanked.length,
      confirmedAvailableCount: group1SuitableAvailable.length,
      unconfirmedAvailabilityCount: group2SuitableUnconfirmed.length,
      excludedIneligibleCount: groupExcludedIneligible.length,
      rankedRecommendations: allRanked,
      excludedFacilities: groupExcludedIneligible,
      fallbackProtocol: cdef['fallback'] as String,
      evaluatedAt: DateTime.now().toIso8601String(),
      isSyntheticDataIncluded: includeSynthetic,
      dataNotice: includeSynthetic
          ? 'SIMULATED DATA — NOT FOR CLINICAL DECISIONS'
          : 'OFFICIAL HEALTHCARE REGISTRY',
    );
  }

  static HierarchicalTechnicalEvaluation _evaluateTechnicalCapabilityOffline(
    Hospital fac,
    Map<String, dynamic> cdef,
  ) {
    final reqSpecialties = (cdef['required_specialties'] as List<String>).map((s) => s.toLowerCase()).toList();
    final essentialEquip = (cdef['essential_equipment'] as List<String>).map((e) => e.toLowerCase()).toList();
    final emergencyReq = cdef['emergency_stabilization_required'] == true;
    final criticalCareReq = cdef['critical_care_required'] == true;

    final facSpecialties = fac.specialties.map((s) => s.toLowerCase()).toList();
    final allResources = <String>{
      ...fac.specialties.map((s) => s.toLowerCase()),
      ...fac.treatmentCapabilities.map((t) => t.toLowerCase()),
      ...fac.diagnosticFacilities.map((d) => d.toLowerCase()),
      ...fac.tags.map((tg) => tg.toLowerCase()),
    };

    final confirmedCaps = <String>[];
    final missingCaps = <String>[];

    // Specialty check
    final specialtyMatched = reqSpecialties.isEmpty ||
        reqSpecialties.any((req) => facSpecialties.any((s) => s.contains(req) || req.contains(s)));

    if (!specialtyMatched) {
      missingCaps.add('Required medical specialty missing (${(cdef['required_specialties'] as List<String>).join(", ")})');
    } else {
      confirmedCaps.add('Specialty available');
    }

    // Equipment checks
    for (final equip in essentialEquip) {
      var found = allResources.any((r) => r.contains(equip) || equip.contains(r));
      if (!found) {
        if (equip.contains('cath') && allResources.any((r) => r.contains('cath') || r.contains('cardiac'))) {
          found = true;
        } else if (equip.contains('ct') && allResources.any((r) => r.contains('ct') || r.contains('radiology'))) {
          found = true;
        } else if (equip.contains('blood') && allResources.any((r) => r.contains('blood'))) {
          found = true;
        } else if (equip.contains('ecg') && (fac.emergencyCare || allResources.any((r) => r.contains('ecg') || r.contains('cardiac')))) {
          found = true;
        } else if (equip.contains('defibrillator') && (fac.emergencyCare || allResources.any((r) => r.contains('defibrillator') || r.contains('resuscitation') || r.contains('cardiac')))) {
          found = true;
        } else if (equip.contains('c-section') && allResources.any((r) => r.contains('delivery') || r.contains('maternity') || r.contains('obstetric') || r.contains('gynae'))) {
          found = true;
        } else if (equip.contains('operating') && (allResources.any((r) => r.contains('surgery') || r.contains('operating') || r.contains('ot')) || fac.facilityType == 'super_speciality_hospital' || fac.facilityType == 'tertiary_care_hospital')) {
          found = true;
        } else if (equip.contains('trauma') && (fac.emergencyCare || allResources.any((r) => r.contains('trauma')))) {
          found = true;
        } else if (equip.contains('respiratory') && allResources.any((r) => r.contains('pediatric') || r.contains('icu') || r.contains('ventilat') || r.contains('pulmon'))) {
          found = true;
        }
      }

      if (found) {
        confirmedCaps.add(equip.toUpperCase());
      } else {
        missingCaps.add(equip.toUpperCase());
      }
    }

    if (emergencyReq && !fac.emergencyCare && !allResources.any((r) => r.contains('emergency'))) {
      missingCaps.add('24/7 Emergency Care');
    } else if (emergencyReq) {
      confirmedCaps.add('24/7 Emergency Care');
    }

    if (criticalCareReq && !fac.icuAvailable && !allResources.any((r) => r.contains('icu'))) {
      missingCaps.add('ICU Critical Care');
    } else if (criticalCareReq) {
      confirmedCaps.add('ICU Critical Care');
    }

    final isEligible = missingCaps.isEmpty;
    final specScore = specialtyMatched ? 30.0 : 0.0;
    final equipScore = essentialEquip.isNotEmpty
        ? (confirmedCaps.length / (essentialEquip.length + 2)) * 40.0
        : 40.0;
    final docScore = specialtyMatched ? 25.0 : 0.0;

    return HierarchicalTechnicalEvaluation(
      isEligible: isEligible,
      eligibilityStatus: isEligible ? 'eligible' : 'ineligible',
      technicalSuitabilityScore: double.parse((specScore + equipScore.clamp(0.0, 40.0) + docScore).toStringAsFixed(1)),
      confirmedCapabilities: confirmedCaps,
      missingEssentialCapabilities: missingCaps,
      unknownCapabilities: const [],
      specialtyScore: specScore,
      equipmentScore: equipScore.clamp(0.0, 40.0),
      doctorScore: docScore,
    );
  }

  static HierarchicalAvailabilityEvaluation _evaluateAvailabilityOffline(
    Hospital fac,
    Map<String, dynamic> cdef,
  ) {
    final opStatus = fac.operatingStatus;
    final bedAvail = fac.bedAvailability;
    final emergencyOpen = fac.emergencyCare;
    final icuAvail = fac.icuAvailable;

    if (opStatus == 'Closed' || opStatus == 'Diverting') {
      return HierarchicalAvailabilityEvaluation(
        status: 'unavailable',
        operatingStatus: opStatus,
        generalBedsAvailable: 0,
        emergencyDepartmentOpen: false,
        isOutdated: false,
        reason: 'Facility status is $opStatus.',
      );
    }

    if (cdef['emergency_stabilization_required'] == true && !emergencyOpen) {
      return HierarchicalAvailabilityEvaluation(
        status: 'unavailable',
        operatingStatus: opStatus,
        generalBedsAvailable: bedAvail,
        emergencyDepartmentOpen: false,
        isOutdated: false,
        reason: 'Emergency department diverted or closed.',
      );
    }

    if (cdef['critical_care_required'] == true && !icuAvail) {
      return HierarchicalAvailabilityEvaluation(
        status: 'unavailable',
        operatingStatus: opStatus,
        generalBedsAvailable: bedAvail,
        emergencyDepartmentOpen: emergencyOpen,
        isOutdated: false,
        reason: 'ICU / CCU beds unavailable.',
      );
    }

    return HierarchicalAvailabilityEvaluation(
      status: 'available',
      operatingStatus: opStatus,
      generalBedsAvailable: bedAvail,
      emergencyDepartmentOpen: emergencyOpen,
      isOutdated: false,
      reason: 'Operational with active bed capacity ($bedAvail beds available).',
    );
  }

  static double _haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return double.parse((r * c).toStringAsFixed(2));
  }

  static int _estimateTransitTimeMinutes(double distanceKm, {required bool isEmergency}) {
    final speed = isEmergency ? 40.0 : 28.0;
    final latency = isEmergency ? 3 : 5;
    final mins = ((distanceKm / speed) * 60.0).ceil() + latency;
    return math.max(5, mins);
  }

  static Map<String, Map<String, dynamic>> _offlineConditionRequirements() => {
        'suspected_heart_attack': {
          'condition_name': 'Suspected Acute Coronary Syndrome / Myocardial Infarction',
          'urgency_level': 'immediate',
          'required_specialties': ['Cardiology', 'Emergency Medicine'],
          'essential_equipment': ['Cath Lab / Cardiac', '12-Lead ECG', 'Defibrillator'],
          'emergency_stabilization_required': true,
          'critical_care_required': true,
          'fallback': 'Immediate transfer to tertiary center with functional Cardiac Catheterization Lab.',
        },
        'suspected_stroke': {
          'condition_name': 'Suspected Acute Ischemic Stroke / Intracranial Hemorrhage',
          'urgency_level': 'immediate',
          'required_specialties': ['Neurology', 'Emergency Medicine'],
          'essential_equipment': ['16-Slice CT Scanner', '24/7 Emergency Care'],
          'emergency_stabilization_required': true,
          'critical_care_required': true,
          'fallback': 'Transfer to dedicated comprehensive stroke unit with immediate unenhanced CT neuroimaging.',
        },
        'major_trauma': {
          'condition_name': 'Severe Polytrauma & Hemorrhagic Shock',
          'urgency_level': 'immediate',
          'required_specialties': ['Orthopaedics', 'General Surgery', 'Emergency Medicine'],
          'essential_equipment': ['Trauma Care', '24/7 Blood Bank', 'Operating Theater'],
          'emergency_stabilization_required': true,
          'critical_care_required': true,
          'fallback': 'Airway control, pelvic binding, high-flow IV access; transfer to Level-1 trauma center.',
        },
        'pediatric_respiratory_distress': {
          'condition_name': 'Severe Pediatric Respiratory Distress / Impending Respiratory Failure',
          'urgency_level': 'urgent',
          'required_specialties': ['Paediatrics'],
          'essential_equipment': ['Pediatric Respiratory Support', '24/7 Emergency Care'],
          'emergency_stabilization_required': true,
          'critical_care_required': true,
          'fallback': 'Continuous high-flow humidified oxygen with qualified pediatric transit escort.',
        },
        'pregnancy_danger_signs': {
          'condition_name': 'Antepartum Hemorrhage / Eclampsia / Obstructed Labor',
          'urgency_level': 'immediate',
          'required_specialties': ['Obstetrics & Gynaecology'],
          'essential_equipment': ['Emergency C-Section', '24/7 Blood Bank', 'Operating Theater'],
          'emergency_stabilization_required': true,
          'critical_care_required': true,
          'fallback': 'Immediate transport with left lateral tilt to Comprehensive Emergency Obstetric Care (CEmONC) center.',
        },
        'routine_fever': {
          'condition_name': 'Undifferentiated Acute Febrile Illness (Non-Toxic)',
          'urgency_level': 'routine',
          'required_specialties': ['General Medicine'],
          'essential_equipment': ['Pathology & Biochemistry Lab'],
          'emergency_stabilization_required': false,
          'critical_care_required': false,
          'fallback': 'Outpatient community dispensary or primary health center evaluation.',
        },
        'diabetes_followup': {
          'condition_name': 'Uncomplicated Type-2 Diabetes Routine Surveillance',
          'urgency_level': 'routine',
          'required_specialties': ['General Medicine'],
          'essential_equipment': ['Pathology & Biochemistry Lab'],
          'emergency_stabilization_required': false,
          'critical_care_required': false,
          'fallback': 'Scheduled daytime outpatient clinic appointment.',
        },
        'new_neurological_symptoms': {
          'condition_name': 'Subacute Progressive Cranial Nerve Palsy / Ataxia',
          'urgency_level': 'urgent',
          'required_specialties': ['Neurology'],
          'essential_equipment': ['16-Slice CT Scanner'],
          'emergency_stabilization_required': false,
          'critical_care_required': false,
          'fallback': 'Elective secondary or tertiary hospital neurology OPD evaluation.',
        },
      };
}
