import 'dart:convert';

/// Represents a persistent pending mutation created locally while offline or online,
/// queued for transactional synchronization with the central backend.
class SyncMutation {
  final String id;
  final String idempotencyKey;
  final String facilityId;
  final String changeType; // e.g. 'update_operational_status', 'clinical_observation'
  final Map<String, dynamic> payload;
  final DateTime clientTimestamp;
  final int clientRevision;
  final String actorId;
  final String actorRole;
  final int retryCount;
  final String? lastError;

  const SyncMutation({
    required this.id,
    required this.idempotencyKey,
    required this.facilityId,
    required this.changeType,
    required this.payload,
    required this.clientTimestamp,
    required this.clientRevision,
    this.actorId = 'clinician_user',
    this.actorRole = 'clinician',
    this.retryCount = 0,
    this.lastError,
  });

  SyncMutation copyWith({
    String? id,
    String? idempotencyKey,
    String? facilityId,
    String? changeType,
    Map<String, dynamic>? payload,
    DateTime? clientTimestamp,
    int? clientRevision,
    String? actorId,
    String? actorRole,
    int? retryCount,
    String? lastError,
  }) {
    return SyncMutation(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      facilityId: facilityId ?? this.facilityId,
      changeType: changeType ?? this.changeType,
      payload: payload ?? this.payload,
      clientTimestamp: clientTimestamp ?? this.clientTimestamp,
      clientRevision: clientRevision ?? this.clientRevision,
      actorId: actorId ?? this.actorId,
      actorRole: actorRole ?? this.actorRole,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idempotencyKey': idempotencyKey,
      'facilityId': facilityId,
      'changeType': changeType,
      'payload': payload,
      'clientTimestamp': clientTimestamp.toIso8601String(),
      'clientRevision': clientRevision,
      'actorId': actorId,
      'actorRole': actorRole,
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  factory SyncMutation.fromMap(Map<String, dynamic> map) {
    return SyncMutation(
      id: map['id'] as String,
      idempotencyKey: map['idempotencyKey'] as String,
      facilityId: map['facilityId'] as String,
      changeType: map['changeType'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      clientTimestamp: DateTime.parse(map['clientTimestamp'] as String),
      clientRevision: (map['clientRevision'] as num?)?.toInt() ?? 1,
      actorId: map['actorId'] as String? ?? 'clinician_user',
      actorRole: map['actorRole'] as String? ?? 'clinician',
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      lastError: map['lastError'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory SyncMutation.fromJson(String source) =>
      SyncMutation.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
