import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/hospital.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import 'hospital_details_screen.dart';

/// Interactive regional referral map powered by OpenStreetMap (`flutter_map`).
///
/// Features:
/// - Clinic Marker (Rural PHC / Referring facility)
/// - Recommended Hospital Marker (Highlighted with star / best match)
/// - Alternative Hospital Markers (Secondary & tertiary partner facilities)
/// - Interactive Route Polyline via `RoutingService`
/// - Clearly labeled Simulated Travel Time (offline speed-based, NO fabricated live traffic)
/// - Fully interactive fallback for offline rural environments
class HospitalMapView extends StatefulWidget {
  final List<Hospital> hospitals;
  final ClinicLocation clinicLocation;
  final Hospital? recommendedHospital;
  final void Function(Hospital hospital)? onSelectHospital;

  const HospitalMapView({
    super.key,
    required this.hospitals,
    required this.clinicLocation,
    this.recommendedHospital,
    this.onSelectHospital,
  });

  @override
  State<HospitalMapView> createState() => _HospitalMapViewState();
}

class _HospitalMapViewState extends State<HospitalMapView> {
  final MapController _mapController = MapController();
  final RoutingService _routingService = const SimulatedRoutingService();

  Hospital? _selectedHospital;
  RouteEstimate? _currentRoute;
  bool _isCalculatingRoute = false;

  @override
  void initState() {
    super.initState();
    // Default selected hospital to recommended hospital if present, or nearest operational hospital
    if (widget.recommendedHospital != null) {
      _selectHospital(widget.recommendedHospital!);
    } else if (widget.hospitals.isNotEmpty) {
      _selectHospital(widget.hospitals.first);
    }
  }

