import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Centralized haptic feedback helpers.
/// Keeps usage consistent across the app and makes it easy to adjust per-platform.
class HapticsService {
  HapticsService._();

  static Future<void> selection() async {
    // Subtle feedback for UI selections
    await HapticFeedback.selectionClick();
  }

  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  static Future<void> success() async {
    // Try to emulate success feedback. iOS has distinct patterns, Android limited.
    // Do a medium impact followed by a light click for a pleasant success feel.
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await HapticFeedback.selectionClick();
  }

  static Future<void> warning() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> error() async {
    // Slightly stronger feedback for errors
    await HapticFeedback.heavyImpact();
  }

  /// Barcode scan feedback - short vibration (100ms)
  /// Matches Odoo OWL barcode scanner vibration
  static Future<void> vibrateScan() async {
    if (!isSupported) return;
    await HapticFeedback.lightImpact();
  }

  /// Convenience wrapper to respect platforms where haptics are undesirable.
  /// Currently returns true for mobile platforms. Extend this if needed.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;
}
