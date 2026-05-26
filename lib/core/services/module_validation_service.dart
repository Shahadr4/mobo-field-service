import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'odoo_session_manager.dart';

/// Service to validate that required Odoo modules are installed
class ModuleValidationService {
  ModuleValidationService._();
  static final ModuleValidationService instance = ModuleValidationService._();

  static const String _cacheKeyModuleStatus = 'module_validation_status';
  static const String _cacheKeyLastCheck = 'module_validation_last_check';
  static const Duration _cacheValidDuration = Duration(hours: 24);

  /// Check if required modules are installed
  /// Returns a map of module names to installation status
  Future<Map<String, bool>> validateRequiredModules({
    bool forceRefresh = false,
  }) async {
    ///Check cache first
    if (!forceRefresh) {
      final cached = await _loadCachedStatus();
      if (cached != null) {
        return cached;
      }
    }

    final results = <String, bool>{};

    try {
      final client = await OdooSessionManager.getClientEnsured();

      /// Check for Inventory module (stock)
      final inventoryInstalled = await _checkModule(client, 'hr_expense');
      results['stock'] = inventoryInstalled;



      return results;
    } catch (e) {
      /// Return empty map on error - let individual features handle it
      return {};
    }
  }

  /// Check if a specific module is installed
  Future<bool> _checkModule(dynamic client, String moduleName) async {
    try {
      /// Try to check if the module exists by querying ir.module.module
      final result = await client.callKw({
        'model': 'ir.module.module',
        'method': 'search_count',
        'args': [
          [
            ['name', '=', moduleName],
            ['state', '=', 'installed'],
          ],
        ],
        'kwargs': {},
      });

      return (result as int) > 0;
    } catch (e) {
      /// If we can't check, assume it might be installed
      /// Individual features will fail gracefully if not
      return false;
    }
  }

  /// Check if Inventory module is installed
  Future<bool> isInventoryInstalled({bool forceRefresh = false}) async {
    final status = await validateRequiredModules(forceRefresh: forceRefresh);
    return status['stock'] ?? false;
  }

  /// Check if Product module is installed
  Future<bool> isProductInstalled({bool forceRefresh = false}) async {
    final status = await validateRequiredModules(forceRefresh: forceRefresh);
    return status['product'] ?? false;
  }

  /// Get a user-friendly message about missing modules
  String getMissingModulesMessage(Map<String, bool> moduleStatus) {
    final missing = <String>[];

    if (moduleStatus['stock'] == false) {
      missing.add('Inventory (stock)');
    }
    if (moduleStatus['product'] == false) {
      missing.add('Product');
    }

    if (missing.isEmpty) {
      return '';
    }

    final modules = missing.join(', ');
    return 'The following required modules are not installed on your Odoo server: $modules.\n\n'
        'This app requires the Inventory module to function properly. '
        'Please contact your administrator to install the required modules.';
  }

  /// Load cached module status
  Future<Map<String, bool>?> _loadCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckStr = prefs.getString(_cacheKeyLastCheck);

      if (lastCheckStr != null) {
        final lastCheck = DateTime.parse(lastCheckStr);
        final now = DateTime.now();

        /// Check if cache is still valid
        if (now.difference(lastCheck) < _cacheValidDuration) {
          final statusStr = prefs.getString(_cacheKeyModuleStatus);
          if (statusStr != null) {
            /// Parse the cached status
            final parts = statusStr.split(',');
            final status = <String, bool>{};
            for (final part in parts) {
              final kv = part.split(':');
              if (kv.length == 2) {
                status[kv[0]] = kv[1] == 'true';
              }
            }
            return status;
          }
        }
      }
    } catch (e) {
    }
    return null;
  }

  /// Cache module status
  Future<void> _cacheStatus(Map<String, bool> status) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      /// Convert map to string for storage
      final statusStr = status.entries
          .map((e) => '${e.key}:${e.value}')
          .join(',');

      await prefs.setString(_cacheKeyModuleStatus, statusStr);
      await prefs.setString(
        _cacheKeyLastCheck,
        DateTime.now().toIso8601String(),
      );

    } catch (e) {
    }
  }

  /// Clear cached module status
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyModuleStatus);
      await prefs.remove(_cacheKeyLastCheck);
    } catch (e) {
    }
  }
}
