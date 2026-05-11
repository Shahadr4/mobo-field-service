import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appsession.dart';
import 'odoo_session_manager.dart';
import 'secure_storage_service.dart';

class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();
  factory SessionService() => instance;
  SessionService._internal();

  AppSessionData? _currentSession;
  bool _isInitialized = false;
  List<Map<String, dynamic>> _storedAccounts = [];

  AppSessionData? get currentSession => _currentSession;
  bool get isInitialized => _isInitialized;
  bool get hasValidSession => _currentSession != null;
  List<Map<String, dynamic>> get storedAccounts => _storedAccounts;

  Future<void> initialize() async {

    debugPrint('[SessionService] Initializing SessionService');
    if (_isInitialized) {
      debugPrint('[SessionService] Already initialized, skipping');
      return;
    }

    // Set up session callbacks
    OdooSessionManager.setSessionCallbacks(
      onSessionUpdated: (sessionModel) {
        debugPrint('[SessionService] Received session update callback ${sessionModel.odooSession} , ${sessionModel.companyId}');
        updateSession(sessionModel);
      },
      onSessionCleared: () {
        debugPrint('[SessionService] Received session clear callback');
        clearSession();
      },
    );

    // Load current session
    _currentSession = await OdooSessionManager.getCurrentSession();

    // Load stored accounts
    await _loadStoredAccounts();

    // Migrate passwords from SharedPreferences to secure storage
    await _migratePasswordsToSecureStorage();

    // Auto-store current session if not already stored
    if (_currentSession != null) {
      await _autoStoreCurrentSession();
    }

    _isInitialized = true;
    debugPrint(
      '[SessionService] Initialization completed. hasValidSession: $hasValidSession',
    );
    debugPrint(
      '[SessionService] Loaded ${_storedAccounts.length} stored accounts',
    );
    notifyListeners();
  }

  void updateSession(AppSessionData newSession) {
    debugPrint('[SessionService] Updating session directly');
    _currentSession = newSession;
    notifyListeners();
  }

  void clearSession() {
    debugPrint('[SessionService] Clearing session');
    _currentSession = null;
    notifyListeners();
  }

  Future<void> logout() async {
    debugPrint('[SessionService] Logging out');
    try {
      // Clear the session on the backend
      await OdooSessionManager.logout();

      // Clear stored accounts for privacy
      await _clearStoredAccountsData();

      // Clear password caches
      await _clearPasswordCaches();

      // Clear session service state
      clearSession();

    } catch (e, stackTrace) {
      debugPrint('[SessionService] Logout encountered an error: $e');
      debugPrint('[SessionService] Stack trace: $stackTrace');
    }
  }

  // Account management methods

  Future<void> _loadStoredAccounts() async {
    debugPrint('[SessionService] Loading stored accounts');
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> storedAccountsJson =
          prefs.getStringList('stored_accounts') ?? [];

      debugPrint(
        '[SessionService] Raw stored accounts JSON: $storedAccountsJson',
      );

      _storedAccounts = storedAccountsJson
          .map((json) {
        try {
          final decoded = Map<String, dynamic>.from(jsonDecode(json));
          debugPrint('[SessionService] Decoded account: $decoded');
          return decoded;
        } catch (e) {
          debugPrint(
            '[SessionService] Error decoding account JSON: $json, error: $e',
          );
          return null;
        }
      })
          .where((account) => account != null)
          .cast<Map<String, dynamic>>()
          .toList();

      // Clean up any duplicate accounts
      await _cleanupDuplicateAccounts();

      debugPrint(
        '[SessionService] Successfully loaded ${_storedAccounts.length} stored accounts',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[SessionService] Error loading stored accounts: $e');
      _storedAccounts = [];
    }
  }

  Future<void> _autoStoreCurrentSession() async {
    if (_currentSession == null) return;

    // Check if current session is already stored
    final currentExists = _storedAccounts.any(
          (account) =>
      account['userId'] == _currentSession!.userId.toString() &&
          account['serverUrl'] == _currentSession!.serverUrl &&
          account['database'] == _currentSession!.database,
    );

    if (!currentExists) {
      debugPrint('[SessionService] Auto-storing current session');
      await storeAccount(
        _currentSession!,
        '',
      ); // Store with empty password initially
    }
  }

  Future<void> _cleanupDuplicateAccounts() async {
    debugPrint(
      '[SessionService] Starting cleanup of ${_storedAccounts.length} accounts',
    );
    final uniqueAccounts = <String, Map<String, dynamic>>{};

    for (final account in _storedAccounts) {
      final userId = account['userId']?.toString() ?? '';
      final serverUrl = account['serverUrl']?.toString() ?? '';
      final database = account['database']?.toString() ?? '';

      if (userId.isEmpty || serverUrl.isEmpty || database.isEmpty) {
        debugPrint('[SessionService] Skipping invalid account: $account');
        continue;
      }

      final key = '${userId}_${serverUrl}_$database';

      if (!uniqueAccounts.containsKey(key)) {
        uniqueAccounts[key] = account;
      } else {
        final existing = uniqueAccounts[key]!;
        final currentHasPassword =
            account['password']?.toString().isNotEmpty == true;
        final existingHasPassword =
            existing['password']?.toString().isNotEmpty == true;

        if (currentHasPassword && !existingHasPassword) {
          uniqueAccounts[key] = account;
        }
      }
    }

    final originalCount = _storedAccounts.length;
    _storedAccounts = uniqueAccounts.values.toList();

    if (_storedAccounts.length != originalCount) {
      debugPrint(
        '[SessionService] Cleaned up ${originalCount - _storedAccounts.length} duplicate accounts',
      );
      await _saveStoredAccountsWithRetry();
    }
  }

  Future<void> storeAccount(
      AppSessionData session,
      String password, {
        bool markAsCurrent = true,
      }) async {
    debugPrint(
      '[SessionService] Storing account for user: ${session.userLogin}, markAsCurrent: $markAsCurrent',
    );
    debugPrint(
      '[SessionService] Current _storedAccounts count before: ${_storedAccounts.length}',
    );

    try {
      String? imageBase64;
      String userDisplayName = session.userLogin;

      // Try to fetch user details including image
      try {
        final client = await OdooSessionManager.getClient();

        if (client != null && session.userId != null) {
          final userDetails = await client.callKw({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [session.userId],
              ['name', 'image_1920'],
            ],
            'kwargs': {}, // Add missing 'kwargs': {} here
          });

          if (userDetails is List && userDetails.isNotEmpty) {
            final user = userDetails.first as Map;
            final n = user['name'];
            if (n != null && n != false) {
              userDisplayName = n.toString();
            }
            final img = user['image_1920'];
            if (img != null && img != false) {
              imageBase64 = img.toString();
            }
          }
        }
      } catch (e) {
        debugPrint(
          '[SessionService] Non-fatal: could not fetch user image/name: $e',
        );
      }

      // Create account data (WITHOUT password - stored securely)
      final accountData = {
        'id': session.userId.toString(),
        'name': userDisplayName,
        'email': session.userLogin,
        'url': session.serverUrl.trim(),
        'database': session.database,
        'username': session.userLogin,
        'isCurrent': markAsCurrent,
        'lastLogin': DateTime.now().toIso8601String(),
        'imageBase64': imageBase64?.isNotEmpty == true ? imageBase64 : null,
        // Keep compatibility fields
        'userId': session.userId.toString(),
        'userName': userDisplayName,
        'serverUrl': session.serverUrl,
        // DON'T store password here - use secure storage
        'sessionId': session.sessionId,
      };

      debugPrint('[SessionService] Account data to store: $accountData');

      // Mark all other accounts as not current only if this account is being marked as current
      if (markAsCurrent) {
        for (var account in _storedAccounts) {
          account['isCurrent'] = false;
        }
      }

      // Check if account already exists
      final existingIndex = _storedAccounts.indexWhere(
            (account) =>
        account['id'] == accountData['id'] &&
            account['url'] == accountData['url'] &&
            account['database'] == accountData['database'],
      );

      if (existingIndex != -1) {
        debugPrint(
          '[SessionService] Updating existing account at index $existingIndex',
        );
        _storedAccounts[existingIndex] = accountData;
      } else {
        debugPrint('[SessionService] Adding new account at the beginning');
        _storedAccounts.insert(0, accountData);
      }

      debugPrint(
        '[SessionService] Current _storedAccounts count after: ${_storedAccounts.length}',
      );

      await _saveStoredAccountsWithRetry();

      // Store password with multiple patterns
      if (password.isNotEmpty) {
        await _storePasswordWithMultiplePatterns(session, password);
      }

      debugPrint('[SessionService] Account stored/updated successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('[SessionService] Error storing account: $e');
      rethrow;
    }
  }

  Future<void> _storePasswordWithMultiplePatterns(
      AppSessionData session,
      String password,
      ) async {
    if (password.isEmpty) return;

    try {
      final secureStorage = SecureStorageService.instance;

      // Store password with multiple patterns for reliable retrieval
      await secureStorage.storePassword(
        'password_${session.userId}_${session.database}',
        password,
      );
      await secureStorage.storePassword(
        'password_${session.userLogin}_${session.database}',
        password,
      );

      debugPrint(
        '[SessionService] Password stored securely with multiple patterns',
      );
    } catch (e) {
      debugPrint('[SessionService] Error storing password patterns: $e');
    }
  }

  Future<String?> retrievePasswordWithMultiplePatterns(
      Map<String, dynamic> accountData,
      ) async {
    try {
      final secureStorage = SecureStorageService.instance;
      final userId = accountData['id'] ?? accountData['userId'];
      final username = accountData['username'] ?? accountData['email'];
      final database = accountData['database'];

      // Try multiple password patterns in secure storage
      List<String> passwordKeys = [
        'password_${userId}_$database',
        'password_${username}_$database',
      ];

      // Try each password key pattern
      for (String key in passwordKeys) {
        final password = await secureStorage.getPassword(key);
        if (password != null && password.isNotEmpty) {
          debugPrint(
            '[SessionService] Found password in secure storage with key: $key',
          );
          return password;
        }
      }

      debugPrint(
        '[SessionService] No password found in secure storage for account: ${accountData['name']}',
      );
      return null;
    } catch (e) {
      debugPrint('[SessionService] Error retrieving password: $e');
      return null;
    }
  }

  Future<void> _saveStoredAccountsWithRetry() async {
    int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
          '[SessionService] Saving ${_storedAccounts.length} accounts',
        );

        final prefs = await SharedPreferences.getInstance();

        // JSON encode accounts
        final updatedAccountsJson = _storedAccounts
            .map((account) => jsonEncode(account))
            .toList();

        await prefs.setStringList('stored_accounts', updatedAccountsJson);

        debugPrint('[SessionService] Stored accounts saved successfully');
        return; // Success
      } catch (e) {
        debugPrint(
          '[SessionService] Error saving stored accounts (attempt $attempt): $e',
        );
        if (attempt == maxRetries) {
          debugPrint(
            '[SessionService] Failed to save accounts after $maxRetries attempts',
          );
        } else {
          await Future.delayed(Duration(milliseconds: 100 * attempt));
        }
      }
    }
  }

  Future<void> removeStoredAccount(int accountIndex) async {
    if (accountIndex < 0 || accountIndex >= _storedAccounts.length) {
      debugPrint(
        '[SessionService] Invalid account index for removal: $accountIndex',
      );
      return;
    }

    final accountData = _storedAccounts[accountIndex];
    debugPrint(
      '[SessionService] Removing stored account: ${accountData['name'] ?? accountData['userName']}',
    );

    _storedAccounts.removeAt(accountIndex);
    await _saveStoredAccountsWithRetry();
    notifyListeners();
  }

  Future<bool> updateSessionDirectly(AppSessionData newSession) async {
    debugPrint(
      '[SessionService] Direct session update: ${newSession.userLogin}',
    );
    try {
      // Update the current session
      _currentSession = newSession;

      // Update OdooSessionManager
      await OdooSessionManager.updateSession(newSession);

      debugPrint(
        '[SessionService] Successfully updated session: ${newSession.userLogin}',
      );

      // Notify listeners
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('[SessionService] Error updating session: $e');
      return false;
    }
  }

  Future<bool> switchToAccount(AppSessionData newSession) async {
    return await updateSessionDirectly(newSession);
  }

  // Legacy method for compatibility with login provider
  Future<void> updateAccountCredentials(
      String username,
      String password,
      ) async {
    if (_currentSession != null) {
      await _storePasswordWithMultiplePatterns(_currentSession!, password);
    }
  }

  Future<void> _clearStoredAccountsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stored_accounts');
      _storedAccounts = [];
      debugPrint('[SessionService] Cleared stored accounts data');
    } catch (e) {
      debugPrint('[SessionService] Error clearing stored accounts: $e');
    }
  }

  Future<void> _clearPasswordCaches() async {
    try {
      // Clear all passwords from secure storage
      await SecureStorageService.instance.clearAll();

      debugPrint(
        '[SessionService] Cleared password caches from secure storage',
      );
    } catch (e) {
      debugPrint('[SessionService] Error clearing password caches: $e');
    }
  }

  /// Migrate passwords from SharedPreferences to secure storage
  Future<void> _migratePasswordsToSecureStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if migration already done
      if (prefs.getBool('passwords_migrated') == true) {
        debugPrint('[SessionService] Passwords already migrated');
        return;
      }

      debugPrint(
        '[SessionService] Starting password migration to secure storage',
      );
      final secureStorage = SecureStorageService.instance;
      int migratedCount = 0;

      // Migrate all password keys from SharedPreferences
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('password_')) {
          final password = prefs.getString(key);
          if (password != null && password.isNotEmpty) {
            await secureStorage.storePassword(key, password);
            await prefs.remove(key);
            migratedCount++;
          }
        }
      }

      // Mark migration as complete
      await prefs.setBool('passwords_migrated', true);
      debugPrint(
        '[SessionService] Migrated $migratedCount passwords to secure storage',
      );
    } catch (e) {
      debugPrint('[SessionService] Error migrating passwords: $e');
    }
  }
}