import '../models/location_context.dart';
import '../models/danger_zone.dart';

/// HeatmapService — auto-generates danger zones based on time of day.
/// No manual input needed. Zones shift with real-world risk patterns.
class HeatmapService {
  final List<DangerZone> _zones = [];

  List<DangerZone> getZones() => List.unmodifiable(_zones);

  /// Called on app init. Generates zones relevant to current time of day.
  void generateZonesForCurrentTime() {
    _zones.clear();
    final hour = DateTime.now().hour;

    if (hour >= 22 || hour < 5) {
      // Late night — highest density near transit + isolated areas
      _addZone(const LatLng(12.9420, 77.6300), 350, 88, 'Late-night transit zone');
      _addZone(const LatLng(12.9650, 77.6000), 280, 75, 'Isolated area');
      _addZone(const LatLng(12.9500, 77.6100), 200, 62, 'Poorly lit street');
      _addZone(const LatLng(12.9580, 77.5980), 180, 70, 'Underpass');
      _addZone(const LatLng(12.9310, 77.6150), 240, 55, 'Empty market area');
    } else if (hour >= 18 && hour < 22) {
      // Evening — moderate risk near busy areas and exits
      _addZone(const LatLng(12.9420, 77.6300), 300, 60, 'Evening rush zone');
      _addZone(const LatLng(12.9650, 77.6000), 250, 48, 'Commuter area');
      _addZone(const LatLng(12.9500, 77.6100), 180, 38, 'Market area');
    } else if (hour >= 7 && hour < 9) {
      // Morning rush — crowded transit, mild risk
      _addZone(const LatLng(12.9420, 77.6300), 280, 40, 'Morning transit zone');
      _addZone(const LatLng(12.9580, 77.5980), 200, 32, 'Bus stand');
    } else {
      // Daytime — low baseline risk
      _addZone(const LatLng(12.9420, 77.6300), 250, 28, 'General caution area');
      _addZone(const LatLng(12.9500, 77.6100), 180, 22, 'Monitor zone');
    }
  }

  void _addZone(LatLng center, double radius, int intensity, String label) {
    _zones.add(DangerZone(
      center: center,
      radius: radius,
      intensity: intensity,
      label: label,
    ));
  }

  void addCustomZone(DangerZone zone) => _zones.add(zone);

  void clearZones() => _zones.clear();
}