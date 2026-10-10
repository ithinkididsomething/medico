import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Structured routing result containing distance, travel duration, and route geometry.
class RouteEstimate {
  final double distanceKm;
  final Duration estimatedTravelTime;
  final List<LatLng> waypoints;
  final bool isSimulated;
  final String sourceLabel;
  final String disclaimer;

  const RouteEstimate({
    required this.distanceKm,
    required this.estimatedTravelTime,
    required this.waypoints,
    required this.isSimulated,
    required this.sourceLabel,
    required this.disclaimer,
  });

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  String get formattedTravelTime {
    final mins = estimatedTravelTime.inMinutes;
    if (mins < 60) return '~$mins mins by Car';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem > 0 ? '~$hrs hr $rem mins by Car' : '~$hrs hr by Car';
  }
}

/// Abstract contract for routing services.
/// Enables seamless transition from simulated offline transit estimation to live OSRM/ORS APIs.
abstract class RoutingService {
  Future<RouteEstimate> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    bool isEmergency = false,
  });
}

/// Robust offline routing service using Haversine calculation and rural road curvature factors.
///
/// CLINICAL SAFETY NOTICE:
/// - Explicitly flags all output as simulated.
/// - Does NOT fabricate live traffic.
/// - Does NOT claim actual live route conditions.
class SimulatedRoutingService implements RoutingService {
  const SimulatedRoutingService();

  // Winding factor for rural road topology (straight-line to actual road distance)
  static const double ruralRoadCurvatureFactor = 1.25;

  // Average vehicle speeds in rural Indian/resource-constrained terrains (km/h)
  static const double standardRuralSpeedKmh = 35.0;
  static const double emergencyAmbulanceSpeedKmh = 45.0;

  @override
  Future<RouteEstimate> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    bool isEmergency = false,
  }) async {
    // 1. Calculate straight-line Haversine distance
    final straightDistance = _calculateHaversineDistance(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    // 2. Apply rural curvature factor to approximate road transit distance
    final roadDistance = straightDistance * ruralRoadCurvatureFactor;

    // 3. Calculate estimated duration based on vehicle type and terrain speed
    final speed = isEmergency ? emergencyAmbulanceSpeedKmh : standardRuralSpeedKmh;
    final durationMinutes = (roadDistance / speed * 60).round().clamp(5, 480);
    final travelTime = Duration(minutes: durationMinutes);

    // 4. Generate smooth route polyline points between origin and destination
    final waypoints = _generateRouteWaypoints(origin, destination, 8);

    return RouteEstimate(
      distanceKm: roadDistance,
      estimatedTravelTime: travelTime,
      waypoints: waypoints,
      isSimulated: true,
      sourceLabel: 'Simulated Rural Transit Estimate by Car (Offline)',
      disclaimer:
          'Simulated travel time by car based on distance (~${speed.toInt()} km/h). Live traffic is NOT monitored. Actual transfer times may vary with weather/monsoon conditions.',
    );
  }

  /// Calculates geodesic distance on a spherical Earth model in kilometers.
  static double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degree) => degree * (math.pi / 180.0);

  /// Generates gentle interpolated path waypoints with subtle realistic curvature.
  static List<LatLng> _generateRouteWaypoints(
    LatLng start,
    LatLng end,
    int segments,
  ) {
    final points = <LatLng>[start];
    for (int i = 1; i < segments; i++) {
      final t = i / segments.toDouble();
      // Linear interpolation
      final lat = start.latitude + (end.latitude - start.latitude) * t;
      final lon = start.longitude + (end.longitude - start.longitude) * t;

      // Subtle perpendicular curve to simulate road winding
      final curve = math.sin(t * math.pi) * 0.003;
      points.add(LatLng(lat + curve, lon - (curve * 0.5)));
    }
    points.add(end);
    return points;
  }
}
