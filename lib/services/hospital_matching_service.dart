import '../models/enums.dart';
import '../models/hospital.dart';
import '../models/patient.dart';
import 'assessment_service.dart';
import 'condition_specific_ranking_service.dart';
import 'distance_service.dart';

/// Configurable weights for clinical hospital suitability scoring.
/// Medical capability (35%) + Specialty match (20%) + Emergency/ICU (15%) +
/// Availability (15%) + Travel time (10%) + Distance (5%) = 100%.
class MatchingWeights {
  final double medicalCapability; // Default: 0.35 (35%)
  final double specialtyMatch;    // Default: 0.20 (20%)
  final double emergencyIcu;       // Default: 0.15 (15%)
  final double availability;       // Default: 0.15 (15%)
  final double travelTime;        // Default: 0.10 (10%)
  final double distance;          // Default: 0.05 (5%)

  const MatchingWeights({
    this.medicalCapability = 0.35,
    this.specialtyMatch = 0.20,
    this.emergencyIcu = 0.15,
    this.availability = 0.15,
    this.travelTime = 0.10,
    this.distance = 0.05,
  }) : assert(
          (medicalCapability +
                  specialtyMatch +
                  emergencyIcu +
                  availability +
                  travelTime +
                  distance -
                  1.0) <
              0.001,
          'Matching weights must sum to 1.0 (100%)',
        );

  /// Preset weights customized for extreme trauma / immediate life threats.
  factory MatchingWeights.emergencyFocused() {
    return const MatchingWeights(
      medicalCapability: 0.30,
      specialtyMatch: 0.15,
      emergencyIcu: 0.25,
      availability: 0.15,
      travelTime: 0.10,
      distance: 0.05,
    );
  }

  /// Preset weights for routine transfers where bed comfort and distance matter more.
  factory MatchingWeights.routineFocused() {
    return const MatchingWeights(
      medicalCapability: 0.30,
      specialtyMatch: 0.20,
      emergencyIcu: 0.05,
      availability: 0.25,
      travelTime: 0.10,
      distance: 0.10,
    );
  }
}

/// Detailed score breakdown showing exact contribution of each criterion to the final match score.
class ScoreBreakdown {
  final double medicalCapabilityScore; // Component weighted out of 35
  final double specialtyMatchScore;    // Component weighted out of 20
  final double emergencyIcuScore;       // Component weighted out of 15
  final double availabilityScore;       // Component weighted out of 15
  final double travelTimeScore;        // Component weighted out of 10
  final double distanceScore;          // Component weighted out of 5
  final double totalScore;              // 0.0 to 100.0

  // Raw component scores (0.0 to 100.0) before applying weights
  final double rawMedicalCapability;
  final double rawSpecialtyMatch;
  final double rawEmergencyIcu;
  final double rawAvailability;
  final double rawTravelTime;
  final double rawDistance;

  const ScoreBreakdown({
    required this.medicalCapabilityScore,
    required this.specialtyMatchScore,
    required this.emergencyIcuScore,
    required this.availabilityScore,
    required this.travelTimeScore,
    required this.distanceScore,
    required this.totalScore,
    required this.rawMedicalCapability,
    required this.rawSpecialtyMatch,
    required this.rawEmergencyIcu,
    required this.rawAvailability,
    required this.rawTravelTime,
    required this.rawDistance,
  });

  Map<String, dynamic> toMap() => {
        'totalScore': totalScore,
        'medicalCapability': {
          'weighted': medicalCapabilityScore,
          'raw': rawMedicalCapability,
        },
        'specialtyMatch': {
          'weighted': specialtyMatchScore,
          'raw': rawSpecialtyMatch,
        },
        'emergencyIcu': {
          'weighted': emergencyIcuScore,
          'raw': rawEmergencyIcu,
        },
        'availability': {
          'weighted': availabilityScore,
          'raw': rawAvailability,
        },
        'travelTime': {
          'weighted': travelTimeScore,
          'raw': rawTravelTime,
        },
        'distance': {
          'weighted': distanceScore,
          'raw': rawDistance,
        },
      };

