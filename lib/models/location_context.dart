import 'dart:math';

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  double distanceTo(LatLng other) {
    const R = 6371000.0;
    final lat1 = latitude * pi / 180;
    final lat2 = other.latitude * pi / 180;
    final dLat = (other.latitude - latitude) * pi / 180;
    final dLon = (other.longitude - longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  @override
  String toString() =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

/// Motion state — derived from speed history
enum MotionState {
  stationary,  // < 0.5 m/s
  walking,     // 0.5 - 2.5 m/s
  running,     // > 2.5 m/s
}

class LocationContext {
  final LatLng position;
  final double speed;
  final bool isUnknownArea;
  final bool isLateNight;
  final bool isEvening;        // 18:00 - 22:00
  final int stationarySeconds;
  final DateTime timestamp;
  final double accuracy;
  final MotionState motionState;
  final bool suddenSpeedIncrease; // walked → ran within 30s
  final double previousSpeed;

  const LocationContext({
    required this.position,
    this.speed = 0.0,
    this.isUnknownArea = false,
    this.isLateNight = false,
    this.isEvening = false,
    this.stationarySeconds = 0,
    required this.timestamp,
    this.accuracy = 0.0,
    this.motionState = MotionState.stationary,
    this.suddenSpeedIncrease = false,
    this.previousSpeed = 0.0,
  });

  LocationContext copyWith({
    LatLng? position,
    double? speed,
    bool? isUnknownArea,
    bool? isLateNight,
    bool? isEvening,
    int? stationarySeconds,
    DateTime? timestamp,
    double? accuracy,
    MotionState? motionState,
    bool? suddenSpeedIncrease,
    double? previousSpeed,
  }) {
    return LocationContext(
      position: position ?? this.position,
      speed: speed ?? this.speed,
      isUnknownArea: isUnknownArea ?? this.isUnknownArea,
      isLateNight: isLateNight ?? this.isLateNight,
      isEvening: isEvening ?? this.isEvening,
      stationarySeconds: stationarySeconds ?? this.stationarySeconds,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      motionState: motionState ?? this.motionState,
      suddenSpeedIncrease: suddenSpeedIncrease ?? this.suddenSpeedIncrease,
      previousSpeed: previousSpeed ?? this.previousSpeed,
    );
  }

  static MotionState motionFromSpeed(double speed) {
    if (speed < 0.5) return MotionState.stationary;
    if (speed < 2.5) return MotionState.walking;
    return MotionState.running;
  }
}

class AlertRecord {
  final String id;
  final DateTime timestamp;
  final LatLng position;
  final int riskScore;
  final String triggerSource;
  final List<String> activeSignals;

  const AlertRecord({
    required this.id,
    required this.timestamp,
    required this.position,
    required this.riskScore,
    required this.triggerSource,
    required this.activeSignals,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'lat': position.latitude,
        'lon': position.longitude,
        'riskScore': riskScore,
        'triggerSource': triggerSource,
        'activeSignals': activeSignals,
      };

  factory AlertRecord.fromJson(Map<String, dynamic> json) => AlertRecord(
        id: json['id'],
        timestamp: DateTime.parse(json['timestamp']),
        position: LatLng(json['lat'], json['lon']),
        riskScore: json['riskScore'],
        triggerSource: json['triggerSource'],
        activeSignals: List<String>.from(json['activeSignals']),
      );
}