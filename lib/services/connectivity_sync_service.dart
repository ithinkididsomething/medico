/// Service abstraction for connectivity and offline synchronization state.
abstract class ConnectivitySyncService {
  /// Checks whether internet connectivity is presently established.
  Future<bool> isOnline();

  /// Gets the count of queued referral transfers awaiting network synchronization.
  Future<int> getPendingSyncCount();

  /// Initiates an offline queue flush when network connectivity returns.
  Future<void> syncPendingRecords();
}

/// Baseline implementation placeholder.
class DefaultConnectivitySyncService implements ConnectivitySyncService {
  const DefaultConnectivitySyncService();

  @override
  Future<bool> isOnline() async {
    // Baseline placeholder - offline-first assumption for rural clinics
    return false;
  }

  @override
  Future<int> getPendingSyncCount() async {
    return 0;
  }

  @override
  Future<void> syncPendingRecords() async {
    // Will be implemented in synchronization milestone
  }
}
