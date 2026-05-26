import 'package:flutter/foundation.dart';

import 'odoo_session_manager.dart';

/// Lightweight metadata helper to probe Odoo capabilities and cache results.
class OdooMetadataService {
  static final Map<String, bool> _modelCache = {};

  /// Returns true if the given model exists in the current DB and is accessible.
  static Future<bool> hasModel(String model) async {
    if (_modelCache.containsKey(model)) return _modelCache[model] ?? false;
    try {
      final client = await OdooSessionManager.getClientEnsured();
      final res = await client.callKw({
        'model': 'ir.model',
        'method': 'search_count',
        'args': [
          [
            ['model', '=', model]
          ]
        ],
        'kwargs': const {},
      });
      final ok = (res is int ? res : 0) > 0;
      _modelCache[model] = ok;
      return ok;
    } catch (e) {
      /// If access to ir.model is restricted (AccessError), attempt a direct probe on the target model
      try {
        final res = await OdooSessionManager.callKwWithCompany({
          'model': model,
          'method': 'fields_get',
          'args': [],
          'kwargs': {
            'attributes': ['string'],
          },
        });
        final ok = res is Map<String, dynamic> && res.isNotEmpty;
        _modelCache[model] = ok;
        return ok;
      } catch (e2) {
        /// If fields_get also fails (e.g., truly missing model), mark as false
        _modelCache[model] = false;
        return false;
      }
    }
  }

  /// Clear cached metadata (e.g., on logout or DB switch)
  static void reset() {
    _modelCache.clear();
  }
}