  @override
  String toString() =>
      'ScoreBreakdown(Total: ${totalScore.toStringAsFixed(1)}, Med: ${medicalCapabilityScore.toStringAsFixed(1)}, Spec: ${specialtyMatchScore.toStringAsFixed(1)}, ICU: ${emergencyIcuScore.toStringAsFixed(1)}, Avail: ${availabilityScore.toStringAsFixed(1)}, Time: ${travelTimeScore.toStringAsFixed(1)}, Dist: ${distanceScore.toStringAsFixed(1)})';
}

/// Evaluated match result for an eligible candidate referral hospital.
class HospitalMatchResult {
  final Hospital hospital;
  final double matchScore; // 0.0 to 100.0
  final double distanceKm;
  final Duration travelTime;
  final ScoreBreakdown scoreBreakdown;

  // Capability checkmarks
  final bool hasRequiredSpecialty;
  final bool hasEmergencyCapability;
  final bool hasIcu;
  final bool hasRequiredDiagnostics;
  final bool hasRequiredTreatments;
  final bool hasAvailableBeds;

  final bool hasRequiredFacilities;
  final double facilityMatchRate;
  final List<String> matchingHighlights;
  final List<String> matchingCaveats;
  final ConditionRankingResult? conditionRanking;

  const HospitalMatchResult({
    required this.hospital,
    required this.matchScore,
    required this.distanceKm,
    required this.travelTime,
    required this.scoreBreakdown,
    required this.hasRequiredSpecialty,
    required this.hasEmergencyCapability,
    required this.hasIcu,
    required this.hasRequiredDiagnostics,
    required this.hasRequiredTreatments,
    required this.hasAvailableBeds,
    required this.hasRequiredFacilities,
    required this.facilityMatchRate,
    required this.matchingHighlights,
    required this.matchingCaveats,
    this.conditionRanking,
  });

  @override
  String toString() =>
      'HospitalMatchResult("${hospital.name}", Score: ${matchScore.toStringAsFixed(1)}, Distance: ${distanceKm.toStringAsFixed(1)}km)';
}

/// Result for a hospital that was excluded by the mandatory capability hard filter.
class UnsuitableHospitalResult {
  final Hospital hospital;
  final List<String> exclusionReasons;
  final double distanceKm;
  final Duration travelTime;

  const UnsuitableHospitalResult({
    required this.hospital,
    required this.exclusionReasons,
    required this.distanceKm,
    required this.travelTime,
  });

  String get primaryReason =>
      exclusionReasons.isNotEmpty ? exclusionReasons.first : 'Does not meet clinical criteria';

  @override
  String toString() =>
      'UnsuitableHospital("${hospital.name}", Excluded: ${exclusionReasons.join(", ")})';
}

/// Complete output of the hospital recommendation engine.
/// Provides the BEST MATCH, alternative options, all ranked eligible hospitals,
/// and unsuitable excluded hospitals with explicit exclusion reasons.
class HospitalRecommendationResult {
  final HospitalMatchResult? bestMatch;
  final List<HospitalMatchResult> alternatives;
  final List<HospitalMatchResult> eligibleHospitals;
  final List<UnsuitableHospitalResult> excludedHospitals;
  final DateTime evaluatedAt;
  final String disclaimer;
  final ConditionRecommendationResult? conditionRecommendation;

  const HospitalRecommendationResult({
    required this.bestMatch,
    required this.alternatives,
    required this.eligibleHospitals,
    required this.excludedHospitals,
    required this.evaluatedAt,
    this.disclaimer =
        'Clinical decision-support recommendations require clinical verification.',
    this.conditionRecommendation,
  });

  bool get hasMatches => bestMatch != null;
  int get totalEligible => eligibleHospitals.length;
  int get totalExcluded => excludedHospitals.length;

  @override
  String toString() =>
      'HospitalRecommendationResult(Best: ${bestMatch?.hospital.name ?? "None"}, Eligible: ${eligibleHospitals.length}, Excluded: ${excludedHospitals.length})';
}

/// Abstract contract for matching patients to referral hospitals.
abstract class HospitalMatchingService {
  /// Evaluates all hospitals against clinical requirements, applies mandatory hard filters,
  /// calculates multi-factor suitability scores, and returns full recommendation output.
  HospitalRecommendationResult evaluateRecommendations({
    required Patient patient,
    required AssessmentResult assessment,
    required List<Hospital> availableHospitals,
    required double clinicLatitude,
    required double clinicLongitude,
    MatchingWeights weights = const MatchingWeights(),
    Set<String>? mandatoryFacilities,
    PatientConditionCategory? conditionCategory,
  });

