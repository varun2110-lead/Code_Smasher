import '../models/location_context.dart';
import '../models/route_option.dart';
import '../models/danger_zone.dart';

/// Service for scoring routes based on danger zones
class RouteScorer {
  /// Scores a list of routes based on danger zones
  /// 
  /// [routes] - List of route options to score
  /// [zones] - List of danger zones to evaluate against
  List<RouteOption> scoreRoutes(List<RouteOption> routes, List<DangerZone> zones) {
    if (routes.isEmpty || zones.isEmpty) {
      // No danger zones, all routes are safe
      return routes.map((r) => r.copyWith(
        safetyScore: 100,
        reasons: ['No danger zones detected'],
      )).toList();
    }

    return routes.map((route) => _scoreRoute(route, zones)).toList();
  }

  /// Scores a single route
  RouteOption _scoreRoute(RouteOption route, List<DangerZone> zones) {
    int totalRisk = 0;
    int pointsInZones = 0;
    final Set<String> intersectedZones = {};

    // Check each point in the route against all danger zones
    for (int i = 0; i < route.path.length; i++) {
      final point = route.path[i];
      
      for (int z = 0; z < zones.length; z++) {
        final zone = zones[z];
        final distance = point.distanceTo(zone.center);
        
        // Check if point is inside the danger zone
        if (distance <= zone.radius) {
          totalRisk += zone.intensity;
          pointsInZones++;
          intersectedZones.add('zone_$z');
        }
      }
    }

    // Calculate base score
    final numberOfPoints = route.path.length;
    double score = 100.0;
    
    if (numberOfPoints > 0) {
      // Reduce score based on risk per point
      score = 100.0 - (totalRisk / numberOfPoints);
      
      // Extra penalty for intersecting multiple zones
      if (intersectedZones.length > 1) {
        score -= (intersectedZones.length - 1) * 10;
      }
    }

    // Clamp score between 0 and 100
    score = score.clamp(0.0, 100.0);

    // Generate reasons
    final reasons = _generateReasons(
      score: score.round(),
      pointsInZones: pointsInZones,
      totalPoints: numberOfPoints,
      zonesIntersected: intersectedZones.length,
    );

    return route.copyWith(
      safetyScore: score.round(),
      reasons: reasons,
    );
  }

  /// Generates human-readable reasons for the score
  List<String> _generateReasons({
    required int score,
    required int pointsInZones,
    required int totalPoints,
    required int zonesIntersected,
  }) {
    final reasons = <String>[];

    if (score >= 80) {
      reasons.add('Avoids dangerous areas');
    } else if (score >= 60) {
      reasons.add('Passes near moderate-risk zones');
    } else if (score >= 40) {
      reasons.add('Passes through elevated-risk zones');
    } else {
      reasons.add('Passes through high-risk zones');
    }

    if (pointsInZones > 0) {
      final percentage = ((pointsInZones / totalPoints) * 100).round();
      reasons.add('$percentage% of route in danger zones');
    }

    if (zonesIntersected > 1) {
      reasons.add('Intersects $zonesIntersected danger areas');
    }

    if (score >= 90) {
      reasons.add('Recommended safest route');
    }

    return reasons;
  }

  /// Sorts routes by safety score (highest first)
  List<RouteOption> sortBySafety(List<RouteOption> routes) {
    final sorted = List<RouteOption>.from(routes);
    sorted.sort((a, b) => b.safetyScore.compareTo(a.safetyScore));
    return sorted;
  }
}