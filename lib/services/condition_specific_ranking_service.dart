import '../models/enums.dart';
import '../models/hospital.dart';
import '../models/hospital_capability_profile.dart';
import '../models/patient.dart';
import 'distance_service.dart';

/// Structured description of the condition-specific priority sequence.
class PrioritizationConfiguration {
  final PatientConditionCategory category;
  final String priority1Name;
  final String priority1Description;
  final String priority2Name;
  final String priority2Description;
  final String priority3Name;
  final String priority3Description;
  final String priority4Name;
  final String priority4Description;
  final List<String> mandatoryCapabilities;

  const PrioritizationConfiguration({
    required this.category,
    required this.priority1Name,
    required this.priority1Description,
    required this.priority2Name,
    required this.priority2Description,
    required this.priority3Name,
    required this.priority3Description,
    required this.priority4Name,
    required this.priority4Description,
    required this.mandatoryCapabilities,
  });

  List<String> get priorityTitles => [
        '1. $priority1Name',
        '2. $priority2Name',
        '3. $priority3Name',
        '4. $priority4Name',
      ];

  String get summaryDescription =>
      'Priority 1: $priority1Name → Priority 2: $priority2Name → Priority 3: $priority3Name → Priority 4: $priority4Name';
}

/// Evaluation outcome for an individual priority level.
class PriorityEvaluationResult {
  final int priorityNumber;
  final String name;
  final String description;
  final bool satisfied;
  final double score; // 0.0 to 100.0 score within this priority criterion
  final String explanation;

  const PriorityEvaluationResult({
    required this.priorityNumber,
    required this.name,
    required this.description,
    required this.satisfied,
    required this.score,
    required this.explanation,
  });

  Map<String, dynamic> toMap() => {
        'priority': priorityNumber,
        'name': name,
        'satisfied': satisfied,
        'score': score,
        'explanation': explanation,
      };

  @override
  String toString() =>
      'Priority $priorityNumber ($name): score=${score.toStringAsFixed(1)}, satisfied=$satisfied';
}

/// Evaluation result for an eligible hospital under condition-specific ranking rules.
class ConditionRankingResult {
  final Hospital hospital;
  final PatientConditionCategory conditionCategory;
  final List<PriorityEvaluationResult> priorityEvaluations;
  final double compositeScore;
  final int rank;
  final double distanceKm;
  final Duration travelTime;
  final String travelTimeSource;
  final bool isSimulatedAvailability;
  final bool isVerifiedAvailability;
  final List<String> warnings;
  final String whyThisHospitalSummary;

  const ConditionRankingResult({
    required this.hospital,
    required this.conditionCategory,
    required this.priorityEvaluations,
    required this.compositeScore,
    required this.rank,
    required this.distanceKm,
    required this.travelTime,
    this.travelTimeSource = 'Estimated Road Transit (Standard Driving Speeds)',
    required this.isSimulatedAvailability,
    required this.isVerifiedAvailability,
    required this.warnings,
    required this.whyThisHospitalSummary,
  });

  PriorityEvaluationResult get priority1 => priorityEvaluations[0];
  PriorityEvaluationResult get priority2 => priorityEvaluations[1];
  PriorityEvaluationResult get priority3 => priorityEvaluations[2];
  PriorityEvaluationResult get priority4 => priorityEvaluations[3];

  @override
  String toString() =>
      'ConditionRankingResult(Rank $rank: "${hospital.name}", Score: ${compositeScore.toStringAsFixed(1)}, Travel: ${travelTime.inMinutes}m)';
}

/// Reason a hospital was excluded by mandatory capability hard filtering.
class ConditionExclusionResult {
  final Hospital hospital;
  final List<String> exclusionReasons;
  final double distanceKm;
  final Duration travelTime;

  const ConditionExclusionResult({
    required this.hospital,
    required this.exclusionReasons,
    required this.distanceKm,
    required this.travelTime,
  });

  String get primaryReason =>
      exclusionReasons.isNotEmpty ? exclusionReasons.first : 'Does not meet mandatory clinical requirements';

  @override
  String toString() =>
      'ConditionExclusionResult("${hospital.name}", Reasons: ${exclusionReasons.join("; ")})';
}

/// Complete output from the condition-specific hospital ranking engine.
class ConditionRecommendationResult {
  final PatientConditionCategory category;
  final PrioritizationConfiguration appliedConfiguration;
  final List<ConditionRankingResult> rankedEligibleHospitals;
  final List<ConditionExclusionResult> excludedHospitals;
  final List<String> missingCapabilities;
  final List<String> missingOrOutdatedWarnings;
  final DateTime evaluatedAt;
  final String escalationProtocol;

  const ConditionRecommendationResult({
    required this.category,
    required this.appliedConfiguration,
    required this.rankedEligibleHospitals,
    required this.excludedHospitals,
    required this.missingCapabilities,
    required this.missingOrOutdatedWarnings,
    required this.evaluatedAt,
    required this.escalationProtocol,
  });

  bool get hasSuitableHospital => rankedEligibleHospitals.isNotEmpty;
  ConditionRankingResult? get bestMatch =>
      rankedEligibleHospitals.isNotEmpty ? rankedEligibleHospitals.first : null;
  List<ConditionRankingResult> get alternatives =>
      rankedEligibleHospitals.length > 1 ? rankedEligibleHospitals.sublist(1) : const [];
}

/// Condition-Specific Hospital Ranking Engine.
///
/// Evaluates and prioritizes referral hospitals differently according to the patient's
/// confirmed condition category, enforcing strict tier-based (lexicographic) prioritization:
///
/// Priority 1 > Priority 2 > Priority 3 > Priority 4.
///
/// Low-priority criteria (such as short travel time or high bed vacancy) can NEVER
/// compensate for missing mandatory clinical capabilities.
class ConditionSpecificRankingService {
  final DistanceService distanceService;

  const ConditionSpecificRankingService({
    this.distanceService = const HaversineDistanceService(),
  });

