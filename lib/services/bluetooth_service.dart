import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BluetoothFingerprintService — SHIELD Phase 4
///
/// Passively scans nearby Bluetooth devices every 60 seconds.
/// Hashes MAC addresses locally (never uploaded — privacy preserving).
/// Detects if the same device appears across multiple different locations.
/// Flags potential stalking when threshold is crossed.
///
/// HOW IT WORKS:
///   1. Scan → collect nearby device MACs
///   2. SHA-256 hash each MAC (one-way, irreversible)
///   3. Store: hash → list of (timestamp, lat, lng, location_label)
///   4. If same hash seen at 3+ distinct locations → STALKER FLAG
///
/// Zero network calls. All data stays on device.
/// Works fully offline.

class DeviceSighting {
  final String hashedMac;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String locationLabel; // "unknown" or hashed home/work label

  const DeviceSighting({
    required this.hashedMac,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.locationLabel,
  });

  Map<String, dynamic> toJson() => {
        'hash': hashedMac,
        'ts': timestamp.toIso8601String(),
        'lat': latitude,
        'lon': longitude,
        'loc': locationLabel,
      };

  factory DeviceSighting.fromJson(Map<String, dynamic> j) => DeviceSighting(
        hashedMac: j['hash'],
        timestamp: DateTime.parse(j['ts']),
        latitude: j['lat'],
        longitude: j['lon'],
        locationLabel: j['loc'],
      );
}

class StalkerCandidate {
  final String hashedMac;
  final List<DeviceSighting> sightings;
  final int distinctLocations;
  final DateTime firstSeen;
  final DateTime lastSeen;

  const StalkerCandidate({
    required this.hashedMac,
    required this.sightings,
    required this.distinctLocations,
    required this.firstSeen,
    required this.lastSeen,
  });

  /// Short display ID — last 6 chars of hash, uppercase
  String get displayId => hashedMac.substring(hashedMac.length - 6).toUpperCase();

  Duration get followDuration => lastSeen.difference(firstSeen);
}

class BluetoothScanResult {
  final int devicesFound;
  final int newSightings;
  final List<StalkerCandidate> stalkerCandidates;
  final DateTime timestamp;

  const BluetoothScanResult({
    required this.devicesFound,
    required this.newSightings,
    required this.stalkerCandidates,
    required this.timestamp,
  });
}

class BluetoothFingerprintService {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final BluetoothFingerprintService _instance =
      BluetoothFingerprintService._internal();
  factory BluetoothFingerprintService() => _instance;
  BluetoothFingerprintService._internal();

  // ── Config ─────────────────────────────────────────────────────────────
  static const _scanInterval = Duration(seconds: 60);
  static const _scanDuration = Duration(seconds: 8);
  static const _stalkerLocationThreshold = 3; // distinct locations
  static const _stalkerTimeWindowHours = 4;   // within 4 hours
  static const _locationDistinctMeters = 150.0; // 150m = distinct location
  static const _storageKey = 'bt_sightings_v2';
  static const _maxStoredSightings = 500;      // cap storage

  // ── State ──────────────────────────────────────────────────────────────
  final _resultController = StreamController<BluetoothScanResult>.broadcast();
  Stream<BluetoothScanResult> get resultStream => _resultController.stream;

  final _stalkerController = StreamController<StalkerCandidate>.broadcast();
  Stream<StalkerCandidate> get stalkerStream => _stalkerController.stream;

  /// All sightings: hashedMac -> list of sightings
  final Map<String, List<DeviceSighting>> _sightingMap = {};

  List<StalkerCandidate> _currentCandidates = [];
  List<StalkerCandidate> get currentCandidates =>
      List.unmodifiable(_currentCandidates);

  bool _scanning = false;
  bool get isScanning => _scanning;

  bool _disposed = false;
  Timer? _scanTimer;
  SharedPreferences? _prefs;

  double _currentLat = 12.9716;
  double _currentLon = 77.5946;

  // ── Demo simulation state ──────────────────────────────────────────────
  bool _demoMode = false;
  final _rng = Random();
  final List<String> _demoDeviceHashes = [];

