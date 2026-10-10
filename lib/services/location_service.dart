import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Location permission status states required for clinical triage.
enum LocationPermissionState {
  /// User or system granted GPS/location access.
  granted,

  /// User or system denied location permission.
  denied,

  /// GPS sensor disabled, airplane mode, or hardware unavailable.
  unavailable,

  /// Healthcare worker explicitly specified clinic coordinates manually.
  manual,
}

/// Represents the referring healthcare clinic or primary health post location.
class ClinicLocation {
  final String name;
  final double latitude;
  final double longitude;
  final bool isManualEntry;
  final String description;

  const ClinicLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.isManualEntry = false,
    this.description = 'Primary Rural Healthcare Facility',
  });

  LatLng get latLng => LatLng(latitude, longitude);

  ClinicLocation copyWith({
    String? name,
    double? latitude,
    double? longitude,
    bool? isManualEntry,
    String? description,
  }) {
    return ClinicLocation(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isManualEntry: isManualEntry ?? this.isManualEntry,
      description: description ?? this.description,
    );
  }

  // Realistic Rural Clinic Presets (Indore District & Regional Network)
  static const ClinicLocation defaultSector4PHC = ClinicLocation(
    name: 'Primary Health Center Sector 4',
    latitude: 22.8100,
    longitude: 75.9200,
    isManualEntry: false,
    description: 'Rural Health Post (Indore District) • Base Referring Facility',
  );

  static const ClinicLocation phcManglia = ClinicLocation(
    name: 'Primary Health Centre (PHC), Manglia',
    latitude: 22.8100,
    longitude: 75.9200,
    isManualEntry: true,
    description: 'Base Rural Health Unit • AB Road, Manglia',
  );

  static const ClinicLocation chcSanwer = ClinicLocation(
    name: 'Community Health Centre (CHC), Sanwer',
    latitude: 22.9750,
    longitude: 75.8250,
    isManualEntry: true,
    description: '30-Bed Tehsil Health Centre • Sanwer Block',
  );

  static const ClinicLocation chcDepalpur = ClinicLocation(
    name: 'Community Health Centre (CHC), Depalpur',
    latitude: 22.8530,
    longitude: 75.5470,
    isManualEntry: true,
    description: 'Sub-District Triage Centre • Depalpur Block',
  );

  static const ClinicLocation chcBetma = ClinicLocation(
    name: 'Community Health Centre (CHC), Betma',
    latitude: 22.6850,
    longitude: 75.5650,
    isManualEntry: true,
    description: 'Rural Community Centre • Betma Tehsil',
  );

  static const ClinicLocation chcManpur = ClinicLocation(
    name: 'Community Health Centre (CHC), Manpur',
    latitude: 22.4300,
    longitude: 75.6200,
    isManualEntry: true,
    description: 'Border Rural Triage Clinic • Manpur Block',
  );

  static const ClinicLocation subCenterBettadasanapura = ClinicLocation(
    name: 'Sub-Center Bettadasanapura',
    latitude: 12.8350,
    longitude: 77.6200,
    isManualEntry: true,
    description: 'Sub-District Outreach Health Unit',
  );

  static const ClinicLocation ramanagaraHealthPost = ClinicLocation(
    name: 'Ramanagara Rural Health Post',
    latitude: 12.7200,
    longitude: 77.2800,
    isManualEntry: true,
    description: 'Semi-Arid Rural Primary Post',
  );

  static const ClinicLocation magadiCommunityClinic = ClinicLocation(
    name: 'Magadi Community Clinic',
    latitude: 12.9560,
    longitude: 77.2250,
    isManualEntry: true,
    description: 'Hilly Rural Taluk Primary Dispensary',
  );

  static const ClinicLocation kanakapuraHealthPost = ClinicLocation(
    name: 'Kanakapura Primary Health Post',
    latitude: 12.5460,
    longitude: 77.4200,
    isManualEntry: true,
    description: 'Border Rural Triage Clinic',
  );

  static List<ClinicLocation> get presets => [
        defaultSector4PHC,
        phcManglia,
        chcSanwer,
        chcDepalpur,
        chcBetma,
        chcManpur,
        subCenterBettadasanapura,
        ramanagaraHealthPost,
        magadiCommunityClinic,
        kanakapuraHealthPost,
      ];
}

/// Abstract contract for Location Services to ensure testability and mockability.
abstract class LocationService {
  LocationPermissionState get permissionState;
  ClinicLocation get currentClinicLocation;
  Stream<ClinicLocation> get locationStream;
  Stream<LocationPermissionState> get permissionStream;

  Future<LocationPermissionState> requestPermission();
  void setManualClinicLocation(ClinicLocation location);
  void updatePermissionState(LocationPermissionState state);
}

/// Default implementation providing robust fallback for rural clinics.
/// Guarantees that the app remains 100% operational even without GPS or when permission is denied.
class DefaultLocationService implements LocationService {
  static final DefaultLocationService _instance = DefaultLocationService._internal();
  factory DefaultLocationService() => _instance;

  DefaultLocationService._internal() {
    _currentLocation = ClinicLocation.defaultSector4PHC;
    _permissionState = LocationPermissionState.granted;
  }

  LocationPermissionState _permissionState = LocationPermissionState.granted;
  ClinicLocation _currentLocation = ClinicLocation.defaultSector4PHC;

  final StreamController<ClinicLocation> _locationController =
      StreamController<ClinicLocation>.broadcast();
  final StreamController<LocationPermissionState> _permissionController =
      StreamController<LocationPermissionState>.broadcast();

  @override
  LocationPermissionState get permissionState => _permissionState;

  @override
  ClinicLocation get currentClinicLocation => _currentLocation;

  @override
  Stream<ClinicLocation> get locationStream => _locationController.stream;

  @override
  Stream<LocationPermissionState> get permissionStream => _permissionController.stream;

  @override
  Future<LocationPermissionState> requestPermission() async {
    // If previously denied or unavailable, user can grant or re-grant clinic location permission
    if (_permissionState == LocationPermissionState.denied ||
        _permissionState == LocationPermissionState.unavailable) {
      _permissionState = LocationPermissionState.granted;
      _permissionController.add(_permissionState);
    }
    return _permissionState;
  }

  @override
  void setManualClinicLocation(ClinicLocation location) {
    _currentLocation = location.copyWith(isManualEntry: true);
    _permissionState = LocationPermissionState.manual;
    _locationController.add(_currentLocation);
    _permissionController.add(_permissionState);
    if (kDebugMode) {
      print('LocationService: Manual clinic set to "${_currentLocation.name}" (${_currentLocation.latitude}, ${_currentLocation.longitude})');
    }
  }

  @override
  void updatePermissionState(LocationPermissionState state) {
    _permissionState = state;
    _permissionController.add(_permissionState);
    if (kDebugMode) {
      print('LocationService: Permission state changed to ${state.name}');
    }
  }

  void dispose() {
    _locationController.close();
    _permissionController.close();
  }
}