  /// Factory configuration mapping for all 8 condition categories.
  static PrioritizationConfiguration getConfiguration(PatientConditionCategory category) {
    switch (category) {
      case PatientConditionCategory.criticalEmergency:
        return const PrioritizationConfiguration(
          category: PatientConditionCategory.criticalEmergency,
          priority1Name: 'Life-saving capability',
          priority1Description: '24/7 Emergency Resuscitation, Airway/Ventilation, and ICU Critical Care capability.',
          priority2Name: 'Immediate availability',
          priority2Description: 'Active operating status, open emergency department, and immediately available beds.',
          priority3Name: 'Travel time',
          priority3Description: 'Fastest estimated transit time to reach immediate life-saving care.',
          priority4Name: 'Required specialty',
          priority4Description: 'Matching specialized surgical or medical department.',
          mandatoryCapabilities: ['24/7 Emergency Care', 'ICU Critical Care'],
        );

      case PatientConditionCategory.suspectedCardiacEmergency:
        return const PrioritizationConfiguration(
          category: PatientConditionCategory.suspectedCardiacEmergency,
          priority1Name: 'Cardiac capability',
          priority1Description: 'Interventional Cardiology, 24/7 Cath Lab, Primary PCI, and Coronary Care.',
          priority2Name: 'Emergency & ICU availability',
          priority2Description: 'Emergency department actively open with available Cardiac ICU/CCU beds.',
          priority3Name: 'Travel time',
          priority3Description: 'Door-to-balloon reperfusion window transit time.',
          priority4Name: 'Capacity',
          priority4Description: 'Current bed vacancy and hospital occupancy headroom.',
          mandatoryCapabilities: ['Cardiology', '24/7 Emergency Care'],
        );

      case PatientConditionCategory.suspectedStroke:
        return const PrioritizationConfiguration(
          category: PatientConditionCategory.suspectedStroke,
          priority1Name: 'Stroke/neuro capability',
          priority1Description: 'Neurosurgery / Neurology team, rapid CT/MRI neuroimaging, and acute thrombolysis.',
          priority2Name: 'Time to treatment',
          priority2Description: 'Time to reach stroke center within the golden hour treatment window.',
          priority3Name: 'Availability',
          priority3Description: 'Operational facility with open emergency receiving and acute beds.',
          priority4Name: 'Travel time',
          priority4Description: 'Geographic proximity and road travel duration.',
          mandatoryCapabilities: ['Stroke / Neuro Care (CT / Neurosurgery)', '24/7 Emergency Care'],
        );

      case PatientConditionCategory.majorTrauma:
        return const PrioritizationConfiguration(
          category: PatientConditionCategory.majorTrauma,
          priority1Name: 'Trauma & operative capability',
          priority1Description: 'Polytrauma resuscitation, 24/7 Emergency OT, and Orthopedic/Trauma surgery.',
          priority2Name: 'Blood availability & ICU capability',
          priority2Description: 'Active Blood Component Bank and continuous ICU mechanical ventilator support.',
          priority3Name: 'Travel time',
          priority3Description: 'Rapid trauma transit duration.',
          priority4Name: 'Required specialty',
          priority4Description: 'Orthopedics, General Surgery, and Neurosurgical coverage.',
          mandatoryCapabilities: ['Trauma & Operative Care', 'Blood Bank', '24/7 Emergency Care'],
        );

      case PatientConditionCategory.obstetricEmergency:
        return const PrioritizationConfiguration(
          category: PatientConditionCategory.obstetricEmergency,
          priority1Name: 'Obstetric emergency capability',
          priority1Description: 'Comprehensive Emergency Obstetric Care (CEmONC) with 24/7 Emergency C-Section.',
          priority2Name: 'Blood bank, OT & ICU availability',
          priority2Description: 'Blood bank cross-matching, operational surgical OT, and obstetric ICU.',
          priority3Name: 'Travel time',
          priority3Description: 'Rapid maternal transit duration.',
          priority4Name: 'Capacity',
          priority4Description: 'Available maternal beds and low ward occupancy.',
          mandatoryCapabilities: ['Obstetrics & Gynecology (C-Section)', 'Blood Bank'],
        );

      case PatientConditionCategory.pediatricEmergency:
        return const PrioritizationConfiguration(
          category: PatientConditionCategory.pediatricEmergency,
          priority1Name: 'Pediatric emergency capability',
          priority1Description: 'Dedicated Pediatrics / Neonatology department and pediatric resuscitation.',
          priority2Name: 'Pediatric ICU availability',
          priority2Description: 'Dedicated Pediatric Intensive Care (PICU) / Neonatal ICU (NICU) beds.',
          priority3Name: 'Travel time',
          priority3Description: 'Rapid pediatric ambulance transit time.',
          priority4Name: 'Capacity',
          priority4Description: 'Pediatric ward bed availability and headroom.',
          mandatoryCapabilities: ['Pediatrics', '24/7 Emergency Care'],
        );

      case PatientConditionCategory.stableFracture:
        return const PrioritizationConfiguration(
          category: PatientConditionCategory.stableFracture,
          priority1Name: 'Orthopaedic capability',
          priority1Description: 'Orthopedic specialty with fracture reduction, fixation, and Digital X-Ray.',
          priority2Name: 'Overall availability',
          priority2Description: 'Active operational status with available admission beds.',
          priority3Name: 'Travel time',
          priority3Description: 'Standard transit duration.',
          priority4Name: 'Distance',
          priority4Description: 'Geographic proximity (km).',
          mandatoryCapabilities: ['Orthopedics / Fracture Care'],
        );

      case PatientConditionCategory.stableMedicalCase:
        return const PrioritizationConfiguration(
          category: PatientConditionCategory.stableMedicalCase,
          priority1Name: 'Required medical specialty',
          priority1Description: 'Hospital possesses the exact required medical specialty department.',
          priority2Name: 'Required diagnostic capability',
          priority2Description: 'On-site clinical laboratory, imaging, and pathology facilities.',
          priority3Name: 'Overall availability',
          priority3Description: 'Operational facility with bed vacancy and open outpatient desk.',
          priority4Name: 'Travel time',
          priority4Description: 'Comfortable transit duration.',
          mandatoryCapabilities: ['Required Medical Specialty'],
        );
    }
  }

