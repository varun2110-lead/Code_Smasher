import 'dart:async';
import 'dart:math';
import '../models/location_context.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _controller = StreamController<LocationContext>.broadcast();
  Stream<LocationContext> get stream => _controller.stream;

  LocationContext? _current;
  LocationContext? get current => _current;

  LatLng? _homeBase;
  LatLng _simPos = const LatLng(12.9716, 77.5946);

  int _stationarySeconds = 0;
  DateTime? _lastMovedAt;
  static const _stationaryThresholdMeters = 3.0;

  // ── Motion tracking ───────────────────────────────────────────────────
  final List<double> _speedHistory = []; // last 10 readings
  static const _speedHistorySize = 10;
  static const _runningThreshold = 2.5;   // m/s — running
  static const _walkingThreshold = 0.5;   // m/s — walking
  // Sudden increase: was walking/still, now running, within short window
  static const _suddenIncreaseMultiplier = 3.0; // speed tripled

  Timer? _simTimer;
  Timer? _stationaryTicker;
  bool _disposed = false;
  final _rng = Random();

  Future<void> init({bool simulate = false}) async {
    if (simulate) {
      _startSimulation();
      return;
    }
    _startSimulation();
  }

  void _handleNewPosition(LatLng pos, double accuracy, double rawSpeed) {
    _homeBase ??= pos;

    final prev = _current?.position ?? pos;
    final dist = prev.distanceTo(pos);

    if (dist >= _stationaryThresholdMeters) {
      _stationarySeconds = 0;
      _lastMovedAt = DateTime.now();
    }

    final ctx = _buildContext(pos, rawSpeed, accuracy);
    _current = ctx;
    if (!_disposed) _controller.add(ctx);
  }

  void _startSimulation() {
    _homeBase ??= _simPos;
    _lastMovedAt = DateTime.now();
    _startStationaryTicker();
    _emitSimulated();
    _simTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_disposed) _emitSimulated();
    });
  }

  void _emitSimulated() {
    final dLat = (_rng.nextDouble() - 0.5) * 0.000015;
    final dLon = (_rng.nextDouble() - 0.5) * 0.000015;
    final newPos = LatLng(_simPos.latitude + dLat, _simPos.longitude + dLon);

    final prev = _current?.position ?? _simPos;
    final dist = prev.distanceTo(newPos);
    final speed = dist / 3.0;

    if (dist >= _stationaryThresholdMeters) {
      _stationarySeconds = 0;
      _lastMovedAt = DateTime.now();
    }

    _simPos = newPos;
    final ctx = _buildContext(_simPos, speed, 5.0);
    _current = ctx;
    if (!_disposed) _controller.add(ctx);
  }

  // ── Core context builder ───────────────────────────────────────────────
  LocationContext _buildContext(LatLng pos, double speed, double accuracy) {
    final now = DateTime.now();
    final hour = now.hour;

    // Update speed history
    _speedHistory.add(speed);
    if (_speedHistory.length > _speedHistorySize) {
      _speedHistory.removeAt(0);
    }

    // Motion state
    final motionState = LocationContext.motionFromSpeed(speed);

    // Sudden speed increase detection
    // Look at average speed of first half vs current
    bool suddenSpeedIncrease = false;
    if (_speedHistory.length >= 4) {
      final prevAvg = _speedHistory
              .sublist(0, _speedHistory.length - 2)
              .reduce((a, b) => a + b) /
          (_speedHistory.length - 2);
      final prevMotion = LocationContext.motionFromSpeed(prevAvg);

      // Was walking or stationary, now running
      if (motionState == MotionState.running &&
          (prevMotion == MotionState.walking ||
              prevMotion == MotionState.stationary) &&
          prevAvg > 0.1 &&
          speed > prevAvg * _suddenIncreaseMultiplier) {
        suddenSpeedIncrease = true;
      }
    }

    return LocationContext(
      position: pos,
      speed: speed,
      isUnknownArea: _homeBase!.distanceTo(pos) > 500,
      isLateNight: hour >= 22 || hour < 5,
      isEvening: hour >= 18 && hour < 22,
      stationarySeconds: _stationarySeconds,
      timestamp: now,
      accuracy: accuracy,
      motionState: motionState,
      suddenSpeedIncrease: suddenSpeedIncrease,
      previousSpeed: _speedHistory.length >= 2
          ? _speedHistory[_speedHistory.length - 2]
          : 0.0,
    );
  }

  void _startStationaryTicker() {
    _stationaryTicker?.cancel();
    _stationaryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _stationarySeconds++;
    });
  }

  // ── Demo injection — now supports speed simulation ─────────────────────
  void injectDemoSignal({
    required bool unknownArea,
    required int forcedStationarySeconds,
    double? forceSpeed,
    bool? forceRunning,
  }) {
    if (_current == null) return;
    _stationarySeconds = forcedStationarySeconds;

    final speed = forceSpeed ?? (forceRunning == true ? 3.5 : 0.0);
    final motion = forceRunning == true
        ? MotionState.running
        : LocationContext.motionFromSpeed(speed);

    // Simulate sudden speed increase if running forced
    final suddenIncrease = forceRunning == true &&
        (_current!.motionState == MotionState.walking ||
            _current!.motionState == MotionState.stationary);

    final ctx = _current!.copyWith(
      isUnknownArea: unknownArea,
      isLateNight: true,
      stationarySeconds: forcedStationarySeconds,
      timestamp: DateTime.now(),
      speed: speed,
      motionState: motion,
      suddenSpeedIncrease: suddenIncrease,
    );
    _current = ctx;
    if (!_disposed) _controller.add(ctx);
  }

  void resetStationary() {
    _stationarySeconds = 0;
    _lastMovedAt = DateTime.now();
  }

  void dispose() {
    _disposed = true;
    _simTimer?.cancel();
    _stationaryTicker?.cancel();
    _controller.close();
  }
}