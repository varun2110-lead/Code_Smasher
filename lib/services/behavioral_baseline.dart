import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_context.dart';

/// BehavioralBaseline — SHIELD Phase 5
///
/// Quietly learns the user's normal patterns over time.
/// No ML model required — pure statistical baseline on-device.
///
/// WHAT IT LEARNS:
///   - Typical locations by hour of day (home, work, commute)
///   - Normal stationary duration at each location type
///   - Usual movement speed patterns
///   - Safe hours (when user is normally active vs asleep)
///   - Route corridors (areas user regularly passes through)
///
/// HOW ANOMALY WORKS:
///   - Each observation is compared to the learned baseline
///   - Anomaly score = deviation from personal normal
///   - Same situation scores differently for different users
///   - Night shift worker at 2am = LOW anomaly (their normal)
///   - Office worker at 2am in unknown area = HIGH anomaly
///
/// Storage: shared_preferences, fully on-device, no network.

// ── Data models ────────────────────────────────────────────────────────

class HourlyPattern {
  final int hour; // 0-23
  final List<double> latitudes;
  final List<double> longitudes;
  final List<int> stationaryDurations; // seconds
  final List<double> speeds;
  int observationCount;

  HourlyPattern({
    required this.hour,
    List<double>? latitudes,
    List<double>? longitudes,
    List<int>? stationaryDurations,
    List<double>? speeds,
    this.observationCount = 0,
  })  : latitudes = latitudes ?? [],
        longitudes = longitudes ?? [],
        stationaryDurations = stationaryDurations ?? [],
        speeds = speeds ?? [];

  // Centroid of known locations for this hour
  LatLng? get centroid {
    if (latitudes.isEmpty) return null;
    final avgLat = latitudes.reduce((a, b) => a + b) / latitudes.length;
    final avgLon = longitudes.reduce((a, b) => a + b) / longitudes.length;
    return LatLng(avgLat, avgLon);
  }

  // Average spread (how far user typically roams during this hour)
  double get locationSpreadMeters {
    final c = centroid;
    if (c == null || latitudes.length < 2) return 500.0;
    double totalDist = 0;
    for (int i = 0; i < latitudes.length; i++) {
      totalDist += c.distanceTo(LatLng(latitudes[i], longitudes[i]));
    }
    return (totalDist / latitudes.length).clamp(50.0, 2000.0);
  }

  double get avgStationarySeconds {
    if (stationaryDurations.isEmpty) return 60.0;
    return stationaryDurations.reduce((a, b) => a + b) /
        stationaryDurations.length;
  }

  double get avgSpeed {
    if (speeds.isEmpty) return 0.5;
    return speeds.reduce((a, b) => a + b) / speeds.length;
  }

  bool get hasEnoughData => observationCount >= 3;

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'lats': latitudes,
        'lons': longitudes,
        'stats': stationaryDurations,
        'speeds': speeds,
        'obs': observationCount,
      };

  factory HourlyPattern.fromJson(Map<String, dynamic> j) => HourlyPattern(
        hour: j['hour'],
        latitudes: List<double>.from(j['lats'] ?? []),
        longitudes: List<double>.from(j['lons'] ?? []),
        stationaryDurations: List<int>.from(j['stats'] ?? []),
        speeds: List<double>.from(j['speeds'] ?? []),
        observationCount: j['obs'] ?? 0,
      );
}

class BaselineProfile {
  final Map<int, HourlyPattern> hourlyPatterns; // hour -> pattern
  final DateTime createdAt;
  DateTime lastUpdated;
  int totalObservations;

  BaselineProfile({
    Map<int, HourlyPattern>? hourlyPatterns,
    DateTime? createdAt,
    DateTime? lastUpdated,
    this.totalObservations = 0,
  })  : hourlyPatterns = hourlyPatterns ?? {},
        createdAt = createdAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  bool get hasEnoughData => totalObservations >= 10;

  // How many hours have learned patterns
  int get learnedHours =>
      hourlyPatterns.values.where((p) => p.hasEnoughData).length;

