import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/appsession.dart';
import 'secure_storage_service.dart';
import 'connectivity_service.dart';


enum LoginStatus {
  success,
  twoFactorEnabled,
  failed,
}
class OdooSessionManager {
  // Session state
  static OdooClient? _client;
  static AppSessionData? _cachedSession;
  static bool _isRefreshing = false;
  static DateTime? _lastAuthTime;

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(milliseconds: 500);
  static const Duration _sessionCacheValidDuration = Duration(minutes: 5);

  // Callbacks for session events
  static Function(AppSessionData)? _onSessionUpdated;
  static Function()? _onSessionCleared;

  /// Set callbacks for session lifecycle events
  static void setSessionCallbacks({
    Function(AppSessionData)? onSessionUpdated,
    Function()? onSessionCleared,
  }) {
    _onSessionUpdated = onSessionUpdated;
    _onSessionCleared = onSessionCleared;
    debugPrint('[OdooSessionManager] Session callbacks configured');
  }

  /// Check if an error is retryable
  static bool _isRetryableError(Object e) {
    if (e is SocketException) return true;
    if (e is TimeoutException) return true;
    if (e is http.ClientException) return true;

    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('connection reset') ||
        errorStr.contains('timed out') ||
        errorStr.contains('connection refused');
  }

  /// Restore a previously saved session and force a company context
  static Future<bool> restoreSession({required int companyId}) async {
    debugPrint('[OdooSessionManager] restoreSession(companyId=$companyId)');
    if (companyId <= 0) return false;

    final saved = await getCurrentSession();
    if (saved == null) return false;

    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(saved.serverUrl);

      // Create client using stored session ID (no invalid casts)
      final OdooClient client = OdooClient(
        saved.serverUrl,
        sessionId: saved.odooSession,
      );

      // Ensure allowed companies include the requested one
      List<int> allowed = [...saved.allowedCompanyIds];

      // If the allowed list is empty, we might need to fetch defaults.
      // But if it's populated, we trust the user's selection and just ensure the active company is added.
      if (allowed.isEmpty && saved.userId != 0) {
        try {
          final userCompanies = await _fetchUserCompanies(client, saved.userId);
          final loadedAllowed =
          (userCompanies['company_ids'] as List<int>? ?? []);
          if (loadedAllowed.isNotEmpty) allowed = loadedAllowed;
        } catch (e) {
          debugPrint(
            '[OdooSessionManager] restoreSession: company load failed: $e',
          );
        }
      }

      // Ensure the target company is in the allowed list
      if (!allowed.contains(companyId)) {
        allowed.add(companyId);
      }

      final refreshed = saved.copyWith(
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        selectedCompanyId: companyId,
        allowedCompanyIds: <int>{...allowed}.toList(),
        isStockUser: saved.isStockUser,
      );

      _client = client;
      _cachedSession = refreshed;
      _lastAuthTime = DateTime.now();
      await refreshed.saveToPrefs();
      ConnectivityService.instance.setCurrentServerUrl(refreshed.serverUrl);
      _onSessionUpdated?.call(refreshed);
      return true;
    } on NoInternetException catch (_) {
      return false;
    } on ServerUnreachableException catch (_) {
      return false;
    } catch (e) {
      debugPrint('[OdooSessionManager] restoreSession failed: $e');
      return false;
    }
  }

  /// Check if an error is authentication-related
  static bool _isAuthError(Object e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('401') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('access denied') ||
        errorStr.contains('invalid session') ||
        errorStr.contains('session expired') ||
        errorStr.contains('authentication') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('403');
  }

  /// Get current session from cache or storage
  static Future<AppSessionData?> getCurrentSession() async {

    if (_cachedSession != null) return _cachedSession;

    // Try to restore from preferences
    try {
      final saved = await AppSessionData.fromPrefs();
      if (saved == null) return null;

      if(saved.odooSession.id.isNotEmpty){

        log("Sesssion is presene");
        final session  = AppSessionData(
            odooSession: saved.odooSession,
            password: saved.password,
            serverUrl: saved.serverUrl,
            database: saved.database,
          version: saved.version,
        );
        return session;
      }



      log(saved.database);
      log(saved.userLogin);
      log(saved.password);

      // Re-authenticate to get fresh session
      final client = OdooClient(saved.serverUrl);
      final odooSession = await client.authenticate(
        saved.database,
        saved.userLogin,
        saved.password,

      );
      final sessionData = AppSessionData(
        odooSession: odooSession,
        password: saved.password,
        serverUrl: saved.serverUrl,
        database: saved.database,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        selectedCompanyId: saved.selectedCompanyId,
        allowedCompanyIds: saved.allowedCompanyIds,
        isStockUser: saved.isStockUser,
      );

      _client = client;
      _cachedSession = sessionData;
      _lastAuthTime = DateTime.now();
      ConnectivityService.instance.setCurrentServerUrl(saved.serverUrl);

      return sessionData;
    } catch (e) {
        debugPrint('[OdooSessionManager] getCurrentSession auth failed: $e');
      return null;
    }
  }

  /// Check if current session is valid (not expired)
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// Login and save session
  static Future<LoginStatus> loginAndSaveSession({
    required String serverUrl,
    required String database,
    required String userLogin,
    required String password,
    bool autoLoadCompanies = true,
    bool otp = false,
    OdooClient? odooClient,
  }) async {

    // Validate inputs
    if (serverUrl.isEmpty || database.isEmpty || userLogin.isEmpty) {
      throw Exception('Invalid login parameters');
    }

    // Normalize server URL
    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }


    // Connectivity checks
    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(normalizedUrl);
    } catch (e) {
      debugPrint('[OdooSessionManager] Connectivity check failed: $e');
      rethrow;
    }

    OdooClient client;
    if(!otp) {
      client = OdooClient(normalizedUrl);
      log("noototp");
    }else{
      log("otp");
      client = odooClient!;
      log("otp");

    }

    // Retry authentication on transient failures
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      log("try -$attempt ,${normalizedUrl}");
      try {
        debugPrint(
          '[OdooSessionManager] Authentication attempt $attempt/$_maxRetries',
        );
        log("startind");
        log(database);
        log(userLogin);
        log(password);


        OdooSession odooSession;
        if(!otp) {
          odooSession = await client.authenticate(
            database,
            userLogin,
            password,
          );
        }else{
          odooSession = client.sessionId!;
        }
        int? selectedCompanyId;
        List<int> allowedCompanyIds = [];

        if (autoLoadCompanies) {
          try {
            debugPrint('[OdooSessionManager] Fetching user companies...');
            final userInfo = await _fetchUserCompanies(
              client,
              odooSession.userId,
            );

            // Only override if company 1 is actually allowed, otherwise keep 1 as default.
            final fetchedAllowed =
                (userInfo['company_ids'] as List?)?.cast<int>() ?? [];

                if (fetchedAllowed.contains(3)) {
              selectedCompanyId = userInfo['company_id'];
              allowedCompanyIds = fetchedAllowed;
            } else {
              selectedCompanyId = userInfo['company_id'] ?? 1;
              allowedCompanyIds = fetchedAllowed.isNotEmpty
                  ? fetchedAllowed
                  : [userInfo['company_ids']];
            }

            debugPrint('[OdooSessionManager] User companies loaded:');
            debugPrint('  - Default company: $selectedCompanyId');
            debugPrint('  - Allowed companies: $allowedCompanyIds');
          } catch (e) {
            debugPrint('[OdooSessionManager] Failed to fetch companies: $e');
          }
        }


        bool isStockUser = false;

        final sessionData = AppSessionData(
          odooSession: odooSession,
          password: password,
          serverUrl: normalizedUrl,
          database: database,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          selectedCompanyId: selectedCompanyId, // will be 1 in your forced case
          allowedCompanyIds: allowedCompanyIds, // will contain 1
          isStockUser: isStockUser,
          version: odooSession.serverVersion
        );

        await sessionData.saveToPrefs();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastServerUrl', normalizedUrl);
        await prefs.setString('lastDatabase', database);

        _client = client;
        _cachedSession = sessionData;
        _lastAuthTime = DateTime.now();

        ConnectivityService.instance.setCurrentServerUrl(normalizedUrl);
        _onSessionUpdated?.call(sessionData);

        debugPrint('[OdooSessionManager] Login successful');
        return LoginStatus.success;
      } catch (e) {
        log("erorr =====>${e.toString()}");



        debugPrint('[OdooSessionManager] Login attempt $attempt failed: $e');

        // Handle HTML response error
        if (e is FormatException && e.toString().contains('<html>')) {
          throw Exception(
            'Server returned HTML instead of JSON. Please check server URL and ensure Odoo is running.',
          );
        }


        final msg = e.toString().toLowerCase();
        if ( msg.contains('type \'null\'') &&
            msg.contains('map<string') &&
            !msg.contains('html') &&
            !msg.contains('502') &&
            !msg.contains('timeout')) {
          log("errror 2fa");
          return LoginStatus.twoFactorEnabled;

        }


        // Don't retry credential errors
        if (e.toString().toLowerCase().contains('access denied') ||
            e.toString().toLowerCase().contains('wrong login/password') ||
            e.toString().toLowerCase().contains('invalid database')) {
          debugPrint('[OdooSessionManager] Credential error - not retrying');


          return LoginStatus.failed;
        }

        // Retry on connection errors
        if (attempt < _maxRetries && _isRetryableError(e)) {
          final delay = _baseDelay * attempt;
          debugPrint(
            '[OdooSessionManager] Retrying in ${delay.inMilliseconds}ms',
          );
          await Future.delayed(delay);
          continue;
        }

        // Non-retryable error or exhausted retries
        if (e is NoInternetException || e is ServerUnreachableException) {
          rethrow;
        }
        return LoginStatus.failed;
      }
    }

    return LoginStatus.failed;
  }

  /// Fetch user's company information from Odoo
  static Future<Map<String, dynamic>> _fetchUserCompanies(
      OdooClient client,
      int userId,
      ) async {
    try {
      final result = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          ['company_id', 'company_ids'],
        ],
        'kwargs': {},
      });

      if (result is List && result.isNotEmpty) {
        final userData = result[0];

        // Extract company_id (can be int or [id, name])
        int? companyId;
        if (userData['company_id'] is int) {
          companyId = userData['company_id'];
        } else if (userData['company_id'] is List &&
            userData['company_id'].isNotEmpty) {
          companyId = userData['company_id'][0];
        }

        // Extract company_ids
        List<int> companyIds = [];
        if (userData['company_ids'] is List) {
          companyIds = (userData['company_ids'] as List)
              .map((e) => e is int ? e : null)
              .whereType<int>()
              .toList();
        }



        return {'company_id': companyId, 'company_ids': companyIds};
      }

      return {};
    } catch (e) {
      debugPrint('[OdooSessionManager] Error fetching user companies: $e');
      return {};
    }
  }

  /// Authenticate without saving (for account switching)
  static Future<AppSessionData?> authenticate({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  }) async {
    debugPrint('[OdooSessionManager] Authenticating user: $username');

    if (serverUrl.isEmpty || database.isEmpty || username.isEmpty) {
      throw Exception('Invalid authentication parameters');
    }

    if (password.isEmpty) {
      throw Exception('Empty password - account needs re-authentication');
    }

    // Normalize server URL
    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    await ConnectivityService.instance.ensureInternetOrThrow();
    await ConnectivityService.instance.ensureServerReachable(normalizedUrl);

    final client = OdooClient(normalizedUrl);

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final odooSession = await client.authenticate(
          database,
          username,
          password,
        );

        final sessionData = AppSessionData(
          odooSession: odooSession,
          password: password,
          serverUrl: normalizedUrl,
          database: database,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );

        _cachedSession = sessionData;
        ConnectivityService.instance.setCurrentServerUrl(normalizedUrl);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastServerUrl', normalizedUrl);
        await prefs.setString('lastDatabase', database);

        debugPrint('[OdooSessionManager] Authentication successful');
        return sessionData;
      } catch (e) {
        if (e is FormatException && e.toString().contains('<html>')) {
          throw Exception(
            'Server returned HTML instead of JSON. Please check server URL.',
          );
        }

        if (e.toString().toLowerCase().contains('access denied') ||
            e.toString().toLowerCase().contains('wrong login/password')) {
          throw e;
        }

        if (attempt < _maxRetries && _isRetryableError(e)) {
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        throw e;
      }
    }

    throw Exception('Authentication failed after $_maxRetries attempts');
  }

  /// Update current session (for account switching)
  static Future<void> updateSession(AppSessionData newSession) async {
    debugPrint(
      '[OdooSessionManager] Updating session to: ${newSession.userLogin}',
    );
    _cachedSession = newSession;
    await newSession.saveToPrefs();

    // Clear client to force re-authentication
    _client = null;
    _lastAuthTime = null;

    ConnectivityService.instance.setCurrentServerUrl(newSession.serverUrl);
    _onSessionUpdated?.call(newSession);

    debugPrint('[OdooSessionManager] Session updated successfully');
  }

  /// Refresh expired session by re-authenticating
  static Future<bool> refreshSession() async {
    // Prevent concurrent refresh attempts
    if (_isRefreshing) {
      debugPrint(
        '[OdooSessionManager] Refresh already in progress, waiting...',
      );
      await Future.delayed(const Duration(milliseconds: 500));
      return await isSessionValid();
    }

    _isRefreshing = true;
    try {
      debugPrint('[OdooSessionManager] Refreshing session');
      final session = await getCurrentSession();

      if (session == null) {
        throw StateError('No Odoo session available. Please login.');
      }

      try {
        await ConnectivityService.instance.ensureInternetOrThrow();
        await ConnectivityService.instance.ensureServerReachable(
          session.serverUrl,
        );

        final client = OdooClient(session.serverUrl);
        final newOdooSession = await client.authenticate(
          session.database,
          session.userLogin,
          session.password,
        );

        _client = client;

        final refreshedSession = session.copyWith(
          odooSession: newOdooSession,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );

        _cachedSession = refreshedSession;
        _lastAuthTime = DateTime.now();
        await refreshedSession.saveToPrefs();
        _onSessionUpdated?.call(refreshedSession);

        ConnectivityService.instance.setCurrentServerUrl(
          refreshedSession.serverUrl,
        );

        debugPrint('[OdooSessionManager] Session refreshed successfully');
        return true;
      } on NoInternetException catch (e) {
        debugPrint('[OdooSessionManager] Cannot refresh - no internet: $e');
        return false;
      } on ServerUnreachableException catch (e) {
        debugPrint(
          '[OdooSessionManager] Cannot refresh - server unreachable: $e',
        );
        return false;
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Get authenticated client (nullable version)
  static Future<OdooClient?> getClient() async {
    try {
      return await getClientEnsured();
    } catch (e) {
      debugPrint('[OdooSessionManager] getClient error: $e');
      return null;
    }
  }

  /// Get authenticated client (throws on error)
  /// Reuses existing client when valid, only re-authenticates when necessary
  static Future<OdooClient> getClientEnsured() async {
    final session = await getCurrentSession();
    if (session == null) {
      throw StateError('No Odoo session available. Please login.');
    }

    // Check if session is expired
    if (session.isExpired) {
      debugPrint('[OdooSessionManager] Session expired, refreshing...');
      final refreshed = await refreshSession();
      if (!refreshed) {
        debugPrint(
          '[OdooSessionManager] Refresh failed, using cached client for offline mode',
        );
        if (_client == null) {
          _client = OdooClient(session.serverUrl);
        }
        return _client!;
      }
    }





    // Reuse existing client if valid
    if (_client != null &&
        _lastAuthTime != null &&
        DateTime.now().difference(_lastAuthTime!) <
            _sessionCacheValidDuration) {
      debugPrint('[OdooSessionManager] Reusing cached client');
      log("reusing===================>");
      log("reusing===================>");
      log("reusing===================>");
      return _client!;
    }



    // Create new authenticated client
    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(
        session.serverUrl,
      );

      debugPrint('[OdooSessionManager] Creating new authenticated client');
      OdooClient client ;
      final saved = await AppSessionData.fromPrefs();
      if(saved != null){
        client = OdooClient(session.serverUrl,sessionId: session.odooSession);

      }else{


        client= OdooClient(session.serverUrl);


        // Retry authentication on transient failures
        for (int attempt = 1; attempt <= _maxRetries; attempt++) {
          try {
            await client.authenticate(
              session.database,
              session.userLogin,
              session.password,
            );
            break;
          } catch (e) {
            if (attempt >= _maxRetries || !_isRetryableError(e)) rethrow;
            final delay = _baseDelay * attempt;
            debugPrint(
              '[OdooSessionManager] Auth retry in ${delay.inMilliseconds}ms',
            );
            await Future.delayed(delay);
          }
        }
      }

      _client = client;
      _lastAuthTime = DateTime.now();

      // Update session expiry
      final updatedSession = session.copyWith(
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );
      _cachedSession = updatedSession;
      await updatedSession.saveToPrefs();

      debugPrint('[OdooSessionManager] Client authenticated successfully');
      return client;
    } on NoInternetException catch (e) {
      debugPrint('[OdooSessionManager] No internet - offline mode: $e');
      final client = OdooClient(session.serverUrl);
      _client = client;
      return client;
    } on ServerUnreachableException catch (e) {
      debugPrint('[OdooSessionManager] Server unreachable - offline mode: $e');
      final client = OdooClient(session.serverUrl);
      _client = client;
      return client;
    }
  }

  /// Execute action with auto session refresh on auth errors
  static Future<T> callWithSession<T>(
      Future<T> Function(OdooClient client) action,
      ) async {
    final client = await getClientEnsured();

    try {
      return await action(client);
    } catch (e) {
      // Don't retry on connectivity issues
      if (e is NoInternetException || e is ServerUnreachableException) {
        rethrow;
      }

      // Retry once on auth errors
      if (_isAuthError(e)) {
        debugPrint('[OdooSessionManager] Auth error detected, refreshing: $e');

        final refreshed = await refreshSession();
        if (refreshed) {
          debugPrint('[OdooSessionManager] Refresh successful, retrying');
          final newClient = await getClientEnsured();
          return await action(newClient);
        } else {
          debugPrint('[OdooSessionManager] Refresh failed due to connectivity');
        }
      }

      rethrow;
    }
  }

  /// Safe wrapper for callKw with automatic company context injection
  /// This is the recommended method for all RPC calls to ensure proper multi-company support
  static Future<dynamic> safeCallKw(Map<String, dynamic> payload) {
    return callKwWithCompany(payload);
  }

  /// Safe wrapper for callKw WITHOUT company context injection
  /// Use this only for system-level calls that should not be company-filtered
  /// (e.g., fetching company list, user authentication, etc.)
  static Future<dynamic> safeCallKwWithoutCompany(
      Map<String, dynamic> payload,
      ) {
    return callWithSession((client) => client.callKw(payload));
  }

  /// Safe wrapper for callRPC
  static Future<dynamic> safeCallRPC(
      String path,
      String method,
      Map<String, dynamic> args,
      ) {
    return callWithSession((client) => client.callRPC(path, method, args));
  }

  /// Fetch the list of allowed companies (id, name) for the current user.
  /// This performs:
  /// 1) Read user's company_ids
  /// 2) search_read on res.company for id, name
  static Future<List<Map<String, dynamic>>> getAllowedCompaniesList() async {
    try {
      final client = await getClientEnsured();
      final session = await getCurrentSession();
      if (session == null) return [];

      // 1) Get the allowed company IDs from the user record
      final info = await _fetchUserCompanies(client, session.userId);
      final ids = (info['company_ids'] as List?)?.cast<int>() ?? [];

      if (ids.isEmpty) {
        // Fallback to current company if allowed list is empty
        final currentId = info['company_id'] as int?;
        if (currentId != null) {
          ids.add(currentId);
        } else {
          return [];
        }
      }

      // 2) Fetch details for ONLY those specific IDs
      final companiesRes = await safeCallKwWithoutCompany({
        'model': 'res.company',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', ids],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      if (companiesRes is List) {
        return companiesRes.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('[OdooSessionManager] Error in getAllowedCompaniesList: $e');
      return [];
    }
  }

  /// Convenience helper to retrieve companies and the currently selected company id
  /// for populating dropdowns.
  /// Returns a map: { 'companies': List<Map<String,dynamic>>, 'selectedCompanyId': int? }
  static Future<Map<String, dynamic>> getCompaniesForDropdown() async {
    final companies = await getAllowedCompaniesList();
    final selectedId = await getSelectedCompanyId();
    return {'companies': companies, 'selectedCompanyId': selectedId};
  }

  /// Make authenticated HTTP request with retry logic
  Future<http.Response> makeAuthenticatedRequest(
      String url, {
        Map<String, dynamic>? body,
      }) async {
    final session = await getCurrentSession();
    if (session == null) {
      throw Exception('No active Odoo session');
    }

    final headers = {
      'Cookie': 'session_id=${session.sessionId}',
      'Content-Type': 'application/json',
      'Accept':
      'application/pdf,application/octet-stream,application/json;q=0.9,*/*;q=0.8',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': '${session.serverUrl}/web',
      'User-Agent': 'Mozilla/5.0 (Linux; Android) FlutterApp/1.0',
    };

    http.Response? lastResponse;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final uri = Uri.parse(url);
        final future = body != null
            ? http.post(uri, headers: headers, body: jsonEncode(body))
            : http.get(uri, headers: headers);
        final response = await future.timeout(const Duration(seconds: 20));

        // Check for HTML response (session expired)
        final contentType = response.headers['content-type'] ?? '';
        final isHtml =
            contentType.contains('text/html') ||
                (response.bodyBytes.isNotEmpty &&
                    String.fromCharCodes(
                      response.bodyBytes.take(64),
                    ).toLowerCase().contains('<!doctype html'));

        if (isHtml && attempt < _maxRetries) {
          debugPrint('[OdooSessionManager] HTML received, refreshing session');
          await refreshSession();
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        // Retry on server errors
        if ([502, 503, 504].contains(response.statusCode) &&
            attempt < _maxRetries) {
          lastResponse = response;
          final delay = _baseDelay * attempt;
          debugPrint(
            '[OdooSessionManager] HTTP ${response.statusCode}, retrying in ${delay.inMilliseconds}ms',
          );
          await Future.delayed(delay);
          continue;
        }

        return response;
      } catch (e) {
        if (attempt >= _maxRetries || !_isRetryableError(e)) rethrow;
        final delay = _baseDelay * attempt;
        debugPrint(
          '[OdooSessionManager] Request error: $e, retrying in ${delay.inMilliseconds}ms',
        );
        await Future.delayed(delay);
      }
    }

    if (lastResponse != null) return lastResponse;
    throw Exception('Request to $url failed after $_maxRetries attempts');
  }

  /// Get selected company ID from current session or preferences
  static Future<int?> getSelectedCompanyId() async {
    // First check if we have it in the cached session
    final session = await getCurrentSession();
    if (session?.companyId != null) {
      return session!.companyId;
    }

    // Fallback to reading from preferences directly
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('selected_company_id');
    } catch (_) {
      return null;
    }
  }

  /// Get selected allowed company IDs from current session or preferences
  static Future<List<int>> getSelectedAllowedCompanyIds() async {
    // First check if we have it in the cached session
    final session = await getCurrentSession();
    if (session != null && session.allowedCompanyIds.isNotEmpty) {
      return session.allowedCompanyIds;
    }

    // Fallback to reading from preferences directly
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('selected_allowed_company_ids') ?? [];
      return raw.map((e) => int.tryParse(e) ?? -1).where((e) => e > 0).toList();
    } catch (_) {
      return [];
    }
  }

  /// Update company selection in current session
  static Future<void> updateCompanySelection({
    required int companyId,
    required List<int> allowedCompanyIds,
  }) async {
    debugPrint('[OdooSessionManager] Updating company selection');
    debugPrint('  - Company ID: $companyId');
    debugPrint('  - Allowed Companies: $allowedCompanyIds');

    final session = await getCurrentSession();
    if (session == null) {
      debugPrint('[OdooSessionManager] No active session to update company');
      return;
    }

    // Ensure selected company is in allowed companies
    List<int> finalAllowedIds = [...allowedCompanyIds];
    if (!finalAllowedIds.contains(companyId)) {
      finalAllowedIds.add(companyId);
    }

    // Update session with new company info
    final updatedSession = session.copyWith(
      selectedCompanyId: companyId,
      allowedCompanyIds: finalAllowedIds,
    );

    _cachedSession = updatedSession;
    await updatedSession.saveToPrefs();

    _onSessionUpdated?.call(updatedSession);

    debugPrint('[OdooSessionManager] Company selection updated successfully');
  }

  /// Clear company selection from session
  static Future<void> clearCompanySelection() async {
    debugPrint('[OdooSessionManager] Clearing company selection');

    final session = await getCurrentSession();
    if (session == null) return;

    final updatedSession = session.copyWith(
      selectedCompanyId: null,
      allowedCompanyIds: [],
    );

    _cachedSession = updatedSession;
    await updatedSession.saveToPrefs();

    _onSessionUpdated?.call(updatedSession);

    debugPrint('[OdooSessionManager] Company selection cleared');
  }

  /// Call Odoo method with company context
  /// Automatically injects company_id and allowed_company_ids into the request context
  static Future<dynamic> callKwWithCompany(
      Map<String, dynamic> payload, {
        int? companyId,
        List<int>? allowedCompanyIds,
      }) async {
    final map = Map<String, dynamic>.from(payload);

    Map<String, dynamic> kwargs = {};
    final rawKwargs = map['kwargs'];
    if (rawKwargs is Map) {
      kwargs = rawKwargs.map((key, value) => MapEntry(key.toString(), value));
    }

    Map<String, dynamic> ctx = {};
    final rawCtx = kwargs['context'];
    if (rawCtx is Map) {
      ctx = rawCtx.map((key, value) => MapEntry(key.toString(), value));
    }

    // Get company info from parameters, session, or preferences (in that order)
    int? selectedCompany = companyId;
    List<int>? allowed = allowedCompanyIds;

    if (selectedCompany == null || allowed == null) {
      final session = await getCurrentSession();
      selectedCompany ??= session?.companyId ?? await getSelectedCompanyId();
      allowed ??= session?.allowedCompanyIds.isNotEmpty == true
          ? session!.allowedCompanyIds
          : await getSelectedAllowedCompanyIds();
    }

    if (selectedCompany != null) {
      ctx['company_id'] = selectedCompany;

      // Ensure selected company is in allowed companies
      List<int> finalAllowed = [...(allowed ?? [])];
      if (!finalAllowed.contains(selectedCompany)) {
        finalAllowed.add(selectedCompany);
      }

      // Deduplicate and set
      ctx['allowed_company_ids'] = <int>{...finalAllowed}.toList();

      debugPrint('[OdooSessionManager] Injecting company context:');
      debugPrint('  - company_id: $selectedCompany');
      debugPrint('  - allowed_company_ids: ${ctx['allowed_company_ids']}');
    }

    kwargs['context'] = ctx;
    map['kwargs'] = kwargs;

    return callWithSession((client) => client.callKw(map));
  }

  /// Logout and clear session
  static Future<void> logout() async {
    debugPrint('[OdooSessionManager] Logging out');

    // Clear password from secure storage
    final session = _cachedSession ?? await getCurrentSession();
    if (session?.userId != null) {
      await SecureStorageService.instance.deletePassword(
        'session_password_${session!.userId}',
      );
    }

    _client = null;
    _cachedSession = null;
    _isRefreshing = false;
    _lastAuthTime = null;

    ConnectivityService.instance.setCurrentServerUrl(null);

    final prefs = await SharedPreferences.getInstance();

    // Only remove session-related keys to preserve app settings
    const keysToRemove = [
      'sessionId',
      'userLogin',
      'database',
      'serverUrl',
      'userId',
      'expiresAt',
      'isLoggedIn',
      'selected_company_id',
      'selected_allowed_company_ids',
    ];

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    _onSessionCleared?.call();
    debugPrint('[OdooSessionManager] Logout complete');
  }

  /// Clear cached client
  static void clearClientCache() {
    debugPrint('[OdooSessionManager] Clearing client cache');
    _client = null;
    _lastAuthTime = null;
  }

  /// Get last used server URL
  static Future<String?> getLastServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastServerUrl');
  }

  /// Get last used database
  static Future<String?> getLastDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastDatabase');
  }

  /// Set last server info
  static Future<void> setLastServerInfo({
    required String serverUrl,
    required String database,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastServerUrl', serverUrl);
    await prefs.setString('lastDatabase', database);
  }


  static Future<void> saveSessionFromExistingSession(
      OdooClient client,
      OdooSession session,
      String serverUrl,
      String password
      ) async {

    log("started=================================>");
    final sessionData = AppSessionData(
      odooSession: session,
      password: password, // ❌ no password
      serverUrl: serverUrl,
      database: session.dbName,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      selectedCompanyId: session.companyId,
      isStockUser: false,
      allowedCompanyIds: session.allowedCompanies.map((s)=>s.id).toList(),
    );

    await sessionData.saveToPrefs();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastServerUrl', serverUrl);
    await prefs.setString('lastDatabase', session.dbName);

    _client = client;
    _cachedSession = sessionData;
    _lastAuthTime = DateTime.now();

    ConnectivityService.instance.setCurrentServerUrl(serverUrl);
    _onSessionUpdated?.call(sessionData);



    debugPrint('[OdooSessionManager] Session restored successfully');
  }

}