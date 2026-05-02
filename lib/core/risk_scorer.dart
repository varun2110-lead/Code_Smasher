import '../models/location_context.dart';
import '../services/behavioral_baseline.dart';

class SensorContext {
  final bool shakeDetected;
  final double shakeMagnitude;
  final int screenOffSeconds;

  const SensorContext({
    this.shakeDetected = false,
    this.shakeMagnitude = 0.0,
    this.screenOffSeconds = 0,
  });
}

class ScoreBreakdown {
  final int total;
  final List<String> activeSignals;
  final Map<String, int> contributions;
  final AnomalyResult? anomaly;
  final bool triggerSosFromMotion; // true = running at night → auto SOS

  const ScoreBreakdown({
    required this.total,
    required this.activeSignals,
    required this.contributions,
    this.anomaly,
    this.triggerSosFromMotion = false,
  });
}

class RiskScorer {
  // Track running duration for sustained running detection
  int _runningSeconds = 0;
  DateTime? _runStartedAt;
  static const _sustainedRunSeconds = 20; // 20s of running = distress flag

  ScoreBreakdown compute(
    LocationContext loc,
    SensorContext sensors, {
    bool stalkerFlagged = false,
    AnomalyResult? anomalyResult,
    double voiceDistressScore = 0.0,
    bool isInSafeZone = false,    // ← NEW: safe zone flag
  }) {
    final contributions = <String, int>{};
    final activeSignals = <String>[];
    bool triggerSosFromMotion = false;

    // ══════════════════════════════════════════════════════════════════
    // SAFE ZONE OVERRIDE — suppress ALL location-based risk signals
    // User is at home/work/known place — no false alerts
    // ══════════════════════════════════════════════════════════════════
    if (isInSafeZone) {
      // Only keep sensor signals that indicate active distress
      // (shake and voice distress still matter even at home)
      if (sensors.shakeDetected && sensors.shakeMagnitude > 30) {
        contributions['Shake detected (safe zone)'] = 20;
        activeSignals.add('Strong shake at safe location');
      }
      if (voiceDistressScore > 0.6) {
        final pts = (voiceDistressScore * 25).round().clamp(0, 25);
        contributions['Voice distress'] = pts;
        activeSignals.add('High vocal distress detected');
      }

      final total = contributions.values
          .fold(0, (a, b) => a + b)
          .clamp(0, 100);

      return ScoreBreakdown(
        total: total,
        activeSignals: activeSignals,
        contributions: contributions,
        anomaly: anomalyResult,
      );
    }

    // ══════════════════════════════════════════════════════════════════
    // LOCATION SIGNALS
    // ══════════════════════════════════════════════════════════════════

    if (loc.isUnknownArea) {
      contributions['Unknown area'] = 25;
      activeSignals.add('Unknown area');
    }

    if (loc.isLateNight) {
      contributions['Late night (10pm-5am)'] = 20;
      activeSignals.add('Late night (10pm-5am)');
    } else if (loc.isEvening) {
      contributions['Evening hours'] = 8;
      activeSignals.add('Evening (6pm-10pm)');
    }

    if (loc.stationarySeconds > 90) {
      final extra = loc.stationarySeconds > 180 ? 10 : 0;
      contributions['Stationary ${loc.stationarySeconds}s'] = 30 + extra;
      activeSignals.add(
          'Stationary ${(loc.stationarySeconds / 60).toStringAsFixed(1)}min');
    } else if (loc.stationarySeconds > 45) {
      contributions['Stationary >45s'] = 15;
      activeSignals.add('Stationary ${loc.stationarySeconds}s');
    }

    if (loc.speed < 0.3 && loc.stationarySeconds > 30) {
      contributions['Near-zero speed'] = 10;
      activeSignals.add('Not moving');
    }

    // ══════════════════════════════════════════════════════════════════
    // MOTION SIGNALS — running detection
    // ══════════════════════════════════════════════════════════════════

    final isNightOrEvening = loc.isLateNight || loc.isEvening;

    // Track running duration
    if (loc.motionState == MotionState.running) {
      if (_runStartedAt == null) {
        _runStartedAt = DateTime.now();
        _runningSeconds = 0;
      } else {
        _runningSeconds =
            DateTime.now().difference(_runStartedAt!).inSeconds;
      }
    } else {
      _runStartedAt = null;
      _runningSeconds = 0;
    }

    // Sudden speed increase (walking → running) at night/evening
    if (loc.suddenSpeedIncrease && isNightOrEvening) {
      contributions['Sudden speed increase'] = 35;
      activeSignals.add('Suddenly running at night');

      // If also in unknown area — this is a strong distress signal
      if (loc.isUnknownArea) {
        contributions['Sudden running in unknown area'] = 20;
        activeSignals.add('Running in unfamiliar area');
      }
    } else if (loc.suddenSpeedIncrease) {
      // Daytime sudden running — lower weight
      contributions['Sudden speed increase'] = 15;
      activeSignals.add('Sudden speed change detected');
    }

    // Sustained running at night in unknown area → trigger SOS
    if (loc.motionState == MotionState.running &&
        isNightOrEvening &&
        loc.isUnknownArea &&
        _runningSeconds >= _sustainedRunSeconds) {
      contributions['Sustained running at night'] = 40;
      activeSignals.add('Running for ${_runningSeconds}s at night');
      triggerSosFromMotion = true; // signal engine to fire SOS
    } else if (loc.motionState == MotionState.running && isNightOrEvening) {
      // Running at night even in known area — moderate signal
      contributions['Running at night'] = 20;
      activeSignals.add('Running at night');
    }

    // ══════════════════════════════════════════════════════════════════
    // SENSOR SIGNALS
    // ══════════════════════════════════════════════════════════════════

    if (sensors.shakeDetected) {
      final intensity = sensors.shakeMagnitude > 30 ? 40 : 25;
      contributions['Shake detected'] = intensity;
      activeSignals.add('Device shake');
    }

    if (sensors.screenOffSeconds > 120) {
      contributions['Screen off >2min'] = 15;
      activeSignals.add('Screen off 2min+');
    }

    // ══════════════════════════════════════════════════════════════════
    // STALKER SIGNAL
    // ══════════════════════════════════════════════════════════════════

    if (stalkerFlagged) {
      contributions['Repeated unknown device'] = 30;
      activeSignals.add('Unknown device detected nearby');

      // Stalker + running at night = very high threat
      if (loc.motionState == MotionState.running && isNightOrEvening) {
        contributions['Fleeing potential stalker'] = 25;
        activeSignals.add('Possible pursuit detected');
        triggerSosFromMotion = true;
      }
    }

    // ══════════════════════════════════════════════════════════════════
    // BEHAVIORAL ANOMALY SIGNAL
    // ══════════════════════════════════════════════════════════════════

    if (anomalyResult != null &&
        anomalyResult.isCalibrated &&
        anomalyResult.hasAnomaly) {
      final anomalyPts = (anomalyResult.score * 0.35).round().clamp(0, 35);
      contributions['Behavioral anomaly'] = anomalyPts;
      if (anomalyResult.isHighAnomaly) {
        activeSignals.add('Unusual behavior pattern');
      } else {
        activeSignals.add('Minor routine deviation');
      }
    }

    // ══════════════════════════════════════════════════════════════════
    // VOICE DISTRESS SIGNAL
    // ══════════════════════════════════════════════════════════════════

    if (voiceDistressScore > 0.3) {
      final pts = (voiceDistressScore * 35).round().clamp(0, 35);
      contributions['Voice distress'] = pts;
      if (voiceDistressScore > 0.6) {
        activeSignals.add('High vocal distress detected');
        // Voice distress + running = immediate SOS
        if (loc.motionState == MotionState.running) {
          triggerSosFromMotion = true;
        }
      } else {
        activeSignals.add('Vocal stress elevated');
      }
    }

    final total =
        contributions.values.fold(0, (a, b) => a + b).clamp(0, 100);

    return ScoreBreakdown(
      total: total,
      activeSignals: activeSignals,
      contributions: contributions,
      anomaly: anomalyResult,
      triggerSosFromMotion: triggerSosFromMotion,
    );
  }
}