import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';

enum LoginResult {
  success,
  twoFactorRequired,
  invalidCredentials,
  networkError,
}

class LoginProvider with ChangeNotifier {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool urlCheck = false;
  bool disableFields = false;
  String? database;
  String? errorMessage;
  bool isLoading = false;
  bool isLoadingDatabases = false;
  List<String> dropdownItems = [];
  OdooClient? client;
  bool obscurePassword = true;
  List<String> _previousUrls = [];
  List<String> get previousUrls => _previousUrls;
  final Map<String, String> _serverDatabaseMap =
  {}; // Maps server URL to last used database
  bool _disposed = false;
  String _selectedProtocol = 'https://';
  String get selectedProtocol => _selectedProtocol;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final TextEditingController urlController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginProvider() {
    _loadSavedCredentials();
  }

  // Try to find a saved database for the current URL, handling protocol differences
  String? _resolveSavedDatabaseForUrl(String fullUrl) {
    // Exact match first
    if (_serverDatabaseMap.containsKey(fullUrl)) {
      return _serverDatabaseMap[fullUrl];
    }

    // Try alternate protocol (http <-> https)
    String alt;
    if (fullUrl.startsWith('https://')) {
      alt = 'http://${fullUrl.substring(8)}';
    } else if (fullUrl.startsWith('http://')) {
      alt = 'https://${fullUrl.substring(7)}';
    } else {
      // If somehow no protocol, check both
      alt = 'https://$fullUrl';
      if (_serverDatabaseMap.containsKey(alt)) return _serverDatabaseMap[alt];
      alt = 'http://$fullUrl';
      if (_serverDatabaseMap.containsKey(alt)) return _serverDatabaseMap[alt];
      return null;
    }
    if (_serverDatabaseMap.containsKey(alt)) {
      return _serverDatabaseMap[alt];
    }

    // Normalize trailing slash differences
    String stripSlash(String u) => u.endsWith('/') ? u.substring(0, u.length - 1) : u;
    final noSlash = stripSlash(fullUrl);
    if (_serverDatabaseMap.containsKey(noSlash)) {
      return _serverDatabaseMap[noSlash];
    }
    final altNoSlash = stripSlash(alt);
    if (_serverDatabaseMap.containsKey(altNoSlash)) {
      return _serverDatabaseMap[altNoSlash];
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    urlController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void setProtocol(String protocol) {
    _selectedProtocol = protocol;
    notifyListeners();
  }

  /// Persist a full server URL (including protocol) into history immediately
  Future<void> seedUrlToHistory(String fullUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (fullUrl.isEmpty) return;
      List<String> urls = prefs.getStringList('previous_server_urls') ?? [];
      // Normalize trailing slash
      String u = fullUrl.endsWith('/') ? fullUrl.substring(0, fullUrl.length - 1) : fullUrl;
      // Move to front if already exists
      urls.removeWhere((e) => e == u);
      urls.insert(0, u);
      if (urls.length > 10) {
        urls = urls.take(10).toList();
      }
      await prefs.setStringList('previous_server_urls', urls);
      _previousUrls = urls;
      debugPrint('[LoginProvider] Seeded URL to history explicitly: $u');
      _safeNotifyListeners();
    } catch (_) {}
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1) Start with any explicitly saved history from previous logins
      final historyUrls = prefs.getStringList('previous_server_urls') ?? [];

      // We'll maintain insertion order and uniqueness
      final Set<String> orderedUnique = <String>{};

      // Helper to add if non-empty and normalized
      String _normalize(String url) {
        String u = url.trim();
        if (u.isEmpty) return u;
        // Ensure protocol prefix for consistency in display/saving
        if (!u.startsWith('http://') && !u.startsWith('https://')) {
          u = '$_selectedProtocol$u';
        }
        if (u.endsWith('/')) u = u.substring(0, u.length - 1);
        return u;
      }

      void addUrl(String? url) {
        if (url == null) return;
        final normalized = _normalize(url);
        if (normalized.isEmpty) return;
        orderedUnique.add(normalized);
      }

      // 2) Last used server info (persists across logout) - prefer to show first
      try {
        final lastFromPrefs = prefs.getString('lastServerUrl');
        // If missing in prefs directly, also try through manager API
        if (lastFromPrefs != null && lastFromPrefs.isNotEmpty) {
          addUrl(lastFromPrefs);
        } else {
          final lastViaMgr = await OdooSessionManager.getLastServerUrl();
          addUrl(lastViaMgr);
        }
      } catch (_) {}

      // 3) Add current session server (if any)
      try {
        final current = await OdooSessionManager.getCurrentSession();
        addUrl(current?.serverUrl);
      } catch (_) {}

      // 4) Add any stored account URLs from SessionService (initialized in AppEntry)
      try {
        final accounts = SessionService.instance.storedAccounts;
        for (final acc in accounts) {
          // Try multiple possible keys to be robust
          addUrl(acc['url']?.toString());
          addUrl(acc['serverUrl']?.toString());
        }
      } catch (_) {}

      // 5) Finally, append historyUrls (keeps their order, deduped by set)
      for (final u in historyUrls) {
        addUrl(u);
      }

      _previousUrls = orderedUnique.toList();

      // Load server-database mappings
      // 4.a) Preferred: consolidated JSON map
      try {
        final rawMap = prefs.getString('server_db_map');
        if (rawMap != null && rawMap.isNotEmpty) {
          final Map<String, dynamic> decoded = Map<String, dynamic>.from(
            jsonDecode(rawMap),
          );
          decoded.forEach((k, v) {
            if (v is String && v.isNotEmpty) {
              _serverDatabaseMap[k] = v;
            }
          });
        }
      } catch (_) {}

      // 4.b) Backward-compat: scan individual keys if any
      try {
        final mappingKeys = prefs.getKeys().where(
              (key) => key.startsWith('server_db_'),
        );
        for (final key in mappingKeys) {
          final serverUrl = key.substring(10); // Remove 'server_db_' prefix
          final dbName = prefs.getString(key);
          if (dbName != null) {
            _serverDatabaseMap[serverUrl] = dbName;
          }
        }
      } catch (_) {}

      // Also seed mapping from lastServerUrl/lastDatabase if present
      final lastServer = prefs.getString('lastServerUrl');
      final lastDb = prefs.getString('lastDatabase');
      if ((lastServer != null && lastServer.isNotEmpty) &&
          (lastDb != null && lastDb.isNotEmpty)) {
        _serverDatabaseMap[lastServer] = lastDb;
      }

      debugPrint('[LoginProvider] Loaded ${_previousUrls.length} previous URLs: $_previousUrls');
      debugPrint(
        '[LoginProvider] Loaded ${_serverDatabaseMap.length} server-database mappings',
      );
      if (_previousUrls.isNotEmpty && urlController.text.isEmpty) {
        final fullUrl = _previousUrls.first;

        _selectedProtocol = extractProtocol(fullUrl);
        urlController.text = extractDomain(fullUrl);

        debugPrint(
          '[LoginProvider] Auto-filled URL controller with previous URL: $fullUrl',
        );

        Future.microtask(() {
          if (isValidUrl(urlController.text)) {
            fetchDatabaseList();
          }
        });
      }

      _isInitialized = true;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('[LoginProvider] Error loading saved credentials: $e');
      _isInitialized = true;
      _safeNotifyListeners();
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fullUrl = getFullUrl();

      // Save server URL to history
      List<String> urls = prefs.getStringList('previous_server_urls') ?? [];
      if (fullUrl.isNotEmpty && !urls.contains(fullUrl)) {
        urls.insert(0, fullUrl);
        if (urls.length > 10) {
          urls = urls.take(10).toList();
        }
        await prefs.setStringList('previous_server_urls', urls);
        _previousUrls = urls;
        debugPrint('[LoginProvider] Saved URL to history: $fullUrl');
      }

      // Save server-database mapping
      if (fullUrl.isNotEmpty && database != null && database!.isNotEmpty) {
        // Backward-compat per-key storage
        await prefs.setString('server_db_$fullUrl', database!);
        _serverDatabaseMap[fullUrl] = database!;

        // Consolidated JSON map for reliable retrieval
        try {
          final existing = prefs.getString('server_db_map');
          final Map<String, dynamic> map = existing != null && existing.isNotEmpty
              ? Map<String, dynamic>.from(jsonDecode(existing))
              : <String, dynamic>{};
          map[fullUrl] = database!;
          await prefs.setString('server_db_map', jsonEncode(map));
        } catch (_) {}
        debugPrint(
          '[LoginProvider] Saved database mapping: $fullUrl -> $database',
        );
      }
    } catch (e) {
      debugPrint('[LoginProvider] Error saving credentials: $e');
    }
  }

  String _normalizeUrl(String url) {
    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = '$_selectedProtocol$normalizedUrl';
    }
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    return normalizedUrl;
  }

  String getFullUrl() {
    final url = urlController.text.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '$_selectedProtocol$url';
  }

  String extractProtocol(String fullUrl) {
    if (fullUrl.startsWith('https://')) return 'https://';
    if (fullUrl.startsWith('http://')) return 'http://';
    return _selectedProtocol;
  }

  String extractDomain(String fullUrl) {
    if (fullUrl.startsWith('https://')) return fullUrl.substring(8);
    if (fullUrl.startsWith('http://')) return fullUrl.substring(7);
    return fullUrl;
  }

  void setUrlFromFullUrl(String fullUrl) {
    final protocol = extractProtocol(fullUrl);
    final domain = extractDomain(fullUrl);
    _selectedProtocol = protocol;
    urlController.text = domain;

    debugPrint('[LoginProvider] Set URL from full URL: $fullUrl');
    debugPrint('[LoginProvider] Protocol: $protocol, Domain: $domain');
  }

  void clearForm() {
    urlController.clear();
    emailController.clear();
    passwordController.clear();
    database = null;
    dropdownItems.clear();
    urlCheck = false;
    errorMessage = null;
    isLoading = false;
    isLoadingDatabases = false;
    disableFields = false;
    notifyListeners();
  }

  Future<void> fetchDatabaseList() async {
    if (urlController.text.trim().isEmpty) {
      _resetDatabaseState();
      errorMessage = 'Please enter a server URL first.';
      _safeNotifyListeners();
      return;
    }

    if (!isValidUrl(urlController.text.trim())) {
      _resetDatabaseState();
      errorMessage = 'Please enter a valid server URL.';
      _safeNotifyListeners();
      return;
    }

    // Preserve the current selection while reloading
    final String? previousSelection = database;

    isLoadingDatabases = true;
    urlCheck = false;
    errorMessage = null;
    // Do not nullify the current database here; keep it until new list arrives
    dropdownItems.clear();
    _safeNotifyListeners();

    try {
      final baseUrl = _normalizeUrl(urlController.text);



      final HttpClient httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12)
        ..idleTimeout = const Duration(seconds: 10)
        ..maxConnectionsPerHost = 5
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      final request = await httpClient.postUrl(
        Uri.parse('$baseUrl/web/database/list'),
      );

      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': {}, 'id': 1}));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      httpClient.close();
      final jsonResponse = jsonDecode(responseBody);

      // Odoo returns a JSON-RPC error object when DB listing is disabled
      if (jsonResponse['error'] != null) {
        final serverError = jsonResponse['error']?['data']?['message']
            ?? jsonResponse['error']?['message']
            ?? jsonResponse['error'].toString();
        errorMessage = 'The listing database is currently disabled. $serverError';
        _resetDatabaseState();
        return;
      }

      final result = jsonResponse['result'];
      if (result == null) {
        final serverError = jsonResponse['error']?['data']?['message']
            ?? jsonResponse['error']?['message']
            ?? '';
        errorMessage = serverError.isNotEmpty
            ? 'The listing database is currently disabled. $serverError'
            : 'The listing database is currently disabled.';
        _resetDatabaseState();
        return;
      }

      final resu = (result as List).map((db) => db.toString()).toList();

      final dbList = resu as List<dynamic>;
      if (dbList.isEmpty) {
        errorMessage = 'No databases found on this server.';
        urlCheck = false;
      } else {
        final uniqueDbList = dbList.toSet().toList();
        uniqueDbList.sort((a, b) => a.toString().compareTo(b.toString()));
        dropdownItems = uniqueDbList.map((e) => e.toString()).toList();
        urlCheck = true;

        // Persist the validated URL to history immediately so suggestions work before the first login
        try {
          final prefs = await SharedPreferences.getInstance();
          final fullUrl = getFullUrl();
          if (fullUrl.isNotEmpty) {
            List<String> urls = prefs.getStringList('previous_server_urls') ?? [];
            if (!urls.contains(fullUrl)) {
              urls.insert(0, fullUrl);
              if (urls.length > 10) {
                urls = urls.take(10).toList();
              }
              await prefs.setStringList('previous_server_urls', urls);
              _previousUrls = urls;
              debugPrint('[LoginProvider] Seeded URL to history from DB fetch: $fullUrl');
            }
          }
        } catch (_) {}

        // Smart database selection logic:
        // 1. Check if there's a saved database for this server URL
        final fullUrl = getFullUrl();
        final savedDatabase = _resolveSavedDatabaseForUrl(fullUrl);

        if (savedDatabase != null && dropdownItems.contains(savedDatabase)) {
          // Auto-select the previously used database for this server
          database = savedDatabase;
          debugPrint(
            '[LoginProvider] Auto-selected saved database: $savedDatabase for server: $fullUrl',
          );
        } else if (previousSelection != null &&
            dropdownItems.contains(previousSelection)) {
          // Restore previous selection if still available
          database = previousSelection;
          debugPrint(
            '[LoginProvider] Restored previous selection: $previousSelection',
          );
        } else {
          // 2. Fallback: check lastServerUrl/lastDatabase from prefs via manager
          try {
            final lastUrl = await OdooSessionManager.getLastServerUrl();
            final lastDb = await OdooSessionManager.getLastDatabase();

            String normalize(String u) {
              String x = u.trim();
              if (x.endsWith('/')) x = x.substring(0, x.length - 1);
              return x;
            }

            bool urlsMatch(String? a, String? b) {
              if (a == null || b == null) return false;
              final A = normalize(a);
              final B = normalize(b);
              // Compare ignoring protocol
              String stripProto(String s) => s
                  .replaceFirst(RegExp('^https?://'), '');
              return stripProto(A) == stripProto(B);
            }

            if (lastUrl != null && lastDb != null &&
                dropdownItems.contains(lastDb) &&
                urlsMatch(lastUrl, fullUrl)) {
              database = lastDb;
              debugPrint('[LoginProvider] Auto-selected lastDatabase "$lastDb" for server: $fullUrl');
            }
          } catch (_) {}

          // 3. As a final fallback, default to first database
          if (database == null && uniqueDbList.isNotEmpty) {
            database = uniqueDbList.first.toString();
            debugPrint('[LoginProvider] Selected first database: $database');
          }
        }
      }
    } on HandshakeException catch (e) {
      debugPrint('[LoginProvider] HandshakeException: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('tls') || msg.contains('ssl') || msg.contains('handshake')) {
        errorMessage =
            'SSL/TLS handshake failed. The server may not support HTTPS. '
            'Try switching to HTTP instead of HTTPS.';
      } else {
        errorMessage =
            'Secure connection failed. Try using HTTP instead of HTTPS, '
            'or contact your administrator.';
      }
      _resetDatabaseState();
    } on SocketException catch (e) {
      debugPrint('[LoginProvider] SocketException: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('network is unreachable') || msg.contains('no route to host')) {
        errorMessage =
            'No internet connection. Please check your network settings and try again.';
      } else if (msg.contains('connection refused')) {
        errorMessage =
            'Connection refused. Please verify the server URL and port are correct, '
            'and that the server is running.';
      } else if (msg.contains('connection timed out') || msg.contains('timed out')) {
        errorMessage =
            'Connection timed out. The server may be slow or unreachable. Please try again.';
      } else if (msg.contains('host lookup failed') || msg.contains('failed host lookup')) {
        errorMessage =
            'Server not found. Please check the server URL for typos and verify your DNS settings.';
      } else if (msg.contains('ssl') || msg.contains('certificate') || msg.contains('tls')) {
        errorMessage =
            'SSL certificate error. Try switching from HTTPS to HTTP, '
            'or contact your administrator about the server certificate.';
      } else {
        errorMessage =
            'Network error: ${e.message}. Please check your internet connection and server URL.';
      }
      _resetDatabaseState();
    } on TimeoutException catch (_) {
      debugPrint('[LoginProvider] TimeoutException fetching databases');
      errorMessage =
          'Connection timed out. The server may be slow or unreachable. '
          'Try switching between HTTP and HTTPS, then try again.';
      _resetDatabaseState();
    } on TlsException catch (e) {
      debugPrint('[LoginProvider] TlsException: $e');
      errorMessage =
          'TLS/SSL error. The server certificate may be invalid or the server '
          'does not support HTTPS. Try switching to HTTP.';
      _resetDatabaseState();
    } on OdooException catch (e) {
      debugPrint('[LoginProvider] OdooException: $e');
      errorMessage = _formatOdooError(e);
      _resetDatabaseState();
    } on FormatException catch (e) {
      debugPrint('[LoginProvider] FormatException: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('html') || msg.contains('<!doctype') || msg.contains('<html')) {
        errorMessage =
            'Invalid server response. This may not be an Odoo server, '
            'Check if HTTPS should be HTTP.';
      } else {
        errorMessage =
            'Server returned an unexpected data format. '
            'Please verify this is a valid Odoo server URL.';
      }
      _resetDatabaseState();
    } on HttpException catch (e) {
      debugPrint('[LoginProvider] HttpException: $e');
      final msg = e.message.toLowerCase();
      if (msg.contains('301') || msg.contains('302') || msg.contains('redirect')) {
        errorMessage =
            'Server redirected the request. Try switching between HTTP and HTTPS.';
      } else {
        errorMessage =
            'HTTP error: ${e.message}. Please verify the server URL is correct.';
      }
      _resetDatabaseState();
    } catch (e) {
      debugPrint('[LoginProvider] Unexpected error fetching databases: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('ssl') || msg.contains('certificate') || msg.contains('tls') || msg.contains('handshake')) {
        errorMessage =
            'SSL/Certificate error. Try switching from HTTPS to HTTP '
            'or contact your administrator.';
      } else if (msg.contains('http') && msg.contains('https')) {
        errorMessage =
            'Protocol mismatch. Try switching between HTTP and HTTPS.';
      } else if (msg.contains('refused') || msg.contains('unreachable')) {
        errorMessage =
            'Cannot reach the server. Please check the URL and your internet connection.';
      } else {
        errorMessage =
            'Unexpected error: ${e.toString()}. '
            'Please verify your server URL and try again.';
      }
      _resetDatabaseState();
    } finally {
      isLoadingDatabases = false;
      _safeNotifyListeners();
    }
  }

  void _resetDatabaseState() {
    database = null;
    urlCheck = false;
    dropdownItems.clear();
  }

  String _formatOdooError(OdooException e) {
    final message = e.message.toLowerCase();
    if (message.contains('404') || message.contains('not found')) {
      return 'Server not found. Please verify your server URL is correct and the server is running.';
    } else if (message.contains('403') || message.contains('forbidden')) {
      return 'Access denied. The server may not allow database listing or requires authentication.';
    } else if (message.contains('500') ||
        message.contains('internal server error')) {
      return 'Server error occurred. Please contact your system administrator or try again later.';
    } else if (message.contains('timeout') || message.contains('timed out')) {
      return 'Connection timed out. Please check your internet connection and try again.';
    } else if (message.contains('ssl') || message.contains('certificate')) {
      return 'SSL certificate error. Try using HTTP instead of HTTPS, or contact your administrator.';
    } else if (message.contains('connection refused') ||
        message.contains('refused')) {
      return 'Connection refused. Please verify the server URL and port number are correct.';
    } else {
      return 'Unable to connect to server. Please check your server URL and internet connection.';
    }
  }

  void setDatabase(String? value) {
    database = value;
    notifyListeners();
  }

  Future<LoginResult> login(BuildContext context) async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return LoginResult.invalidCredentials;
    }
    if (database == null || database!.isEmpty) {
      errorMessage = 'Please select a database first.';
      _safeNotifyListeners();
      return LoginResult.invalidCredentials;
    }

    isLoading = true;
    errorMessage = null;
    disableFields = true;
    _safeNotifyListeners();

    try {
      final serverUrl = _normalizeUrl(urlController.text);
      final userLogin = emailController.text.trim();
      final password = passwordController.text.trim();

      if (serverUrl.isEmpty || userLogin.isEmpty || password.isEmpty) {
        throw Exception('Please fill in all required fields.');
      }

      final loginSuccess = await OdooSessionManager.loginAndSaveSession(
        serverUrl: serverUrl,
        database: database!,
        userLogin: userLogin,
        password: password,
      );



      if (loginSuccess == LoginStatus.success) {
        await _saveCredentials();
        await _setAuthenticationTimestamp();

        // Store account in SessionService for account switching
        try {
          final sessionService = SessionService.instance;
          final currentSession = await OdooSessionManager.getCurrentSession();

          if (currentSession != null) {
            //await sessionService.storeAccount(currentSession, password);
            debugPrint('[LoginProvider] Stored account in SessionService');
          }
        } catch (e) {
          debugPrint(
            '[LoginProvider] Error storing account in SessionService: $e',
          );
        }

        return  LoginResult.success;
      } else {
        if (loginSuccess == LoginStatus.twoFactorEnabled) {
          return LoginResult.twoFactorRequired;
        }

        errorMessage = 'Login failed. Please check your credentials.';
        return  LoginResult.invalidCredentials;
      }
    } on SocketException catch (e) {
      debugPrint('[LoginProvider] SocketException during login: $e');
      if (e.toString().contains('Network is unreachable')) {
        errorMessage =
        'No internet connection. Please check your network settings.';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage =
        'Server is not responding. Please verify the server URL is correct.';
      } else {
        errorMessage =
        'Network error occurred. Please check your internet connection and server URL.';
      }
      return  LoginResult.networkError;
    } on TimeoutException catch (e) {
      debugPrint('[LoginProvider] TimeoutException during login: $e');
      errorMessage =
      'Connection timed out. The server may be slow or unreachable. Please try again.';
      return  LoginResult.networkError;
    } on OdooException catch (e) {
      debugPrint('[LoginProvider] OdooException during login: $e');
      final message = e.message.toLowerCase();
      if (message.contains('invalid login') ||
          message.contains('access denied')) {
        errorMessage =
        'Incorrect email or password. Please check your login credentials.';
      } else if (message.contains('database')) {
        errorMessage =
        'Database access failed. Please verify the selected database is correct.';
      } else {
        errorMessage = _formatOdooError(e);
      }
      return  LoginResult.invalidCredentials;
    } catch (e) {
      debugPrint('[LoginProvider] Unexpected error during login: $e');
      errorMessage =
      'Login failed. Please check your credentials and server settings.';
      return  LoginResult.invalidCredentials;
    } finally {
      isLoading = false;
      disableFields = false;
      _safeNotifyListeners();
    }
  }

  Future<void> _setAuthenticationTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('lastSuccessfulAuth', currentTime);
    } catch (_) {}
  }

  bool isValidUrl(String url) {
    try {
      String urlToValidate = url.trim();
      if (!urlToValidate.startsWith('http://') &&
          !urlToValidate.startsWith('https://')) {
        urlToValidate = '$_selectedProtocol$urlToValidate';
      }
      final uri = Uri.parse(urlToValidate);
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  bool get isFormReady {
    return urlController.text.trim().isNotEmpty &&
        emailController.text.trim().isNotEmpty &&
        passwordController.text.trim().isNotEmpty &&
        database != null &&
        database!.isNotEmpty &&
        !isLoading &&
        !isLoadingDatabases;
  }


  Future<void> onLoginSuccessFromSession(
      Map<String, dynamic> sessionInfo,
      { required String login,
        required String password2,
        required String serverUrls,
        required String databses,
        required String sessionId
      }


      ) async {
    try {
      log('[LoginProvider] Login success via existing session');
      log(serverUrls);
      log(login);
      log(databses);
      log(password2);
      log("+++++++++++++++++++++++++++++++++++++++++++>>>>>>");
      final Map<String, dynamic> userCompanies =
      sessionInfo['user_companies'] as Map<String, dynamic>;

      final List<Company> allowedCompanies =
      (userCompanies['allowed_companies'] as Map<String, dynamic>)
          .values
          .map<Company>((e) => Company(
        id: e['id'] as int,
        name: e['name'] as String,
      ))
          .toList();

      final odooSession = OdooSession(
        id:sessionId ,
        userId: sessionInfo['uid'],
        partnerId: sessionInfo['partner_id'],
        userLogin: sessionInfo['username'],
        dbName: sessionInfo['db'],
        companyId:
        sessionInfo['user_companies']['current_company'],
        userLang: sessionInfo['user_context']['lang'],
        userTz: sessionInfo['user_context']['tz'],
        isSystem: sessionInfo['is_system'] ?? false,
        allowedCompanies:allowedCompanies,
        userName: sessionInfo['username'],
        serverVersion: sessionInfo['server_version'],
      );
      log("===========");

      log(odooSession.toString());

      // Persist last used server + database
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'lastServerUrl',
        sessionInfo['server_url'] ?? '',
      );
      await prefs.setString(
        'lastDatabase',
        sessionInfo['db'] ?? '',
      );

      // Mark logged in
      await prefs.setBool('isLoggedIn', true);

      final  clientnew = OdooClient(serverUrls,sessionId: odooSession);



      log(serverUrls);
      log(login);
      log(databses);
      log(password2);
      log("++++++++++++++++++");


      client = clientnew;

      await OdooSessionManager.saveSessionFromExistingSession(
        client!,
        client!.sessionId!,
        serverUrls,
        password2,
      );


      log("+++++++++gooog +++++++");

      notifyListeners();
    } catch (e) {
      log('[LoginProvider] Failed to restore session: $e');
      rethrow;
    }
  }


}