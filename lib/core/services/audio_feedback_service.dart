import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for managing audio feedback during barcode scanning
/// Matches the sound functionality from Odoo OWL barcode interface
class AudioFeedbackService {
  static final AudioFeedbackService _instance =
  AudioFeedbackService._internal();
  factory AudioFeedbackService() => _instance;
  AudioFeedbackService._internal();

  final Map<String, AudioPlayer> _players = {};
  bool _isEnabled = true;
  bool _isInitialized = false;

  /// Initialize audio players and preload sounds
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      /// Create players for each sound type
      _players['success'] = AudioPlayer();
      _players['error'] = AudioPlayer();
      _players['notify'] = AudioPlayer();

      /// Set audio mode for all players
      for (final player in _players.values) {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(1.0);
      }

      /// Preload audio files
      await _players['success']?.setSource(AssetSource('audio/success.mp3'));
      await _players['error']?.setSource(AssetSource('audio/error.mp3'));
      await _players['notify']?.setSource(AssetSource('audio/notify.mp3'));

      _isInitialized = true;
    } catch (e) {
      /// Don't throw - audio is optional, app should work without it
    }
  }

  /// Play success sound (on successful barcode scan)
  Future<void> playSuccess() async {
    await _playSound('success');
  }

  /// Play error sound (on scan error or invalid barcode)
  Future<void> playError() async {
    await _playSound('error');
  }

  /// Play notify sound (for general notifications)
  Future<void> playNotify() async {
    await _playSound('notify');
  }

  /// Internal method to play a sound
  Future<void> _playSound(String type) async {
    if (!_isEnabled || !_isInitialized) return;

    try {
      final player = _players[type];
      if (player == null) return;

      /// Stop current playback if any
      await player.stop();

      /// Play from beginning
      await player.resume();
    } catch (e) {
      /// Silently fail - don't disrupt user experience
    }
  }

  /// Enable or disable audio feedback
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if audio is enabled
  bool get isEnabled => _isEnabled;

  /// Dispose all audio players
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _isInitialized = false;
  }

  /// Reset audio players (useful after errors)
  Future<void> reset() async {
    await dispose();
    await initialize();
  }
}
