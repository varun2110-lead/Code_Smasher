import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/location_context.dart';
import '../models/route_option.dart';

/// Service for fetching routes from OpenRouteService API
class RouteApiService {
  static const String _baseUrl = 'https://api.openrouteservice.org/v2/directions/foot-walking';

  /// Fetches walking routes from ORS API
  /// 
  /// [startLat], [startLng] - Start coordinates
  /// [endLat], [endLng] - Destination coordinates
  /// [alternativeRoutes] - Whether to request alternative routes
  Future<List<RouteOption>> getRoutes(
    double startLat,
    double startLng,
    double endLat,
    double endLng, {
    bool alternativeRoutes = true,
  }) async {
    final queryParams = {
      'api_key': ApiConfig.orsApiKey,
      'start': '$startLng,$startLat',
      'end': '$endLng,$endLat',
      if (alternativeRoutes) 'alternative_routes': 'true',
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw RouteApiException(
          'API returned status ${response.statusCode}: ${response.body}',
        );
      }

      final data = json.decode(response.body);
      return _parseRoutes(data);
    } catch (e) {
      if (e is RouteApiException) rethrow;
      throw RouteApiException('Failed to fetch routes: $e');
    }
  }

  /// Parses the ORS API response into RouteOption objects
  List<RouteOption> _parseRoutes(Map<String, dynamic> data) {
    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      return [];
    }

    final routes = <RouteOption>[];
    
    for (int i = 0; i < features.length; i++) {
      final feature = features[i] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      final properties = feature['properties'] as Map<String, dynamic>?;
      
      if (geometry == null || properties == null) continue;

      // Parse coordinates [lng, lat] -> LatLng(lat, lng)
      final coordinates = geometry['coordinates'] as List<dynamic>?;
      if (coordinates == null) continue;

      final path = coordinates.map((coord) {
        final coordList = coord as List<dynamic>;
        return LatLng(
          (coordList[1] as num).toDouble(),
          (coordList[0] as num).toDouble(),
        );
      }).toList();

      // Parse summary (distance in meters, duration in seconds)
      final summary = properties['summary'] as Map<String, dynamic>?;
      final distanceMeters = (summary?['distance'] as num?)?.toDouble() ?? 0.0;
      final durationSeconds = (summary?['duration'] as num?)?.toDouble() ?? 0.0;

      routes.add(RouteOption(
        id: 'route_${i + 1}',
        path: path,
        distanceKm: distanceMeters / 1000.0,
        durationMinutes: (durationSeconds / 60).round(),
      ));
    }

    return routes;
  }

  /// Test method to verify API connectivity
  Future<void> testRouteFetch() async {
    // Sample Bangalore coordinates
    const startLat = 12.9352;
    const startLng = 77.6245;
    const endLat = 12.9760;
    const endLng = 77.5715;

    print('Testing route fetch...');
    print('Start: $startLat, $startLng');
    print('End: $endLat, $endLng');

    final routes = await getRoutes(startLat, startLng, endLat, endLng);

    print('Number of routes: ${routes.length}');
    for (int i = 0; i < routes.length; i++) {
      print('Route ${i + 1}: ${routes[i].path.length} points, '
          '${routes[i].distanceKm.toStringAsFixed(2)} km, '
          '${routes[i].durationMinutes} min');
    }
  }
}

/// Custom exception for route API errors
class RouteApiException implements Exception {
  final String message;
  RouteApiException(this.message);

  @override
  String toString() => 'RouteApiException: $message';
}