  /// Evaluates all available hospitals for the patient and condition category.
  ConditionRecommendationResult rankHospitals({
    required Patient patient,
    required List<Hospital> availableHospitals,
    required double clinicLatitude,
    required double clinicLongitude,
    PatientConditionCategory? conditionCategory,
    String? targetSpecialty,
    Set<String>? requiredFacilities,
  }) {
    final category = conditionCategory ??
        patient.conditionCategory ??
        PatientConditionCategory.stableMedicalCase;

    final config = getConfiguration(category);
    final specialty = (targetSpecialty ?? patient.requiredSpecialty).trim();

    final eligibleCandidates = <ConditionRankingResult>[];
    final excludedHospitals = <ConditionExclusionResult>[];
    final missingCapabilitiesSet = <String>{};
    final globalWarnings = <String>[];

    final now = DateTime.now();

    for (final hospital in availableHospitals) {
      final distance = distanceService.calculateDistanceKm(
        clinicLatitude,
        clinicLongitude,
        hospital.latitude,
        hospital.longitude,
      );
      final travelTime = distanceService.estimateTravelTime(distance);
      final profile = hospital.effectiveCapabilityProfile;

      // =======================================================================
      // STEP 1: HARD FILTER — MANDATORY CLINICAL CAPABILITIES CHECK
      // A missing or unknown mandatory capability causes IMMEDIATE exclusion.
      // Low travel time or high capacity can NEVER compensate for a missing capability.
      // =======================================================================
      final exclusionReasons = <String>[];

      // 1. Operating Status Hard Filter
      final statusLower = hospital.operatingStatus.toLowerCase();
      if (statusLower == 'diverting') {
        exclusionReasons.add('Hospital operating status is Diverting (cannot accept acute emergency intake)');
      } else if (statusLower == 'closed' || statusLower == 'temporary closure') {
        exclusionReasons.add('Hospital is temporarily closed');
      } else if (hospital.bedAvailability <= 0) {
        exclusionReasons.add('Zero beds currently available in facility');
      }

      // 2. Condition-Specific Mandatory Capability Checks
      _evaluateMandatoryCapabilities(
        category: category,
        hospital: hospital,
        profile: profile,
        targetSpecialty: specialty,
        requiredFacilities: requiredFacilities,
        exclusionReasons: exclusionReasons,
        missingCapabilitiesSet: missingCapabilitiesSet,
      );

      // If excluded, register and proceed to next hospital
      if (exclusionReasons.isNotEmpty) {
        excludedHospitals.add(
          ConditionExclusionResult(
            hospital: hospital,
            exclusionReasons: exclusionReasons,
            distanceKm: distance,
            travelTime: travelTime,
          ),
        );
        continue;
      }

      // =======================================================================
      // STEP 2: CONDITION-SPECIFIC PRIORITY EVALUATION (Priorities 1 to 4)
      // =======================================================================
      final priorityEvaluations = _evaluatePriorities(
        category: category,
        config: config,
        hospital: hospital,
        profile: profile,
        targetSpecialty: specialty,
        travelTime: travelTime,
        distanceKm: distance,
        requiredFacilities: requiredFacilities,
      );

      // Warnings for data confidence and recency
      final hospitalWarnings = <String>[];
      final isSimulated = hospital.availability?.isSimulated ?? hospital.isSimulatedData;

      if (isSimulated) {
        hospitalWarnings.add(
          'Simulated availability data: Real-time bed status requires voice confirmation with hospital receiving desk before dispatch.',
        );
      }

      final minutesSinceUpdate = now.difference(hospital.availabilityLastUpdated).inMinutes;
      if (minutesSinceUpdate > 60) {
        hospitalWarnings.add(
          'Outdated capacity data: Last status update was $minutesSinceUpdate minutes ago.',
        );
      }

      // Calculate composite score (out of 100) reflecting priority weighting
      // Priority 1 (40%) + Priority 2 (30%) + Priority 3 (20%) + Priority 4 (10%) = 100%
      final p1Score = priorityEvaluations[0].score;
      final p2Score = priorityEvaluations[1].score;
      final p3Score = priorityEvaluations[2].score;
      final p4Score = priorityEvaluations[3].score;
      final compositeScore = ((p1Score * 0.40) + (p2Score * 0.30) + (p3Score * 0.20) + (p4Score * 0.10))
          .clamp(0.0, 100.0);

      final whySummary = _buildWhyThisHospitalSummary(config, priorityEvaluations);

      eligibleCandidates.add(
        ConditionRankingResult(
          hospital: hospital,
          conditionCategory: category,
          priorityEvaluations: priorityEvaluations,
          compositeScore: (compositeScore * 10).roundToDouble() / 10,
          rank: 0, // Assigned after sorting
          distanceKm: distance,
          travelTime: travelTime,
          isSimulatedAvailability: isSimulated,
          isVerifiedAvailability: !isSimulated,
          warnings: hospitalWarnings,
          whyThisHospitalSummary: whySummary,
        ),
      );
    }

    // =======================================================================
    // STEP 3: TIER-BASED (LEXICOGRAPHIC) SORTING
    // Strictly evaluates: Priority 1 > Priority 2 > Priority 3 > Priority 4 > Distance.
    // Lower priorities distinguish otherwise comparable hospitals.
    // =======================================================================
    eligibleCandidates.sort((a, b) => _compareHospitals(a, b));

    // Assign 1-indexed ranks
    final rankedHospitals = <ConditionRankingResult>[];
    for (var i = 0; i < eligibleCandidates.length; i++) {
      final c = eligibleCandidates[i];
      rankedHospitals.add(
        ConditionRankingResult(
          hospital: c.hospital,
          conditionCategory: c.conditionCategory,
          priorityEvaluations: c.priorityEvaluations,
          compositeScore: c.compositeScore,
          rank: i + 1,
          distanceKm: c.distanceKm,
          travelTime: c.travelTime,
          travelTimeSource: c.travelTimeSource,
          isSimulatedAvailability: c.isSimulatedAvailability,
          isVerifiedAvailability: c.isVerifiedAvailability,
          warnings: c.warnings,
          whyThisHospitalSummary: c.whyThisHospitalSummary,
        ),
      );
    }

    // Escalation advisory when no eligible hospital is found
    final escalationText = category.isEmergency
        ? 'No suitable hospital could be confirmed from available data. '
            'ACTION: Immediately contact State Emergency Operations Center (Ambulance 108/112) for regional diversion bypass. '
            'Notify Medical Officer In-Charge and prepare on-site resuscitation & continuous oxygen stabilization.'
        : 'No suitable hospital could be confirmed from available data. '
            'ACTION: Hold patient in observation ward and contact District Health Officer to arrange secondary specialty consult.';

    return ConditionRecommendationResult(
      category: category,
      appliedConfiguration: config,
      rankedEligibleHospitals: rankedHospitals,
      excludedHospitals: excludedHospitals,
      missingCapabilities: missingCapabilitiesSet.toList(),
      missingOrOutdatedWarnings: globalWarnings,
      evaluatedAt: now,
      escalationProtocol: escalationText,
    );
  }