  /// Legacy convenience method returning ranked eligible hospital match results.
  List<HospitalMatchResult> matchHospitals({
    required Patient patient,
    required AssessmentResult assessment,
    required List<Hospital> availableHospitals,
    required double clinicLatitude,
    required double clinicLongitude,
  });
}

/// Production implementation of the clinical hospital recommendation engine.
///
/// Follows clinical referral logic:
/// Patient assessment → Determine mandatory capabilities → Hard Filter exclusions →
/// Multi-factor weighted scoring → Deterministic tie-breaking → Rank eligible destinations.
class ClinicalHospitalMatchingService implements HospitalMatchingService {
  final DistanceService distanceService;

  const ClinicalHospitalMatchingService({
    this.distanceService = const HaversineDistanceService(),
  });

  @override
  List<HospitalMatchResult> matchHospitals({
    required Patient patient,
    required AssessmentResult assessment,
    required List<Hospital> availableHospitals,
    required double clinicLatitude,
    required double clinicLongitude,
  }) {
    return evaluateRecommendations(
      patient: patient,
      assessment: assessment,
      availableHospitals: availableHospitals,
      clinicLatitude: clinicLatitude,
      clinicLongitude: clinicLongitude,
    ).eligibleHospitals;
  }

  @override
  HospitalRecommendationResult evaluateRecommendations({
    required Patient patient,
    required AssessmentResult assessment,
    required List<Hospital> availableHospitals,
    required double clinicLatitude,
    required double clinicLongitude,
    MatchingWeights weights = const MatchingWeights(),
    Set<String>? mandatoryFacilities,
    PatientConditionCategory? conditionCategory,
  }) {
    final effectiveCategory = conditionCategory ??
        assessment.conditionCategory ??
        patient.conditionCategory;

    if (effectiveCategory != null) {
      final rankingService = ConditionSpecificRankingService(distanceService: distanceService);
      final conditionResult = rankingService.rankHospitals(
        patient: patient,
        availableHospitals: availableHospitals,
        clinicLatitude: clinicLatitude,
        clinicLongitude: clinicLongitude,
        conditionCategory: effectiveCategory,
        targetSpecialty: assessment.requiredSpecialty,
        requiredFacilities: mandatoryFacilities,
      );

      final eligibleMatches = conditionResult.rankedEligibleHospitals.map((c) {
        return HospitalMatchResult(
          hospital: c.hospital,
          matchScore: c.compositeScore,
          distanceKm: c.distanceKm,
          travelTime: c.travelTime,
          scoreBreakdown: ScoreBreakdown(
            medicalCapabilityScore: (c.priority1.score * 0.40 * 10).roundToDouble() / 10,
            specialtyMatchScore: (c.priority4.score * 0.10 * 10).roundToDouble() / 10,
            emergencyIcuScore: (c.priority2.score * 0.30 * 10).roundToDouble() / 10,
            availabilityScore: (c.priority2.score * 0.30 * 10).roundToDouble() / 10,
            travelTimeScore: (c.priority3.score * 0.20 * 10).roundToDouble() / 10,
            distanceScore: (c.distanceKm <= 20 ? 5.0 : 2.5),
            totalScore: c.compositeScore,
            rawMedicalCapability: c.priority1.score,
            rawSpecialtyMatch: c.priority4.score,
            rawEmergencyIcu: c.priority2.score,
            rawAvailability: c.priority2.score,
            rawTravelTime: c.priority3.score,
            rawDistance: (100.0 - c.distanceKm).clamp(0.0, 100.0),
          ),
          hasRequiredSpecialty: c.priority4.satisfied || c.priority1.satisfied,
          hasEmergencyCapability: c.hospital.emergencyCare,
          hasIcu: c.hospital.icuAvailable,
          hasRequiredDiagnostics: true,
          hasRequiredTreatments: true,
          hasAvailableBeds: c.hospital.bedAvailability > 0,
          hasRequiredFacilities: true,
          facilityMatchRate: 1.0,
          matchingHighlights: [
            c.whyThisHospitalSummary,
            ...c.priorityEvaluations.map((e) => 'Priority ${e.priorityNumber}: ${e.name} — ${e.explanation}'),
          ],
          matchingCaveats: c.warnings,
          conditionRanking: c,
        );
      }).toList();

      final excludedMatches = conditionResult.excludedHospitals.map((e) {
        return UnsuitableHospitalResult(
          hospital: e.hospital,
          exclusionReasons: e.exclusionReasons,
          distanceKm: e.distanceKm,
          travelTime: e.travelTime,
        );
      }).toList();

      return HospitalRecommendationResult(
        bestMatch: eligibleMatches.isNotEmpty ? eligibleMatches.first : null,
        alternatives: eligibleMatches.length > 1 ? eligibleMatches.sublist(1) : const [],
        eligibleHospitals: eligibleMatches,
        excludedHospitals: excludedMatches,
        evaluatedAt: conditionResult.evaluatedAt,
        conditionRecommendation: conditionResult,
      );
    }

    final eligibleResults = <HospitalMatchResult>[];
    final excludedResults = <UnsuitableHospitalResult>[];

    // 1. Determine clinical requirements
    final targetSpecialty = assessment.requiredSpecialty.trim();
    final isEmergency = assessment.urgencyLevel == UrgencyLevel.emergency;
    final isIcuRequired = _determineIfIcuRequired(patient, assessment);

    // Build effective set of mandatory clinical facilities
    final effectiveMandatoryFacilities = mandatoryFacilities ??
        _determineMandatoryFacilities(patient, assessment);

    for (final hospital in availableHospitals) {
      final distance = distanceService.calculateDistanceKm(
        clinicLatitude,
        clinicLongitude,
        hospital.latitude,
        hospital.longitude,
      );
      final travelTime = distanceService.estimateTravelTime(distance);

      // =======================================================================
      // STEP 2 & 3: HARD FILTER — MANDATORY CAPABILITY CHECK
      // A missing mandatory capability CANNOT be compensated by a high score.
      // =======================================================================
      final exclusionReasons = <String>[];

      // A. Operating Status Hard Filter
      final statusLower = hospital.operatingStatus.toLowerCase();
      if (statusLower == 'diverting') {
        exclusionReasons.add('Excluded because hospital operating status is Diverting.');
      } else if (statusLower == 'closed' || statusLower == 'temporary closure') {
        exclusionReasons.add('Excluded because hospital is temporarily closed.');
      } else if (hospital.bedAvailability <= 0) {
        exclusionReasons.add('Excluded because zero beds are currently available.');
      }

      // B. Mandatory Specialty Hard Filter
      final hasSpecialty = hospital.hasSpecialty(targetSpecialty);
      final isGenericSpecialty = targetSpecialty.toLowerCase() == 'general medicine' ||
          targetSpecialty.isEmpty;

      if (!isGenericSpecialty && !hasSpecialty) {
        exclusionReasons.add(
          'Excluded because missing required specialty: $targetSpecialty.',
        );
      }

      // C. Mandatory 24/7 Emergency Care Hard Filter
      if (isEmergency && !hospital.emergencyCare) {
        exclusionReasons.add(
          'Excluded because 24/7 Emergency Care is unavailable.',
        );
      }

      // D. Mandatory ICU Hard Filter
      if (isIcuRequired) {
        final icuBeds = hospital.availability?.icuBedsAvailable ??
            (hospital.icuAvailable ? 1 : 0);
        if (!hospital.icuAvailable || icuBeds <= 0) {
          exclusionReasons.add('Excluded because ICU is unavailable.');
        }
      }

      // E. Mandatory Diagnostic & Treatment Facilities Hard Filter
      for (final mandatoryFacility in effectiveMandatoryFacilities) {
        if (!hospital.hasFacility(mandatoryFacility)) {
          exclusionReasons.add(
            'Excluded because mandatory capability "$mandatoryFacility" is unavailable.',
          );
        }
      }

      // If any mandatory capability is missing, EXCLUDE IMMEDIATELY
      if (exclusionReasons.isNotEmpty) {
        excludedResults.add(
          UnsuitableHospitalResult(
            hospital: hospital,
            exclusionReasons: exclusionReasons,
            distanceKm: distance,
            travelTime: travelTime,
          ),
        );
        continue;
      }

      // =======================================================================
      // STEP 4: SUITABILITY SCORING FOR ELIGIBLE HOSPITALS
      // Weights: Med Cap 35% | Specialty 20% | Emerg/ICU 15% | Avail 15% | Time 10% | Dist 5%
      // =======================================================================
      final highlights = <String>[];
      final caveats = <String>[];

      // 1. Medical Capability (Weight: 35%)
      final rawMedicalCap = _calculateMedicalCapabilityScore(
        hospital,
        assessment,
        highlights,
        caveats,
      );
      final weightedMedicalCap = (rawMedicalCap * weights.medicalCapability * 10).roundToDouble() / 10;

      // 2. Specialty Match (Weight: 20%)
      final rawSpecialty = _calculateSpecialtyScore(
        hospital,
        targetSpecialty,
        hasSpecialty,
        highlights,
        caveats,
      );
      final weightedSpecialty = (rawSpecialty * weights.specialtyMatch * 10).roundToDouble() / 10;

      // 3. Emergency / ICU (Weight: 15%)
      final rawEmergencyIcu = _calculateEmergencyIcuScore(
        hospital,
        isEmergency,
        isIcuRequired,
        highlights,
        caveats,
      );
      final weightedEmergencyIcu = (rawEmergencyIcu * weights.emergencyIcu * 10).roundToDouble() / 10;

      // 4. Availability & Simulated Capacity (Weight: 15%)
      final rawAvailability = _calculateAvailabilityScore(
        hospital,
        highlights,
        caveats,
      );
      final weightedAvailability = (rawAvailability * weights.availability * 10).roundToDouble() / 10;

      // 5. Travel Time (Weight: 10%)
      final rawTravelTime = _calculateTravelTimeScore(travelTime);
      final weightedTravelTime = (rawTravelTime * weights.travelTime * 10).roundToDouble() / 10;

      // 6. Distance (Weight: 5%)
      final rawDistance = _calculateDistanceScore(distance);
      final weightedDistance = (rawDistance * weights.distance * 10).roundToDouble() / 10;

      // Total Score (0.0 to 100.0)
      final rawTotal = (weightedMedicalCap +
              weightedSpecialty +
              weightedEmergencyIcu +
              weightedAvailability +
              weightedTravelTime +
              weightedDistance)
          .clamp(0.0, 100.0);
      final finalScore = (rawTotal * 10).roundToDouble() / 10;

      final breakdown = ScoreBreakdown(
        medicalCapabilityScore: weightedMedicalCap,
        specialtyMatchScore: weightedSpecialty,
        emergencyIcuScore: weightedEmergencyIcu,
        availabilityScore: weightedAvailability,
        travelTimeScore: weightedTravelTime,
        distanceScore: weightedDistance,
        totalScore: finalScore,
        rawMedicalCapability: rawMedicalCap,
        rawSpecialtyMatch: rawSpecialty,
        rawEmergencyIcu: rawEmergencyIcu,
        rawAvailability: rawAvailability,
        rawTravelTime: rawTravelTime,
        rawDistance: rawDistance,
      );

      // Capability flags for UI checkmarks
      final hasReqDiagnostics = _checkDiagnostics(hospital, assessment);
      final hasReqTreatments = _checkTreatments(hospital, assessment);

      eligibleResults.add(
        HospitalMatchResult(
          hospital: hospital,
          matchScore: finalScore,
          distanceKm: distance,
          travelTime: travelTime,
          scoreBreakdown: breakdown,
          hasRequiredSpecialty: hasSpecialty || isGenericSpecialty,
          hasEmergencyCapability: hospital.emergencyCare,
          hasIcu: hospital.icuAvailable && (hospital.availability?.icuBedsAvailable ?? 1) > 0,
          hasRequiredDiagnostics: hasReqDiagnostics,
          hasRequiredTreatments: hasReqTreatments,
          hasAvailableBeds: hospital.bedAvailability > 0,
          hasRequiredFacilities: hasReqDiagnostics && hasReqTreatments,
          facilityMatchRate: (rawMedicalCap / 100.0).clamp(0.0, 1.0),
          matchingHighlights: highlights,
          matchingCaveats: caveats,
        ),
      );
    }

    // =======================================================================
    // STEP 5: RANK ELIGIBLE HOSPITALS WITH DETERMINISTIC TIE-BREAKING
    // Rank primary: matchScore DESC
    // Tie-breakers: travelTime ASC -> bedAvailability DESC -> distance ASC -> name ASC
    // =======================================================================
    eligibleResults.sort((a, b) {
      final scoreCompare = b.matchScore.compareTo(a.matchScore);
      if (scoreCompare != 0) return scoreCompare;

      final timeCompare = a.travelTime.compareTo(b.travelTime);
      if (timeCompare != 0) return timeCompare;

      final bedsCompare = b.hospital.bedAvailability.compareTo(a.hospital.bedAvailability);
      if (bedsCompare != 0) return bedsCompare;

      final distCompare = a.distanceKm.compareTo(b.distanceKm);
      if (distCompare != 0) return distCompare;

      return a.hospital.name.compareTo(b.hospital.name);
    });

    final bestMatch = eligibleResults.isNotEmpty ? eligibleResults.first : null;
    final alternatives = eligibleResults.length > 1
        ? eligibleResults.skip(1).take(2).toList()
        : <HospitalMatchResult>[];

    return HospitalRecommendationResult(
      bestMatch: bestMatch,
      alternatives: alternatives,
      eligibleHospitals: eligibleResults,
      excludedHospitals: excludedResults,
      evaluatedAt: DateTime.now(),
    );
  }

