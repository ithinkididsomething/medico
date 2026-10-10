import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/facility_resource.dart';
import '../../models/indore_hospital_dataset.dart';
import '../../repositories/facility_resource_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/section_header.dart';

/// Dedicated screen for Clinic and Hospital Administrators to register, manage,
/// and update medical infrastructure, 7-category equipment, bed capacity, and staffing.
class FacilityResourcesScreen extends StatefulWidget {
  final String? initialFacilityId;

  const FacilityResourcesScreen({
    super.key,
    this.initialFacilityId,
  });

  @override
  State<FacilityResourcesScreen> createState() => _FacilityResourcesScreenState();
}

class _FacilityResourcesScreenState extends State<FacilityResourcesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedFacilityId;
  FacilityCompleteResources? _resources;
  bool _isLoading = true;
  String? _errorMessage;

  // Filter & Search states for Equipment Tab
  ResourceCategory? _selectedCategoryFilter;
  String _searchQuery = '';
  ResourceOperationalStatus? _statusFilter;

  // Department filter & search states
  String _departmentSearchQuery = '';
  bool _departmentEmergencyOnly = false;
  bool _departmentOperationalOnly = false;

  // Simulated active user credentials
  final String _currentActorId = 'admin_user';
  final String _currentActorRole = 'admin'; // 'admin', 'hospital_duty_officer', 'clinician'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _selectedFacilityId = widget.initialFacilityId ??
        FacilityResourceRepository.instance.activeFacilityId;
    _resources = FacilityResourceRepository.instance.getCachedResources(_selectedFacilityId);
    _isLoading = _resources == null;
    _loadFacilityData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilityData({bool forceRefresh = false}) async {
    if (_resources == null || forceRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await FacilityResourceRepository.instance
          .getFacilityResources(_selectedFacilityId, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _resources = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load facility infrastructure: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onFacilityChanged(String? newId) {
    if (newId != null && newId != _selectedFacilityId) {
      final cached = FacilityResourceRepository.instance.getCachedResources(newId);
      setState(() {
        _selectedFacilityId = newId;
        _resources = cached;
        _isLoading = cached == null;
      });
      FacilityResourceRepository.instance.setActiveFacilityId(newId);
      _loadFacilityData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar & Facility Selector
            _buildFacilitySelectorBar(context),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primaryGreen,
                labelColor: AppColors.primaryGreen,
                unselectedLabelColor: AppColors.textGreyMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Profile & Support'),
                  Tab(icon: Icon(Icons.biotech_outlined, size: 18), text: 'Equipment & Tech'),
                  Tab(icon: Icon(Icons.meeting_room_outlined, size: 18), text: 'Departments & Services'),
                  Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Staff & Personnel'),
                  Tab(icon: Icon(Icons.hotel_outlined, size: 18), text: 'Beds & Capacity'),
                  Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Verification & Audit'),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.borderLight),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const LoadingState(message: 'Loading verified facility infrastructure...')
                  : _errorMessage != null
                      ? _buildErrorView()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildProfileAndSupportTab(),
                            _buildEquipmentInventoryTab(),
                            _buildDepartmentsAndServicesTab(),
                            _buildStaffAffiliationsTab(),
                            _buildBedsAndCapacityTab(),
                            _buildVerificationAuditTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitySelectorBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.domain_rounded, color: AppColors.primaryGreen, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Facility Infrastructure Management',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textNavyPrimary,
                      ),
                    ),
                    Text(
                      'Maintain equipment, live capacity & capabilities in advance for automated referral matching',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textGreyMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryGreen),
                tooltip: 'Refresh Infrastructure Data',
                onPressed: () => _loadFacilityData(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFacilityId,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                      items: IndoreHospitalDataset.allFacilities.map((f) {
                        final fid = f.hospitalId;
                        final name = f.name;
                        final isTer = f.emergencyCare;
                        return DropdownMenuItem<String>(
                          value: fid,
                          child: Text(
                            '$name (${isTer ? "Tertiary / 24h" : "Clinic / PHC"})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _onFacilityChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shield_outlined, color: AppColors.primaryGreen, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Admin Authorized',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.urgencyEmergencyRed),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'An error occurred', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Retry',
              onPressed: () => _loadFacilityData(forceRefresh: true),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 1: Profile & Supporting Infrastructure
  // ==========================================================================
  Widget _buildProfileAndSupportTab() {
    final res = _resources!;
    final prof = res.profile;
    final supp = res.supportingInfrastructure;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Cards Row
          _buildKPIMetricsRow(res),
          const SizedBox(height: AppConstants.spacingMd),

          // Facility Profile Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        res.facilityName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.statusGreenBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        prof.verificationStatus.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _buildDetailRow('Facility ID', res.facilityId),
                _buildDetailRow('Category Type', res.facilityType.replaceAll('_', ' ').toUpperCase()),
                _buildDetailRow('Physical Address', res.address),
                _buildDetailRow('GPS Coordinates', '${res.latitude.toStringAsFixed(4)}° N, ${res.longitude.toStringAsFixed(4)}° E'),
                _buildDetailRow('Contact Phone', prof.contactNumber),
                _buildDetailRow('Official Email', prof.officialEmail),
                _buildDetailRow('Operating Hours', prof.openingHours),
                _buildDetailRow('Operating Days', prof.operatingDays),
                _buildDetailRow('Establishment License', prof.licenseNumber),
                _buildDetailRow('Licensing Authority', prof.registrationAuthority),
                _buildDetailRow('Registered Administrator', prof.adminName),
                _buildDetailRow('Emergency Services', prof.emergencyServicesDetail),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Supporting Infrastructure Card
          const SectionHeader(
            title: 'Supporting Hospital Infrastructure',
            subtitle: 'Critical utilities, life-support logistics, and emergency readiness',
          ),
          AppCard(
            child: Column(
              children: [
                _buildInfrastructureTile(
                  Icons.local_shipping_outlined,
                  'Ambulance Arrangements',
                  supp.ambulanceArrangements,
                  AppColors.urgencyEmergencyRed,
                ),
                const Divider(height: 1),
                _buildInfrastructureTile(
                  Icons.bloodtype_outlined,
                  'Blood Bank & Storage Access',
                  supp.bloodBankAccess,
                  Colors.red.shade700,
                ),
                const Divider(height: 1),
                _buildInfrastructureTile(
                  Icons.local_pharmacy_outlined,
                  'Pharmacy Availability',
                  supp.pharmacyAvailable,
                  AppColors.primaryGreen,
                ),
                const Divider(height: 1),
                _buildInfrastructureTile(
                  Icons.air_outlined,
                  'Medical Oxygen Supply Infrastructure',
                  supp.oxygenInfrastructure,
                  AppColors.tealAccentDark,
                ),
                const Divider(height: 1),
                _buildInfrastructureTile(
                  Icons.electrical_services_outlined,
                  'Continuous Power Backup',
                  supp.powerBackup,
                  Colors.amber.shade900,
                ),
                const Divider(height: 1),
                _buildInfrastructureTile(
                  Icons.masks_outlined,
                  'Infection Control & Airborne Isolation',
                  '${supp.isolationCapability} • ${supp.infectionControl}',
                  Colors.deepPurple,
                ),
                const Divider(height: 1),
                _buildInfrastructureTile(
                  Icons.video_camera_front_outlined,
                  'Telemedicine & Network Empanelment',
                  '${supp.telemedicineCapability} • ${supp.referralPartnerships}',
                  Colors.blue.shade700,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Edit Action Button
          SecondaryButton(
            text: 'Update Facility Profile Details',
            icon: Icons.edit_note_outlined,
            onPressed: () => _showEditProfileDialog(prof),
          ),
          const SizedBox(height: AppConstants.spacingXl),
        ],
      ),
    );
  }

  Widget _buildKPIMetricsRow(FacilityCompleteResources res) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetricBox('Total Equipment', '${res.inventory.length}', Icons.biotech, AppColors.tealAccentDark),
            _buildMetricBox('Operational', '${res.inventory.where((i) => i.isOperational).length}', Icons.check_circle_outline, AppColors.statusGreen),
            _buildMetricBox('Available Beds', '${res.availableBeds} / ${res.totalBeds}', Icons.hotel, AppColors.primaryGreen),
            _buildMetricBox('ICU Beds Free', '${res.availableIcuBeds}', Icons.monitor_heart, AppColors.urgencyEmergencyRed),
          ],
        );
      },
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppColors.textGreyMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGreyMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textNavyPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfrastructureTile(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textNavyPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textGreyDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 2: Medical Equipment & Technology Inventory (7 Categories)
  // ==========================================================================
  Widget _buildEquipmentInventoryTab() {
    final res = _resources!;
    var items = res.inventory;

    // Filter by Category
    if (_selectedCategoryFilter != null) {
      items = items.where((i) => i.category == _selectedCategoryFilter).toList();
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.modelSpec.toLowerCase().contains(q) ||
          i.locationInFacility.toLowerCase().contains(q)).toList();
    }

    // Filter by Status
    if (_statusFilter != null) {
      items = items.where((i) => i.operationalStatus == _statusFilter).toList();
    }

    return Column(
      children: [
        // Top Filter Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search equipment, models, locations...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Equipment', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddEquipmentModal(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      selected: _selectedCategoryFilter == null,
                      label: const Text('All Categories'),
                      onSelected: (_) => setState(() => _selectedCategoryFilter = null),
                    ),
                    ...ResourceCategory.values.map((cat) {
                      final count = res.inventory.where((i) => i.category == cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                          selected: _selectedCategoryFilter == cat,
                          avatar: Icon(cat.icon, size: 14, color: cat.color),
                          label: Text('${cat.label} ($count)'),
                          onSelected: (sel) => setState(() => _selectedCategoryFilter = sel ? cat : null),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Equipment List
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingXl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textGreyMuted),
                        SizedBox(height: 8),
                        Text(
                          'No medical equipment matching filters',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppConstants.spacingSm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildEquipmentCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEquipmentCard(FacilityResourceItem item) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: item.category.color.withValues(alpha: 0.12),
                child: Icon(item.category.icon, size: 20, color: item.category.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textNavyPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.modelSpec.isNotEmpty ? "${item.modelSpec} • " : ""}${item.locationInFacility}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGreyDark),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.operationalStatus.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  item.operationalStatus.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item.operationalStatus.color,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          // Metadata grid
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildTag(Icons.numbers_outlined, 'Installed: ${item.quantityInstalled} | Oper: ${item.quantityOperational}'),
              _buildTag(Icons.business_center_outlined, item.ownershipType.label),
              _buildTag(Icons.access_time_outlined, item.availabilitySchedule),
              _buildTag(Icons.person_pin_outlined, item.operatorRequirements),
              _buildTag(
                item.isVerified ? Icons.verified : Icons.pending_actions,
                '${item.verificationStatus.label} (${item.verifiedBy})',
                color: item.verificationStatus.color,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.verified_outlined, size: 16),
                label: const Text('Verify / Audit', style: TextStyle(fontSize: 12)),
                onPressed: () => _showVerifyDialog(item),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                onPressed: () => _showEditEquipmentModal(item),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.urgencyEmergencyRed),
                tooltip: 'Decommission Equipment',
                onPressed: () => _confirmDecommissionEquipment(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.textGreyDark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildInfoBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 3: Departments & Specialized Services (Prompt Section 7)
  // ==========================================================================
  Widget _buildDepartmentsAndServicesTab() {
    final res = _resources!;
    var depts = res.departments;

    if (_departmentSearchQuery.isNotEmpty) {
      final q = _departmentSearchQuery.toLowerCase();
      depts = depts.where((d) {
        final matchesName = d.departmentName.toLowerCase().contains(q);
        final matchesHOD = d.headOfDepartment.toLowerCase().contains(q);
        final matchesSpec = d.specialties.any((s) => s.toLowerCase().contains(q));
        final matchesServ = d.services.any((s) => s.toLowerCase().contains(q));
        return matchesName || matchesHOD || matchesSpec || matchesServ;
      }).toList();
    }

    if (_departmentEmergencyOnly) {
      depts = depts.where((d) => d.emergencyAvailable).toList();
    }

    if (_departmentOperationalOnly) {
      depts = depts.where((d) => d.isOperational).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Clinical Departments & Services',
                  subtitle: 'Operating hours, emergency triage, specialist coverage & care levels',
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                ),
                icon: const Icon(Icons.add_business, size: 16),
                label: const Text('Add Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddOrEditDepartmentModal(),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),

          // Search and Filters
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search departments, specialties, services, or HOD...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _departmentSearchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      selected: _departmentEmergencyOnly,
                      label: const Text('24/7 Emergency Active', style: TextStyle(fontSize: 11)),
                      selectedColor: AppColors.urgencyEmergencyRed.withValues(alpha: 0.18),
                      checkmarkColor: AppColors.urgencyEmergencyRed,
                      onSelected: (val) {
                        setState(() {
                          _departmentEmergencyOnly = val;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _departmentOperationalOnly,
                      label: const Text('Fully Operational Only', style: TextStyle(fontSize: 11)),
                      selectedColor: AppColors.primaryGreen.withValues(alpha: 0.18),
                      checkmarkColor: AppColors.primaryGreen,
                      onSelected: (val) {
                        setState(() {
                          _departmentOperationalOnly = val;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),

          if (depts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingXl),
                child: Column(
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 48, color: AppColors.textGreyMuted),
                    const SizedBox(height: 12),
                    const Text('No matching clinical departments found.', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Register departments or clear search filters above.', style: TextStyle(color: AppColors.textGreyMuted, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ...depts.map((d) => _buildDepartmentCard(d)),

          const SizedBox(height: AppConstants.spacingXl),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(FacilityDepartment d) {
    final isOperational = d.isOperational;
    final hasEmergency = d.emergencyAvailable;

    String coverageLabel = 'On-Site Specialist';
    Color coverageColor = AppColors.primaryGreen;
    if (d.specialistCoverage == 'on_call') {
      coverageLabel = 'On-Call Specialist';
      coverageColor = AppColors.urgencyUrgentOrange;
    } else if (d.specialistCoverage == 'not_available') {
      coverageLabel = 'No Dedicated Specialist';
      coverageColor = AppColors.textGreyMuted;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: (isOperational ? AppColors.primaryGreen : AppColors.urgencyUrgentOrange).withValues(alpha: 0.12),
                  child: Icon(
                    Icons.local_hospital_outlined,
                    color: isOperational ? AppColors.primaryGreen : AppColors.urgencyUrgentOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.departmentName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isOperational ? AppColors.statusGreen : AppColors.urgencyUrgentOrange).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isOperational ? 'Operational' : 'Restricted / Closed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOperational ? AppColors.statusGreen : AppColors.urgencyUrgentOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HOD: ${d.headOfDepartment}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textGreyMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Temporary closure alert if not operational
            if (!isOperational && d.temporaryClosureReason != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.urgencyUrgentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.urgencyUrgentOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.urgencyUrgentOrange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Service Restriction: ${d.temporaryClosureReason}',
                        style: const TextStyle(fontSize: 11, color: AppColors.urgencyUrgentOrange, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Badges row: Hours, Appointment Mode, Emergency Availability, Specialist Coverage
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildInfoBadge(Icons.access_time, '${d.operatingHours} (${d.operationalDays})', Colors.blueGrey),
                _buildInfoBadge(Icons.calendar_today_outlined, d.appointmentMode, Colors.indigo),
                _buildInfoBadge(
                  hasEmergency ? Icons.emergency : Icons.block,
                  hasEmergency ? '24/7 Emergency Available' : 'No Emergency Triage',
                  hasEmergency ? AppColors.urgencyEmergencyRed : AppColors.textGreyMuted,
                ),
                _buildInfoBadge(Icons.person_pin, coverageLabel, coverageColor),
              ],
            ),
            const SizedBox(height: 10),

            // Care Levels
            if (d.careLevels.isNotEmpty) ...[
              const Text('Care Levels:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGreyMuted)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: d.careLevels.map((lvl) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      lvl.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textNavyPrimary),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Clinical Specialties
            if (d.specialties.isNotEmpty) ...[
              const Text('Specialties:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGreyMuted)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: d.specialties.map((spec) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.tealAccentDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.tealAccentDark.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      spec,
                      style: const TextStyle(fontSize: 11, color: AppColors.tealAccentDark, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Clinical Services Provided
            if (d.services.isNotEmpty) ...[
              const Text('Services Provided:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGreyMuted)),
              const SizedBox(height: 4),
              Text(
                d.services.join(' • '),
                style: const TextStyle(fontSize: 12, color: AppColors.textNavyPrimary),
              ),
            ],

            const Divider(height: 16),

            // Action row: Edit department & Toggle restriction
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(isOperational ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 16),
                  label: Text(
                    isOperational ? 'Restrict / Close' : 'Reactivate',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOperational ? AppColors.urgencyUrgentOrange : AppColors.primaryGreen,
                    ),
                  ),
                  onPressed: () => _toggleDepartmentOperational(d),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                  ),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit Details', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showAddOrEditDepartmentModal(d),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 4: Staff & Doctor Affiliations
  // ==========================================================================
  Widget _buildStaffAffiliationsTab() {
    final res = _resources!;
    final staff = res.staff;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Clinical & Technical Personnel',
                  subtitle: 'Doctors, ICU specialists, imaging techs & emergency duty roster',
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                ),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Add Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddStaffModal(),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),

          if (staff.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppConstants.spacingXl),
                child: Text('No staff affiliations registered yet.'),
              ),
            )
          else
            ...staff.map((s) => _buildStaffCard(s)),

          const SizedBox(height: AppConstants.spacingXl),
        ],
      ),
    );
  }

  Widget _buildStaffCard(FacilityStaffAffiliation s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryLightMint,
              child: Icon(
                s.staffRole == 'doctor' ? Icons.medical_services_outlined : Icons.badge_outlined,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.staffName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.emergencyDutyParticipating
                              ? AppColors.urgencyEmergencyRed.withValues(alpha: 0.12)
                              : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        child: Text(
                          s.emergencyDutyParticipating ? 'On Emergency Duty' : 'Regular Shift',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: s.emergencyDutyParticipating
                                ? AppColors.urgencyEmergencyRed
                                : AppColors.textGreyMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.designation} • ${s.department}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textNavyPrimary),
                  ),
                  if (s.primarySpecialty != null && s.primarySpecialty!.isNotEmpty)
                    Text(
                      'Specialty: ${s.primarySpecialty}',
                      style: const TextStyle(fontSize: 11, color: AppColors.tealAccentDark, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Shift: ${s.shiftTiming} • Days: ${s.workingDays}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textGreyMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 4: Beds & Operational Capacity Management
  // ==========================================================================
  Widget _buildBedsAndCapacityTab() {
    final res = _resources!;
    final capacity = res.capacity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Operational Bed & Unit Capacity',
                  subtitle: 'Real-time bed distribution, active theatres & dialysis stations',
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                ),
                icon: const Icon(Icons.sync_alt, size: 16),
                label: const Text('Update Bed Census', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showUpdateCapacityModal(capacity),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),

          ...capacity.map((c) => _buildCapacityCategoryCard(c)),

          const SizedBox(height: AppConstants.spacingXl),
        ],
      ),
    );
  }

  Widget _buildCapacityCategoryCard(FacilityCapacityRecord c) {
    final isIcuOrEmergency = c.category == 'icu_beds' || c.category == 'emergency_bays';
    final color = isIcuOrEmergency ? AppColors.urgencyEmergencyRed : AppColors.primaryGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  c.category == 'icu_beds'
                      ? Icons.monitor_heart
                      : (c.category == 'operating_theatres' ? Icons.healing : Icons.hotel),
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.categoryLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  '${c.availableCapacity} Available',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Linear occupancy bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.occupancyRate,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  c.occupancyRate > 0.85 ? AppColors.urgencyEmergencyRed : AppColors.primaryGreen,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Installed: ${c.installedCapacity}', style: const TextStyle(fontSize: 11, color: AppColors.textGreyMuted)),
                Text('Staffed/Open: ${c.operationalCapacity}', style: const TextStyle(fontSize: 11, color: AppColors.textGreyMuted)),
                Text('Occupied: ${c.occupiedCapacity} (${(c.occupancyRate * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 11, color: AppColors.textGreyMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 5: Verification & Audit Trail
  // ==========================================================================
  Widget _buildVerificationAuditTab() {
    final res = _resources!;
    final records = res.verificationRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Audit & Quality Verification Trail',
            subtitle: 'Evidence documents, calibration logs, and administrative decisions',
          ),
          const SizedBox(height: AppConstants.spacingSm),

          if (records.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppConstants.spacingXl),
                child: Text('No verification records logged yet.'),
              ),
            )
          else
            ...records.map((r) => _buildAuditRecordCard(r)),

          const SizedBox(height: AppConstants.spacingXl),
        ],
      ),
    );
  }

  Widget _buildAuditRecordCard(FacilityResourceVerificationRecord r) {
    final isApproved = r.decision == 'approved';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isApproved
                  ? AppColors.statusGreen.withValues(alpha: 0.12)
                  : AppColors.urgencyEmergencyRed.withValues(alpha: 0.12),
              child: Icon(
                isApproved ? Icons.verified : Icons.cancel_outlined,
                color: isApproved ? AppColors.statusGreen : AppColors.urgencyEmergencyRed,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Decision: ${r.decision.toUpperCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isApproved ? AppColors.statusGreen : AppColors.urgencyEmergencyRed,
                          ),
                        ),
                      ),
                      Text(
                        r.verifiedAt.toIso8601String().substring(0, 10),
                        style: const TextStyle(fontSize: 11, color: AppColors.textGreyMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reviewed By: ${r.reviewedBy} (${r.reviewerRole})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (r.evidenceNotes != null && r.evidenceNotes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      r.evidenceNotes!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textGreyDark),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // MODALS & DIALOGS
  // ==========================================================================

  void _showAddEquipmentModal() {
    _showEquipmentFormModal(null);
  }

  void _showEditEquipmentModal(FacilityResourceItem item) {
    _showEquipmentFormModal(item);
  }

  void _showEquipmentFormModal(FacilityResourceItem? existing) {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final modelCtrl = TextEditingController(text: existing?.modelSpec ?? '');
    final locationCtrl = TextEditingController(text: existing?.locationInFacility ?? 'Main Clinical Block');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final docRefCtrl = TextEditingController(text: existing?.evidenceDocumentName ?? 'AMC_Cert_2026.pdf');

    var cat = existing?.category ?? ResourceCategory.diagnosticAndImaging;
    var status = existing?.operationalStatus ?? ResourceOperationalStatus.operational;
    var ownership = existing?.ownershipType ?? OwnershipType.inHouseOwned;
    var schedule = existing?.availabilitySchedule ?? '24/7';
    var opReq = existing?.operatorRequirements ?? 'Trained Clinical Staff';
    var qtyInstalled = existing?.quantityInstalled ?? 1;
    var qtyOper = existing?.quantityOperational ?? 1;
    var qtyOut = existing?.quantityOutOfService ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppConstants.spacingMd,
                right: AppConstants.spacingMd,
                top: AppConstants.spacingMd,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppConstants.spacingMd,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Edit Medical Equipment' : 'Register New Medical Technology',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),

                    // Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Equipment / Technology Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category
                    DropdownButtonFormField<ResourceCategory>(
                      initialValue: cat,
                      decoration: const InputDecoration(
                        labelText: 'Functional Category (1 of 7) *',
                        border: OutlineInputBorder(),
                      ),
                      items: ResourceCategory.values.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(c.icon, size: 16, color: c.color),
                              const SizedBox(width: 8),
                              Text(c.label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => cat = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Model / Technical Spec
                    TextField(
                      controller: modelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Model, Make or Technical Specification',
                        hintText: 'e.g. GE MAC 2000, Hamilton-C3 Ventilator',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quantities Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: qtyInstalled.toString(),
                            decoration: const InputDecoration(labelText: 'Installed Qty', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => qtyInstalled = int.tryParse(v) ?? 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: qtyOper.toString(),
                            decoration: const InputDecoration(labelText: 'Operational', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => qtyOper = int.tryParse(v) ?? 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: qtyOut.toString(),
                            decoration: const InputDecoration(labelText: 'Out of Service', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => qtyOut = int.tryParse(v) ?? 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Operational Status
                    DropdownButtonFormField<ResourceOperationalStatus>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Operational Status *',
                        border: OutlineInputBorder(),
                      ),
                      items: ResourceOperationalStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => status = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Location
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Physical Location (Dept / Room / Floor)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Ownership & Service Delivery
                    DropdownButtonFormField<OwnershipType>(
                      initialValue: ownership,
                      decoration: const InputDecoration(
                        labelText: 'Ownership & Delivery Model *',
                        border: OutlineInputBorder(),
                      ),
                      items: OwnershipType.values.map((o) {
                        return DropdownMenuItem(value: o, child: Text(o.label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => ownership = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Operator Requirement
                    DropdownButtonFormField<String>(
                      initialValue: opReq,
                      decoration: const InputDecoration(
                        labelText: 'Operator / Specialist Requirement *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Trained Clinical Staff', child: Text('Trained Clinical Staff')),
                        DropdownMenuItem(value: 'requires_radiologist', child: Text('Requires Certified Radiologist')),
                        DropdownMenuItem(value: 'requires_anaesthetist', child: Text('Requires Anaesthetist')),
                        DropdownMenuItem(value: 'technician_operated', child: Text('Technician-Operated')),
                        DropdownMenuItem(value: 'nurse_operated', child: Text('Nurse-Operated')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => opReq = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Document Reference
                    TextField(
                      controller: docRefCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Document Reference (AMC / Calibration Certificate)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Save Action
                    PrimaryButton(
                      text: isEditing ? 'Save Changes' : 'Register Equipment to Facility',
                      icon: Icons.check,
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx);

                        final itemToSave = FacilityResourceItem(
                          id: existing?.id ?? 'res_${DateTime.now().millisecondsSinceEpoch}',
                          facilityId: _selectedFacilityId,
                          name: nameCtrl.text.trim(),
                          category: cat,
                          modelSpec: modelCtrl.text.trim(),
                          quantityInstalled: qtyInstalled,
                          quantityOperational: qtyOper,
                          quantityOutOfService: qtyOut,
                          operationalStatus: status,
                          locationInFacility: locationCtrl.text.trim(),
                          ownershipType: ownership,
                          operatorRequirements: opReq,
                          availabilitySchedule: schedule,
                          evidenceDocumentName: docRefCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                          lastVerifiedAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );

                        if (isEditing) {
                          await FacilityResourceRepository.instance.updateResource(
                            _selectedFacilityId,
                            itemToSave,
                            actorId: _currentActorId,
                            actorRole: _currentActorRole,
                          );
                        } else {
                          await FacilityResourceRepository.instance.addResource(
                            _selectedFacilityId,
                            itemToSave,
                            actorId: _currentActorId,
                            actorRole: _currentActorRole,
                          );
                        }
                        _loadFacilityData();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDecommissionEquipment(FacilityResourceItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decommission Equipment?'),
        content: Text(
          'Are you sure you want to decommission "${item.name}"? It will no longer be considered available for clinical referral triage.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.urgencyEmergencyRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await FacilityResourceRepository.instance.deleteResource(
                _selectedFacilityId,
                item.id,
                actorId: _currentActorId,
                actorRole: _currentActorRole,
              );
              _loadFacilityData();
            },
            child: const Text('Decommission', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVerifyDialog(FacilityResourceItem item) {
    final notesCtrl = TextEditingController(text: 'Routine Annual Maintenance & Calibration Verification Passed.');
    var decision = 'approved';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Audit & Verify: ${item.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record authoritative administrative verification decision for medical quality assurance.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGreyMuted),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: decision,
                  decoration: const InputDecoration(labelText: 'Verification Decision', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'approved', child: Text('Approved (Verified)')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected / Degraded')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending More Evidence')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => decision = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Auditor Notes', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FacilityResourceRepository.instance.verifyResource(
                    _selectedFacilityId,
                    item.id,
                    decision: decision,
                    reviewerId: 'Auditor Dr. Sharma (NABH)',
                    reviewerRole: 'district_officer',
                    notes: notesCtrl.text.trim(),
                  );
                  _loadFacilityData();
                },
                child: const Text('Record Audit Decision', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateCapacityModal(List<FacilityCapacityRecord> records) {
    final localCopy = records.map((r) => r.copyWith()).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppConstants.spacingMd,
                right: AppConstants.spacingMd,
                top: AppConstants.spacingMd,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppConstants.spacingMd,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Update Bed & Unit Capacity Census', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    ...localCopy.map((rec) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(rec.categoryLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: rec.operationalCapacity.toString(),
                                decoration: const InputDecoration(labelText: 'Staffed', contentPadding: EdgeInsets.all(6), border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                onChanged: (v) {
                                  final num = int.tryParse(v) ?? rec.operationalCapacity;
                                  final idx = localCopy.indexOf(rec);
                                  localCopy[idx] = rec.copyWith(
                                    operationalCapacity: num,
                                    availableCapacity: (num - rec.occupiedCapacity).clamp(0, 9999),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: rec.occupiedCapacity.toString(),
                                decoration: const InputDecoration(labelText: 'Occupied', contentPadding: EdgeInsets.all(6), border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                onChanged: (v) {
                                  final num = int.tryParse(v) ?? rec.occupiedCapacity;
                                  final idx = localCopy.indexOf(rec);
                                  localCopy[idx] = rec.copyWith(
                                    occupiedCapacity: num,
                                    availableCapacity: (rec.operationalCapacity - num).clamp(0, 9999),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      text: 'Save and Synchronize Live Capacity',
                      icon: Icons.sync,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await FacilityResourceRepository.instance.updateCapacity(
                          _selectedFacilityId,
                          localCopy,
                          actorId: _currentActorId,
                          actorRole: _currentActorRole,
                        );
                        _loadFacilityData();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddStaffModal() {
    final nameCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'Emergency Medicine');
    final desigCtrl = TextEditingController(text: 'Consultant Physician');
    final specCtrl = TextEditingController(text: 'Emergency Medicine');
    var isEmergencyDuty = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Staff Affiliation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Staff Name', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: desigCtrl, decoration: const InputDecoration(labelText: 'Designation', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Primary Specialty', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('On Emergency Roster', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: isEmergencyDuty,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (v) => setDialogState(() => isEmergencyDuty = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await FacilityResourceRepository.instance.addStaffAffiliation(
                    _selectedFacilityId,
                    FacilityStaffAffiliation(
                      affiliationId: 'aff_${DateTime.now().millisecondsSinceEpoch}',
                      facilityId: _selectedFacilityId,
                      staffName: nameCtrl.text.trim(),
                      staffRole: 'doctor',
                      department: deptCtrl.text.trim(),
                      designation: desigCtrl.text.trim(),
                      primarySpecialty: specCtrl.text.trim(),
                      emergencyDutyParticipating: isEmergencyDuty,
                    ),
                    actorId: _currentActorId,
                    actorRole: _currentActorRole,
                  );
                  _loadFacilityData();
                },
                child: const Text('Add Staff', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditProfileDialog(FacilityDetailedProfile prof) {
    final phoneCtrl = TextEditingController(text: prof.contactNumber);
    final emailCtrl = TextEditingController(text: prof.officialEmail);
    final hoursCtrl = TextEditingController(text: prof.openingHours);
    final adminCtrl = TextEditingController(text: prof.adminName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Facility Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Contact Phone', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Official Email', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: hoursCtrl, decoration: const InputDecoration(labelText: 'Opening Hours', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: adminCtrl, decoration: const InputDecoration(labelText: 'Registered Administrator', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () async {
              Navigator.pop(ctx);
              await FacilityResourceRepository.instance.updateProfile(
                _selectedFacilityId,
                {
                  'contact_number': phoneCtrl.text.trim(),
                  'official_email': emailCtrl.text.trim(),
                  'opening_hours': hoursCtrl.text.trim(),
                  'admin_name': adminCtrl.text.trim(),
                },
                actorId: _currentActorId,
                actorRole: _currentActorRole,
              );
              _loadFacilityData();
            },
            child: const Text('Save Profile', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleDepartmentOperational(FacilityDepartment d) {
    if (d.isOperational) {
      final reasonCtrl = TextEditingController(text: 'Scheduled sanitization and clinical equipment maintenance');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Restrict ${d.departmentName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter reason for temporary service restriction or closure:'),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Restriction Reason', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.urgencyUrgentOrange),
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = d.copyWith(
                  isOperational: false,
                  temporaryClosureReason: reasonCtrl.text.trim(),
                  lastUpdatedAt: DateTime.now(),
                );
                await FacilityResourceRepository.instance.updateDepartment(
                  _selectedFacilityId,
                  updated,
                  actorId: _currentActorId,
                  actorRole: _currentActorRole,
                );
                _loadFacilityData();
              },
              child: const Text('Set Restriction', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      // Reactivate
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Reactivate ${d.departmentName}'),
          content: Text('Reopen ${d.departmentName} for live patient referral routing and clinical services?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = d.copyWith(
                  isOperational: true,
                  temporaryClosureReason: null,
                  lastUpdatedAt: DateTime.now(),
                );
                await FacilityResourceRepository.instance.updateDepartment(
                  _selectedFacilityId,
                  updated,
                  actorId: _currentActorId,
                  actorRole: _currentActorRole,
                );
                _loadFacilityData();
              },
              child: const Text('Reactivate Department', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _showAddOrEditDepartmentModal([FacilityDepartment? existing]) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.departmentName ?? '');
    final hodCtrl = TextEditingController(text: existing?.headOfDepartment ?? '');
    final hoursCtrl = TextEditingController(text: existing?.operatingHours ?? '24 Hours');
    final daysCtrl = TextEditingController(text: existing?.operationalDays ?? 'Mon-Sun');
    final specsCtrl = TextEditingController(text: existing?.specialties.join(', ') ?? '');
    final servsCtrl = TextEditingController(text: existing?.services.join(', ') ?? '');
    final closureCtrl = TextEditingController(text: existing?.temporaryClosureReason ?? '');

    String appointmentMode = existing?.appointmentMode ?? 'Walk-in & Appointment';
    String specialistCoverage = existing?.specialistCoverage ?? 'on_site';
    bool emergencyAvailable = existing?.emergencyAvailable ?? true;
    bool isOperational = existing?.isOperational ?? true;

    final selectedCareLevels = Set<String>.from(existing?.careLevels ?? ['outpatient', 'inpatient', 'emergency']);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Clinical Department' : 'Register Clinical Department'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Department Name *',
                        hintText: 'e.g. Emergency Medicine, Cardiology, Obstetrics',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: hodCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Head of Department / Clinical Lead',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hoursCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Operating Hours',
                              hintText: 'e.g. 24 Hours, 09:00 - 17:00',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: daysCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Operating Days',
                              hintText: 'e.g. Mon-Sun, Mon-Sat',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: appointmentMode,
                      decoration: const InputDecoration(
                        labelText: 'Appointment Mode',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Walk-in & Appointment', child: Text('Walk-in & Appointment')),
                        DropdownMenuItem(value: 'Appointment Only', child: Text('Appointment Only')),
                        DropdownMenuItem(value: 'Walk-in Only', child: Text('Walk-in Only')),
                        DropdownMenuItem(value: 'Emergency & Inpatient Transfer Only', child: Text('Emergency Transfer Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => appointmentMode = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: specialistCoverage,
                      decoration: const InputDecoration(
                        labelText: 'Specialist Doctor Coverage',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'on_site', child: Text('On-Site Specialist Coverage')),
                        DropdownMenuItem(value: 'on_call', child: Text('On-Call Specialist Coverage')),
                        DropdownMenuItem(value: 'not_available', child: Text('No Dedicated Specialist')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => specialistCoverage = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('24/7 Emergency Service Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Department handles acute triage and resuscitations', style: TextStyle(fontSize: 11)),
                      value: emergencyAvailable,
                      activeThumbColor: AppColors.primaryGreen,
                      onChanged: (val) => setModalState(() => emergencyAvailable = val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Department Is Currently Operational', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Disable if closed for maintenance, renovation, or staffing', style: TextStyle(fontSize: 11)),
                      value: isOperational,
                      activeThumbColor: AppColors.primaryGreen,
                      onChanged: (val) => setModalState(() => isOperational = val),
                    ),
                    if (!isOperational) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: closureCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Temporary Closure / Restriction Reason *',
                          hintText: 'e.g. Scheduled sanitization, OT maintenance',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text('Care Levels Provided:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: ['outpatient', 'inpatient', 'day_care', 'emergency'].map((lvl) {
                        final isSel = selectedCareLevels.contains(lvl);
                        return FilterChip(
                          label: Text(lvl.toUpperCase(), style: const TextStyle(fontSize: 11)),
                          selected: isSel,
                          selectedColor: AppColors.primaryGreen.withValues(alpha: 0.18),
                          checkmarkColor: AppColors.primaryGreen,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedCareLevels.add(lvl);
                              } else {
                                selectedCareLevels.remove(lvl);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: specsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Associated Specialties (comma separated)',
                        hintText: 'e.g. Cardiology, Electrophysiology, Interventional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: servsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Services Provided (comma separated)',
                        hintText: 'e.g. Angiography, Echo, Stenting, Pacemaker',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              if (isEdit)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await FacilityResourceRepository.instance.deleteDepartment(
                      _selectedFacilityId,
                      existing.departmentId,
                      actorId: _currentActorId,
                      actorRole: _currentActorRole,
                    );
                    _loadFacilityData();
                  },
                  child: const Text('Delete', style: TextStyle(color: AppColors.urgencyEmergencyRed)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final dept = FacilityDepartment(
                    departmentId: existing?.departmentId ?? 'dept_${_selectedFacilityId}_${DateTime.now().millisecondsSinceEpoch}',
                    facilityId: _selectedFacilityId,
                    departmentName: nameCtrl.text.trim(),
                    headOfDepartment: hodCtrl.text.trim().isEmpty ? 'Clinical Lead' : hodCtrl.text.trim(),
                    operatingHours: hoursCtrl.text.trim().isEmpty ? '24 Hours' : hoursCtrl.text.trim(),
                    operationalDays: daysCtrl.text.trim().isEmpty ? 'Mon-Sun' : daysCtrl.text.trim(),
                    appointmentMode: appointmentMode,
                    specialistCoverage: specialistCoverage,
                    emergencyAvailable: emergencyAvailable,
                    isOperational: isOperational,
                    temporaryClosureReason: isOperational ? null : closureCtrl.text.trim(),
                    careLevels: selectedCareLevels.toList(),
                    specialties: specsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                    services: servsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                    lastUpdatedAt: DateTime.now(),
                  );

                  if (isEdit) {
                    await FacilityResourceRepository.instance.updateDepartment(
                      _selectedFacilityId,
                      dept,
                      actorId: _currentActorId,
                      actorRole: _currentActorRole,
                    );
                  } else {
                    await FacilityResourceRepository.instance.addDepartment(
                      _selectedFacilityId,
                      dept,
                      actorId: _currentActorId,
                      actorRole: _currentActorRole,
                    );
                  }
                  _loadFacilityData();
                },
                child: Text(isEdit ? 'Save Changes' : 'Register Department', style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}