  /// Lexicographic / tier-based comparator ensuring Priority 1 > Priority 2 > Priority 3 > Priority 4.
  static int _compareHospitals(ConditionRankingResult a, ConditionRankingResult b) {
    // 1. Compare Priority 1
    final p1Comp = _comparePriorityScores(a.priority1, b.priority1);
    if (p1Comp != 0) return p1Comp;

    // 2. Compare Priority 2
    final p2Comp = _comparePriorityScores(a.priority2, b.priority2);
    if (p2Comp != 0) return p2Comp;

    // 3. Compare Priority 3
    final p3Comp = _comparePriorityScores(a.priority3, b.priority3);
    if (p3Comp != 0) return p3Comp;

    // 4. Compare Priority 4
    final p4Comp = _comparePriorityScores(a.priority4, b.priority4);
    if (p4Comp != 0) return p4Comp;

    // Tie-breaker: Distance (shorter is better)
    final distComp = a.distanceKm.compareTo(b.distanceKm);
    if (distComp != 0) return distComp;

    return a.hospital.name.compareTo(b.hospital.name);
  }

  /// Compares two priority results. Difference threshold of 0.5 allows tie-breaking by subsequent priorities.
  static int _comparePriorityScores(PriorityEvaluationResult a, PriorityEvaluationResult b) {
    if (a.satisfied && !b.satisfied) return -1;
    if (!a.satisfied && b.satisfied) return 1;

    final diff = b.score - a.score;
    if (diff.abs() > 0.5) {
      return diff > 0 ? 1 : -1;
    }
    return 0; // Considered tied on this priority; delegate to next priority
  }

  void _evaluateMandatoryCapabilities({
    required PatientConditionCategory category,
    required Hospital hospital,
    required HospitalCapabilityProfile profile,
    required String targetSpecialty,
    required Set<String>? requiredFacilities,
    required List<String> exclusionReasons,
    required Set<String> missingCapabilitiesSet,
  }) {
    switch (category) {
      case PatientConditionCategory.criticalEmergency:
        if (!profile.lifeSavingEmergency.isConfirmed) {
          final reason = profile.lifeSavingEmergency.isUnknown
              ? 'Life-saving emergency capability is unknown/unverified'
              : 'Missing mandatory 24/7 Life-Saving & Emergency Resuscitation capability';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('24/7 Emergency Care');
        }
        if (!profile.icuAvailability.isConfirmed) {
          final reason = profile.icuAvailability.isUnknown
              ? 'ICU availability is unknown/unverified'
              : 'Missing mandatory ICU Critical Care capability';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('ICU Critical Care');
        }
        break;

      case PatientConditionCategory.suspectedCardiacEmergency:
        if (!profile.cardiacCapability.isConfirmed) {
          final reason = profile.cardiacCapability.isUnknown
              ? 'Cardiac specialty/Cath Lab capability is unknown/unverified'
              : 'Missing mandatory Cardiology / Acute Cardiac Care capability';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('Cardiology / Cath Lab');
        }
        if (!hospital.emergencyCare) {
          exclusionReasons.add('Missing 24/7 Emergency Department intake');
          missingCapabilitiesSet.add('24/7 Emergency Care');
        }
        break;

      case PatientConditionCategory.suspectedStroke:
        if (!profile.strokeNeuroCapability.isConfirmed) {
          final reason = profile.strokeNeuroCapability.isUnknown
              ? 'Stroke / Neuroimaging capability is unknown/unverified'
              : 'Missing mandatory Stroke / Neuro Care capability (CT Scanner or Neurosurgery)';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('Stroke Care / CT Neuroimaging');
        }
        if (!hospital.emergencyCare) {
          exclusionReasons.add('Missing 24/7 Emergency Care intake');
          missingCapabilitiesSet.add('24/7 Emergency Care');
        }
        break;

      case PatientConditionCategory.majorTrauma:
        if (!profile.traumaOperativeCapability.isConfirmed) {
          final reason = profile.traumaOperativeCapability.isUnknown
              ? 'Trauma & operative capability is unknown/unverified'
              : 'Missing mandatory Trauma Resuscitation & Emergency Operative capability';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('Trauma Resuscitation & Operative OT');
        }
        if (!profile.bloodBankAvailability.isConfirmed) {
          final reason = profile.bloodBankAvailability.isUnknown
              ? 'Blood Bank availability is unknown/unverified'
              : 'Missing mandatory 24/7 Blood Bank & transfusion capability';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('24/7 Blood Bank');
        }
        if (!hospital.emergencyCare) {
          exclusionReasons.add('Missing 24/7 Emergency Care intake');
          missingCapabilitiesSet.add('24/7 Emergency Care');
        }
        break;

      case PatientConditionCategory.obstetricEmergency:
        if (!profile.obstetricEmergencyCapability.isConfirmed) {
          final reason = profile.obstetricEmergencyCapability.isUnknown
              ? 'Obstetric emergency / C-Section capability is unknown/unverified'
              : 'Missing mandatory Obstetric Emergency capability (Emergency C-Section)';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('Obstetric Care (Emergency C-Section)');
        }
        if (!profile.bloodBankAvailability.isConfirmed) {
          final reason = profile.bloodBankAvailability.isUnknown
              ? 'Blood Bank availability is unknown/unverified'
              : 'Missing mandatory Blood Bank availability for obstetric hemorrhage';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('24/7 Blood Bank');
        }
        break;

      case PatientConditionCategory.pediatricEmergency:
        if (!profile.pediatricEmergencyCapability.isConfirmed) {
          final reason = profile.pediatricEmergencyCapability.isUnknown
              ? 'Pediatric emergency capability is unknown/unverified'
              : 'Missing mandatory Pediatrics emergency care capability';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('Pediatrics');
        }
        if (!hospital.emergencyCare) {
          exclusionReasons.add('Missing 24/7 Emergency Care intake');
          missingCapabilitiesSet.add('24/7 Emergency Care');
        }
        break;

      case PatientConditionCategory.stableFracture:
        if (!profile.orthopaedicCapability.isConfirmed) {
          final reason = profile.orthopaedicCapability.isUnknown
              ? 'Orthopaedic capability is unknown/unverified'
              : 'Missing mandatory Orthopaedics / Fracture Care capability';
          exclusionReasons.add(reason);
          missingCapabilitiesSet.add('Orthopaedics / Fracture Care');
        }
        break;

      case PatientConditionCategory.stableMedicalCase:
        final req = targetSpecialty.trim();
        final isGeneric = req.isEmpty || req.toLowerCase() == 'general medicine';
        if (!isGeneric && !hospital.hasSpecialty(req)) {
          exclusionReasons.add('Missing required medical specialty: $req');
          missingCapabilitiesSet.add(req);
        }
        break;
    }

    // Additional user-specified mandatory facilities
    if (requiredFacilities != null) {
      for (final fac in requiredFacilities) {
        if (!hospital.hasFacility(fac)) {
          exclusionReasons.add('Missing requested facility: $fac');
          missingCapabilitiesSet.add(fac);
        }
      }
    }
  }