  // ── Init ───────────────────────────────────────────────────────────────
  Future<void> init({
    required double initialLat,
    required double initialLon,
    bool demoMode = false,
  }) async {
    _currentLat = initialLat;
    _currentLon = initialLon;
    _demoMode = demoMode;

    _prefs = await SharedPreferences.getInstance();
    await _loadSightings();

    if (_demoMode) {
      _seedDemoData();
    }

    // Check if Bluetooth is available (won't crash if not)
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        _startDemoScanning();
        return;
      }
      _startRealScanning();
    } catch (_) {
      // Emulator or BT unavailable — fall back to demo simulation
      _startDemoScanning();
    }
  }

  // ── Location update (called by SafetyEngine) ───────────────────────────
  void updateLocation(double lat, double lon) {
    _currentLat = lat;
    _currentLon = lon;
  }

  // ── Real Bluetooth scanning ────────────────────────────────────────────
  void _startRealScanning() {
    _doRealScan(); // immediate first scan
    _scanTimer = Timer.periodic(_scanInterval, (_) {
      if (!_disposed) _doRealScan();
    });
  }

  Future<void> _doRealScan() async {
    if (_scanning || _disposed) return;
    _scanning = true;

    try {
      // Check permissions + BT state
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        _scanning = false;
        return;
      }

      final discovered = <String>{};

      // Listen to scan results
      final sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final mac = r.device.remoteId.str;
          if (mac.isNotEmpty) discovered.add(mac);
        }
      });

      await FlutterBluePlus.startScan(timeout: _scanDuration);
      await Future.delayed(_scanDuration + const Duration(milliseconds: 200));
      await FlutterBluePlus.stopScan();
      await sub.cancel();

      final newSightings = await _processMacs(discovered.toList());
      final candidates = _detectStalkers();

      _currentCandidates = candidates;

      final result = BluetoothScanResult(
        devicesFound: discovered.length,
        newSightings: newSightings,
        stalkerCandidates: candidates,
        timestamp: DateTime.now(),
      );

      if (!_disposed) _resultController.add(result);

      // Emit each new stalker candidate
      for (final c in candidates) {
        if (!_disposed) _stalkerController.add(c);
      }
    } catch (e) {
      // Scan failed — continue silently
    } finally {
      _scanning = false;
    }
  }

  // ── Demo scanning (emulator / no BT) ──────────────────────────────────
  void _startDemoScanning() {
    _doDemo();
    _scanTimer = Timer.periodic(_scanInterval, (_) {
      if (!_disposed) _doDemo();
    });
  }

  Future<void> _doDemo() async {
    if (_disposed) return;
    _scanning = true;

    await Future.delayed(const Duration(seconds: 2)); // simulate scan time

    // Generate 5-15 random "nearby" devices
    final randomCount = 5 + _rng.nextInt(10);
    final fakeMacs = List.generate(randomCount, (_) => _randomMac());

    // Always include our demo "stalker" devices (3 of them)
    final allMacs = [...fakeMacs, ..._demoDeviceHashes.take(3)];

    final newSightings = await _processMacs(allMacs);
    final candidates = _detectStalkers();
    _currentCandidates = candidates;

    final result = BluetoothScanResult(
      devicesFound: allMacs.length,
      newSightings: newSightings,
      stalkerCandidates: candidates,
      timestamp: DateTime.now(),
    );

    if (!_disposed) _resultController.add(result);
    for (final c in candidates) {
      if (!_disposed) _stalkerController.add(c);
    }

    _scanning = false;
  }

  // ── Seed demo data — pre-populate sightings for demo ──────────────────
  void _seedDemoData() {
    // Create 3 fake "stalker" device hashes
    for (int i = 0; i < 3; i++) {
      final mac = 'AA:BB:CC:DD:EE:0$i';
      final hash = _hashMac(mac);
      _demoDeviceHashes.add(hash);

      // Seed 2 prior sightings at different locations (past 2 hours)
      final offsets = [
        [0.002, 0.001],   // ~200m away
        [0.004, -0.002],  // ~400m away
      ];

      for (final offset in offsets) {
        final s = DeviceSighting(
          hashedMac: hash,
          timestamp: DateTime.now().subtract(
            Duration(minutes: 30 + _rng.nextInt(60)),
          ),
          latitude: _currentLat + offset[0],
          longitude: _currentLon + offset[1],
          locationLabel: 'area_${_rng.nextInt(9999)}',
        );
        _sightingMap.putIfAbsent(hash, () => []).add(s);
      }
    }
  }

  // ── MAC processing ─────────────────────────────────────────────────────
  Future<int> _processMacs(List<String> macs) async {
    int newSightings = 0;
    final now = DateTime.now();

    for (final mac in macs) {
      final hash = _hashMac(mac);
      final existing = _sightingMap[hash] ?? [];

      // Skip if already sighted at this location recently (within 5 min)
      final recentHere = existing.any((s) =>
          now.difference(s.timestamp).inMinutes < 5 &&
          _distanceMeters(s.latitude, s.longitude, _currentLat, _currentLon) <
              _locationDistinctMeters);

      if (recentHere) continue;

      final sighting = DeviceSighting(
        hashedMac: hash,
        timestamp: now,
        latitude: _currentLat,
        longitude: _currentLon,
        locationLabel: _locationLabel(_currentLat, _currentLon),
      );

      _sightingMap.putIfAbsent(hash, () => []).add(sighting);
      newSightings++;
    }

    // Prune old sightings to keep storage bounded
    _pruneOldSightings();
    await _saveSightings();

    return newSightings;
  }

  // ── Stalker detection algorithm ────────────────────────────────────────
  List<StalkerCandidate> _detectStalkers() {
    final candidates = <StalkerCandidate>[];
    final cutoff = DateTime.now()
        .subtract(Duration(hours: _stalkerTimeWindowHours));

    for (final entry in _sightingMap.entries) {
      final hash = entry.key;
      final allSightings = entry.value;

      // Only look at sightings within the time window
      final recent = allSightings
          .where((s) => s.timestamp.isAfter(cutoff))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (recent.length < 2) continue;

      // Count distinct locations
      final distinctLocs = _countDistinctLocations(recent);

      if (distinctLocs >= _stalkerLocationThreshold) {
        candidates.add(StalkerCandidate(
          hashedMac: hash,
          sightings: recent,
          distinctLocations: distinctLocs,
          firstSeen: recent.first.timestamp,
          lastSeen: recent.last.timestamp,
        ));
      }
    }

    // Sort by most dangerous (most distinct locations)
    candidates.sort((a, b) => b.distinctLocations.compareTo(a.distinctLocations));
    return candidates;
  }

  int _countDistinctLocations(List<DeviceSighting> sightings) {
    final clusters = <DeviceSighting>[];

    for (final s in sightings) {
      final isNew = clusters.every((c) =>
          _distanceMeters(c.latitude, c.longitude, s.latitude, s.longitude) >=
          _locationDistinctMeters);
      if (isNew) clusters.add(s);
    }

    return clusters.length;
  }

  // ── Hashing ────────────────────────────────────────────────────────────
  String _hashMac(String mac) {
    final bytes = utf8.encode(mac.toUpperCase().trim());
    return sha256.convert(bytes).toString();
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  String _randomMac() {
    return List.generate(
      6,
      (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join(':').toUpperCase();
  }

  String _locationLabel(double lat, double lon) {
    // Hashed label — doesn't reveal actual address
    final raw = '${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 8);
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _pruneOldSightings() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    for (final key in _sightingMap.keys.toList()) {
      _sightingMap[key]!.removeWhere((s) => s.timestamp.isBefore(cutoff));
      if (_sightingMap[key]!.isEmpty) _sightingMap.remove(key);
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────
  Future<void> _saveSightings() async {
    if (_prefs == null) return;
    try {
      final all = <Map<String, dynamic>>[];
      for (final sightings in _sightingMap.values) {
        for (final s in sightings) {
          all.add(s.toJson());
        }
      }
      // Keep only most recent N sightings
      all.sort((a, b) => b['ts'].compareTo(a['ts']));
      final trimmed = all.take(_maxStoredSightings).toList();
      await _prefs!.setString(_storageKey, jsonEncode(trimmed));
    } catch (_) {}
  }

  Future<void> _loadSightings() async {
    if (_prefs == null) return;
    try {
      final raw = _prefs!.getString(_storageKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      for (final item in list) {
        final s = DeviceSighting.fromJson(item);
        _sightingMap.putIfAbsent(s.hashedMac, () => []).add(s);
      }
    } catch (_) {}
  }

  // ── Manual trigger for demo button ────────────────────────────────────
  Future<void> triggerImmediateScan() async {
    if (_demoMode) {
      await _doDemo();
    } else {
      await _doRealScan();
    }
  }

  // ── Stats for UI ───────────────────────────────────────────────────────
  int get totalDevicesTracked => _sightingMap.length;
  int get totalSightings =>
      _sightingMap.values.fold(0, (sum, list) => sum + list.length);

  // ── Cleanup ────────────────────────────────────────────────────────────
  void dispose() {
    _disposed = true;
    _scanTimer?.cancel();
    _resultController.close();
    _stalkerController.close();
  }
}