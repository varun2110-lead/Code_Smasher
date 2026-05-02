import 'dart:async';
import 'dart:math';
import 'package:record/record.dart';

/// VoiceDistressService — SHIELD Phase 6
///
/// Passively monitors microphone for vocal distress patterns.
/// No speech recognition — pure audio signal analysis.
/// Privacy-safe: audio is never stored or transmitted.
///
/// DETECTION METHOD:
///   1. Sample audio amplitude every 200ms
///   2. Compute RMS energy (volume level)
///   3. Track rapid energy spikes (shouting/screaming)
///   4. Detect sustained high energy (panic/crying)
///   5. Output distress score 0-100
///
/// SIGNALS DETECTED:
///   - Sudden loud shout (spike > 3x baseline in < 500ms)
///   - Sustained elevated volume (>baseline x2 for 3+ seconds)
///   - Rapid volume oscillation (crying pattern)

class VoiceDistressResult {
  final double distressScore; // 0.0 - 1.0
  final VoiceDistressLevel level;
  final String label;

  const VoiceDistressResult({
    required this.distressScore,
    required this.level,
    required this.label,
  });

  static const none = VoiceDistressResult(
    distressScore: 0.0,
    level: VoiceDistressLevel.none,
    label: 'No distress detected',
  );
}

enum VoiceDistressLevel { none, mild, moderate, high }

class VoiceDistressService {
  static final VoiceDistressService _instance = VoiceDistressService._internal();
  factory VoiceDistressService() => _instance;
  VoiceDistressService._internal();

  final _audioRecorder = AudioRecorder();
  final _distressController = StreamController<VoiceDistressResult>.broadcast();
  Stream<VoiceDistressResult> get distressStream => _distressController.stream;

  // State
  bool _isListening = false;
  bool _disposed = false;
  bool _permissionGranted = false;

  // Signal processing state
  final List<double> _amplitudeHistory = [];
  double _baselineRms = 0.0;
  double _currentRms = 0.0;
  int _elevatedCount = 0; // consecutive elevated readings
  DateTime? _lastSpikeAt;
  int _spikeCount = 0;

  // Config
  static const _sampleIntervalMs = 200;
  static const _baselineWindowSize = 15; // 3 seconds of baseline
  static const _spikeThresholdMultiplier = 2.8;
  static const _sustainedThresholdMultiplier = 2.0;
  static const _sustainedCountThreshold = 10; // 2 seconds sustained
  static const _spikeWindowSeconds = 3;
  static const _spikeBurstThreshold = 3; // 3 spikes in window = distress

  VoiceDistressResult _lastResult = VoiceDistressResult.none;
  VoiceDistressResult get lastResult => _lastResult;

  bool get isListening => _isListening;
  double get currentRms => _currentRms;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<bool> init() async {
    try {
      _permissionGranted = await _audioRecorder.hasPermission();
      return _permissionGranted;
    } catch (_) {
      return false;
    }
  }

