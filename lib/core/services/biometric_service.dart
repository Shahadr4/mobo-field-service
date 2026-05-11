import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling biometric authentication
/// Provides methods for checking availability, enabling/disabling, and authenticating
class BiometricService {
  static LocalAuthentication? _localAuth;
  static bool _isInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      _localAuth = LocalAuthentication();
      _isInitialized = true;
      log('BiometricService initialized');
    }
  }

  /// Check if biometric authentication is available on the device
  static Future<bool> isBiometricAvailable() async {
    try {
      await _ensureInitialized();

      if (_localAuth == null) {
        log('LocalAuth instance is null');
        return false;
      }

      log('Checking device support for biometrics');
      final bool isDeviceSupported = await _localAuth!.isDeviceSupported();
      log('Device supported: $isDeviceSupported');

      if (!isDeviceSupported) {
        return false;
      }

      log('Checking if can check biometrics');
      final bool canCheckBiometrics = await _localAuth!.canCheckBiometrics;
      log('Can check biometrics: $canCheckBiometrics');

      return canCheckBiometrics;
    } on PlatformException catch (e) {
      log(
        'Platform exception checking biometric availability: ${e.code} - ${e.message}',
      );
      return false;
    } catch (e) {
      log('Unexpected error checking biometric availability: $e');
      return false;
    }
  }

  /// Get list of available biometric types on the device
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      await _ensureInitialized();
      if (_localAuth == null) return [];

      return await _localAuth!.getAvailableBiometrics();
    } catch (e) {
      log('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if biometric authentication is enabled in app settings
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  /// Enable or disable biometric authentication in app settings
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
    log('Biometric authentication ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Perform biometric authentication
  /// Returns true if authentication succeeds, false otherwise
  static Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to access the app',
  }) async {
    try {
      await _ensureInitialized();
      if (_localAuth == null) {
        log('LocalAuth instance is null for authentication');
        return false;
      }

      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        log('Biometric authentication not available');
        return false;
      }

      final bool didAuthenticate = await _localAuth!.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow PIN/Pattern as fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      log('Biometric authentication result: $didAuthenticate');
      return didAuthenticate;
    } on PlatformException catch (e) {
      log('Biometric authentication error: ${e.message}');

      // Handle specific error cases
      switch (e.code) {
        case 'NotAvailable':
          log('Biometric authentication not available');
          break;
        case 'NotEnrolled':
          log('No biometrics enrolled');
          break;
        case 'LockedOut':
          log('Biometric authentication locked out');
          break;
        case 'PermanentlyLockedOut':
          log('Biometric authentication permanently locked out');
          break;
        default:
          log('Unknown biometric error: ${e.code}');
      }
      return false;
    } catch (e) {
      log('Unexpected biometric error: $e');
      return false;
    }
  }

  /// Get human-readable name for biometric type
  static String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.weak:
        return 'PIN/Pattern';
      case BiometricType.strong:
        return 'Strong Biometric';
    }
  }

  /// Get list of available biometric type names
  static Future<List<String>> getAvailableBiometricNames() async {
    final types = await getAvailableBiometrics();
    return types.map((type) => getBiometricTypeName(type)).toList();
  }

  /// Check if biometric prompt should be shown
  /// Returns true if biometric is enabled and available
  static Future<bool> shouldPromptBiometric() async {
    try {
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        log('Biometric not enabled in settings');
        return false;
      }

      final isAvailable = await isBiometricAvailable();
      log('Biometric available: $isAvailable');
      return isAvailable;
    } catch (e) {
      log('Error checking if should prompt biometric: $e');
      return false;
    }
  }

  /// Get user-friendly error message for biometric errors
  static String getErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device';
      case 'NotEnrolled':
        return 'No biometric credentials enrolled. Please set up biometric authentication in your device settings';
      case 'LockedOut':
        return 'Too many failed attempts. Please try again later';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is locked. Please use your device password';
      case 'PasscodeNotSet':
        return 'Please set up a device passcode first';
      case 'OtherOperatingSystem':
        return 'Biometric authentication is not supported on this platform';
      default:
        return 'Biometric authentication failed: ${e.message ?? 'Unknown error'}';
    }
  }

  /// Initialize the biometric service
  static Future<void> initialize() async {
    try {
      await _ensureInitialized();
      // Pre-initialize the local auth instance
      await _localAuth?.isDeviceSupported();
      log('Biometric service initialized successfully');
    } catch (e) {
      log('Error initializing biometric service: $e');
    }
  }
}
