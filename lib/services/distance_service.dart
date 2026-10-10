import 'dart:math' as math;

/// Service abstraction for calculating geographic distance and transit duration
/// across rural road networks.
abstract class DistanceService {
  /// Computes distance in kilometers between two GPS coordinates.
  double calculateDistanceKm(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  );

  /// Estimates travel duration in minutes based on distance and vehicle speed.
  Duration estimateTravelTime(
    double distanceKm, {
    double averageSpeedKmH = 40.0,
    double roadCircuityFactor = 1.25,
  });
}

/// Standard Haversine distance calculator with rural road circuity adjustment.
class HaversineDistanceService implements DistanceService {
  static const double earthRadiusKm = 6371.0;

  const HaversineDistanceService();

  @override
  double calculateDistanceKm(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    if (startLat == endLat && startLon == endLon) {
      return 0.0;
    }

    final dLat = _degreesToRadians(endLat - startLat);
    final dLon = _degreesToRadians(endLon - startLon);

    final lat1Rad = _degreesToRadians(startLat);
    final lat2Rad = _degreesToRadians(endLat);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1Rad) *
            math.cos(lat2Rad);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadiusKm * c;

    return (distance * 10).roundToDouble() / 10; // Round to 1 decimal place
  }

  @override
  Duration estimateTravelTime(
    double distanceKm, {
    double averageSpeedKmH = 40.0,
    double roadCircuityFactor = 1.25,
  }) {
    if (distanceKm <= 0 || averageSpeedKmH <= 0) {
      return Duration.zero;
    }

    // Adjust straight-line distance for winding rural terrain
    final effectiveRoadDistance = distanceKm * roadCircuityFactor;
    final hours = effectiveRoadDistance / averageSpeedKmH;
    final minutes = (hours * 60).round();

    return Duration(minutes: math.max(1, minutes));
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
