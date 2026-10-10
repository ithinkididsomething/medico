import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/sync_mutation.dart';
import 'central_api_client.dart';
import 'local_facility_store.dart';

/// Connection and synchronization state indicator.
enum SyncState {
  synchronized, // Green: In sync with server, 0 pending
  syncing,      // Blue: Network sync in progress
  pending,      // Amber: Unsynced local mutations queued
  offline,      // Grey: No connection, serving cached data
  failed,       // Red/Orange: Sync attempt encountered error
}

/// Snapshot of synchronization engine status for UI widgets.
class SyncStatus {
  final SyncState state;
  final int pendingCount;
  final DateTime? lastSyncTime;
  final int localRevision;
  final int serverRevision;
  final String? lastError;
  final bool isOnline;

  const SyncStatus({
    required this.state,
    required this.pendingCount,
    this.lastSyncTime,
    this.localRevision = 0,
    this.serverRevision = 0,
    this.lastError,
    this.isOnline = true,
  });

  String get label {
    switch (state) {
      case SyncState.synchronized:
        return 'Synchronized';
      case SyncState.syncing:
        return 'Syncing...';
      case SyncState.pending:
        return '$pendingCount Pending Sync';
      case SyncState.offline:
        return 'Offline (Cached Data)';
      case SyncState.failed:
        return 'Sync Error';
    }
  }
}

/// Core synchronization engine managing bi-directional delta synchronization,
/// offline queueing, conflict handling, and network presence detection.
class SyncEngine extends ChangeNotifier {
  final LocalFacilityStore localStore;
  final CentralApiClient apiClient;
  final String clientId;

  SyncState _state = SyncState.offline;
  String? _lastError;
  int _serverRevision = 0;
  bool _isOnline = false;
  bool _isSyncing = false;
  Timer? _periodicTimer;

  SyncEngine({
    required this.localStore,
    required this.apiClient,
    String? clientId,
  }) : clientId = clientId ?? 'device_${DateTime.now().millisecondsSinceEpoch}';

  SyncStatus get status => SyncStatus(
        state: _state,
        pendingCount: localStore.getPendingMutations().length,
        lastSyncTime: localStore.lastSyncedAt,
        localRevision: localStore.lastSyncedRevision,
        serverRevision: _serverRevision > 0 ? _serverRevision : localStore.lastSyncedRevision,
        lastError: _lastError,
        isOnline: _isOnline,
      );

  SyncState get state => _state;
  bool get isSyncing => _isSyncing;

  /// Starts background synchronization loop.
  void startPeriodicSync({Duration interval = const Duration(seconds: 40)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => triggerSync());
  }

  /// Stops periodic timer.
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Triggers a bidirectional synchronization cycle.
  Future<bool> triggerSync({bool force = false}) async {
    if (_isSyncing && !force) return false;

    _isSyncing = true;
    _setState(SyncState.syncing);

    try {
      // 1. Connectivity check
      final health = await apiClient.checkHealth();
      if (!health.isHealthy) {
        _isOnline = false;
        _isSyncing = false;
        final pending = localStore.getPendingMutations();
        _setState(pending.isNotEmpty ? SyncState.pending : SyncState.offline);
        return false;
      }

      _isOnline = true;

      // 2. Push pending mutations first (upstream sync)
      final pendingMutations = localStore.getPendingMutations();
      if (pendingMutations.isNotEmpty) {
        final pushResult = await apiClient.pushChanges(
          clientId: clientId,
          mutations: pendingMutations,
        );

        if (pushResult.success) {
          // Remove applied mutations from persistent queue
          final syncedIds = pendingMutations.map((m) => m.id).toList();
          await localStore.removeMutations(syncedIds);
          if (pushResult.serverRevision > _serverRevision) {
            _serverRevision = pushResult.serverRevision;
          }
        } else {
          // Record mutation errors
          for (final m in pendingMutations) {
            await localStore.updateMutationError(
              m.id,
              pushResult.error ?? 'Push failed',
            );
          }
        }
      }

      // 3. Incremental Pull (downstream sync)
      final pullResult = await apiClient.pullChanges(
        sinceRevision: localStore.lastSyncedRevision,
      );

      if (pullResult.success) {
        _serverRevision = pullResult.serverRevision;
        if (pullResult.facilities.isNotEmpty) {
          await localStore.upsertFacilities(
            pullResult.facilities,
            serverRevision: pullResult.serverRevision,
            syncTime: pullResult.serverTime,
          );
        } else {
          // No new records, update sync timestamp
          await localStore.upsertFacilities(
            [],
            serverRevision: pullResult.serverRevision,
            syncTime: pullResult.serverTime,
          );
        }

        _lastError = null;
        final remainingPending = localStore.getPendingMutations().length;
        _setState(remainingPending > 0 ? SyncState.pending : SyncState.synchronized);
        _isSyncing = false;
        return true;
      } else {
        _lastError = pullResult.error;
        _setState(SyncState.failed);
        _isSyncing = false;
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      _isOnline = false;
      final remaining = localStore.getPendingMutations().length;
      _setState(remaining > 0 ? SyncState.pending : SyncState.failed);
      _isSyncing = false;
      return false;
    }
  }

  /// Enqueues a local change (e.g. bed availability update or observation)
  /// and automatically attempts upstream sync if online.
  Future<void> recordLocalChange({
    required String facilityId,
    required String changeType,
    required Map<String, dynamic> payload,
    String? actorId,
    String? actorRole,
  }) async {
    final mutation = SyncMutation(
      id: 'mut_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (facilityId.hashCode % 9000))}',
      idempotencyKey: 'idem_${DateTime.now().microsecondsSinceEpoch}_$facilityId',
      facilityId: facilityId,
      changeType: changeType,
      payload: payload,
      clientTimestamp: DateTime.now(),
      clientRevision: localStore.lastSyncedRevision,
      actorId: actorId ?? 'clinician_user',
      actorRole: actorRole ?? 'clinician',
    );

    await localStore.enqueueMutation(mutation);
    _setState(SyncState.pending);

    // Opportunistic sync attempt in background
    unawaited(triggerSync());
  }

  void _setState(SyncState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPeriodicSync();
    super.dispose();
  }
}