  // --- Clinical Capability Helper Logic ---

  bool _determineIfIcuRequired(Patient patient, AssessmentResult assessment) {
    if (assessment.requiredFacilities.any((f) {
      final fl = f.toLowerCase();
      return fl.contains('icu') || fl.contains('ventilator') || fl.contains('intensive care');
    })) {
      return true;
    }

    // Critical vitals indicating impending respiratory or hemodynamic collapse
    if (patient.oxygenSaturation != null && patient.oxygenSaturation! < 88.0) {
      return true;
    }
    if (patient.systolicBP != null && patient.systolicBP! < 75) {
      return true;
    }
    if (patient.respiratoryRate != null && patient.respiratoryRate! >= 40) {
      return true;
    }

    return false;
  }

  Set<String> _determineMandatoryFacilities(Patient patient, AssessmentResult assessment) {
    final mandatory = <String>{};

    if (assessment.urgencyLevel == UrgencyLevel.emergency) {
      for (final facility in assessment.requiredFacilities) {
        final fl = facility.toLowerCase();
        // Life-critical emergency capabilities cannot be waived in emergency triage
        if (fl.contains('blood bank') ||
            fl.contains('blood transfusion') ||
            fl.contains('c-section') ||
            fl.contains('cesarean') ||
            fl.contains('ventilator') ||
            fl.contains('dialysis')) {
          mandatory.add(facility);
        }
      }
    }

    return mandatory;
  }

