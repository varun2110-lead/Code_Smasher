import 'dart:async';
import 'dart:math';

/// SensorService: Shake detection via accelerometer.
/// Uses sensors_plus package. Falls back to simulation if unavailable.
class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  final _shakeController = StreamController<double>.broadcast();
  Stream<double> get shakeStream => _shakeController.stream;

  int _shakeBuffer = 0;
  DateTime? _lastShake;
  Timer? _bufferResetTimer;

  // Screen off tracking (simplified)
  int _screenOffSeconds = 0;
  int get screenOffSeconds => _screenOffSeconds;

  Future<void> init() async {
    // --- REAL ACCELEROMETER (uncomment with sensors_plus) ---
    // import 'package:sensors_plus/sensors_plus.dart';
    //
    // accelerometerEventStream().listen((AccelerometerEvent event) {
    //   final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    //   _handleAcceleration(magnitude);
    // });
    // --------------------------------------------------------

    // Simulation: no-op (shake triggered via simulateShake() for demo)
  }

  void _handleAcceleration(double magnitude) {
    const threshold = 20.0;
    const burstRequired = 3;

    if (magnitude > threshold) {
      final now = DateTime.now();
      if (_lastShake == null ||
          now.difference(_lastShake!).inMilliseconds > 100) {
        _shakeBuffer++;
        _lastShake = now;

        _bufferResetTimer?.cancel();
        _bufferResetTimer = Timer(const Duration(milliseconds: 800), () {
          _shakeBuffer = 0;
        });

        if (_shakeBuffer >= burstRequired) {
          _shakeController.add(magnitude);
          _shakeBuffer = 0;
        }
      }
    }
  }

  /// Call this from a test button or accelerometer stream
  void injectShake({double magnitude = 25.0}) {
    _handleAcceleration(magnitude);
  }

  /// Simulate rapid shake burst for demo
  void simulateShakeBurst() {
    Timer.periodic(const Duration(milliseconds: 150), (t) {
      if (t.tick > 5) {
        t.cancel();
        return;
      }
      _handleAcceleration(28.0 + t.tick.toDouble());
    });
  }

  void dispose() {
    _bufferResetTimer?.cancel();
    _shakeController.close();
  }
}