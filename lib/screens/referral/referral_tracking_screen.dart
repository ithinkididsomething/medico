import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/enums.dart';
import '../../models/referral.dart';
import '../../models/referral_status_history.dart';
import '../../repositories/referral_repository.dart';
import '../../services/offline_assessment_storage_service.dart';
import '../../widgets/widgets.dart';
import '../../core/utils/navigation_utils.dart';
import 'referral_summary_screen.dart';

/// Clinical Referral Tracking Screen.
/// Displays active and past inter-facility transfers in clean cards/tables,
/// visual progression timelines, and manual clinician status update controls.
class ReferralTrackingScreen extends StatefulWidget {
  final ReferralRepository repository;
  final ReferralFilterTag initialFilterTag;

  ReferralTrackingScreen({
    super.key,
    ReferralRepository? repository,
    this.initialFilterTag = ReferralFilterTag.all,
  }) : repository = repository ?? LocalReferralRepository.instance;

  @override
  State<ReferralTrackingScreen> createState() => _ReferralTrackingScreenState();
}

class _ReferralTrackingScreenState extends State<ReferralTrackingScreen> {
  List<Referral> _allReferrals = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late ReferralFilterTag _filterTag;

  // Track which referral cards have their visual timeline expanded
  final Set<String> _expandedTimelineIds = {};

  @override
  void initState() {
    super.initState();
    _filterTag = widget.initialFilterTag;
    _loadReferrals();
  }