  // Learning progress 0.0 - 1.0
  double get learningProgress =>
      (totalObservations / 50.0).clamp(0.0, 1.0);

  String get learningStatusLabel {
    if (totalObservations < 5) return 'Learning started';
    if (totalObservations < 15) return 'Building your profile';
    if (totalObservations < 30) return 'Getting smarter';
    return 'Fully calibrated';
  }

  Map<String, dynamic> toJson() => {
        'patterns': hourlyPatterns
            .map((k, v) => MapEntry(k.toString(), v.toJson())),
        'createdAt': createdAt.toIso8601String(),
        'lastUpdated': lastUpdated.toIso8601String(),
        'totalObs': totalObservations,
      };

  factory BaselineProfile.fromJson(Map<String, dynamic> j) {
    final patterns = <int, HourlyPattern>{};
    final raw = j['patterns'] as Map<String, dynamic>? ?? {};
    for (final entry in raw.entries) {
      final hour = int.tryParse(entry.key) ?? 0;
      patterns[hour] = HourlyPattern.fromJson(entry.value);
    }
    return BaselineProfile(
      hourlyPatterns: patterns,
      createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      lastUpdated: DateTime.tryParse(j['lastUpdated'] ?? '') ?? DateTime.now(),
      totalObservations: j['totalObs'] ?? 0,
    );
  }
}

// ── Main service ───────────────────────────────────────────────────────

class BehavioralBaseline {
  // Singleton
  static final BehavioralBaseline _instance = BehavioralBaseline._internal();
  factory BehavioralBaseline() => _instance;
  BehavioralBaseline._internal();

  static const _storageKey = 'behavioral_baseline_v1';
  static const _maxObservationsPerHour = 30; // cap memory usage
  static const _observationInterval = Duration(seconds: 30);

  BaselineProfile _profile = BaselineProfile();
  BaselineProfile get profile => _profile;

  SharedPreferences? _prefs;
  Timer? _observationTimer;
  bool _initialized = false;
  bool _disposed = false;

  LocationContext? _lastContext;

  // ── Init ───────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _prefs = await SharedPreferences.getInstance();
    await _load();