  double _calculateMedicalCapabilityScore(
    Hospital hospital,
    AssessmentResult assessment,
    List<String> highlights,
    List<String> caveats,
  ) {
    if (assessment.requiredFacilities.isEmpty) {
      // General capability baseline
      var base = 70.0;
      if (hospital.diagnosticFacilities.length >= 3) base += 15.0;
      if (hospital.treatmentCapabilities.length >= 3) base += 15.0;
      return base.clamp(0.0, 100.0);
    }

    var matched = 0;
    for (final req in assessment.requiredFacilities) {
      if (hospital.hasFacility(req)) {
        matched++;
      }
    }

    final matchRatio = matched / assessment.requiredFacilities.length;
    final score = matchRatio * 100.0;

    if (matchRatio >= 1.0) {
      highlights.add('Full match for all required clinical facilities ($matched/$matched)');
    } else if (matchRatio >= 0.5) {
      highlights.add('Partial match: $matched of ${assessment.requiredFacilities.length} facilities');
    } else {
      caveats.add('Missing key facilities ($matched/${assessment.requiredFacilities.length} available)');
    }

    return score.clamp(0.0, 100.0);
  }

  double _calculateSpecialtyScore(
    Hospital hospital,
    String targetSpecialty,
    bool hasSpecialty,
    List<String> highlights,
    List<String> caveats,
  ) {
    if (targetSpecialty.toLowerCase() == 'general medicine' || targetSpecialty.isEmpty) {
      return 100.0;
    }

    if (hasSpecialty) {
      highlights.add('Direct specialty: $targetSpecialty');
      return 100.0;
    }

    // Related specialty fallback
    if (targetSpecialty.toLowerCase().contains('surgery') &&
        hospital.hasSpecialty('General Surgery')) {
      highlights.add('Related surgical coverage (General Surgery)');
      return 75.0;
    }

    if (hospital.hasSpecialty('General Medicine')) {
      caveats.add('General Medicine only; lacks $targetSpecialty department');
      return 40.0;
    }

    caveats.add('No matching specialty coverage');
    return 10.0;
  }

