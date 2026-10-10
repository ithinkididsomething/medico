/// Hospital real-time capacity and bed availability state.
/// Designed so simulated capacity can be seamlessly swapped with real authenticated APIs later.
class HospitalAvailability {
  final String hospitalId;
  final int icuBedsAvailable;
  final int generalBedsAvailable;
  final bool emergencyDepartmentOpen;
  final int operatingTheatersAvailable;
  final double currentCapacity; // 0.0 (empty) to 1.0 (100% full capacity)
  final String operatingStatus; // "Operational", "Limited Services", "Diverting"
  final DateTime availabilityLastUpdated;

  /// Flags whether this record is synthetic/mocked or received from an authorized live API.
  final bool isSimulated;
  final String dataSource;

  const HospitalAvailability({
    required this.hospitalId,
    required this.icuBedsAvailable,
    required this.generalBedsAvailable,
    required this.emergencyDepartmentOpen,
    required this.operatingTheatersAvailable,
    required this.currentCapacity,
    required this.operatingStatus,
    required this.availabilityLastUpdated,
    this.isSimulated = true,
    this.dataSource = 'SYNTHETIC_SIMULATED_FEED',
  });

  int get totalBedsAvailable => icuBedsAvailable + generalBedsAvailable;
  bool get hasIcuBed => icuBedsAvailable > 0;
  bool get hasGeneralBed => generalBedsAvailable > 0;
  bool get isOperational => operatingStatus.toLowerCase() == 'operational' && emergencyDepartmentOpen;

  HospitalAvailability copyWith({
    String? hospitalId,
    int? icuBedsAvailable,
    int? generalBedsAvailable,
    bool? emergencyDepartmentOpen,
    int? operatingTheatersAvailable,
    double? currentCapacity,
    String? operatingStatus,
    DateTime? availabilityLastUpdated,
    bool? isSimulated,
    String? dataSource,
  }) {
    return HospitalAvailability(
      hospitalId: hospitalId ?? this.hospitalId,
      icuBedsAvailable: icuBedsAvailable ?? this.icuBedsAvailable,
      generalBedsAvailable: generalBedsAvailable ?? this.generalBedsAvailable,
      emergencyDepartmentOpen: emergencyDepartmentOpen ?? this.emergencyDepartmentOpen,
      operatingTheatersAvailable: operatingTheatersAvailable ?? this.operatingTheatersAvailable,
      currentCapacity: currentCapacity ?? this.currentCapacity,
      operatingStatus: operatingStatus ?? this.operatingStatus,
      availabilityLastUpdated: availabilityLastUpdated ?? this.availabilityLastUpdated,
      isSimulated: isSimulated ?? this.isSimulated,
      dataSource: dataSource ?? this.dataSource,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hospitalId': hospitalId,
      'icuBedsAvailable': icuBedsAvailable,
      'generalBedsAvailable': generalBedsAvailable,
      'emergencyDepartmentOpen': emergencyDepartmentOpen,
      'operatingTheatersAvailable': operatingTheatersAvailable,
      'currentCapacity': currentCapacity,
      'operatingStatus': operatingStatus,
      'availabilityLastUpdated': availabilityLastUpdated.toIso8601String(),
      'isSimulated': isSimulated,
      'dataSource': dataSource,
    };
  }

  factory HospitalAvailability.fromMap(Map<String, dynamic> map) {
    return HospitalAvailability(
      hospitalId: map['hospitalId'] as String,
      icuBedsAvailable: (map['icuBedsAvailable'] as num).toInt(),
      generalBedsAvailable: (map['generalBedsAvailable'] as num).toInt(),
      emergencyDepartmentOpen: map['emergencyDepartmentOpen'] as bool? ?? true,
      operatingTheatersAvailable: (map['operatingTheatersAvailable'] as num? ?? 1).toInt(),
      currentCapacity: (map['currentCapacity'] as num).toDouble(),
      operatingStatus: map['operatingStatus'] as String? ?? 'Operational',
      availabilityLastUpdated: DateTime.parse(map['availabilityLastUpdated'] as String),
      isSimulated: map['isSimulated'] as bool? ?? true,
      dataSource: map['dataSource'] as String? ?? 'SYNTHETIC_SIMULATED_FEED',
    );
  }

  @override
  String toString() =>
      'HospitalAvailability($hospitalId, ICU: $icuBedsAvailable, General: $generalBedsAvailable, Simulated: $isSimulated)';
}
