import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../services/location_service.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';

/// Modal dialog allowing healthcare workers to manage location permissions,
/// select preset rural clinics, or manually enter custom clinic coordinates.
class ClinicLocationDialog extends StatefulWidget {
  final LocationService locationService;
  final VoidCallback onLocationChanged;

  const ClinicLocationDialog({
    super.key,
    required this.locationService,
    required this.onLocationChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required LocationService locationService,
    required VoidCallback onLocationChanged,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ClinicLocationDialog(
        locationService: locationService,
        onLocationChanged: onLocationChanged,
      ),
    );
  }

  @override
  State<ClinicLocationDialog> createState() => _ClinicLocationDialogState();
}

class _ClinicLocationDialogState extends State<ClinicLocationDialog> {
  late TextEditingController _nameController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  final _formKey = GlobalKey<FormState>();

  bool _showCustomFields = false;

  @override
  void initState() {
    super.initState();
    final cur = widget.locationService.currentClinicLocation;
    _nameController = TextEditingController(text: cur.name);
    _latController = TextEditingController(text: cur.latitude.toString());
    _lngController = TextEditingController(text: cur.longitude.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curLoc = widget.locationService.currentClinicLocation;
    final permState = widget.locationService.permissionState;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightMint,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        child: const Icon(Icons.my_location_rounded, color: AppColors.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Clinic Location & GPS Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textNavyPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // GPS Permission Status Indicator
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getPermBgColor(permState),
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      border: Border.all(color: _getPermBorderColor(permState)),
                    ),
                    child: Row(
                      children: [
                        Icon(_getPermIcon(permState), size: 18, color: _getPermTextColor(permState)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GPS Status: ${_getPermLabel(permState)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _getPermTextColor(permState),
                                ),
                              ),
                              Text(
                                _getPermDescription(permState),
                                style: const TextStyle(fontSize: 10, color: AppColors.textNavySecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Permission Simulation Controls
                  const Text(
                    'Simulate Permission States (Testing & Offline):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPermStateChip(
                        label: 'Granted',
                        state: LocationPermissionState.granted,
                        activeState: permState,
                      ),
                      _buildPermStateChip(
                        label: 'Denied',
                        state: LocationPermissionState.denied,
                        activeState: permState,
                      ),
                      _buildPermStateChip(
                        label: 'Unavailable',
                        state: LocationPermissionState.unavailable,
                        activeState: permState,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderLight, height: 1),
                  const SizedBox(height: 14),

                  // Preset Rural Clinics Selector
                  const Text(
                    'Select Rural Clinic Preset:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                  ),
                  const SizedBox(height: 6),
                  Column(
                    children: ClinicLocation.presets.map((preset) {
                      final isSelected = curLoc.name == preset.name;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () {
                            widget.locationService.setManualClinicLocation(preset);
                            setState(() {
                              _nameController.text = preset.name;
                              _latController.text = preset.latitude.toString();
                              _lngController.text = preset.longitude.toString();
                              _showCustomFields = false;
                            });
                            widget.onLocationChanged();
                          },
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryLightMint : AppColors.surfaceMutedLight,
                              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryGreen : AppColors.borderLight,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  size: 16,
                                  color: isSelected ? AppColors.primaryGreen : AppColors.textNavyMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        preset.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                          color: isSelected ? AppColors.primaryDarkGreen : AppColors.textNavyPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${preset.description} • (${preset.latitude.toStringAsFixed(3)}, ${preset.longitude.toStringAsFixed(3)})',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textNavyMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 10),

                  // Custom Manual Coordinate Input Toggle
                  InkWell(
                    onTap: () => setState(() => _showCustomFields = !_showCustomFields),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _showCustomFields ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.secondarySlateTeal,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _showCustomFields ? 'Hide Custom Coordinates' : 'Enter Custom Clinic Coordinates Manually',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondarySlateTeal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_showCustomFields) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Clinic Facility Name',
                        isDense: true,
                        hintText: 'e.g. Sub-Center Ramanagara Unit 2',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              isDense: true,
                              hintText: '12.9716',
                            ),
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid lat' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              isDense: true,
                              hintText: '77.5946',
                            ),
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid lng' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      text: 'Apply Custom Location',
                      icon: Icons.check_circle_outline,
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          final custom = ClinicLocation(
                            name: _nameController.text.trim(),
                            latitude: double.parse(_latController.text.trim()),
                            longitude: double.parse(_lngController.text.trim()),
                            isManualEntry: true,
                            description: 'Manual Clinic Entry by Clinician',
                          );
                          widget.locationService.setManualClinicLocation(custom);
                          widget.onLocationChanged();
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 14),

                  SecondaryButton(
                    text: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermStateChip({
    required String label,
    required LocationPermissionState state,
    required LocationPermissionState activeState,
  }) {
    final isSelected = activeState == state;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          widget.locationService.updatePermissionState(state);
          setState(() {});
          widget.onLocationChanged();
        }
      },
    );
  }

  Color _getPermBgColor(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.granted:
        return AppColors.primaryLightMint;
      case LocationPermissionState.denied:
        return AppColors.statusAmberBg;
      case LocationPermissionState.unavailable:
        return AppColors.surfaceMutedLight;
      case LocationPermissionState.manual:
        return const Color(0xFFEFF6FF);
    }
  }

  Color _getPermBorderColor(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.granted:
        return AppColors.primaryGreen;
      case LocationPermissionState.denied:
        return AppColors.statusAmber;
      case LocationPermissionState.unavailable:
        return AppColors.borderLight;
      case LocationPermissionState.manual:
        return const Color(0xFF3B82F6);
    }
  }

  Color _getPermTextColor(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.granted:
        return AppColors.primaryDarkGreen;
      case LocationPermissionState.denied:
        return AppColors.statusAmber;
      case LocationPermissionState.unavailable:
        return AppColors.textNavyMuted;
      case LocationPermissionState.manual:
        return const Color(0xFF1D4ED8);
    }
  }

  IconData _getPermIcon(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.granted:
        return Icons.check_circle_rounded;
      case LocationPermissionState.denied:
        return Icons.warning_amber_rounded;
      case LocationPermissionState.unavailable:
        return Icons.location_off_rounded;
      case LocationPermissionState.manual:
        return Icons.edit_location_alt_rounded;
    }
  }

  String _getPermLabel(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.granted:
        return 'Granted & Active';
      case LocationPermissionState.denied:
        return 'Permission Denied';
      case LocationPermissionState.unavailable:
        return 'Hardware / Service Unavailable';
      case LocationPermissionState.manual:
        return 'Manual Override Active';
    }
  }

  String _getPermDescription(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.granted:
        return 'Using device coordinates for distance calculations.';
      case LocationPermissionState.denied:
        return 'Using rural PHC base preset. Directory remains fully functional.';
      case LocationPermissionState.unavailable:
        return 'Location sensors offline. Directory remains fully functional.';
      case LocationPermissionState.manual:
        return 'Distances calculated from custom clinic coordinates.';
    }
  }
}
