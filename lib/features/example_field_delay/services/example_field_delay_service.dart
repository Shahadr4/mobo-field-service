import 'package:flutter/foundation.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../model/product_model.dart';

class ExampleFieldDelayService {
  /// Fetch products from Odoo with a limit of 40
  static Future<List<Product>> fetchProducts({
    int limit = 40,
    int offset = 0,
  }) async {
    try {
      debugPrint('[ExampleFieldDelayService] Fetching $limit products...');

      final result = await OdooSessionManager.safeCallKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['is_storable', '=', true],
          ],
        ],
        'kwargs': {
          'fields': [
            // 'id',
            // 'name',
            // 'display_name',
            // 'default_code',
            // 'barcode',
            // 'list_price',
            // 'qty_available',
            // 'image_128',
            // 'sfds'
          ],
          'limit': limit,
          'offset': offset,
          'order': 'name asc',
        },
      });

      if (result is List) {
        return result
            .map((json) => Product.fromOdoo(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ExampleFieldDelayService] Error fetching products: $e');
      rethrow;
    }
  }
}