    // For demo: seed baseline data so it shows something immediately
    if (_profile.totalObservations < 5) {
      _seedDemoBaseline();
    }
  }

  // ── Observation pipeline ───────────────────────────────────────────────
  /// Feed location context into the baseline every 30 seconds.
  /// Call this from SafetyEngine whenever location updates.
  void observe(LocationContext ctx) {
    _lastContext = ctx;
  }

  /// Start the periodic observation timer.
  void startLearning() {
    _observationTimer?.cancel();
    _observationTimer =
        Timer.periodic(_observationInterval, (_) => _recordObservation());
  }

  void _recordObservation() {
    final ctx = _lastContext;
    if (ctx == null || _disposed) return;

    final hour = DateTime.now().hour;
    final pattern = _profile.hourlyPatterns.putIfAbsent(
      hour,
      () => HourlyPattern(hour: hour),
    );

    // Record location (keep last N per hour)
    if (pattern.latitudes.length < _maxObservationsPerHour) {
      pattern.latitudes.add(ctx.position.latitude);
      pattern.longitudes.add(ctx.position.longitude);
      pattern.stationaryDurations.add(ctx.stationarySeconds);
      pattern.speeds.add(ctx.speed);
    } else {
      // Rolling window - replace oldest
      final idx = pattern.observationCount % _maxObservationsPerHour;
      pattern.latitudes[idx] = ctx.position.latitude;
      pattern.longitudes[idx] = ctx.position.longitude;
      pattern.stationaryDurations[idx] = ctx.stationarySeconds;
      pattern.speeds[idx] = ctx.speed;
    }

    pattern.observationCount++;
    _profile.totalObservations++;
    _profile.lastUpdated = DateTime.now();

    _save(); // async, fire and forget
  }

  // ── Anomaly computation ────────────────────────────────────────────────
  /// Returns anomaly score 0-100.
  /// 0 = perfectly normal for this user.
  /// 100 = extremely unusual for this user at this time.
  AnomalyResult computeAnomaly(LocationContext ctx) {
    final hour = DateTime.now().hour;
    final pattern = _profile.hourlyPatterns[hour];
    final reasons = <String>[];

    // Not enough data yet — return neutral
    if (!_profile.hasEnoughData || pattern == null || !pattern.hasEnoughData) {
      return AnomalyResult(
        score: 0,
        reasons: [],
        isCalibrated: false,
      );
    }

    int anomalyScore = 0;

    // 1. Location anomaly — how far from usual location at this hour
    final centroid = pattern.centroid;
    if (centroid != null) {
      final distFromNormal =
          centroid.distanceTo(ctx.position);
      final spread = pattern.locationSpreadMeters;

      if (distFromNormal > spread * 3) {
        // Very far from usual location at this hour
        final severity = ((distFromNormal - spread * 3) / 500).clamp(0, 1);
        final pts = (severity * 35).round();
        anomalyScore += pts;
        if (pts > 10) {
          reasons.add(
              'You are unusually far from your typical location at this hour');
        }
      } else if (distFromNormal > spread * 1.5) {
        anomalyScore += 15;
        reasons.add('You are in an area you rarely visit at this time');
      }
    }

    // 2. Stationary anomaly — stationary longer than usual for this hour
    final avgStationary = pattern.avgStationarySeconds;
    if (ctx.stationarySeconds > avgStationary * 2.5 &&
        ctx.stationarySeconds > 60) {
      final pts =
          ((ctx.stationarySeconds - avgStationary * 2.5) / 60).clamp(0, 25).round();
      anomalyScore += pts;
      if (pts > 5) {
        reasons.add(
            'You have been still much longer than you usually are at ${_hourLabel(hour)}');
      }
    }

    // 3. Speed anomaly — moving much slower or faster than usual
    final avgSpd = pattern.avgSpeed;
    if (avgSpd > 0.5 && ctx.speed < 0.1 && ctx.stationarySeconds > 45) {
      anomalyScore += 10;
      reasons.add('You are stationary when you are usually moving at this time');
    }

    // 4. Time-of-day anomaly — being active when normally inactive (sleep hours)
    final isNormallyActiveHour = _isNormallyActiveHour(hour);
    if (!isNormallyActiveHour && ctx.speed > 0.5) {
      anomalyScore += 20;
      reasons.add('You are moving during hours you are usually asleep');
    }

    return AnomalyResult(
      score: anomalyScore.clamp(0, 100),
      reasons: reasons,
      isCalibrated: true,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  bool _isNormallyActiveHour(int hour) {
    // Check if user has observations during this hour
    final pattern = _profile.hourlyPatterns[hour];
    if (pattern == null) return true; // unknown - assume active
    return pattern.observationCount > 2;
  }

  String _hourLabel(int hour) {
    if (hour == 0) return 'midnight';
    if (hour < 12) return '${hour}am';
    if (hour == 12) return 'noon';
    return '${hour - 12}pm';
  }

  // ── Demo seeding ───────────────────────────────────────────────────────
  /// Seeds realistic baseline data so demo works on first launch.
  /// Simulates a typical Bangalore office worker routine.
  void _seedDemoBaseline() {
    final rng = Random();
    const homeLat = 12.9352;
    const homeLon = 77.6245;
    const workLat = 12.9760;
    const workLon = 77.5715;

    // Morning routine: 7am-9am — commuting from home to work
    for (int hour in [7, 8, 9]) {
      final p = HourlyPattern(hour: hour);
      for (int i = 0; i < 8; i++) {
        // Locations between home and work
        final t = i / 8.0;
        p.latitudes.add(homeLat + (workLat - homeLat) * t +
            (rng.nextDouble() - 0.5) * 0.003);
        p.longitudes.add(homeLon + (workLon - homeLon) * t +
            (rng.nextDouble() - 0.5) * 0.003);
        p.stationaryDurations.add(rng.nextInt(30) + 10);
        p.speeds.add(1.5 + rng.nextDouble() * 2.0); // walking/auto speed
        p.observationCount++;
        _profile.totalObservations++;
      }
      _profile.hourlyPatterns[hour] = p;
    }

    // Work hours: 10am-6pm — stationary at office
    for (int hour in [10, 11, 12, 13, 14, 15, 16, 17, 18]) {
      final p = HourlyPattern(hour: hour);
      for (int i = 0; i < 8; i++) {
        p.latitudes
            .add(workLat + (rng.nextDouble() - 0.5) * 0.001);
        p.longitudes
            .add(workLon + (rng.nextDouble() - 0.5) * 0.001);
        p.stationaryDurations
            .add(rng.nextInt(120) + 180); // long stationary at desk
        p.speeds.add(rng.nextDouble() * 0.3); // nearly still
        p.observationCount++;
        _profile.totalObservations++;
      }
      _profile.hourlyPatterns[hour] = p;
    }

    // Evening commute: 7pm-8pm
    for (int hour in [19, 20]) {
      final p = HourlyPattern(hour: hour);
      for (int i = 0; i < 8; i++) {
        final t = i / 8.0;
        p.latitudes.add(workLat + (homeLat - workLat) * t +
            (rng.nextDouble() - 0.5) * 0.003);
        p.longitudes.add(workLon + (homeLon - workLon) * t +
            (rng.nextDouble() - 0.5) * 0.003);
        p.stationaryDurations.add(rng.nextInt(40) + 15);
        p.speeds.add(1.0 + rng.nextDouble() * 1.5);
        p.observationCount++;
        _profile.totalObservations++;
      }
      _profile.hourlyPatterns[hour] = p;
    }

    // Home evening: 9pm-11pm — stationary at home
    for (int hour in [21, 22, 23]) {
      final p = HourlyPattern(hour: hour);
      for (int i = 0; i < 6; i++) {
        p.latitudes
            .add(homeLat + (rng.nextDouble() - 0.5) * 0.0005);
        p.longitudes
            .add(homeLon + (rng.nextDouble() - 0.5) * 0.0005);
        p.stationaryDurations.add(rng.nextInt(200) + 300);
        p.speeds.add(rng.nextDouble() * 0.1);
        p.observationCount++;
        _profile.totalObservations++;
      }
      _profile.hourlyPatterns[hour] = p;
    }

    // Sleep: 0am-6am — no/minimal activity
    for (int hour in [0, 1, 2, 3, 4, 5, 6]) {
      final p = HourlyPattern(hour: hour);
      for (int i = 0; i < 4; i++) {
        p.latitudes
            .add(homeLat + (rng.nextDouble() - 0.5) * 0.0002);
        p.longitudes
            .add(homeLon + (rng.nextDouble() - 0.5) * 0.0002);
        p.stationaryDurations.add(rng.nextInt(60) + 600);
        p.speeds.add(0.0);
        p.observationCount++;
        _profile.totalObservations++;
      }
      _profile.hourlyPatterns[hour] = p;
    }

    _profile.lastUpdated = DateTime.now();
    _save();
  }

  // ── Persistence ────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_prefs == null) return;
    try {
      await _prefs!
          .setString(_storageKey, jsonEncode(_profile.toJson()));
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_prefs == null) return;
    try {
      final raw = _prefs!.getString(_storageKey);
      if (raw != null) {
        _profile = BaselineProfile.fromJson(jsonDecode(raw));
      }
    } catch (_) {
      _profile = BaselineProfile();
    }
  }

  Future<void> resetBaseline() async {
    _profile = BaselineProfile();
    await _prefs?.remove(_storageKey);
  }

  // ── Cleanup ────────────────────────────────────────────────────────────
  void dispose() {
    _disposed = true;
    _observationTimer?.cancel();
  }
}

// ── Result model ───────────────────────────────────────────────────────

class AnomalyResult {
  final int score; // 0-100
  final List<String> reasons;
  final bool isCalibrated;

  const AnomalyResult({
    required this.score,
    required this.reasons,
    required this.isCalibrated,
  });

  bool get hasAnomaly => score > 20;
  bool get isHighAnomaly => score > 50;
}