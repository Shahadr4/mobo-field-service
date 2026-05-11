import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Centralized connectivity service to check device network status and real internet access.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _internetController = StreamController<bool>.broadcast();
  final StreamController<bool> _serverController = StreamController<bool>.broadcast();
  bool _lastInternetReachable = false;
  bool _lastServerReachable = true; // default optimistic until checked
  String? _currentServerUrl;

  /// Listen to real internet reachability changes (not just network type)
  Stream<bool> get onInternetChanged => _internetController.stream;

  /// Listen to current server reachability changes. Emits true when reachable, false otherwise.
  Stream<bool> get onServerChanged => _serverController.stream;

  /// Start monitoring connectivity (idempotent)
  void startMonitoring() {
    // Initial probe
    _probeInternet();
    _probeServer();
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      await _probeInternet();
      await _probeServer();
    });
  }

  Future<void> _probeInternet() async {
    final reachable = await hasInternetAccess();
    if (reachable != _lastInternetReachable) {
      _lastInternetReachable = reachable;
      _internetController.add(reachable);
    }
  }

  Future<void> _probeServer() async {
    final url = _currentServerUrl;
    if (url == null) return;
    // Only meaningful to probe server if we have internet
    if (!_lastInternetReachable) {
      // When internet is down, we implicitly consider server unreachable, but we don't spam stream unless state changes
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
      return;
    }
    try {
      await ensureServerReachable(url);
      if (_lastServerReachable != true) {
        _lastServerReachable = true;
        _serverController.add(true);
      }
    } catch (_) {
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
    }
  }

  /// Returns true if device has any network (wifi/mobile/ethernet)
  Future<bool> isNetworkAvailable() async {
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// DNS probe to confirm real internet access. Optionally specify host for enterprise networks.
  Future<bool> hasInternetAccess({String host = 'example.com'}) async {
    try {
      final result = await InternetAddress.lookup(host).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Ensures internet is reachable, else throws [NoInternetException].
  Future<void> ensureInternetOrThrow() async {
    final net = await isNetworkAvailable();
    if (!net) {
      throw NoInternetException('No network connection. Please check Wi‑Fi or mobile data.');
    }
    final online = await hasInternetAccess();
    if (!online) {
      throw NoInternetException('Connected to a network but no internet access.');
    }
  }

  /// Ensures the specified server host is reachable via DNS.
  Future<void> ensureServerReachable(String serverUrl) async {
    try {
      final uri = Uri.parse(serverUrl);
      final host = uri.host.isNotEmpty ? uri.host : serverUrl;
      final res = await InternetAddress.lookup(host).timeout(const Duration(seconds: 3));
      if (res.isEmpty) {
        throw ServerUnreachableException('Unable to reach server host: $host');
      }
    } on Exception {
      throw ServerUnreachableException('Unable to reach server. Please verify the URL and network.');
    }
  }

  /// Set current server URL to be monitored for reachability. Pass null to clear.
  void setCurrentServerUrl(String? serverUrl) {
    _currentServerUrl = serverUrl;
    // Re-probe when server changes
    _probeServer();
  }

  /// Returns last known server reachability state. If no server set, returns true.
  bool get lastKnownServerReachable => _currentServerUrl == null ? true : _lastServerReachable;
}

class NoInternetException implements Exception {
  final String message;
  NoInternetException(this.message);
  @override
  String toString() => 'NoInternetException: $message';
}

class ServerUnreachableException implements Exception {
  final String message;
  ServerUnreachableException(this.message);
  @override
  String toString() => 'ServerUnreachableException: $message';
}
