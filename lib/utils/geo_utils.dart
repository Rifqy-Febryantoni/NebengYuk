import 'dart:math';

class GeoUtils {
  /// Calculate the Haversine distance between two geopoints in kilometers.
  static double haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Check if two points are within a given radius (in km).
  static bool isWithinRadius(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    double radiusKm,
  ) {
    return haversineDistance(lat1, lng1, lat2, lng2) <= radiusKm;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
