import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/safety_state.dart';
import '../models/location_context.dart';
import '../core/risk_scorer.dart';
import '../services/location_service.dart';
import '../services/sensor_service.dart';
import '../services/alert_storage.dart';
import '../services/bluetooth_service.dart';
import '../services/behavioral_baseline.dart';
import '../services/heatmap_service.dart';
import '../services/voice_distress_service.dart';
import '../services/safe_zone_service.dart';
import '../services/activity_timeline_service.dart';
import '../services/volume_trigger_service.dart';

class SafetyEngine extends ChangeNotifier {
  // ── Public state ──────────────────────────────────────────────────────
  SafetyState _state = SafetyState(timestamp: DateTime.now());
  SafetyState get state => _state;

  LocationContext? _locationCtx;
  LocationContext? get locationCtx => _locationCtx;

  List<String> _activeSignals = [];
  List<String> get activeSignals => List.unmodifiable(_activeSignals);

  int _displayScore = 0;
  int get displayScore => _displayScore;

  bool _demoMode = false;
  bool get demoMode => _demoMode;

  TriggerSource? _lastTrigger;
  TriggerSource? get lastTrigger => _lastTrigger;

  // ── Behavioral baseline ───────────────────────────────────────────────
  final _baseline = BehavioralBaseline();
  BehavioralBaseline get baseline => _baseline;

  AnomalyResult? _lastAnomaly;
  AnomalyResult? get lastAnomaly => _lastAnomaly;

  // ── Heatmap ───────────────────────────────────────────────────────────
  final _heatmap = HeatmapService();
  HeatmapService get heatmapService => _heatmap;

  // ── Voice distress ────────────────────────────────────────────────────
  final _voiceService = VoiceDistressService();
  VoiceDistressService get voiceService => _voiceService;

  double get voiceDistressScore => _voiceService.lastResult.distressScore;

  String get voiceDistressLevel {
    switch (_voiceService.lastResult.level) {
      case VoiceDistressLevel.none: return 'Normal';
      case VoiceDistressLevel.mild: return 'Mild';
      case VoiceDistressLevel.moderate: return 'Elevated';
      case VoiceDistressLevel.high: return 'HIGH';
    }
  }

  // ── Safe zones ────────────────────────────────────────────────────────
  final _safeZoneService = SafeZoneService();
  SafeZoneService get safeZoneService => _safeZoneService;

  bool get isInSafeZone {
    final loc = _locationCtx;
    if (loc == null) return false;
    return _safeZoneService.isInSafeZone(loc.position);
  }

  String get currentZoneLabel {
    final loc = _locationCtx;
    if (loc == null) return 'Unknown';
    final zone = _safeZoneService.getCurrentZone(loc.position);
    return zone?.name ?? 'Current Location';
  }

  void simulateVoiceDistress() => _voiceService.simulateDistress();

  // ── Activity Timeline ─────────────────────────────────────────────────
  final _timeline = ActivityTimelineService();
  ActivityTimelineService get timelineService => _timeline;
  DateTime? _lastTimelineSnapshot;
  final _volumeTrigger = VolumeTriggerService();
  // ── Explanation ───────────────────────────────────────────────────────
  String get explanation => _buildExplanation();

  // ── Stalker ───────────────────────────────────────────────────────────
  bool _stalkerFlagged = false;
  bool get stalkerFlagged => _stalkerFlagged || btCandidates.isNotEmpty;

  int _stalkerSimCount = 0;
  int get stalkerDetectionCount => _stalkerSimCount;

  // ── Bluetooth ─────────────────────────────────────────────────────────
  final _btService = BluetoothFingerprintService();
  BluetoothFingerprintService get bluetoothService => _btService;

  BluetoothScanResult? _lastBtResult;
  BluetoothScanResult? get lastBtResult => _lastBtResult;

  List<StalkerCandidate> get btCandidates => _btService.currentCandidates;

  StreamSubscription<BluetoothScanResult>? _btResultSub;
  StreamSubscription<StalkerCandidate>? _btStalkerSub;