  List<PriorityEvaluationResult> _evaluatePriorities({
    required PatientConditionCategory category,
    required PrioritizationConfiguration config,
    required Hospital hospital,
    required HospitalCapabilityProfile profile,
    required String targetSpecialty,
    required Duration travelTime,
    required double distanceKm,
    required Set<String>? requiredFacilities,
  }) {
    switch (category) {
      // -----------------------------------------------------------------------
      // A. Critical Emergency
      // Priority 1: Life-saving capability
      // Priority 2: Immediate availability
      // Priority 3: Travel time
      // Priority 4: Required specialty
      // -----------------------------------------------------------------------
      case PatientConditionCategory.criticalEmergency:
        final hasVentilator = hospital.hasFacility('ICU Mechanical Ventilation') || hospital.hasFacility('ventilator');
        final p1Score = (hospital.emergencyCare ? 50.0 : 0.0) +
            (profile.icuAvailability.isConfirmed ? 30.0 : 0.0) +
            (hasVentilator ? 20.0 : 0.0);
        final p1 = PriorityEvaluationResult(
          priorityNumber: 1,
          name: config.priority1Name,
          description: config.priority1Description,
          satisfied: profile.lifeSavingEmergency.isConfirmed && profile.icuAvailability.isConfirmed,
          score: p1Score,
          explanation: '24/7 Emergency Department active, ICU Critical Care confirmed${hasVentilator ? ', Mechanical Ventilator on-site' : ''}.',
        );

        final icuBeds = hospital.availability?.icuBedsAvailable ?? (hospital.icuAvailable ? 2 : 0);
        final ots = hospital.availability?.operatingTheatersAvailable ?? 1;
        final p2Score = (hospital.operatingStatus.toLowerCase() == 'operational' ? 40.0 : 20.0) +
            (icuBeds > 0 ? 30.0 : 0.0) +
            (ots > 0 ? 30.0 : 0.0);
        final p2 = PriorityEvaluationResult(
          priorityNumber: 2,
          name: config.priority2Name,
          description: config.priority2Description,
          satisfied: hospital.operatingStatus.toLowerCase() == 'operational' && icuBeds > 0,
          score: p2Score,
          explanation: '$icuBeds ICU bed(s) available, $ots surgical OT(s) functional, status ${hospital.operatingStatus}.',
        );

        final p3Score = _scoreTravelTime(travelTime);
        final p3 = PriorityEvaluationResult(
          priorityNumber: 3,
          name: config.priority3Name,
          description: config.priority3Description,
          satisfied: travelTime.inMinutes <= 60,
          score: p3Score,
          explanation: 'Estimated transit: ${travelTime.inMinutes} mins (~${distanceKm.toStringAsFixed(1)} km by Car).',
        );

        final hasSpec = targetSpecialty.isNotEmpty && hospital.hasSpecialty(targetSpecialty);
        final p4Score = hasSpec ? 100.0 : 60.0;
        final p4 = PriorityEvaluationResult(
          priorityNumber: 4,
          name: config.priority4Name,
          description: config.priority4Description,
          satisfied: hasSpec,
          score: p4Score,
          explanation: hasSpec
              ? 'Confirmed department of $targetSpecialty on-site.'
              : 'General emergency and resuscitation coverage active.',
        );

        return [p1, p2, p3, p4];

      // -----------------------------------------------------------------------
      // B. Suspected Cardiac Emergency
      // Priority 1: Cardiac capability
      // Priority 2: Emergency and ICU availability
      // Priority 3: Travel time
      // Priority 4: Capacity
      // -----------------------------------------------------------------------
      case PatientConditionCategory.suspectedCardiacEmergency:
        final hasCathLab = hospital.hasFacility('Cath Lab') || hospital.hasFacility('PCI');
        final hasEcho = hospital.hasFacility('Echocardiography');
        final p1Score = (hasCathLab ? 55.0 : 30.0) +
            (hospital.hasSpecialty('Cardiology') ? 30.0 : 0.0) +
            (hasEcho ? 15.0 : 0.0);
        final p1 = PriorityEvaluationResult(
          priorityNumber: 1,
          name: config.priority1Name,
          description: config.priority1Description,
          satisfied: profile.cardiacCapability.isConfirmed,
          score: p1Score,
          explanation: hasCathLab
              ? '24/7 Primary PCI Cath Lab and Interventional Cardiology team on-site.'
              : 'Clinical Cardiology department with cardiac stabilization facilities.',
        );

        final icuBeds = hospital.availability?.icuBedsAvailable ?? (hospital.icuAvailable ? 2 : 0);
        final p2Score = (hospital.emergencyCare ? 50.0 : 0.0) + (icuBeds > 0 ? 50.0 : 20.0);
        final p2 = PriorityEvaluationResult(
          priorityNumber: 2,
          name: config.priority2Name,
          description: config.priority2Description,
          satisfied: hospital.emergencyCare && icuBeds > 0,
          score: p2Score,
          explanation: 'Emergency resuscitation suite active with $icuBeds cardiac ICU/CCU bed(s) available.',
        );

        final p3Score = _scoreTravelTime(travelTime);
        final p3 = PriorityEvaluationResult(
          priorityNumber: 3,
          name: config.priority3Name,
          description: config.priority3Description,
          satisfied: travelTime.inMinutes <= 60,
          score: p3Score,
          explanation: 'Reperfusion transit duration: ${travelTime.inMinutes} mins (~${distanceKm.toStringAsFixed(1)} km by Car).',
        );

        final p4Score = _scoreCapacity(hospital);
        final p4 = PriorityEvaluationResult(
          priorityNumber: 4,
          name: config.priority4Name,
          description: config.priority4Description,
          satisfied: hospital.bedAvailability > 5,
          score: p4Score,
          explanation: '${hospital.bedAvailability} beds available (${((1.0 - hospital.currentCapacity) * 100).toInt()}% vacancy headroom).',
        );

        return [p1, p2, p3, p4];

      // -----------------------------------------------------------------------
      // C. Suspected Stroke
      // Priority 1: Stroke/neuro capability
      // Priority 2: Time to treatment
      // Priority 3: Availability
      // Priority 4: Travel time
      // -----------------------------------------------------------------------
      case PatientConditionCategory.suspectedStroke:
        final hasNeuroSurgery = hospital.hasSpecialty('Neurosurgery');
        final hasAdvancedCt = hospital.hasFacility('128-Slice CT') || hospital.hasFacility('3T MRI');
        final hasCt = hospital.hasFacility('CT') || hasAdvancedCt;
        final p1Score = (hasNeuroSurgery ? 50.0 : 25.0) +
            (hasAdvancedCt ? 35.0 : (hasCt ? 25.0 : 0.0)) +
            (hospital.hasFacility('Craniotomy') ? 15.0 : 0.0);
        final p1 = PriorityEvaluationResult(
          priorityNumber: 1,
          name: config.priority1Name,
          description: config.priority1Description,
          satisfied: profile.strokeNeuroCapability.isConfirmed,
          score: p1Score,
          explanation: hasNeuroSurgery
              ? 'Dedicated Neurosurgical emergency team with high-resolution neuroimaging on-site.'
              : 'Rapid stroke neuroimaging (CT Scanner) and stabilization confirmed.',
        );

        // Golden hour: time-to-treatment strictly weighted
        final p2Score = _scoreGoldenHour(travelTime);
        final p2 = PriorityEvaluationResult(
          priorityNumber: 2,
          name: config.priority2Name,
          description: config.priority2Description,
          satisfied: travelTime.inMinutes <= 45,
          score: p2Score,
          explanation: 'Golden hour transit window: ${travelTime.inMinutes} mins to neuro-intervention.',
        );

        final p3Score = (hospital.operatingStatus.toLowerCase() == 'operational' ? 60.0 : 30.0) +
            (hospital.emergencyCare ? 40.0 : 0.0);
        final p3 = PriorityEvaluationResult(
          priorityNumber: 3,
          name: config.priority3Name,
          description: config.priority3Description,
          satisfied: hospital.operatingStatus.toLowerCase() == 'operational',
          score: p3Score,
          explanation: 'Facility fully operational with open acute neuro-receiving intake.',
        );

        final p4Score = _scoreTravelTime(travelTime);
        final p4 = PriorityEvaluationResult(
          priorityNumber: 4,
          name: config.priority4Name,
          description: config.priority4Description,
          satisfied: true,
          score: p4Score,
          explanation: 'Travel distance: ${distanceKm.toStringAsFixed(1)} km (~${travelTime.inMinutes} mins by Car).',
        );

        return [p1, p2, p3, p4];

      // -----------------------------------------------------------------------
      // D. Major Trauma
      // Priority 1: Trauma and operative capability
      // Priority 2: Blood availability and ICU capability
      // Priority 3: Travel time
      // Priority 4: Required specialty
      // -----------------------------------------------------------------------
      case PatientConditionCategory.majorTrauma:
        final hasPolytrauma = hospital.hasFacility('Polytrauma Resuscitation');
        final hasOrthoFix = hospital.hasFacility('Orthopedic Fracture Fixation');
        final ots = hospital.availability?.operatingTheatersAvailable ?? 1;
        final p1Score = (hasPolytrauma ? 40.0 : 20.0) +
            (hasOrthoFix ? 30.0 : 15.0) +
            (ots >= 2 ? 30.0 : 15.0);
        final p1 = PriorityEvaluationResult(
          priorityNumber: 1,
          name: config.priority1Name,
          description: config.priority1Description,
          satisfied: profile.traumaOperativeCapability.isConfirmed,
          score: p1Score,
          explanation: 'Polytrauma resuscitation bay, $ots emergency OT(s), and trauma fracture fixation on-site.',
        );

        final hasCompBlood = hospital.hasFacility('Comprehensive Blood Component Bank');
        final hasBlood = hospital.hasFacility('Blood Bank') || hasCompBlood;
        final hasIcuVent = hospital.hasFacility('ICU Mechanical Ventilation') || hospital.icuAvailable;
        final p2Score = (hasCompBlood ? 50.0 : (hasBlood ? 35.0 : 0.0)) +
            (hasIcuVent ? 50.0 : 20.0);
        final p2 = PriorityEvaluationResult(
          priorityNumber: 2,
          name: config.priority2Name,
          description: config.priority2Description,
          satisfied: profile.bloodBankAvailability.isConfirmed && profile.icuAvailability.isConfirmed,
          score: p2Score,
          explanation: '${hasCompBlood ? 'Comprehensive component blood bank' : '24/7 blood bank'} and continuous mechanical ICU ventilation confirmed.',
        );

        final p3Score = _scoreTravelTime(travelTime);
        final p3 = PriorityEvaluationResult(
          priorityNumber: 3,
          name: config.priority3Name,
          description: config.priority3Description,
          satisfied: travelTime.inMinutes <= 60,
          score: p3Score,
          explanation: 'Trauma golden-period transit: ${travelTime.inMinutes} mins (~${distanceKm.toStringAsFixed(1)} km by Car).',
        );

        final hasOrtho = hospital.hasSpecialty('Orthopedics & Trauma Surgery') || hospital.hasSpecialty('Orthopedics');
        final hasSurg = hospital.hasSpecialty('General Surgery');
        final p4Score = (hasOrtho ? 50.0 : 20.0) + (hasSurg ? 50.0 : 20.0);
        final p4 = PriorityEvaluationResult(
          priorityNumber: 4,
          name: config.priority4Name,
          description: config.priority4Description,
          satisfied: hasOrtho || hasSurg,
          score: p4Score,
          explanation: 'Trauma surgical coverage: ${hospital.specialties.join(", ")}.',
        );

        return [p1, p2, p3, p4];

      // -----------------------------------------------------------------------
      // E. Obstetric Emergency
      // Priority 1: Obstetric emergency capability
      // Priority 2: Blood bank, operation theatre and ICU availability
      // Priority 3: Travel time
      // Priority 4: Capacity
      // -----------------------------------------------------------------------
      case PatientConditionCategory.obstetricEmergency:
        final hasCSection = hospital.hasFacility('Emergency Cesarean Section (C-Section)') ||
            hospital.hasFacility('c-section');
        final hasHighRisk = hospital.hasFacility('High-Risk Obstetric Surgery') ||
            hospital.hasFacility('Pre-eclampsia Protocol Care');
        final p1Score = (hospital.hasSpecialty('Obstetrics & Gynecology') ? 40.0 : 0.0) +
            (hasCSection ? 40.0 : 0.0) +
            (hasHighRisk ? 20.0 : 0.0);
        final p1 = PriorityEvaluationResult(
          priorityNumber: 1,
          name: config.priority1Name,
          description: config.priority1Description,
          satisfied: profile.obstetricEmergencyCapability.isConfirmed,
          score: p1Score,
          explanation: 'CEmONC service with 24/7 emergency C-Section and Obstetric surgical team active.',
        );

        final hasBlood = profile.bloodBankAvailability.isConfirmed;
        final ots = hospital.availability?.operatingTheatersAvailable ?? 1;
        final hasIcu = profile.icuAvailability.isConfirmed;
        final p2Score = (hasBlood ? 40.0 : 0.0) + (ots > 0 ? 30.0 : 0.0) + (hasIcu ? 30.0 : 0.0);
        final p2 = PriorityEvaluationResult(
          priorityNumber: 2,
          name: config.priority2Name,
          description: config.priority2Description,
          satisfied: hasBlood && ots > 0,
          score: p2Score,
          explanation: 'Blood bank cross-matching ready, $ots functional surgical OT(s), and ICU support on standby.',
        );

        final p3Score = _scoreTravelTime(travelTime);
        final p3 = PriorityEvaluationResult(
          priorityNumber: 3,
          name: config.priority3Name,
          description: config.priority3Description,
          satisfied: travelTime.inMinutes <= 60,
          score: p3Score,
          explanation: 'Maternal transit time: ${travelTime.inMinutes} mins (~${distanceKm.toStringAsFixed(1)} km by Car).',
        );

        final p4Score = _scoreCapacity(hospital);
        final p4 = PriorityEvaluationResult(
          priorityNumber: 4,
          name: config.priority4Name,
          description: config.priority4Description,
          satisfied: hospital.bedAvailability > 5,
          score: p4Score,
          explanation: '${hospital.bedAvailability} available beds (${((1.0 - hospital.currentCapacity) * 100).toInt()}% vacancy headroom).',
        );

        return [p1, p2, p3, p4];

      // -----------------------------------------------------------------------
      // F. Pediatric Emergency
      // Priority 1: Pediatric emergency capability
      // Priority 2: Pediatric ICU availability
      // Priority 3: Travel time
      // Priority 4: Capacity
      // -----------------------------------------------------------------------
      case PatientConditionCategory.pediatricEmergency:
        final hasPeds = hospital.hasSpecialty('Pediatrics');
        final hasNeo = hospital.hasSpecialty('Neonatology (NICU)') || hospital.hasSpecialty('Neonatology');
        final hasIncubator = hospital.hasFacility('Neonatal Resuscitation & Incubators');
        final p1Score = (hasPeds ? 50.0 : 0.0) + (hasNeo ? 30.0 : 15.0) + (hasIncubator ? 20.0 : 0.0);
        final p1 = PriorityEvaluationResult(
          priorityNumber: 1,
          name: config.priority1Name,
          description: config.priority1Description,
          satisfied: profile.pediatricEmergencyCapability.isConfirmed,
          score: p1Score,
          explanation: 'Specialized Pediatrics and Neonatal emergency resuscitation capabilities confirmed.',
        );

        final hasPicu = profile.pediatricIcuAvailability.isConfirmed;
        final p2Score = hasPicu ? 100.0 : (hospital.icuAvailable ? 60.0 : 20.0);
        final p2 = PriorityEvaluationResult(
          priorityNumber: 2,
          name: config.priority2Name,
          description: config.priority2Description,
          satisfied: hasPicu || hospital.icuAvailable,
          score: p2Score,
          explanation: hasPicu
              ? 'Dedicated Pediatric Intensive Care (PICU) / Neonatal NICU ventilator beds on-site.'
              : 'General ICU respiratory support available.',
        );

        final p3Score = _scoreTravelTime(travelTime);
        final p3 = PriorityEvaluationResult(
          priorityNumber: 3,
          name: config.priority3Name,
          description: config.priority3Description,
          satisfied: travelTime.inMinutes <= 60,
          score: p3Score,
          explanation: 'Pediatric transit duration: ${travelTime.inMinutes} mins (~${distanceKm.toStringAsFixed(1)} km by Car).',
        );

        final p4Score = _scoreCapacity(hospital);
        final p4 = PriorityEvaluationResult(
          priorityNumber: 4,
          name: config.priority4Name,
          description: config.priority4Description,
          satisfied: hospital.bedAvailability > 5,
          score: p4Score,
          explanation: '${hospital.bedAvailability} beds available with low ward congestion.',
        );

        return [p1, p2, p3, p4];

      // -----------------------------------------------------------------------
      // G. Stable Fracture
      // Priority 1: Orthopaedic capability
      // Priority 2: Overall availability
      // Priority 3: Travel time
      // Priority 4: Distance
      // -----------------------------------------------------------------------
      case PatientConditionCategory.stableFracture:
        final hasOrtho = hospital.hasSpecialty('Orthopedics & Trauma Surgery') || hospital.hasSpecialty('Orthopedics');
        final hasXray = hospital.hasFacility('Digital X-Ray') || hospital.hasFacility('X-Ray');
        final hasFixation = hospital.hasFacility('Orthopedic Fracture Fixation');
        final p1Score = (hasOrtho ? 50.0 : 0.0) + (hasXray ? 25.0 : 10.0) + (hasFixation ? 25.0 : 10.0);
        final p1 = PriorityEvaluationResult(
          priorityNumber: 1,
          name: config.priority1Name,
          description: config.priority1Description,
          satisfied: profile.orthopaedicCapability.isConfirmed,
          score: p1Score,
          explanation: 'Orthopedic surgical department with Digital X-Ray & fracture stabilization confirmed.',
        );

        final p2Score = _scoreCapacity(hospital);
        final p2 = PriorityEvaluationResult(
          priorityNumber: 2,
          name: config.priority2Name,
          description: config.priority2Description,
          satisfied: hospital.operatingStatus.toLowerCase() == 'operational' && hospital.bedAvailability > 0,
          score: p2Score,
          explanation: 'Fully operational status with ${hospital.bedAvailability} admission beds open.',
        );

        final p3Score = _scoreTravelTime(travelTime);
        final p3 = PriorityEvaluationResult(
          priorityNumber: 3,
          name: config.priority3Name,
          description: config.priority3Description,
          satisfied: true,
          score: p3Score,
          explanation: 'Road transit time: ${travelTime.inMinutes} mins by Car.',
        );

        final p4Score = _scoreDistance(distanceKm);
        final p4 = PriorityEvaluationResult(
          priorityNumber: 4,
          name: config.priority4Name,
          description: config.priority4Description,
          satisfied: true,
          score: p4Score,
          explanation: 'Geographic proximity: ${distanceKm.toStringAsFixed(1)} km.',
        );

        return [p1, p2, p3, p4];

      // -----------------------------------------------------------------------
      // H. Stable Medical Case
      // Priority 1: Required medical specialty
      // Priority 2: Required diagnostic capability
      // Priority 3: Overall availability
      // Priority 4: Travel time
      // -----------------------------------------------------------------------
      case PatientConditionCategory.stableMedicalCase:
        final hasTarget = targetSpecialty.isNotEmpty && hospital.hasSpecialty(targetSpecialty);
        final p1Score = hasTarget ? 100.0 : (hospital.hasSpecialty('General Medicine') ? 70.0 : 30.0);
        final p1 = PriorityEvaluationResult(
          priorityNumber: 1,
          name: config.priority1Name,
          description: config.priority1Description,
          satisfied: hasTarget || hospital.hasSpecialty('General Medicine'),
          score: p1Score,
          explanation: hasTarget
              ? 'Confirmed department of $targetSpecialty on-site.'
              : 'General Medicine and primary specialty coverage available.',
        );

        var matchDiag = 0;
        final targetDiags = requiredFacilities ?? {'Basic Clinical Lab'};
        for (final d in targetDiags) {
          if (hospital.hasFacility(d)) matchDiag++;
        }
        final p2Score = targetDiags.isEmpty ? 80.0 : ((matchDiag / targetDiags.length) * 100).clamp(0.0, 100.0);
        final p2 = PriorityEvaluationResult(
          priorityNumber: 2,
          name: config.priority2Name,
          description: config.priority2Description,
          satisfied: matchDiag > 0 || targetDiags.isEmpty,
          score: p2Score,
          explanation: 'On-site diagnostic facilities match clinical requirements ($matchDiag/${targetDiags.length} confirmed).',
        );

        final p3Score = _scoreCapacity(hospital);
        final p3 = PriorityEvaluationResult(
          priorityNumber: 3,
          name: config.priority3Name,
          description: config.priority3Description,
          satisfied: hospital.bedAvailability > 0,
          score: p3Score,
          explanation: 'Operational with ${hospital.bedAvailability} admission beds open.',
        );

        final p4Score = _scoreTravelTime(travelTime);
        final p4 = PriorityEvaluationResult(
          priorityNumber: 4,
          name: config.priority4Name,
          description: config.priority4Description,
          satisfied: true,
          score: p4Score,
          explanation: 'Transit time: ${travelTime.inMinutes} mins (~${distanceKm.toStringAsFixed(1)} km by Car).',
        );

        return [p1, p2, p3, p4];
    }
  }