  // ── Start listening ───────────────────────────────────────────────────────
  Future<void> startListening() async {
    if (_isListening || !_permissionGranted || _disposed) return;

    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          // Low quality — we only need amplitude, not quality
        ),
        path: '', // Not saving to file
      );

      _isListening = true;
      _amplitudeHistory.clear();
      _baselineRms = 0;
      _elevatedCount = 0;
      _spikeCount = 0;

      // Sample amplitude periodically
      Timer.periodic(
        const Duration(milliseconds: _sampleIntervalMs),
        (t) async {
          if (!_isListening || _disposed) {
            t.cancel();
            return;
          }
          await _processAudioSample();
        },
      );
    } catch (e) {
      _isListening = false;
    }
  }

  // ── Stop listening ────────────────────────────────────────────────────────
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    _lastResult = VoiceDistressResult.none;
  }

  // ── Audio sample processing ───────────────────────────────────────────────
  Future<void> _processAudioSample() async {
    try {
      final amplitude = await _audioRecorder.getAmplitude();
      final rms = _dbToLinear(amplitude.current);
      _currentRms = rms;

      _amplitudeHistory.add(rms);
      if (_amplitudeHistory.length > 50) {
        _amplitudeHistory.removeAt(0);
      }

      // Build baseline from first N readings (quiet environment)
      if (_amplitudeHistory.length <= _baselineWindowSize) {
        _baselineRms = _amplitudeHistory.reduce((a, b) => a + b) /
            _amplitudeHistory.length;
        return;
      }

      // Ensure baseline isn't near zero
      final effectiveBaseline = max(_baselineRms, 0.01);

      final result = _analyzeSignal(rms, effectiveBaseline);
      _lastResult = result;

      if (!_disposed) _distressController.add(result);
    } catch (_) {}
  }

  // ── Signal analysis ────────────────────────────────────────────────────────
  VoiceDistressResult _analyzeSignal(double rms, double baseline) {
    double distressScore = 0.0;
    final now = DateTime.now();

    // 1. Check for spike (sudden loud sound)
    final spikeRatio = rms / baseline;
    if (spikeRatio > _spikeThresholdMultiplier) {
      // Detected a spike
      if (_lastSpikeAt != null &&
          now.difference(_lastSpikeAt!).inSeconds <= _spikeWindowSeconds) {
        _spikeCount++;
      } else {
        _spikeCount = 1;
      }
      _lastSpikeAt = now;

      // Multiple spikes = distress burst
      if (_spikeCount >= _spikeBurstThreshold) {
        distressScore += 0.6;
      } else {
        distressScore += 0.3 * _spikeCount;
      }
    }

    // 2. Check for sustained elevation (crying/panic)
    if (rms > baseline * _sustainedThresholdMultiplier) {
      _elevatedCount++;
      if (_elevatedCount >= _sustainedCountThreshold) {
        distressScore += 0.4;
      } else {
        distressScore += 0.04 * _elevatedCount;
      }
    } else {
      _elevatedCount = max(0, _elevatedCount - 1);
    }

    // 3. Oscillation detection (crying pattern)
    if (_amplitudeHistory.length >= 10) {
      final recent = _amplitudeHistory.sublist(_amplitudeHistory.length - 10);
      double oscillation = 0;
      for (int i = 1; i < recent.length; i++) {
        oscillation += (recent[i] - recent[i - 1]).abs();
      }
      final avgOscillation = oscillation / recent.length;
      if (avgOscillation > baseline * 0.5 && rms > baseline * 1.5) {
        distressScore += 0.2;
      }
    }

    distressScore = distressScore.clamp(0.0, 1.0);

    // Map to level
    VoiceDistressLevel level;
    String label;
    if (distressScore < 0.2) {
      level = VoiceDistressLevel.none;
      label = 'Normal';
    } else if (distressScore < 0.4) {
      level = VoiceDistressLevel.mild;
      label = 'Mild distress detected';
    } else if (distressScore < 0.7) {
      level = VoiceDistressLevel.moderate;
      label = 'Elevated vocal stress';
    } else {
      level = VoiceDistressLevel.high;
      label = 'High distress detected';
    }

    return VoiceDistressResult(
      distressScore: distressScore,
      level: level,
      label: label,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double _dbToLinear(double db) {
    // Convert dB to linear amplitude (0.0 - 1.0)
    if (db <= -60) return 0.0;
    return pow(10, db / 20).toDouble().clamp(0.0, 1.0);
  }

  // ── Demo simulation ───────────────────────────────────────────────────────
  void simulateDistress() async {
    // Simulate a distress event for demo
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      final simulatedScore = 0.4 + (i * 0.1);
      final result = VoiceDistressResult(
        distressScore: simulatedScore.clamp(0.0, 1.0),
        level: simulatedScore > 0.6
            ? VoiceDistressLevel.high
            : VoiceDistressLevel.moderate,
        label: simulatedScore > 0.6
            ? 'High distress detected'
            : 'Elevated vocal stress',
      );
      _lastResult = result;
      if (!_disposed) _distressController.add(result);
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    _disposed = true;
    await stopListening();
    await _audioRecorder.dispose();
    await _distressController.close();
  }
}