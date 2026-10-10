import 'enums.dart';
import 'hospital.dart';
import 'patient.dart';
import 'referral_status_history.dart';

/// Strongly typed Referral model encapsulating clinical assessment findings,
/// hospital recommendation scoring, travel estimates, and lifecycle status history.
class Referral {
  final String referralId;
  final Patient patient;
  final UrgencyLevel urgencyLevel;
  final String referralReason;
  final String requiredSpecialty;
  final List<String> requiredFacilities;
  final Hospital? recommendedHospital;
  final List<Hospital> alternativeHospitals;
  final double? estimatedDistance; // distance in kilometers (km)
  final Duration? estimatedTravelTime;
  final double? recommendationScore; // 0.0 to 100.0 matching score
  final ReferralStatus status;
  final List<ReferralStatusHistory> statusHistory;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String referringClinic;

  const Referral({
    required this.referralId,
    required this.patient,
    required this.urgencyLevel,
    required this.referralReason,
    required this.requiredSpecialty,
    required this.requiredFacilities,
    this.recommendedHospital,
    this.alternativeHospitals = const [],
    this.estimatedDistance,
    this.estimatedTravelTime,
    this.recommendationScore,
    required this.status,
    this.statusHistory = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.referringClinic,
  });

  /// Human-readable travel time string (e.g. "45 mins" or "1 hr 15 mins").
  String get formattedTravelTime {
    if (estimatedTravelTime == null) return 'Calculating...';
    final minutes = estimatedTravelTime!.inMinutes;
    if (minutes < 60) return '$minutes mins';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    return remainingMins > 0 ? '$hours hr $remainingMins mins' : '$hours hr';
  }

  /// Formatted distance string (e.g., "18.4 km").
  String get formattedDistance {
    if (estimatedDistance == null) return 'Distance unavailable';
    return '${estimatedDistance!.toStringAsFixed(1)} km';
  }

  /// Creates a new Referral with an updated status and appends a new audit history item.
  Referral withNewStatus(ReferralStatus newStatus, {required String note, DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    final newHistoryItem = ReferralStatusHistory(
      status: newStatus,
      timestamp: now,
      note: note,
    );

    return copyWith(
      status: newStatus,
      updatedAt: now,
      statusHistory: [...statusHistory, newHistoryItem],
    );
  }

  Referral copyWith({
    String? referralId,
    Patient? patient,
    UrgencyLevel? urgencyLevel,
    String? referralReason,
    String? requiredSpecialty,
    List<String>? requiredFacilities,
    Hospital? recommendedHospital,
    List<Hospital>? alternativeHospitals,
    double? estimatedDistance,
    Duration? estimatedTravelTime,
    double? recommendationScore,
    ReferralStatus? status,
    List<ReferralStatusHistory>? statusHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? referringClinic,
  }) {
    return Referral(
      referralId: referralId ?? this.referralId,
      patient: patient ?? this.patient,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      referralReason: referralReason ?? this.referralReason,
      requiredSpecialty: requiredSpecialty ?? this.requiredSpecialty,
      requiredFacilities:
          requiredFacilities ?? List.from(this.requiredFacilities),
      recommendedHospital: recommendedHospital ?? this.recommendedHospital,
      alternativeHospitals:
          alternativeHospitals ?? List.from(this.alternativeHospitals),
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      estimatedTravelTime: estimatedTravelTime ?? this.estimatedTravelTime,
      recommendationScore: recommendationScore ?? this.recommendationScore,
      status: status ?? this.status,
      statusHistory: statusHistory ?? List.from(this.statusHistory),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      referringClinic: referringClinic ?? this.referringClinic,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'referralId': referralId,
      'patient': patient.toMap(),
      'urgencyLevel': urgencyLevel.name,
      'referralReason': referralReason,
      'requiredSpecialty': requiredSpecialty,
      'requiredFacilities': requiredFacilities,
      'recommendedHospital': recommendedHospital?.toMap(),
      'alternativeHospitals':
          alternativeHospitals.map((h) => h.toMap()).toList(),
      'estimatedDistance': estimatedDistance,
      'estimatedTravelTimeMinutes': estimatedTravelTime?.inMinutes,
      'recommendationScore': recommendationScore,
      'status': status.name,
      'statusHistory': statusHistory.map((s) => s.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'referringClinic': referringClinic,
    };
  }

  factory Referral.fromMap(Map<String, dynamic> map) {
    return Referral(
      referralId: map['referralId'] as String,
      patient: Patient.fromMap(Map<String, dynamic>.from(map['patient'] as Map)),
      urgencyLevel: UrgencyLevel.fromString(map['urgencyLevel'] as String),
      referralReason: map['referralReason'] as String,
      requiredSpecialty: map['requiredSpecialty'] as String,
      requiredFacilities: (map['requiredFacilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendedHospital: map['recommendedHospital'] != null
          ? Hospital.fromMap(
              Map<String, dynamic>.from(map['recommendedHospital'] as Map))
          : null,
      alternativeHospitals: (map['alternativeHospitals'] as List<dynamic>?)
              ?.map((h) =>
                  Hospital.fromMap(Map<String, dynamic>.from(h as Map)))
              .toList() ??
          [],
      estimatedDistance: (map['estimatedDistance'] as num?)?.toDouble(),
      estimatedTravelTime: map['estimatedTravelTimeMinutes'] != null
          ? Duration(minutes: (map['estimatedTravelTimeMinutes'] as num).toInt())
          : null,
      recommendationScore: (map['recommendationScore'] as num?)?.toDouble(),
      status: ReferralStatus.fromString(map['status'] as String),
      statusHistory: (map['statusHistory'] as List<dynamic>?)
              ?.map((s) => ReferralStatusHistory.fromMap(
                  Map<String, dynamic>.from(s as Map)))
              .toList() ??
          [],
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      referringClinic: map['referringClinic'] as String? ?? 'Rural Health Post',
    );
  }

  @override
  String toString() =>
      'Referral($referralId, Urgency: ${urgencyLevel.displayName}, Status: ${status.displayName}, Hospital: ${recommendedHospital?.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Referral &&
          runtimeType == other.runtimeType &&
          referralId == other.referralId;

  @override
  int get hashCode => referralId.hashCode;
}