  static double _scoreTravelTime(Duration duration) {
    final mins = duration.inMinutes;
    if (mins <= 20) return 100.0;
    if (mins <= 35) return 90.0;
    if (mins <= 50) return 75.0;
    if (mins <= 75) return 60.0;
    if (mins <= 100) return 40.0;
    return 20.0;
  }

  static double _scoreGoldenHour(Duration duration) {
    final mins = duration.inMinutes;
    if (mins <= 25) return 100.0;
    if (mins <= 40) return 85.0;
    if (mins <= 60) return 65.0;
    if (mins <= 90) return 40.0;
    return 15.0;
  }

  static double _scoreCapacity(Hospital hospital) {
    var score = 40.0;
    if (hospital.bedAvailability >= 30) {
      score += 30.0;
    } else if (hospital.bedAvailability >= 15) {
      score += 20.0;
    } else if (hospital.bedAvailability >= 5) {
      score += 10.0;
    }

    final vacancyRate = (1.0 - hospital.currentCapacity).clamp(0.0, 1.0);
    score += (vacancyRate * 30.0);

    return score.clamp(0.0, 100.0);
  }

  static double _scoreDistance(double km) {
    if (km <= 10) return 100.0;
    if (km <= 20) return 85.0;
    if (km <= 35) return 70.0;
    if (km <= 50) return 50.0;
    return 30.0;
  }

  static String _buildWhyThisHospitalSummary(
    PrioritizationConfiguration config,
    List<PriorityEvaluationResult> evaluations,
  ) {
    final buf = StringBuffer();
    buf.writeln('Prioritized for ${config.category.displayName}:');
    for (final e in evaluations) {
      buf.writeln('• Priority ${e.priorityNumber} (${e.name}): ${e.explanation}');
    }
    return buf.toString().trim();
  }
}
