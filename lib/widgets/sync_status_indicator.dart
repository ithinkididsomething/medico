import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../repositories/offline_first_hospital_repository.dart';
import '../services/sync/sync_engine.dart';
import 'primary_button.dart';

/// Compact, interactive synchronization status pill for headers and app bars.
class SyncStatusPill extends StatelessWidget {
  final SyncEngine? engine;
  final bool compact;

  const SyncStatusPill({
    super.key,
    this.engine,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final syncEngine = engine ?? OfflineFirstHospitalRepository.instance.syncEngine;

    return AnimatedBuilder(
      animation: syncEngine,
      builder: (context, _) {
        final status = syncEngine.status;
        final config = _getDisplayConfig(status);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showSyncDetailsSheet(context, engine: syncEngine),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: config.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: config.borderColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(config.icon, size: 14, color: config.textColor),
                  if (!compact) ...[
                    const SizedBox(width: 5),
                    Text(
                      config.text,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: config.textColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _PillConfig _getDisplayConfig(SyncStatus status) {
    switch (status.state) {
      case SyncState.synchronized:
        return _PillConfig(
          icon: Icons.cloud_done_rounded,
          text: 'Synced',
          backgroundColor: const Color(0xFFE8F5E9),
          borderColor: const Color(0xFFA5D6A7),
          textColor: const Color(0xFF2E7D32),
        );
      case SyncState.syncing:
        return _PillConfig(
          icon: Icons.sync_rounded,
          text: 'Syncing...',
          backgroundColor: const Color(0xFFE3F2FD),
          borderColor: const Color(0xFF90CAF9),
          textColor: const Color(0xFF1565C0),
        );
      case SyncState.pending:
        return _PillConfig(
          icon: Icons.cloud_upload_outlined,
          text: '${status.pendingCount} Pending',
          backgroundColor: const Color(0xFFFFF8E1),
          borderColor: const Color(0xFFFFE082),
          textColor: const Color(0xFFE65100),
        );
      case SyncState.offline:
        return _PillConfig(
          icon: Icons.cloud_off_outlined,
          text: 'Offline Cache',
          backgroundColor: const Color(0xFFECEFF1),
          borderColor: const Color(0xFFCFD8DC),
          textColor: const Color(0xFF546E7A),
        );
      case SyncState.failed:
        return _PillConfig(
          icon: Icons.sync_problem_rounded,
          text: 'Sync Error',
          backgroundColor: const Color(0xFFFFEBEE),
          borderColor: const Color(0xFFFFCDD2),
          textColor: const Color(0xFFC62828),
        );
    }
  }
}

class _PillConfig {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _PillConfig({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}

/// Displays comprehensive bottom sheet for network state, sync history, and manual trigger.
void showSyncDetailsSheet(BuildContext context, {SyncEngine? engine}) {
  final syncEngine = engine ?? OfflineFirstHospitalRepository.instance.syncEngine;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SyncDetailsSheetContent(engine: syncEngine),
  );
}

class _SyncDetailsSheetContent extends StatefulWidget {
  final SyncEngine engine;

  const _SyncDetailsSheetContent({required this.engine});

  @override
  State<_SyncDetailsSheetContent> createState() => _SyncDetailsSheetContentState();
}

class _SyncDetailsSheetContentState extends State<_SyncDetailsSheetContent> {
  bool _isManualSyncing = false;

  Future<void> _handleManualSync() async {
    setState(() => _isManualSyncing = true);
    await widget.engine.triggerSync(force: true);
    if (mounted) {
      setState(() => _isManualSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.engine,
      builder: (context, _) {
        final status = widget.engine.status;
        final pending = widget.engine.localStore.getPendingMutations();

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLightMint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cloud_sync_rounded,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Centralized Synchronization',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textNavyPrimary,
                          ),
                        ),
                        Text(
                          'Authoritative Healthcare Registry Sync Engine',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Status Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      'Connection Status',
                      status.isOnline ? 'Online (Authoritative Backend)' : 'Offline (Local Persistent Cache)',
                      status.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      status.isOnline ? AppColors.statusGreen : Colors.grey,
                    ),
                    const Divider(height: 18),
                    _buildInfoRow(
                      'Current State',
                      status.label,
                      Icons.info_outline_rounded,
                      AppColors.primaryGreen,
                    ),
                    const Divider(height: 18),
                    _buildInfoRow(
                      'Last Synchronized',
                      status.lastSyncTime != null
                          ? _formatTime(status.lastSyncTime!)
                          : 'Never (Baseline offline data)',
                      Icons.access_time_rounded,
                      Colors.grey.shade700,
                    ),
                    const Divider(height: 18),
                    _buildInfoRow(
                      'Database Revisions',
                      'Local: rev ${status.localRevision} • Central: rev ${status.serverRevision}',
                      Icons.layers_outlined,
                      Colors.grey.shade700,
                    ),
                    const Divider(height: 18),
                    _buildInfoRow(
                      'Offline Queue',
                      '${status.pendingCount} mutations awaiting upload',
                      Icons.queue_rounded,
                      status.pendingCount > 0 ? AppColors.statusAmber : AppColors.statusGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Clinical Data Freshness Notice (Section 5 Requirement)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Clinical Safety Note: Dynamic bed capacity and diversion statuses expire after 60 minutes of inactivity. Referral guidance prioritizes verified baseline capabilities offline without network blockage.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.brown.shade800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (pending.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Pending Local Mutations (${pending.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textNavyPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pending.length,
                    itemBuilder: (ctx, i) {
                      final m = pending[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pending_actions_rounded, size: 16, color: AppColors.statusAmber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${m.changeType} (${m.facilityId})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              _formatTime(m.clientTimestamp),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Action Trigger Button
              PrimaryButton(
                text: _isManualSyncing ? 'Synchronizing Network...' : 'Sync Now with Central Registry',
                icon: Icons.sync_rounded,
                isLoading: _isManualSyncing || status.state == SyncState.syncing,
                onPressed: _handleManualSync,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textNavyPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
