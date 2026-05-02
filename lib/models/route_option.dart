import '../models/location_context.dart';

/// Route option model for displaying route alternatives
class RouteOption {
  final String id;
  final List<LatLng> path;
  final double distanceKm;
  final int durationMinutes;
  final int safetyScore;
  final List<String> reasons;

  const RouteOption({
    required this.id,
    required this.path,
    required this.distanceKm,
    required this.durationMinutes,
    this.safetyScore = 0,
    this.reasons = const [],
  });

  RouteOption copyWith({
    String? id,
    List<LatLng>? path,
    double? distanceKm,
    int? durationMinutes,
    int? safetyScore,
    List<String>? reasons,
  }) {
    return RouteOption(
      id: id ?? this.id,
      path: path ?? this.path,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      safetyScore: safetyScore ?? this.safetyScore,
      reasons: reasons ?? this.reasons,
    );
  }
}