  @override
  void didUpdateWidget(covariant ReferralTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilterTag != widget.initialFilterTag) {
      setState(() {
        _filterTag = widget.initialFilterTag;
      });
    }
  }

  Future<void> _loadReferrals() async {
    setState(() => _isLoading = true);
    final list = await widget.repository.getAllReferrals();
    setState(() {
      _allReferrals = list;
      _isLoading = false;
    });

    if (kDebugMode) {
      print('ReferralTrackingScreen: Loaded ${list.length} referrals.');
    }
  }

  bool _matchesFilterTag(Referral r, ReferralFilterTag tag) {
    switch (tag) {
      case ReferralFilterTag.all:
        return true;
      case ReferralFilterTag.emergency:
        return r.urgencyLevel == UrgencyLevel.emergency;
      case ReferralFilterTag.inTransit:
        return r.status == ReferralStatus.transferred;
      case ReferralFilterTag.completed:
        return r.status == ReferralStatus.completed;
      case ReferralFilterTag.pending:
        return r.status == ReferralStatus.pending;
      case ReferralFilterTag.referred:
        return r.status == ReferralStatus.referred;
      case ReferralFilterTag.accepted:
        return r.status == ReferralStatus.accepted;
    }
  }

  List<Referral> get _filteredReferrals {
    return _allReferrals.where((r) {
      final matchesFilter = _matchesFilterTag(r, _filterTag);
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return matchesFilter;

      final matchesSearch = r.patient.patientId.toLowerCase().contains(q) ||
          r.referralId.toLowerCase().contains(q) ||
          (r.recommendedHospital?.name.toLowerCase().contains(q) ?? false) ||
          r.urgencyLevel.name.toLowerCase().contains(q) ||
          r.status.name.toLowerCase().contains(q);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  /// Opens the manual status update modal.
  /// Strictly manual: Clinician must select the new status and confirm.
  void _onOpenManualStatusUpdateModal(Referral referral, {ReferralStatus? targetStatus}) {
    ReferralStatus selectedStatus = targetStatus ?? _getNextLogicalStatus(referral.status);
    final noteController = TextEditingController(
      text: _getDefaultStatusNote(selectedStatus, referral.recommendedHospital?.name),
    );
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: AppConstants.spacingLg,
              right: AppConstants.spacingLg,
              top: AppConstants.spacingLg,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppConstants.spacingLg,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightMint,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        child: const Icon(Icons.published_with_changes_rounded, color: AppColors.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Update Referral Status',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Referral ID: ${referral.referralId} • Patient: ${referral.patient.patientId}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textNavyMuted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Current Status vs New Status
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text('Current: ', style: TextStyle(fontSize: 12, color: AppColors.textNavySecondary)),
                      StatusBadge(status: referral.status, isCompact: true),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textNavyMuted),
                      const Text('New: ', style: TextStyle(fontSize: 12, color: AppColors.textNavySecondary)),
                      StatusBadge(status: selectedStatus, isCompact: true),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Status Selection Header
                  const Text(
                    'Select New Status (Manual Entry Only):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                  ),
                  const SizedBox(height: 8),

                  // Interactive Status Selection Option Cards
                  ...ReferralStatus.values.map((status) {
                    final isSelected = selectedStatus == status;
                    final color = _getStatusColor(status);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        key: ValueKey('status_option_${status.name}'),
                        onTap: isSubmitting
                            ? null
                            : () {
                                setModalState(() {
                                  selectedStatus = status;
                                  noteController.text = _getDefaultStatusNote(
                                    status,
                                    referral.recommendedHospital?.name,
                                  );
                                });
                              },
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surfaceMutedLight,
                            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                            border: Border.all(
                              color: isSelected ? color : AppColors.borderLight,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withValues(alpha: 0.2) : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getStatusIcon(status),
                                  size: 16,
                                  color: isSelected ? color : AppColors.textNavySecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      status.displayName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? AppColors.textNavyPrimary : AppColors.textNavySecondary,
                                      ),
                                    ),
                                    Text(
                                      _getStatusShortDescription(status),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected ? AppColors.textNavyPrimary : AppColors.textNavyMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, size: 20, color: color)
                              else
                                const Icon(Icons.radio_button_unchecked_rounded, size: 20, color: AppColors.borderDark),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  // Clinical Transition Note Field
                  const Text(
                    'Status Change Note / Audit Memo:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter clinical handover memo or transport details...',
                      filled: true,
                      fillColor: AppColors.surfaceMutedLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),

                  const SizedBox(height: 16),

                  // Confirm Action
                  PrimaryButton(
                    text: isSubmitting ? 'Updating Status...' : 'Confirm Manual Status Update',
                    icon: isSubmitting ? null : Icons.check_circle_rounded,
                    isLoading: isSubmitting,
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            try {
                              final noteText = noteController.text.trim();
                              final updated = await widget.repository.updateStatus(
                                referral.referralId,
                                selectedStatus,
                                noteText.isNotEmpty
                                    ? noteText
                                    : _getDefaultStatusNote(selectedStatus, referral.recommendedHospital?.name),
                                timestamp: DateTime.now(),
                              );

                              if (kDebugMode) {
                                print('ReferralTrackingScreen: Manual status change for RefID=${referral.referralId} -> ${selectedStatus.name}, success=${updated != null}');
                              }

                              if (!mounted) return;

                              if (updated != null) {
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                await _loadReferrals();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.primaryGreen,
                                      content: Text(
                                        'Referral ${referral.referralId} updated to ${selectedStatus.displayName}.',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                setModalState(() => isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.statusRed,
                                      content: Text(
                                        'Failed to update status for ${referral.referralId}. Referral not found.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.statusRed,
                                    content: Text('Error updating status: $e'),
                                  ),
                                );
                              }
                            }
                          },
                  ),

                  const SizedBox(height: 8),

                  SecondaryButton(
                    text: 'Cancel',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(ReferralStatus status) {
    switch (status) {
      case ReferralStatus.pending:
        return AppColors.statusAmber;
      case ReferralStatus.referred:
        return AppColors.statusInfo;
      case ReferralStatus.accepted:
        return AppColors.primaryDarkGreen;
      case ReferralStatus.transferred:
        return AppColors.secondarySlateTeal;
      case ReferralStatus.completed:
        return AppColors.primaryGreen;
    }
  }

  String _getStatusShortDescription(ReferralStatus status) {
    switch (status) {
      case ReferralStatus.pending:
        return 'Triage formulated, awaiting transfer authorization';
      case ReferralStatus.referred:
        return 'Outbound referral order transmitted to receiving hospital';
      case ReferralStatus.accepted:
        return 'Receiving facility verified capacity & specialist acceptance';
      case ReferralStatus.transferred:
        return 'Patient departed clinic via emergency transport / ambulance';
      case ReferralStatus.completed:
        return 'Patient safely admitted and care handover finalized';
    }
  }

  IconData _getStatusIcon(ReferralStatus status) {
    switch (status) {
      case ReferralStatus.pending:
        return Icons.hourglass_top_rounded;
      case ReferralStatus.referred:
        return Icons.send_rounded;
      case ReferralStatus.accepted:
        return Icons.check_circle_outline_rounded;
      case ReferralStatus.transferred:
        return Icons.airport_shuttle_rounded;
      case ReferralStatus.completed:
        return Icons.task_alt_rounded;
    }
  }

  ReferralStatus _getNextLogicalStatus(ReferralStatus current) {
    switch (current) {
      case ReferralStatus.pending:
        return ReferralStatus.referred;
      case ReferralStatus.referred:
        return ReferralStatus.accepted;
      case ReferralStatus.accepted:
        return ReferralStatus.transferred;
      case ReferralStatus.transferred:
        return ReferralStatus.completed;
      case ReferralStatus.completed:
        return ReferralStatus.completed;
    }
  }

  String _getDefaultStatusNote(ReferralStatus status, String? hospitalName) {
    final hosp = hospitalName ?? 'receiving hospital';
    switch (status) {
      case ReferralStatus.pending:
        return 'Triage formulated; pending dispatch authorization.';
      case ReferralStatus.referred:
        return 'Outbound referral order transmitted to $hosp.';
      case ReferralStatus.accepted:
        return '$hosp confirmed acceptance and bed availability.';
      case ReferralStatus.transferred:
        return 'Patient departed referring clinic via emergency transport.';
      case ReferralStatus.completed:
        return 'Patient safely admitted and care transfer completed at $hosp.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReferrals;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            AppHeader(
              title: 'Referral Tracking',
              subtitle: 'Active Inter-Facility Transfers',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => SafeNavigation.pop(context, fallbackTab: 0),
                tooltip: 'Back to Dashboard',
              ),
              showClinicStatusBar: true,
            ),

            // Top Status Metrics Bar
            _buildStatusMetricsBar(),

            // Search & Filter Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: 8),
              child: Column(
                children: [
                  SearchField(
                    hintText: 'Search by Patient ID (e.g. P001), Ref ID, Hospital...',
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildStatusFilterChips(),
                  if (_filterTag != ReferralFilterTag.all)
                    _buildActiveFilterBanner(),
                ],
              ),
            ),

            // Main Referral Cards / Table List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadReferrals,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppConstants.spacingMd),
                            itemCount: filtered.length,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildReferralCard(item);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMetricsBar() {
    final emergencyCount = _allReferrals.where((r) => r.urgencyLevel == UrgencyLevel.emergency).length;
    final inTransitCount = _allReferrals.where((r) => r.status == ReferralStatus.transferred).length;
    final completedCount = _allReferrals.where((r) => r.status == ReferralStatus.completed).length;
    final pendingCount = _allReferrals.where((r) => r.status == ReferralStatus.pending).length;
    final referredCount = _allReferrals.where((r) => r.status == ReferralStatus.referred).length;
    final acceptedCount = _allReferrals.where((r) => r.status == ReferralStatus.accepted).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMetricPill('Total', _allReferrals.length, AppColors.textNavyPrimary, ReferralFilterTag.all),
            const SizedBox(width: 8),
            _buildMetricPill('Emergency', emergencyCount, AppColors.statusRed, ReferralFilterTag.emergency),
            const SizedBox(width: 8),
            _buildMetricPill('In Transit', inTransitCount, AppColors.secondarySlateTeal, ReferralFilterTag.inTransit),
            const SizedBox(width: 8),
            _buildMetricPill('Completed', completedCount, AppColors.primaryGreen, ReferralFilterTag.completed),
            const SizedBox(width: 8),
            _buildMetricPill('Pending', pendingCount, AppColors.statusAmber, ReferralFilterTag.pending),
            const SizedBox(width: 8),
            _buildMetricPill('Referred', referredCount, AppColors.statusInfo, ReferralFilterTag.referred),
            const SizedBox(width: 8),
            _buildMetricPill('Accepted', acceptedCount, AppColors.primaryDarkGreen, ReferralFilterTag.accepted),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill(String label, int count, Color color, ReferralFilterTag tag) {
    final isSelected = _filterTag == tag;

    return InkWell(
      onTap: () {
        setState(() {
          _filterTag = tag;
        });
      },
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surfaceMutedLight,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: Border.all(
            color: isSelected ? color : AppColors.borderLight,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : AppColors.textNavySecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? color : AppColors.borderLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.textNavyPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All Referrals'),
            selected: _filterTag == ReferralFilterTag.all,
            onSelected: (_) => setState(() => _filterTag = ReferralFilterTag.all),
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.notification_important_rounded, size: 14, color: AppColors.statusRed),
            label: const Text('Emergency'),
            selected: _filterTag == ReferralFilterTag.emergency,
            selectedColor: AppColors.statusRed.withValues(alpha: 0.18),
            onSelected: (selected) {
              setState(() {
                _filterTag = selected ? ReferralFilterTag.emergency : ReferralFilterTag.all;
              });
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.airport_shuttle_rounded, size: 14, color: AppColors.secondarySlateTeal),
            label: const Text('In Transit'),
            selected: _filterTag == ReferralFilterTag.inTransit,
            selectedColor: AppColors.secondarySlateTeal.withValues(alpha: 0.18),
            onSelected: (selected) {
              setState(() {
                _filterTag = selected ? ReferralFilterTag.inTransit : ReferralFilterTag.all;
              });
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primaryGreen),
            label: const Text('Completed'),
            selected: _filterTag == ReferralFilterTag.completed,
            selectedColor: AppColors.primaryGreen.withValues(alpha: 0.18),
            onSelected: (selected) {
              setState(() {
                _filterTag = selected ? ReferralFilterTag.completed : ReferralFilterTag.all;
              });
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.hourglass_top_rounded, size: 14, color: AppColors.statusAmber),
            label: const Text('Pending'),
            selected: _filterTag == ReferralFilterTag.pending,
            selectedColor: AppColors.statusAmber.withValues(alpha: 0.18),
            onSelected: (selected) {
              setState(() {
                _filterTag = selected ? ReferralFilterTag.pending : ReferralFilterTag.all;
              });
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.send_rounded, size: 14, color: AppColors.statusInfo),
            label: const Text('Referred'),
            selected: _filterTag == ReferralFilterTag.referred,
            selectedColor: AppColors.statusInfo.withValues(alpha: 0.18),
            onSelected: (selected) {
              setState(() {
                _filterTag = selected ? ReferralFilterTag.referred : ReferralFilterTag.all;
              });
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primaryDarkGreen),
            label: const Text('Accepted'),
            selected: _filterTag == ReferralFilterTag.accepted,
            selectedColor: AppColors.primaryDarkGreen.withValues(alpha: 0.18),
            onSelected: (selected) {
              setState(() {
                _filterTag = selected ? ReferralFilterTag.accepted : ReferralFilterTag.all;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterBanner() {
    if (_filterTag == ReferralFilterTag.all) {
      return const SizedBox.shrink();
    }

    final Color tagColor;
    final IconData tagIcon;
    switch (_filterTag) {
      case ReferralFilterTag.emergency:
        tagColor = AppColors.statusRed;
        tagIcon = Icons.notification_important_rounded;
        break;
      case ReferralFilterTag.inTransit:
        tagColor = AppColors.secondarySlateTeal;
        tagIcon = Icons.airport_shuttle_rounded;
        break;
      case ReferralFilterTag.completed:
        tagColor = AppColors.primaryGreen;
        tagIcon = Icons.check_circle_rounded;
        break;
      case ReferralFilterTag.pending:
        tagColor = AppColors.statusAmber;
        tagIcon = Icons.hourglass_top_rounded;
        break;
      case ReferralFilterTag.referred:
        tagColor = AppColors.statusInfo;
        tagIcon = Icons.send_rounded;
        break;
      case ReferralFilterTag.accepted:
        tagColor = AppColors.primaryDarkGreen;
        tagIcon = Icons.check_circle_outline_rounded;
        break;
      case ReferralFilterTag.all:
        tagColor = AppColors.textNavyPrimary;
        tagIcon = Icons.filter_alt_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: tagColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(tagIcon, size: 14, color: tagColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Filtered by: ${_filterTag.displayName} (${_filteredReferrals.length} cases)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tagColor,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _filterTag = ReferralFilterTag.all),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Show All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tagColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.close_rounded, size: 13, color: tagColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REFERRAL CARD / TABLE ROW
  // Format requested: P001 | Emergency | Hospital B | Pending
  // ===========================================================================

  Widget _buildReferralCard(Referral referral) {
    final patient = referral.patient;
    final hospName = referral.recommendedHospital?.name ?? 'Local Treatment';
    final isTimelineExpanded = _expandedTimelineIds.contains(referral.referralId);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      child: AppCard(
        accentColor: referral.urgencyLevel == UrgencyLevel.emergency
            ? AppColors.statusRed
            : (referral.urgencyLevel == UrgencyLevel.urgent ? AppColors.statusAmber : AppColors.primaryGreen),
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Structured Header Row:
            // Example: P001 | Emergency | Hospital B | Pending
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMutedLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Patient ID
                    Text(
                      patient.patientId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                    const Text('  |  ', style: TextStyle(color: AppColors.borderDark, fontWeight: FontWeight.w300)),

                    // Urgency
                    UrgencyBadge(urgencyLevel: referral.urgencyLevel, isCompact: true),
                    const Text('  |  ', style: TextStyle(color: AppColors.borderDark, fontWeight: FontWeight.w300)),

                    // Hospital
                    Text(
                      hospName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                    const Text('  |  ', style: TextStyle(color: AppColors.borderDark, fontWeight: FontWeight.w300)),

                    // Status
                    StatusBadge(status: referral.status, isCompact: true),
                    if (OfflineAssessmentStorageService.instance.getLifecycleState(referral.referralId) != null) ...[
                      const Text('  |  ', style: TextStyle(color: AppColors.borderDark, fontWeight: FontWeight.w300)),
                      Builder(
                        builder: (_) {
                          final state = OfflineAssessmentStorageService.instance.getLifecycleState(referral.referralId)!;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: state.isOfflinePending ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(state.icon, size: 10, color: state.isOfflinePending ? const Color(0xFF92400E) : const Color(0xFF166534)),
                                const SizedBox(width: 3),
                                Text(
                                  state.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: state.isOfflinePending ? const Color(0xFF92400E) : const Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppConstants.spacingSm),

            // Secondary Info: Referral ID, Chief Complaint, Transit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Ref: ${referral.referralId} • ${patient.age}y ${patient.sex.displayName}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Transit: ${referral.formattedDistance} (~${referral.formattedTravelTime} by Car)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondarySlateTeal),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Complaint: ${patient.mainComplaint}',
              style: const TextStyle(fontSize: 12, color: AppColors.textNavyPrimary, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: AppConstants.spacingMd),

            // Visual Timeline Toggle Button
            InkWell(
              onTap: () {
                setState(() {
                  if (isTimelineExpanded) {
                    _expandedTimelineIds.remove(referral.referralId);
                  } else {
                    _expandedTimelineIds.add(referral.referralId);
                  }
                });
              },
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isTimelineExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.secondarySlateTeal,
                    ),
                    Expanded(
                      child: Text(
                        isTimelineExpanded
                            ? 'Hide Visual Transfer Timeline'
                            : 'View Visual Transfer Timeline (Pending ↓ Referred ↓ Accepted ↓ Transferred ↓ Completed)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondarySlateTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ========================================================
            // VISUAL TIMELINE:
            // Pending ↓ Referred ↓ Accepted ↓ Transferred ↓ Completed
            // ========================================================
            if (isTimelineExpanded) ...[
              const SizedBox(height: 8),
              _buildVisualTimeline(referral),
            ],

            const SizedBox(height: AppConstants.spacingMd),

            // Action Buttons:
            // 1. Manual Status Update
            // 2. View Summary
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Update Status',
                    icon: Icons.edit_note_rounded,
                    onPressed: () => _onOpenManualStatusUpdateModal(referral),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: SecondaryButton(
                    text: 'View Summary',
                    icon: Icons.description_outlined,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (ctx) => ReferralSummaryScreen(
                            referral: referral,
                            repository: widget.repository,
                          ),
                        ),
                      ).then((_) => _loadReferrals());
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Visual timeline displaying the 5 sequential stages:
  /// Pending ↓ Referred ↓ Accepted ↓ Transferred ↓ Completed
  Widget _buildVisualTimeline(Referral referral) {
    const stages = [
      ReferralStatus.pending,
      ReferralStatus.referred,
      ReferralStatus.accepted,
      ReferralStatus.transferred,
      ReferralStatus.completed,
    ];

    final currentIdx = stages.indexOf(referral.status);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMutedLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(stages.length, (idx) {
          final stage = stages[idx];
          final isCompleted = idx < currentIdx;
          final isCurrent = idx == currentIdx;
          final isPending = idx > currentIdx;
          final isLast = idx == stages.length - 1;

          // Find audit record timestamp if exists
          final historyEntry = referral.statusHistory.firstWhere(
            (h) => h.status == stage,
            orElse: () => ReferralStatusHistory(
              status: stage,
              timestamp: DateTime.now(),
              note: '',
            ),
          );
          final hasHistory = referral.statusHistory.any((h) => h.status == stage);

          return InkWell(
            onTap: () => _onOpenManualStatusUpdateModal(referral, targetStatus: stage),
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Node + Line
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                            ? AppColors.primaryGreen
                            : (isCompleted ? AppColors.primaryLightMint : Colors.white),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primaryGreen
                              : (isCompleted ? AppColors.primaryGreen : AppColors.borderLight),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 13, color: AppColors.primaryGreen)
                            : (isCurrent
                                ? const Icon(Icons.circle, size: 8, color: Colors.white)
                                : null),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 20,
                        color: isCompleted ? AppColors.primaryGreen : AppColors.borderLight,
                      ),
                  ],
                ),
                const SizedBox(width: 10),

                // Stage Label & Audit Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stage.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCurrent ? FontWeight.w800 : (isCompleted ? FontWeight.w700 : FontWeight.w500),
                                  color: isCurrent
                                      ? AppColors.primaryDarkGreen
                                      : (isCompleted ? AppColors.textNavyPrimary : AppColors.textNavyMuted),
                                ),
                              ),
                              if (hasHistory && historyEntry.note.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  historyEntry.note,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textNavySecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasHistory)
                          Text(
                            '${historyEntry.timestamp.hour.toString().padLeft(2, '0')}:${historyEntry.timestamp.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyMuted),
                          )
                        else if (isPending)
                          const Text(
                            'Pending update',
                            style: TextStyle(fontSize: 10, color: AppColors.textNavyMuted, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textNavyMuted),
            const SizedBox(height: AppConstants.spacingMd),
            const Text(
              'No Matching Referrals Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try clearing search filters or adjust status tabs.',
              style: TextStyle(fontSize: 12, color: AppColors.textNavyMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _filterTag = ReferralFilterTag.all;
                });
              },
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear All Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
