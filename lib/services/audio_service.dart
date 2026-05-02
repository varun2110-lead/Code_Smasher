import 'package:audioplayers/audioplayers.dart';

/// AudioService — Fixed Phase 6
///
/// FLOW:
///   1. Screen opens → playRingtone() loops ringtone.mp3
///   2. User taps Accept → stopAll() then playVoice() plays voice.mp3 once
///   3. User taps Decline / screen closes → stopAll()
///
/// Uses two separate AudioPlayer instances to avoid
/// the race condition that caused voice to play during ringing.
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Separate players — one for ringtone (loop), one for voice (once)
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();

  bool _ringtonePlaying = false;
  bool _voicePlaying = false;

  /// Call when fake call screen appears.
  /// Loops ringtone.mp3 until stopAll() is called.
  Future<void> playRingtone() async {
    if (_ringtonePlaying) return;
    _ringtonePlaying = true;

    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.setVolume(1.0);
      await _ringtonePlayer.play(AssetSource('audio/ringtone.mp3'));
    } catch (e) {
      _ringtonePlaying = false;
    }
  }

  /// Call ONLY after user taps Accept.
  /// Stops ringtone first, then plays voice.mp3 once.
  Future<void> playVoice() async {
    if (_voicePlaying) return;

    // Stop ringtone FIRST — this is the key fix
    await _ringtonePlayer.stop();
    _ringtonePlaying = false;

    _voicePlaying = true;

    try {
      await _voicePlayer.setReleaseMode(ReleaseMode.release);
      await _voicePlayer.setVolume(1.0);
      await _voicePlayer.play(AssetSource('audio/voice.mp3'));

      // Reset flag when voice completes
      _voicePlayer.onPlayerComplete.listen((_) {
        _voicePlaying = false;
      });
    } catch (e) {
      _voicePlaying = false;
    }
  }

  /// Stop all audio immediately.
  /// Call on dismiss, decline, or dispose.
  Future<void> stopAll() async {
    _ringtonePlaying = false;
    _voicePlaying = false;
    await _ringtonePlayer.stop();
    await _voicePlayer.stop();
  }

  Future<void> dispose() async {
    await stopAll();
    await _ringtonePlayer.dispose();
    await _voicePlayer.dispose();
  }
}