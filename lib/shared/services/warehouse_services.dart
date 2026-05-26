import 'package:flutter/foundation.dart';
import '../../core/services/odoo_session_manager.dart';

class WarehouseService {
  /// Returns the main stock location (lot_stock_id) for the first warehouse of the company
  /// { 'warehouse_id': int, 'warehouse_name': String, 'location_id': int, 'location_name': String }
  static Future<Map<String, dynamic>?> getDefaultWarehouseMainLocation({
    required int companyId,
  }) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse',
        'method': 'search_read',
        'args': [
          [
            ['company_id', '=', companyId],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'lot_stock_id'],
          'order': 'id asc',
          'limit': 1,
        },
        'context': {
          'company_id': companyId,
          'allowed_company_ids': [companyId],
        },
      });

      if (result is List && result.isNotEmpty) {
        final w = result.first as Map<String, dynamic>;
        final lot = w['lot_stock_id'];
        int? locId;
        String? locName;
        if (lot is List && lot.isNotEmpty) {
          locId = lot[0] as int?;
          if (lot.length > 1) locName = lot[1]?.toString();
        } else if (lot is Map && lot.containsKey('id')) {
          locId = lot['id'] as int?;
          locName = (lot['display_name'] ?? lot['name'])?.toString();
        } else if (lot is int) {
          locId = lot;
        }
        if (locId != null) {
          return {
            'warehouse_id': w['id'],
            'warehouse_name': w['name'],
            'location_id': locId,
            'location_name': locName,
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
