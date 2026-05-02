import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_context.dart';

/// SafeZoneService — SHIELD Phase 6
///
/// Lets users define their own known-safe locations.
/// When user is stationary in a safe zone, risk scoring is suppressed.
/// Users can add zones by name (Home, Work, etc.) or by tapping the map.

class SafeZone {
  final String id;
  final String name;
  final LatLng position;
  final double radiusMeters;
  final SafeZoneType type;
  final DateTime addedAt;

  const SafeZone({
    required this.id,
    required this.name,
    required this.position,
    this.radiusMeters = 100.0,
    this.type = SafeZoneType.custom,
    required this.addedAt,
  });

  bool contains(LatLng point) =>
      position.distanceTo(point) <= radiusMeters;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': position.latitude,
        'lon': position.longitude,
        'radius': radiusMeters,
        'type': type.index,
        'addedAt': addedAt.toIso8601String(),
      };

  factory SafeZone.fromJson(Map<String, dynamic> j) => SafeZone(
        id: j['id'],
        name: j['name'],
        position: LatLng(j['lat'], j['lon']),
        radiusMeters: j['radius'] ?? 100.0,
        type: SafeZoneType.values[j['type'] ?? 0],
        addedAt: DateTime.parse(j['addedAt']),
      );
}

enum SafeZoneType { home, work, custom }

extension SafeZoneTypeX on SafeZoneType {
  String get label {
    switch (this) {
      case SafeZoneType.home: return 'Home';
      case SafeZoneType.work: return 'Work';
      case SafeZoneType.custom: return 'Safe Place';
    }
  }

  String get emoji {
    switch (this) {
      case SafeZoneType.home: return '🏠';
      case SafeZoneType.work: return '🏢';
      case SafeZoneType.custom: return '📍';
    }
  }
}

class SafeZoneService {
  static final SafeZoneService _instance = SafeZoneService._internal();
  factory SafeZoneService() => _instance;
  SafeZoneService._internal();

  static const _storageKey = 'safe_zones_v1';
  final List<SafeZone> _zones = [];
  List<SafeZone> get zones => List.unmodifiable(_zones);

  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _prefs = await SharedPreferences.getInstance();
    await _load();
  }

  // ── Zone management ────────────────────────────────────────────────────
  Future<void> addZone(SafeZone zone) async {
    _zones.removeWhere((z) => z.id == zone.id);
    _zones.add(zone);
    await _save();
  }

  Future<void> addCurrentLocation(
    LatLng position,
    String name,
    SafeZoneType type,
  ) async {
    final zone = SafeZone(
      id: 'zone_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      position: position,
      radiusMeters: 100.0,
      type: type,
      addedAt: DateTime.now(),
    );
    await addZone(zone);
  }

  Future<void> removeZone(String id) async {
    _zones.removeWhere((z) => z.id == id);
    await _save();
  }

  bool isInSafeZone(LatLng position) =>
      _zones.any((z) => z.contains(position));

  SafeZone? getCurrentZone(LatLng position) {
    try {
      return _zones.firstWhere((z) => z.contains(position));
    } catch (_) {
      return null;
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_prefs == null) return;
    final list = _zones.map((z) => jsonEncode(z.toJson())).toList();
    await _prefs!.setStringList(_storageKey, list);
  }

  Future<void> _load() async {
    if (_prefs == null) return;
    final list = _prefs!.getStringList(_storageKey) ?? [];
    _zones.clear();
    for (final s in list) {
      try {
        _zones.add(SafeZone.fromJson(jsonDecode(s)));
      } catch (_) {}
    }
  }
  void dispose() {}
}