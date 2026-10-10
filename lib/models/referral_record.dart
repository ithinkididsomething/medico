/// Architectural model placeholder for patient referral records.
/// Detailed medical fields will be implemented in subsequent phases.
class ReferralRecord {
  final String id;
  final String patientIdentifier;
  final DateTime createdAt;
  final String urgencyLevel;
  final String status;
  final String facilityName;

  const ReferralRecord({
    required this.id,
    required this.patientIdentifier,
    required this.createdAt,
    required this.urgencyLevel,
    required this.status,
    required this.facilityName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientIdentifier': patientIdentifier,
      'createdAt': createdAt.toIso8601String(),
      'urgencyLevel': urgencyLevel,
      'status': status,
      'facilityName': facilityName,
    };
  }

  factory ReferralRecord.fromMap(Map<String, dynamic> map) {
    return ReferralRecord(
      id: map['id'] as String,
      patientIdentifier: map['patientIdentifier'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      urgencyLevel: map['urgencyLevel'] as String,
      status: map['status'] as String,
      facilityName: map['facilityName'] as String,
    );
  }
}