  @override
  void didUpdateWidget(covariant HospitalMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clinicLocation.latitude != widget.clinicLocation.latitude ||
        oldWidget.clinicLocation.longitude != widget.clinicLocation.longitude) {
      if (_selectedHospital != null) {
        _selectHospital(_selectedHospital!);
      }
    }
  }

  Future<void> _selectHospital(Hospital hospital) async {
    setState(() {
      _selectedHospital = hospital;
      _isCalculatingRoute = true;
    });

    final route = await _routingService.calculateRoute(
      origin: widget.clinicLocation.latLng,
      destination: LatLng(hospital.latitude, hospital.longitude),
      isEmergency: hospital.emergencyCare,
    );

    if (mounted) {
      setState(() {
        _currentRoute = route;
        _isCalculatingRoute = false;
      });
    }
  }

  void _centerOnClinic() {
    _mapController.move(widget.clinicLocation.latLng, 11.5);
  }

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1.0);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final clinicPoint = widget.clinicLocation.latLng;
    final recommended = widget.recommendedHospital;

    return Stack(
      children: [
        // 1. FlutterMap with OpenStreetMap TileLayer
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: clinicPoint,
            initialZoom: 10.5,
            minZoom: 6.0,
            maxZoom: 18.0,
          ),
          children: [
            // OpenStreetMap Standard Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'org.smartreferral.health',
              maxZoom: 19,
            ),

            // Route Polyline Layer between Clinic and Selected Hospital
            if (_currentRoute != null && _currentRoute!.waypoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _currentRoute!.waypoints,
                    strokeWidth: 4.5,
                    color: _selectedHospital == recommended
                        ? AppColors.primaryGreen
                        : AppColors.secondarySlateTeal,
                  ),
                ],
              ),

            // Markers Layer: Clinic + Recommended + Alternatives
            MarkerLayer(
              markers: [
                // 1. Clinic Marker
                Marker(
                  point: clinicPoint,
                  width: 52,
                  height: 52,
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text('Referring Clinic: ${widget.clinicLocation.name}'),
                        ),
                      );
                    },
                    child: _buildClinicMarkerWidget(),
                  ),
                ),

                // 2. Hospital Markers (Recommended + Alternatives)
                ...widget.hospitals.map((hospital) {
                  final isRec = recommended != null && hospital.hospitalId == recommended.hospitalId;
                  final isSelected = _selectedHospital?.hospitalId == hospital.hospitalId;
                  final point = LatLng(hospital.latitude, hospital.longitude);

                  return Marker(
                    point: point,
                    width: isRec ? 56 : (isSelected ? 50 : 44),
                    height: isRec ? 56 : (isSelected ? 50 : 44),
                    child: GestureDetector(
                      onTap: () => _selectHospital(hospital),
                      child: _buildHospitalMarkerWidget(
                        hospital: hospital,
                        isRecommended: isRec,
                        isSelected: isSelected,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // 2. Map Legend & Routing Notice Banner (Top)
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Column(
            children: [
              // Clear Simulated Transit Disclaimer Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppColors.secondarySlateTeal),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Simulated Transit Estimates (Offline) • Live traffic not monitored',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textNavyPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Interactive Legend Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendItem(color: AppColors.primaryGreen, icon: Icons.health_and_safety, label: 'Clinic'),
                      const SizedBox(width: 8),
                      _buildLegendItem(color: const Color(0xFFD97706), icon: Icons.star_rounded, label: 'Recommended'),
                      const SizedBox(width: 8),
                      _buildLegendItem(color: AppColors.secondarySlateTeal, icon: Icons.local_hospital_rounded, label: 'Alternatives'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Zoom & Center Floating Map Controls (Right Side)
        Positioned(
          right: 12,
          top: 100,
          child: Column(
            children: [
              _buildFloatingMapButton(
                icon: Icons.add_rounded,
                tooltip: 'Zoom In',
                onPressed: _zoomIn,
              ),
              const SizedBox(height: 6),
              _buildFloatingMapButton(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom Out',
                onPressed: _zoomOut,
              ),
              const SizedBox(height: 6),
              _buildFloatingMapButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Center on Clinic',
                onPressed: _centerOnClinic,
              ),
            ],
          ),
        ),

        // 4. Selected Hospital Floating Summary Card (Bottom)
        if (_selectedHospital != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildSelectedHospitalCard(_selectedHospital!),
          ),
      ],
    );
  }

  // ===========================================================================
  // MARKER WIDGET BUILDERS
  // ===========================================================================

  Widget _buildClinicMarkerWidget() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.health_and_safety_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildHospitalMarkerWidget({
    required Hospital hospital,
    required bool isRecommended,
    required bool isSelected,
  }) {
    final bgColor = isRecommended
        ? const Color(0xFFD97706) // Amber-gold for recommended
        : (isSelected ? AppColors.secondarySlateTeal : const Color(0xFF334155));

    final icon = isRecommended ? Icons.star_rounded : Icons.local_hospital_rounded;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.yellowAccent : Colors.white,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: isRecommended ? 26 : 20,
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyPrimary),
        ),
      ],
    );
  }

  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: AppColors.textNavyPrimary),
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM FLOATING CARD FOR SELECTED HOSPITAL
  // ===========================================================================

  Widget _buildSelectedHospitalCard(Hospital hospital) {
    final isRecommended = widget.recommendedHospital?.hospitalId == hospital.hospitalId;
    final isDiverting = hospital.operatingStatus.toLowerCase() == 'diverting';

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: isRecommended ? AppColors.primaryGreen : AppColors.borderLight,
            width: isRecommended ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge & Name Row
            Row(
              children: [
                if (isRecommended)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLightMint,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.primaryGreen),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 12, color: AppColors.primaryGreen),
                        SizedBox(width: 3),
                        Text(
                          'RECOMMENDED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDarkGreen),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Text(
                    hospital.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textNavyPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDiverting ? AppColors.statusRedBg : AppColors.statusGreenBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hospital.operatingStatus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDiverting ? AppColors.statusRed : AppColors.primaryDarkGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Distance & Simulated Transit Row
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.straighten_rounded, size: 14, color: AppColors.secondarySlateTeal),
                    const SizedBox(width: 4),
                    Text(
                      _currentRoute != null
                          ? _currentRoute!.formattedDistance
                          : 'Calculating distance...',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                    ),
                  ],
                ),
                const Text('•', style: TextStyle(color: AppColors.borderDark)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.secondarySlateTeal),
                    const SizedBox(width: 4),
                    Text(
                      _currentRoute != null
                          ? '${_currentRoute!.formattedTravelTime} (Simulated)'
                          : 'Calculating transit...',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDarkGreen),
                    ),
                  ],
                ),
                if (_isCalculatingRoute)
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 6),

            // Key Capability Summary
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildQuickPill(
                  hospital.emergencyCare ? '24/7 ED' : 'No ED',
                  hospital.emergencyCare ? AppColors.primaryGreen : AppColors.textNavyMuted,
                ),
                _buildQuickPill(
                  hospital.icuAvailable ? 'ICU (${hospital.availability?.icuBedsAvailable ?? 0} beds)' : 'No ICU',
                  hospital.icuAvailable ? AppColors.statusAmber : AppColors.textNavyMuted,
                ),
                _buildQuickPill(
                  '${hospital.bedAvailability} Beds Free',
                  hospital.bedAvailability > 0 ? AppColors.primaryDarkGreen : AppColors.statusRed,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Buttons: View Details & Select
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.info_outline_rounded, size: 15),
                    label: const Text('View Capabilities & Limits', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppColors.borderLight),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (ctx) => HospitalDetailsScreen(
                            hospital: hospital,
                            clinicLocation: widget.clinicLocation,
                            onSelectHospital: widget.onSelectHospital != null
                                ? () => widget.onSelectHospital!(hospital)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.onSelectHospital != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => widget.onSelectHospital!(hospital),
                    child: const Text('Select', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
