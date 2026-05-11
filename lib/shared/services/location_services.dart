import 'dart:developer';

import 'package:flutter/foundation.dart';
import '../../core/services/odoo_session_manager.dart';

class LocationService {
  /// Fetch internal locations for the current company
  /// Optionally filter by a search term found in name or complete_name
  /// If [parentLocationId] is provided (picking mode), filters to locations within that parent
  static Future<List<Map<String, dynamic>>> fetchInternalLocations({
    required int companyId,
    String? search,
    int limit = 100,
    int? parentLocationId, // For picking mode - filter to warehouse hierarchy
  }) async {
    try {
      log("parentLocationId : $parentLocationId");
      final List<dynamic> domain = [];

      if (parentLocationId != null) {
        // Picking mode: filter to locations within parent (warehouse) hierarchy
        domain.add(['id', 'child_of', parentLocationId]);
      } else {
        // Normal inventory mode: internal and transit locations
        domain.add([
          'usage',
          'in',
          ['internal', 'transit'],
        ]);
      }

      if (search != null && search.trim().isNotEmpty) {
        domain.addAll([
          '|',
          ['name', 'ilike', search.trim()],
          ['complete_name', 'ilike', search.trim()],
        ]);
      }

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.location',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name', 'complete_name', 'location_id', 'usage'],
          'limit': limit,
          'order': 'complete_name asc',
        },
        'context': {
          'company_id': companyId,
          'allowed_company_ids': [companyId],
          if (parentLocationId == null) 'inventory_mode': true,
        },
      });

      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('[LocationService] Error fetching locations: $e');
      rethrow;
    }
  }
}
