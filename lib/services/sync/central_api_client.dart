import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/hospital.dart';
import '../../models/sync_mutation.dart';

/// Response payload from central backend health check.
class BackendHealthResponse {
  final bool isHealthy;
  final String service;
  final String version;
  final int facilitiesCount;
  final String? error;

  const BackendHealthResponse({
    required this.isHealthy,
    this.service = 'smart-referral-central-backend',
    this.version = '1.0.0',
    this.facilitiesCount = 0,
    this.error,
  });
}

/// Response payload from incremental sync pull.
class SyncPullResponse {
  final List<Hospital> facilities;
  final int serverRevision;
  final int count;
  final DateTime serverTime;
  final bool success;
  final String? error;

  const SyncPullResponse({
    required this.facilities,
    required this.serverRevision,
    required this.count,
    required this.serverTime,
    required this.success,
    this.error,
  });
}

/// Response payload from atomic sync push.
class SyncPushResponse {
  final bool success;
  final int appliedCount;
  final int serverRevision;
  final List<Map<String, dynamic>> results;
  final String? error;

  const SyncPushResponse({
    required this.success,
    required this.appliedCount,
    required this.serverRevision,
    this.results = const [],
    this.error,
  });
}

/// HTTP REST client communicating with the centralized authoritative backend.
class CentralApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Duration timeout;

  CentralApiClient({
    String? baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 5),
  })  : baseUrl = (baseUrl ?? 'http://localhost:8000/api/v1').replaceAll(RegExp(r'/+$'), ''),
        _httpClient = httpClient ?? http.Client();

  /// Checks backend health and connectivity with a short non-blocking timeout.
  Future<BackendHealthResponse> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final res = await _httpClient.get(uri).timeout(timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return BackendHealthResponse(
          isHealthy: data['status'] == 'healthy',
          service: data['service']?.toString() ?? 'central-backend',
          version: data['version']?.toString() ?? '1.0.0',
          facilitiesCount: (data['facilitiesCount'] as num?)?.toInt() ?? 0,
        );
      }
      return BackendHealthResponse(
        isHealthy: false,
        error: 'HTTP ${res.statusCode}',
      );
    } catch (e) {
      return BackendHealthResponse(
        isHealthy: false,
        error: e.toString(),
      );
    }
  }

  /// Incremental pull of facility changes since the client's last known revision cursor.
  Future<SyncPullResponse> pullChanges({
    int sinceRevision = 0,
    int limit = 200,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/sync/pull?since_revision=$sinceRevision&limit=$limit');
      final res = await _httpClient.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawList = (data['facilities'] as List<dynamic>?) ?? [];
        final facilities = rawList
            .map((item) => Hospital.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        final serverRev = (data['serverRevision'] as num?)?.toInt() ?? sinceRevision;
        final serverTime = data['serverTime'] != null
            ? DateTime.tryParse(data['serverTime'] as String) ?? DateTime.now()
            : DateTime.now();

        return SyncPullResponse(
          facilities: facilities,
          serverRevision: serverRev,
          count: facilities.length,
          serverTime: serverTime,
          success: true,
        );
      }
      return SyncPullResponse(
        facilities: const [],
        serverRevision: sinceRevision,
        count: 0,
        serverTime: DateTime.now(),
        success: false,
        error: 'HTTP ${res.statusCode}: ${res.body}',
      );
    } catch (e) {
      return SyncPullResponse(
        facilities: const [],
        serverRevision: sinceRevision,
        count: 0,
        serverTime: DateTime.now(),
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Pushes a batch of queued pending mutations atomically to the backend.
  Future<SyncPushResponse> pushChanges({
    required String clientId,
    required List<SyncMutation> mutations,
    String? authToken,
  }) async {
    if (mutations.isEmpty) {
      return const SyncPushResponse(
        success: true,
        appliedCount: 0,
        serverRevision: 0,
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/sync/push');
      final payload = {
        'clientId': clientId,
        'changes': mutations.map((m) => {
          'id': m.id,
          'idempotencyKey': m.idempotencyKey,
          'facilityId': m.facilityId,
          'changeType': m.changeType,
          'clientRevision': m.clientRevision,
          'payload': m.payload,
          'actorId': m.actorId,
          'actorRole': m.actorRole,
        }).toList(),
      };

      final headers = {
        'Content-Type': 'application/json',
        'X-Client-Id': clientId,
        'Authorization': authToken ?? 'Bearer clinician_token',
      };

      final res = await _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final applied = (data['appliedCount'] as num?)?.toInt() ?? 0;
        final sRev = (data['serverRevision'] as num?)?.toInt() ?? 0;
        final results = ((data['results'] as List<dynamic>?) ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        return SyncPushResponse(
          success: true,
          appliedCount: applied,
          serverRevision: sRev,
          results: results,
        );
      }

      return SyncPushResponse(
        success: false,
        appliedCount: 0,
        serverRevision: 0,
        error: 'HTTP ${res.statusCode}: ${res.body}',
      );
    } catch (e) {
      return SyncPushResponse(
        success: false,
        appliedCount: 0,
        serverRevision: 0,
        error: e.toString(),
      );
    }
  }

  /// Updates operational status directly on the central backend for authorized duty officers.
  Future<Hospital?> updateOperationalStatus({
    required String facilityId,
    required Map<String, dynamic> statusData,
    String? authToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/facilities/$facilityId/status');
      final res = await _httpClient.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authToken ?? 'Bearer duty_officer_token',
        },
        body: jsonEncode(statusData),
      ).timeout(timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['facility'] != null) {
          return Hospital.fromMap(Map<String, dynamic>.from(data['facility'] as Map));
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