  double _calculateEmergencyIcuScore(
    Hospital hospital,
    bool isEmergency,
    bool isIcuRequired,
    List<String> highlights,
    List<String> caveats,
  ) {
    var score = 0.0;

    if (hospital.emergencyCare) {
      score += 50.0;
      highlights.add('24/7 Emergency Department operational');
    } else {
      caveats.add('No dedicated 24/7 emergency unit');
    }

    final icuBeds = hospital.availability?.icuBedsAvailable ?? (hospital.icuAvailable ? 1 : 0);
    if (hospital.icuAvailable && icuBeds > 0) {
      score += 50.0;
      highlights.add('ICU care available ($icuBeds bed${icuBeds > 1 ? "s" : ""})');
    } else if (hospital.icuAvailable && icuBeds == 0) {
      score += 20.0;
      caveats.add('ICU unit present but currently 0 beds vacant');
    } else {
      if (!isIcuRequired) {
        score += 25.0; // Non-ICU patient penalty is minimal
      } else {
        caveats.add('No ICU facilities on-site');
      }
    }

    return score.clamp(0.0, 100.0);
  }

  double _calculateAvailabilityScore(
    Hospital hospital,
    List<String> highlights,
    List<String> caveats,
  ) {
    // 60% capacity utilization factor (higher free capacity = better)
    final freeCapacityRatio = (1.0 - hospital.currentCapacity).clamp(0.0, 1.0);
    final capacityComponent = freeCapacityRatio * 60.0;

    // 40% absolute bed volume buffer (30+ beds = max buffer)
    final bedVolumeRatio = (hospital.bedAvailability / 30.0).clamp(0.0, 1.0);
    final bedComponent = bedVolumeRatio * 40.0;

    final score = capacityComponent + bedComponent;

    if (hospital.bedAvailability >= 25) {
      highlights.add('${hospital.bedAvailability} beds available (High capacity buffer)');
    } else if (hospital.bedAvailability >= 10) {
      highlights.add('${hospital.bedAvailability} beds available');
    } else {
      caveats.add('Limited bed reserve (${hospital.bedAvailability} remaining)');
    }

    return score.clamp(0.0, 100.0);
  }

