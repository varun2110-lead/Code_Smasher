import 'dart:async';
import 'package:flutter/services.dart';

/// VolumeTriggerService — SHIELD
///
/// Detects triple press of volume-down button within 2 seconds.
/// Fires a callback that SafetyEngine uses to trigger SOS.
///
/// Works via Flutter's hardware keyboard / key event channel.
/// No special permissions needed — volume events are always accessible.
///
/// DEMO: Press volume down 3 times quickly → SOS triggers.

class VolumeTriggerService {
  static final VolumeTriggerService _instance =
      VolumeTriggerService._internal();
  factory VolumeTriggerService() => _instance;
  VolumeTriggerService._internal();

  // Callback fired when triple press detected
  VoidCallback? onTriplePress;

  final List<DateTime> _pressTimes = [];
  static const _requiredPresses = 3;
  static const _windowSeconds = 2;

  bool _active = false;
  bool _disposed = false;

  // ── Init ──────────────────────────────────────────────────────────────
  void init({required VoidCallback onTrigger}) {
    if (_active) return;
    _active = true;
    onTriplePress = onTrigger;

    // Listen to hardware key events via ServicesBinding
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  // ── Key handler ───────────────────────────────────────────────────────
  bool _onKey(KeyEvent event) {
    if (_disposed) return false;

    // Only care about volume down key-down events
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.audioVolumeDown) return false;

    final now = DateTime.now();
    _pressTimes.add(now);

    // Remove presses older than window
    _pressTimes.removeWhere(
      (t) => now.difference(t).inSeconds >= _windowSeconds,
    );

    if (_pressTimes.length >= _requiredPresses) {
      _pressTimes.clear();
      // Fire on next frame to avoid blocking key handler
      Future.microtask(() {
        if (!_disposed) onTriplePress?.call();
      });
    }

    // Return false so volume still changes normally
    // (returning true would consume the event and block volume change)
    return false;
  }

  // ── Cleanup ───────────────────────────────────────────────────────────
  void dispose() {
    _disposed = true;
    _active = false;
    HardwareKeyboard.instance.removeHandler(_onKey);
  }
}