  // ── Fake call ─────────────────────────────────────────────────────────
  bool _fakeCallActive = false;
  bool get fakeCallActive => _fakeCallActive;

  String _fakeCallContact = 'Mom';
  String get fakeCallContact => _fakeCallContact;

  bool fakeCallOnHighRisk = true;

  // ── Smart controls ────────────────────────────────────────────────────
  bool _isEmergencyPaused = false;
  DateTime? _lastCallTime;
  Timer? _fakeCallTimer;
  DateTime? _lastAlertFiredAt;

  final Duration _alertCooldown = const Duration(minutes: 5);
  static const _callCooldown = Duration(minutes: 5);
  static const _fakeCallDuration = Duration(seconds: 15);

  static const _safeLocations = [
    LatLng(12.9352, 77.6245),
    LatLng(12.9760, 77.5715),
  ];
  static const _safeRadiusMeters = 100.0;

  bool get _inCooldown {
    if (_lastAlertFiredAt == null) return false;
    return DateTime.now().difference(_lastAlertFiredAt!) < _alertCooldown;
  }

  // ── Dependencies ──────────────────────────────────────────────────────
  final _scorer = RiskScorer();
  final _locationSvc = LocationService();
  final _sensorSvc = SensorService();
  final _storage = AlertStorage();

  StreamSubscription<LocationContext>? _locationSub;
  StreamSubscription<double>? _shakeSub;
  StreamSubscription<VoiceDistressResult>? _voiceSub;
  Timer? _scoreAnimTimer;
  Timer? _countdownTimer;
  int _countdownRemaining = 10;

  // ── Init ──────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _storage.init();
    await _locationSvc.init(simulate: true);
    await _sensorSvc.init();

    await _baseline.init();
    _baseline.startLearning();

    _heatmap.generateZonesForCurrentTime();

    await _safeZoneService.init();

    await _timeline.init();
    _timeline.startTracking();

    final hasPermission = await _voiceService.init();
    if (hasPermission) {
      await _voiceService.startListening();
      _voiceSub = _voiceService.distressStream.listen(_onVoiceDistress);
    }

    _locationSub = _locationSvc.stream.listen(_onLocationUpdate);
    _shakeSub = _sensorSvc.shakeStream.listen(_onShake);

    final loc = _locationSvc.current;
    await _btService.init(
      initialLat: loc?.position.latitude ?? 12.9716,
      initialLon: loc?.position.longitude ?? 77.5946,
      demoMode: true,
    );

