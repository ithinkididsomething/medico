/// Models representing the Three-Level Hierarchical Hospital Referral Ranking Engine:
/// Priority 1: Technical and infrastructural capability
/// Priority 2: Current availability
/// Priority 3: Travel distance and time
library;

class HierarchicalTechnicalEvaluation {
  final bool isEligible;
  final String eligibilityStatus; // 'eligible', 'ineligible', 'unknown'
  final double technicalSuitabilityScore; // 0.0 to 100.0
  final List<String> confirmedCapabilities;
  final List<String> missingEssentialCapabilities;
  final List<String> unknownCapabilities;
  final double specialtyScore;
  final double equipmentScore;
  final double doctorScore;

  const HierarchicalTechnicalEvaluation({
    required this.isEligible,
    required this.eligibilityStatus,
    required this.technicalSuitabilityScore,
    required this.confirmedCapabilities,
    required this.missingEssentialCapabilities,
    required this.unknownCapabilities,
    required this.specialtyScore,
    required this.equipmentScore,
    required this.doctorScore,
  });

  factory HierarchicalTechnicalEvaluation.fromMap(Map<String, dynamic> map) {
    List<String> toStrList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return const [];
    }

    return HierarchicalTechnicalEvaluation(
      isEligible: map['is_eligible'] == true || map['isEligible'] == true,
      eligibilityStatus: map['eligibility_status'] as String? ?? 'unknown',
      technicalSuitabilityScore: (map['technical_suitability_score'] as num?)?.toDouble() ?? 0.0,
      confirmedCapabilities: toStrList(map['confirmed_capabilities']),
      missingEssentialCapabilities: toStrList(map['missing_essential_capabilities']),
      unknownCapabilities: toStrList(map['unknown_capabilities']),
      specialtyScore: (map['specialty_score'] as num?)?.toDouble() ?? 0.0,
      equipmentScore: (map['equipment_score'] as num?)?.toDouble() ?? 0.0,
      doctorScore: (map['doctor_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HierarchicalAvailabilityEvaluation {
  final String status; // 'available', 'unavailable', 'unknown', 'outdated'
  final String operatingStatus;
  final int generalBedsAvailable;
  final bool emergencyDepartmentOpen;
  final bool isOutdated;
  final String? lastReportedAt;
  final String reason;

  const HierarchicalAvailabilityEvaluation({
    required this.status,
    required this.operatingStatus,
    required this.generalBedsAvailable,
    required this.emergencyDepartmentOpen,
    required this.isOutdated,
    this.lastReportedAt,
    required this.reason,
  });

  factory HierarchicalAvailabilityEvaluation.fromMap(Map<String, dynamic> map) {
    return HierarchicalAvailabilityEvaluation(
      status: map['status'] as String? ?? 'unknown',
      operatingStatus: map['operating_status'] as String? ?? 'Operational',
      generalBedsAvailable: (map['general_beds_available'] as num?)?.toInt() ?? 0,
      emergencyDepartmentOpen: map['emergency_department_open'] == true,
      isOutdated: map['is_outdated'] == true,
      lastReportedAt: map['last_reported_at'] as String?,
      reason: map['reason'] as String? ?? '',
    );
  }
}

class HierarchicalFacilityEntry {
  final String facilityId;
  final String facilityName;
  final String address;
  final String facilityType;
  final double distanceKm;
  final int transitTimeMinutes;
  final int? rank; // Null for excluded facilities
  final String statusLabel; // 'Suitable — availability confirmed', 'Essential capability missing', etc.
  final String recommendationTier; // 'Tier 1: Recommended', 'Tier 2: Conditional', 'Tier 3: Ineligible'
  final String whyRankedSummary;
  final HierarchicalTechnicalEvaluation technicalEvaluation;
  final HierarchicalAvailabilityEvaluation availabilityEvaluation;
  final int affiliatedDoctorsCount;
  final bool isSimulatedData;

  const HierarchicalFacilityEntry({
    required this.facilityId,
    required this.facilityName,
    required this.address,
    required this.facilityType,
    required this.distanceKm,
    required this.transitTimeMinutes,
    this.rank,
    required this.statusLabel,
    required this.recommendationTier,
    required this.whyRankedSummary,
    required this.technicalEvaluation,
    required this.availabilityEvaluation,
    required this.affiliatedDoctorsCount,
    this.isSimulatedData = true,
  });

  bool get isEligible => technicalEvaluation.isEligible;

  factory HierarchicalFacilityEntry.fromMap(Map<String, dynamic> map) {
    return HierarchicalFacilityEntry(
      facilityId: map['facility_id'] as String? ?? map['hospitalId'] as String? ?? '',
      facilityName: map['facility_name'] as String? ?? map['name'] as String? ?? 'Healthcare Facility',
      address: map['address'] as String? ?? '',
      facilityType: map['facility_type'] as String? ?? 'hospital',
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0.0,
      transitTimeMinutes: (map['transit_time_minutes'] as num?)?.toInt() ?? 10,
      rank: (map['rank'] as num?)?.toInt(),
      statusLabel: map['status_label'] as String? ?? 'Evaluation pending',
      recommendationTier: map['recommendation_tier'] as String? ?? 'Tier 1: Recommended',
      whyRankedSummary: map['why_ranked_summary'] as String? ?? '',
      technicalEvaluation: HierarchicalTechnicalEvaluation.fromMap(
        map['technical_evaluation'] is Map<String, dynamic>
            ? map['technical_evaluation'] as Map<String, dynamic>
            : const {},
      ),
      availabilityEvaluation: HierarchicalAvailabilityEvaluation.fromMap(
        map['availability_evaluation'] is Map<String, dynamic>
            ? map['availability_evaluation'] as Map<String, dynamic>
            : const {},
      ),
      affiliatedDoctorsCount: (map['affiliated_doctors_count'] as num?)?.toInt() ?? 0,
      isSimulatedData: map['is_simulated_data'] == true,
    );
  }
}

class HierarchicalReferralResponse {
  final String conditionKey;
  final String conditionName;
  final String urgencyLevel;
  final List<String> rankingHierarchy;
  final int totalEvaluatedFacilities;
  final int eligibleFacilitiesCount;
  final int confirmedAvailableCount;
  final int unconfirmedAvailabilityCount;
  final int excludedIneligibleCount;
  final List<HierarchicalFacilityEntry> rankedRecommendations;
  final List<HierarchicalFacilityEntry> excludedFacilities;
  final String fallbackProtocol;
  final String evaluatedAt;
  final bool isSyntheticDataIncluded;
  final String dataNotice;

  const HierarchicalReferralResponse({
    required this.conditionKey,
    required this.conditionName,
    required this.urgencyLevel,
    required this.rankingHierarchy,
    required this.totalEvaluatedFacilities,
    required this.eligibleFacilitiesCount,
    required this.confirmedAvailableCount,
    required this.unconfirmedAvailabilityCount,
    required this.excludedIneligibleCount,
    required this.rankedRecommendations,
    required this.excludedFacilities,
    required this.fallbackProtocol,
    required this.evaluatedAt,
    required this.isSyntheticDataIncluded,
    required this.dataNotice,
  });

  HierarchicalFacilityEntry? get bestMatch =>
      rankedRecommendations.isNotEmpty ? rankedRecommendations.first : null;

  factory HierarchicalReferralResponse.fromMap(Map<String, dynamic> map) {
    List<HierarchicalFacilityEntry> parseEntries(dynamic val) {
      if (val is List) {
        return val
            .whereType<Map<String, dynamic>>()
            .map((e) => HierarchicalFacilityEntry.fromMap(e))
            .toList();
      }
      return const [];
    }

    List<String> toStrList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return const [];
    }

    return HierarchicalReferralResponse(
      conditionKey: map['condition_key'] as String? ?? 'general_condition',
      conditionName: map['condition_name'] as String? ?? 'Clinical Assessment',
      urgencyLevel: map['urgency_level'] as String? ?? 'standard',
      rankingHierarchy: toStrList(map['ranking_hierarchy']),
      totalEvaluatedFacilities: (map['total_evaluated_facilities'] as num?)?.toInt() ?? 0,
      eligibleFacilitiesCount: (map['eligible_facilities_count'] as num?)?.toInt() ?? 0,
      confirmedAvailableCount: (map['confirmed_available_count'] as num?)?.toInt() ?? 0,
      unconfirmedAvailabilityCount: (map['unconfirmed_availability_count'] as num?)?.toInt() ?? 0,
      excludedIneligibleCount: (map['excluded_ineligible_count'] as num?)?.toInt() ?? 0,
      rankedRecommendations: parseEntries(map['ranked_recommendations']),
      excludedFacilities: parseEntries(map['excluded_facilities']),
      fallbackProtocol: map['fallback_protocol'] as String? ?? '',
      evaluatedAt: map['evaluated_at'] as String? ?? '',
      isSyntheticDataIncluded: map['is_synthetic_data_included'] == true,
      dataNotice: map['data_notice'] as String? ?? 'OFFICIAL HEALTHCARE REGISTRY',
    );
  }
}
