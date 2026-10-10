import 'package:flutter/material.dart';
import '../../models/emergency_referral.dart';
import '../../repositories/emergency_referral_repository.dart';
import '../../services/emergency_referral_service.dart';
import 'emergency_quick_referral_screen.dart';
import 'emergency_referral_detail_screen.dart';

/// Dedicated Emergency Referrals Command Dashboard.
/// Real-time monitoring and coordination across emergency cases, active ambulance transports,
/// and hospital response statuses.
class EmergencyReferralDashboardScreen extends StatefulWidget {
  const EmergencyReferralDashboardScreen({super.key});

  @override
  State<EmergencyReferralDashboardScreen> createState() => _EmergencyReferralDashboardScreenState();
}

class _EmergencyReferralDashboardScreenState extends State<EmergencyReferralDashboardScreen> {
  List<EmergencyReferral> _referrals = [];
  bool _isLoading = true;
  String _selectedTab = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReferrals({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final list = await EmergencyReferralRepository.instance.getAllReferrals(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _referrals = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<EmergencyReferral> get _filteredReferrals {
    return _referrals.where((ref) {
      // Tab filter
      if (_selectedTab == 'IN_TRANSIT') {
        final isTransit = ref.ambulanceStatus == AmbulanceDispatchStatus.enRouteScene ||
            ref.ambulanceStatus == AmbulanceDispatchStatus.patientLoadedInTransit ||
            ref.workflowStatus == EmergencyWorkflowStatus.inTransit;
        if (!isTransit) return false;
      } else if (_selectedTab == 'AWAITING') {
        if (ref.responseStatus != ReceivingResponseStatus.noResponseYet) return false;
      } else if (_selectedTab == 'COMPLETED') {
        if (ref.workflowStatus != EmergencyWorkflowStatus.handoverCompleted) return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchId = ref.referralId.toLowerCase().contains(q);
        final matchPt = ref.patientDisplayLabel.toLowerCase().contains(q);
        final matchHosp = ref.receivingFacilityName.toLowerCase().contains(q);
        final matchDx = ref.emergencyCategory.label.toLowerCase().contains(q);
        if (!matchId && !matchPt && !matchHosp && !matchDx) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transitCount = _referrals.where((r) =>
        r.ambulanceStatus == AmbulanceDispatchStatus.enRouteScene ||
        r.ambulanceStatus == AmbulanceDispatchStatus.patientLoadedInTransit).length;
    final awaitingCount = _referrals.where((r) => r.responseStatus == ReceivingResponseStatus.noResponseYet).length;
    final totalCount = _referrals.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF991B1B), // Emergency Crimson
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Referral Command Center',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Live Triage & Ambulance Response Tracking',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Call Emergency 108',
            icon: const Icon(Icons.phone_in_talk),
            onPressed: () => EmergencyReferralService.launchAmbulanceCall(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadReferrals(forceRefresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.flash_on),
        label: const Text('NEW EMERGENCY', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmergencyQuickReferralScreen()),
          );
          _loadReferrals(forceRefresh: true);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadReferrals(forceRefresh: true),
        child: Column(
          children: [
            // Top Metrics Bar
            _buildTelemetrySummaryBar(totalCount, transitCount, awaitingCount),

            // Search Bar & Filters
            _buildFilterAndSearchSection(),

            // Referrals Feed List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredReferrals.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
                          itemCount: _filteredReferrals.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            final ref = _filteredReferrals[index];
                            return _buildEmergencyCard(ref);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetrySummaryBar(int total, int inTransit, int awaiting) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              label: 'Total Cases',
              value: '$total',
              color: const Color(0xFF0F172A),
              icon: Icons.list_alt,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricTile(
              label: 'In Transit',
              value: '$inTransit',
              color: const Color(0xFF0284C7),
              icon: Icons.airport_shuttle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricTile(
              label: 'Awaiting Res',
              value: '$awaiting',
              color: const Color(0xFFD97706),
              icon: Icons.hourglass_top,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        children: [
          // Search input
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search referral ID, patient, hospital...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
          const SizedBox(height: 10),

          // Segmented Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Cases (${_referrals.length})'),
                const SizedBox(width: 6),
                _buildFilterChip('IN_TRANSIT', '🚑 In Transit'),
                const SizedBox(width: 6),
                _buildFilterChip('AWAITING', '⏳ Awaiting Response'),
                const SizedBox(width: 6),
                _buildFilterChip('COMPLETED', '✅ Handover Complete'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedTab == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF991B1B),
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (val) {
        if (val) setState(() => _selectedTab = key);
      },
    );
  }

  Widget _buildEmergencyCard(EmergencyReferral ref) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmergencyReferralDetailScreen(referralId: ref.referralId),
            ),
          );
          _loadReferrals(forceRefresh: true);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: ID, Category, Version
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF991B1B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ref.referralId,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('v${ref.currentVersion}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  // Time
                  Text(
                    '${ref.createdAt.toLocal().hour.toString().padLeft(2, '0')}:${ref.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Patient Display
              Text(
                ref.patientDisplayLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                '${ref.emergencyCategory.label} • ${ref.presentingComplaint}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),

              // Vitals Summary Line
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Vitals: ${ref.formattedVitals}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 10),

              // Destination & Ambulance Bar
              Row(
                children: [
                  const Icon(Icons.apartment, size: 14, color: Color(0xFF0D7A68)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ref.receivingFacilityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D7A68)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '🚑 ${ref.ambulanceStatus.label}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Status badges & Quick Actions
              Row(
                children: [
                  _buildMiniBadge(
                    label: ref.deliveryStatus.label,
                    isPositive: ref.deliveryStatus == EmergencyDeliveryStatus.delivered,
                  ),
                  const SizedBox(width: 6),
                  _buildMiniBadge(
                    label: ref.responseStatus.label,
                    isPositive: ref.responseStatus == ReceivingResponseStatus.accepted,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => EmergencyReferralService.launchPhoneCall('07312549999'),
                    icon: const Icon(Icons.phone, size: 14),
                    label: const Text('Call', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7A68),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(60, 30),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EmergencyReferralDetailScreen(referralId: ref.referralId),
                        ),
                      );
                      _loadReferrals(forceRefresh: true);
                    },
                    child: const Text('MANAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge({required String label, required bool isPositive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isPositive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_hospital_outlined, size: 64, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            const Text(
              'No Emergency Referrals Found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create a rapid emergency referral when urgent patient transfer is initiated.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.flash_on),
              label: const Text('CREATE EMERGENCY REFERRAL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmergencyQuickReferralScreen()),
                );
                _loadReferrals(forceRefresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
