import 'enums.dart';

/// Immutable audit record tracking transitions in the referral lifecycle.
class ReferralStatusHistory {
  final ReferralStatus status;
  final DateTime timestamp;
  final String note;

  const ReferralStatusHistory({
    required this.status,
    required this.timestamp,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
    };
  }

  factory ReferralStatusHistory.fromMap(Map<String, dynamic> map) {
    return ReferralStatusHistory(
      status: ReferralStatus.fromString(map['status'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      note: map['note'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'ReferralStatusHistory(${status.displayName}, ${timestamp.toIso8601String()}, "$note")';
}
