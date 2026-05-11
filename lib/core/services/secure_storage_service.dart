import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing sensitive data like passwords
/// Uses platform-specific secure storage (Keychain on iOS, Keystore on Android)
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._internal();
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Store a password securely
  Future<void> storePassword(String key, String password) async {
    if (password.isEmpty) return;
    await _storage.write(key: key, value: password);
  }

  /// Retrieve a password securely
  Future<String?> getPassword(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a specific password
  Future<void> deletePassword(String key) async {
    await _storage.delete(key: key);
  }

  /// Delete multiple passwords by pattern
  Future<void> deletePasswordsByPattern(String pattern) async {
    final allKeys = await _storage.readAll();
    for (final key in allKeys.keys) {
      if (key.contains(pattern)) {
        await _storage.delete(key: key);
      }
    }
  }

  /// Clear all stored passwords
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Check if a password exists for a key
  Future<bool> hasPassword(String key) async {
    final value = await _storage.read(key: key);
    return value != null && value.isNotEmpty;
  }
}