  double _calculateTravelTimeScore(Duration travelTime) {
    final minutes = travelTime.inMinutes;
    if (minutes <= 15) return 100.0;
    if (minutes <= 30) return 90.0;
    if (minutes <= 45) return 75.0;
    if (minutes <= 60) return 60.0;
    if (minutes <= 90) return 40.0;
    if (minutes <= 120) return 20.0;
    return 5.0;
  }

  double _calculateDistanceScore(double distanceKm) {
    if (distanceKm <= 5.0) return 100.0;
    if (distanceKm <= 15.0) return 85.0;
    if (distanceKm <= 30.0) return 70.0;
    if (distanceKm <= 50.0) return 50.0;
    if (distanceKm <= 80.0) return 25.0;
    return 5.0;
  }

  bool _checkDiagnostics(Hospital hospital, AssessmentResult assessment) {
    final diags = assessment.requiredFacilities
        .where((f) =>
            f.toLowerCase().contains('lab') ||
            f.toLowerCase().contains('scan') ||
            f.toLowerCase().contains('x-ray') ||
            f.toLowerCase().contains('ultrasound') ||
            f.toLowerCase().contains('mri') ||
            f.toLowerCase().contains('blood bank'))
        .toList();

    if (diags.isEmpty) return true;
    return diags.every((d) => hospital.hasFacility(d));
  }

  bool _checkTreatments(Hospital hospital, AssessmentResult assessment) {
    final treatments = assessment.requiredFacilities
        .where((f) =>
            f.toLowerCase().contains('delivery') ||
            f.toLowerCase().contains('surgery') ||
            f.toLowerCase().contains('section') ||
            f.toLowerCase().contains('fixation') ||
            f.toLowerCase().contains('ventilation') ||
            f.toLowerCase().contains('transfusion') ||
            f.toLowerCase().contains('rehydration'))
        .toList();

    if (treatments.isEmpty) return true;
    return treatments.every((t) => hospital.hasFacility(t));
  }
}