    _btResultSub = _btService.resultStream.listen(_onBtResult);
    _btStalkerSub = _btService.stalkerStream.listen(_onBtStalker);
    _volumeTrigger.init(
  onTrigger: () => triggerEmergency(TriggerSource.manual, instantSend: true),
);
  }

  // ── Location pipeline ─────────────────────────────────────────────────
  void _onLocationUpdate(LocationContext ctx) {
    _locationCtx = ctx;
    _btService.updateLocation(ctx.position.latitude, ctx.position.longitude);
    _baseline.observe(ctx);
    _lastAnomaly = _baseline.computeAnomaly(ctx);

    // Record timeline snapshot every 2 minutes
    final now = DateTime.now();
    if (_lastTimelineSnapshot == null ||
        now.difference(_lastTimelineSnapshot!).inMinutes >= 2) {
      _lastTimelineSnapshot = now;
      _timeline.recordSnapshot(
        position: ctx.position,
        riskScore: _state.riskScore,
        riskLevel: _state.risk,
        signals: _activeSignals,
        inSafeZone: _safeZoneService.isInSafeZone(ctx.position),
        inUnknownArea: ctx.isUnknownArea,
      );
    }

    final sensors = SensorContext(
      shakeDetected: false,
      shakeMagnitude: 0,
      screenOffSeconds: _sensorSvc.screenOffSeconds,
    );

    final breakdown = _scorer.compute(
      ctx,
      sensors,
      stalkerFlagged: _stalkerFlagged || btCandidates.isNotEmpty,
      anomalyResult: _lastAnomaly,
      voiceDistressScore: voiceDistressScore,
    );
    _applyScore(breakdown.total, breakdown.activeSignals);
  }

  // ── Voice distress pipeline ───────────────────────────────────────────
  void _onVoiceDistress(VoiceDistressResult result) {
    if (result.level != VoiceDistressLevel.none && _locationCtx != null) {
      _onLocationUpdate(_locationCtx!);
    }
    notifyListeners();
  }

  void _onBtResult(BluetoothScanResult result) {
    _lastBtResult = result;
    notifyListeners();
    if (result.stalkerCandidates.isNotEmpty && _locationCtx != null) {
      _onLocationUpdate(_locationCtx!);
    }
  }

  void _onBtStalker(StalkerCandidate candidate) {
    if (_locationCtx != null) _onLocationUpdate(_locationCtx!);
    notifyListeners();
  }

  void _onShake(double magnitude) {
    final ctx = _locationCtx;
    if (ctx == null) return;

    final sensors = SensorContext(
      shakeDetected: true,
      shakeMagnitude: magnitude,
      screenOffSeconds: 0,
    );

    final breakdown = _scorer.compute(
      ctx,
      sensors,
      stalkerFlagged: _stalkerFlagged || btCandidates.isNotEmpty,
      anomalyResult: _lastAnomaly,
      voiceDistressScore: voiceDistressScore,
    );
    _applyScore(breakdown.total, breakdown.activeSignals);

    if (magnitude > 24.0) triggerEmergency(TriggerSource.shake);
  }

  // ── Score application ─────────────────────────────────────────────────
  void _applyScore(int score, List<String> signals) {
    _activeSignals = signals;
    _animateScoreTo(score);

    final newRisk = SafetyState.levelFromScore(score);

    if (fakeCallOnHighRisk &&
        (newRisk == RiskLevel.high || newRisk == RiskLevel.critical) &&
        !_fakeCallActive &&
        shouldTriggerFakeCall(score, _locationCtx?.position)) {
      _triggerFakeCallInternal();
    }

    if (newRisk == RiskLevel.critical &&
        !_state.alertActive &&
        !_state.countdownActive &&
        !_inCooldown &&
        _locationCtx != null &&
        !_safeZoneService.isInSafeZone(_locationCtx!.position) &&
        !isSafeLocation(_locationCtx!.position)) {
      triggerEmergency(TriggerSource.auto);
      return;
    }

    _state = _state.copyWith(
      risk: newRisk,
      reason: signals.isNotEmpty ? signals.join(' · ') : 'All clear',
      riskScore: score,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void _animateScoreTo(int target) {
    _scoreAnimTimer?.cancel();
    _scoreAnimTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (_displayScore < target) {
        _displayScore = (_displayScore + 2).clamp(0, target);
      } else if (_displayScore > target) {
        _displayScore = (_displayScore - 2).clamp(target, 100);
      } else {
        t.cancel();
        return;
      }
      notifyListeners();
    });
  }

  // ── Emergency protocol ────────────────────────────────────────────────
  Future<void> triggerEmergency(TriggerSource source,
      {bool instantSend = false}) async {
    if (_state.countdownActive || _state.alertActive) return;

    _lastTrigger = source;

    if (source == TriggerSource.manual || instantSend) {
      await _fireAlert(source);
      return;
    }

    _countdownRemaining = 10;
    _state = _state.copyWith(
      countdownActive: true,
      countdownSeconds: _countdownRemaining,
      alertActive: false,
    );
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _countdownRemaining--;
      if (_countdownRemaining <= 0) {
        t.cancel();
        _fireAlert(source);
      } else {
        _state = _state.copyWith(
          countdownSeconds: _countdownRemaining,
          countdownActive: true,
        );
        notifyListeners();
      }
    });
  }

  void cancelCountdown() {
    _countdownTimer?.cancel();
    _locationSvc.resetStationary();
    _state = _state.copyWith(countdownActive: false, countdownSeconds: 10);
    notifyListeners();
  }

  Future<void> _fireAlert(TriggerSource source) async {
    _lastAlertFiredAt = DateTime.now();

    final ctx = _locationCtx;
    final record = AlertRecord(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      position: ctx?.position ?? const LatLng(12.9716, 77.5946),
      riskScore: _state.riskScore,
      triggerSource: _triggerLabel(source),
      activeSignals: List.from(_activeSignals),
    );

    await _storage.save(record);

    // Record in timeline
    _timeline.recordEvent(
      type: ActivityEventType.sosTriggered,
      position: ctx?.position ?? const LatLng(12.9716, 77.5946),
      riskScore: _state.riskScore,
      riskLevel: _state.risk,
      description: 'SOS alert triggered — ${_triggerLabel(source)}',
      signals: List.from(_activeSignals),
    );

    _state = _state.copyWith(
      alertActive: true,
      countdownActive: false,
      countdownSeconds: 10,
    );

    Future.delayed(const Duration(seconds: 4), () {
      if (_state.alertActive && !_fakeCallActive && !_state.countdownActive) {
        _triggerFakeCallInternal(contact: 'Sister');
      }
    });

    notifyListeners();
  }

  String _triggerLabel(TriggerSource s) {
    switch (s) {
      case TriggerSource.manual: return 'Manual SOS';
      case TriggerSource.auto: return 'Auto (Predicted)';
      case TriggerSource.bluetooth: return 'Bluetooth Trigger';
      case TriggerSource.shake: return 'Shake Detected';
    }
  }

  void dismissAlert() {
    _locationSvc.resetStationary();
    _stalkerFlagged = false;
    _state = _state.copyWith(alertActive: false);
    notifyListeners();
  }

  // ── Explainable risk ──────────────────────────────────────────────────
  String _buildExplanation() {
    final signals = _activeSignals;
    final anomaly = _lastAnomaly;

    if (signals.isEmpty) {
      if (anomaly != null && anomaly.isCalibrated) {
        return 'Your current behavior matches your normal routine. All clear.';
      }
      return 'All conditions appear normal. No risk indicators detected.';
    }

    final parts = <String>[];
    final hasUnknown = signals.any((s) => s.toLowerCase().contains('unknown area'));
    final hasStationary = signals.any((s) => s.toLowerCase().contains('stationary'));
    final hasLateNight = signals.any((s) => s.toLowerCase().contains('late night'));
    final hasShake = signals.any((s) => s.toLowerCase().contains('shake'));
    final hasScreenOff = signals.any((s) => s.toLowerCase().contains('screen off'));
    final hasBtStalker = signals.any((s) => s.toLowerCase().contains('device'));
    final hasNotMoving = signals.any((s) => s.toLowerCase().contains('not moving'));
    final hasAnomaly = signals.any((s) =>
        s.toLowerCase().contains('behavior') || s.toLowerCase().contains('routine'));
    final hasVoiceDistress = signals.any((s) =>
        s.toLowerCase().contains('vocal') || s.toLowerCase().contains('voice'));

    if (hasUnknown && hasStationary) {
      parts.add('You have been stationary in an unfamiliar area for an extended period.');
    } else {
      if (hasUnknown) parts.add('Your current location is unfamiliar, outside your known area.');
      if (hasStationary) parts.add('You have been stationary for an unusually long time.');
    }

    if (hasLateNight) parts.add('It is late at night, increasing vulnerability.');
    if (hasShake) parts.add('Sudden device movement detected, suggesting a disturbance.');
    if (hasScreenOff) parts.add('Your screen has been off for over 2 minutes.');
    if (hasNotMoving && !hasStationary) parts.add('You do not appear to be moving.');
    if (hasBtStalker) parts.add('A Bluetooth device has been detected following you across multiple locations.');
    if (hasAnomaly && anomaly != null && anomaly.reasons.isNotEmpty) {
      parts.addAll(anomaly.reasons);
    }
    if (hasVoiceDistress) {
      parts.add('Vocal distress detected — your voice patterns indicate elevated stress.');
    }

    return parts.isEmpty ? 'Multiple risk signals are active. Stay alert.' : parts.join(' ');
  }

  // ── Stalker detection ─────────────────────────────────────────────────
  void incrementStalkerSignal() {
    _stalkerSimCount++;
    if (_stalkerSimCount >= 3 && !_stalkerFlagged) {
      _stalkerFlagged = true;
      if (_locationCtx != null) _onLocationUpdate(_locationCtx!);
    }
    notifyListeners();
  }

  void simulateStalkerSequence() async {
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_demoMode) return;
      incrementStalkerSignal();
    }
  }

  Future<void> triggerBluetoothScan() async => _btService.triggerImmediateScan();

  // ── Fake call ─────────────────────────────────────────────────────────
  void triggerFakeCall({String contact = 'Mom'}) =>
      _triggerFakeCallInternal(contact: contact);

  void dismissFakeCall() {
    _fakeCallActive = false;
    _fakeCallTimer?.cancel();
    notifyListeners();
  }

  bool isSafeLocation(LatLng current) {
    if (_safeZoneService.isInSafeZone(current)) return true;
    for (final safe in _safeLocations) {
      if (current.distanceTo(safe) <= _safeRadiusMeters) return true;
    }
    return false;
  }

  bool canTriggerCall() {
    if (_lastCallTime == null) return true;
    return DateTime.now().difference(_lastCallTime!) > _callCooldown;
  }

  bool shouldTriggerFakeCall(int riskScore, LatLng? currentLocation) {
    if (_isEmergencyPaused) return false;
    if (_fakeCallActive) return false;
    if (_state.countdownActive) return false;
    if (!canTriggerCall()) return false;
    if (riskScore <= 60) return false;
    if (currentLocation != null && isSafeLocation(currentLocation)) return false;
    return true;
  }

  void _triggerFakeCallInternal({String contact = 'Mom'}) {
    if (_state.countdownActive) return;
    _fakeCallContact = contact;
    _fakeCallActive = true;
    _lastCallTime = DateTime.now();
    _fakeCallTimer?.cancel();
    _fakeCallTimer = Timer(_fakeCallDuration, () {
      if (_fakeCallActive) {
        _fakeCallActive = false;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  // ── Demo mode ─────────────────────────────────────────────────────────
  void toggleDemoMode() {
    _demoMode = !_demoMode;
    notifyListeners();
    if (_demoMode) _runDemoSequence();
  }

  void _runDemoSequence() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!_demoMode) return;
    _locationSvc.injectDemoSignal(unknownArea: true, forcedStationarySeconds: 50);

    await Future.delayed(const Duration(seconds: 3));
    if (!_demoMode) return;
    _locationSvc.injectDemoSignal(unknownArea: true, forcedStationarySeconds: 100);

    await Future.delayed(const Duration(seconds: 3));
    if (!_demoMode) return;
    _locationSvc.injectDemoSignal(unknownArea: true, forcedStationarySeconds: 200);
  }

  void simulateShake() => _sensorSvc.simulateShakeBurst();

  // ── Alert log ─────────────────────────────────────────────────────────
  List<AlertRecord> get alertLog => _storage.getAll();

  Duration get cooldownRemaining {
    if (!_inCooldown) return Duration.zero;
    return _alertCooldown - DateTime.now().difference(_lastAlertFiredAt!);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────
  @override
  void dispose() {
    _voiceSub?.cancel();
    _voiceService.dispose();
    _safeZoneService.dispose();
    _timeline.dispose();
    _locationSub?.cancel();
    _shakeSub?.cancel();
    _btResultSub?.cancel();
    _btStalkerSub?.cancel();
    _scoreAnimTimer?.cancel();
    _countdownTimer?.cancel();
    _fakeCallTimer?.cancel();
    _locationSvc.dispose();
    _sensorSvc.dispose();
    _btService.dispose();
    _baseline.dispose();
    _volumeTrigger.dispose();
    super.dispose();
  }
}