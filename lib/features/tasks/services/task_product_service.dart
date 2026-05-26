import 'dart:developer';
import '../../../core/services/odoo_session_manager.dart';
import '../model/task_product_model.dart';

class TaskProductService {
  /// Fetches the FSM material lines for this task.
  /// Resolves the sale_order_id from the task first, then reads lines
  /// from that order — matching what action_fsm_view_material uses.
  Future<List<TaskProductLine>> fetchLines(int taskId) async {
    try {
      /// Step 1: get sale_order_id from the task
      final taskRes = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [['id', '=', taskId]]
        ],
        'kwargs': {
          'fields': ['sale_order_id'],
          'limit': 1,
        },
      });
      if (taskRes is! List || taskRes.isEmpty) return [];
      final raw = taskRes.first['sale_order_id'];
      int? orderId;
      if (raw is List && raw.isNotEmpty) {
        orderId = (raw[0] as num).toInt();
      }
      if (orderId == null) return [];

      /// Step 2: read lines from the sale order, excluding section/note/downpayment
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'sale.order.line',
        'method': 'search_read',
        'args': [
          [
            ['order_id', '=', orderId],
            ['product_uom_qty', '>', 0],
            ['is_downpayment', '=', false],
            ['display_type', '=', false],
          ]
        ],
        'kwargs': {
          'fields': [
            'id',
            'product_id',
            'product_uom_qty',
            'price_unit',
            'product_uom_id',
          ],
          'order': 'id asc',
        },
      });
      if (result is! List) return [];
      return result
          .whereType<Map<String, dynamic>>()
          .map(TaskProductLine.fromMap)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Searches FSM-eligible products by name for typeahead.
  /// Matches the domain used by action_fsm_view_material:
  ///   consumable products OR (service + delivery invoicing + manual service_type)
  Future<List<ProductSuggestion>> searchProducts(String query) async {
    try {
      final domain = [
        ['sale_ok', '=', true],
        ['active', '=', true],
        '|',
        ['type', '=', 'consu'],
        '&', '&',
        ['type', '=', 'service'],
        ['invoice_policy', '=', 'delivery'],
        ['service_type', '=', 'manual'],
        if (query.isNotEmpty) ['name', 'ilike', query],
      ];
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name', 'list_price', 'uom_id'],
          'limit': 20,
          'order': 'name asc',
        },
      });
      if (result is! List) return [];
      return result
          .whereType<Map<String, dynamic>>()
          .map(ProductSuggestion.fromMap)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Adds a new product line to the task's sale order.
  /// Returns the new line id or null on failure.
  Future<int?> addLine({
    required int taskId,
    required int productId,
    required double qty,
    required double priceUnit,
  }) async {
    try {
      // Read sale_order_id and project_id from the task
      final taskRes = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [['id', '=', taskId]]
        ],
        'kwargs': {

          'limit': 1,
        },
      });
      if (taskRes is! List || taskRes.isEmpty) return null;

      final rawOrder = taskRes.first['sale_order_id'];
      int? orderId = (rawOrder is List && rawOrder.isNotEmpty)
          ? (rawOrder[0] as num).toInt()
          : null;

      /// No sale order yet — create one and link it to the task
      if (orderId == null) {
        final rawPartner = taskRes.first['partner_id'];
        final int? partnerId = (rawPartner is List && rawPartner.isNotEmpty)
            ? (rawPartner[0] as num).toInt()
            : null;
        if (partnerId == null) {
          return null;
        }

        final rawProject = taskRes.first['project_id'];
        final int? projectIdForOrder = (rawProject is List && rawProject.isNotEmpty)
            ? (rawProject[0] as num).toInt()
            : null;

        final soVals = <String, dynamic>{'partner_id': partnerId};
        if (projectIdForOrder != null) soVals['project_id'] = projectIdForOrder;
        final company  = await OdooSessionManager.getSelectedCompanyId();

        final newOrderId = await OdooSessionManager.callKwWithCompany({
          'model': 'sale.order',
          'method': 'create',
          'args': [soVals],
          'kwargs': {},
        },companyId:company,allowedCompanyIds: [company!] );
        orderId = (newOrderId as num?)?.toInt();
        if (orderId == null) return null;

        /// Link the new sale order back to the task
        await OdooSessionManager.callKwWithCompany({
          'model': 'project.task',
          'method': 'write',
          'args': [
            [taskId],
            {'sale_order_id': orderId},
          ],
          'kwargs': {},
        });
      }

      final rawProject = taskRes.first['project_id'];
      final int? projectId = (rawProject is List && rawProject.isNotEmpty)
          ? (rawProject[0] as num).toInt()
          : null;

      final vals = <String, dynamic>{
        'product_id': productId,
        'product_uom_qty': qty,
        'price_unit': priceUnit,
        'task_id': taskId,
        'order_id': orderId,
        'project_id': projectId,
      }..removeWhere((_, v) => v == null);

      final newId = await OdooSessionManager.callKwWithCompany({
        'model': 'sale.order.line',
        'method': 'create',
        'args': [vals],
        'kwargs': {},
      });
      return (newId as num?)?.toInt();
    } catch (e) {
      return null;
    }
  }

  /// Updates qty and price on an existing line.
  Future<bool> updateLine({
    required int lineId,
    required double qty,
    required double priceUnit,
  }) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'sale.order.line',
        'method': 'write',
        'args': [
          [lineId],
          {
            'product_uom_qty': qty,
            'price_unit': priceUnit,
          }
        ],
        'kwargs': {},
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a product line.
  /// Sets qty to 0 first (Odoo FSM catalog pattern) then attempts unlink.
  /// On confirmed orders, setting qty=0 is sufficient — Odoo removes the line.
  Future<bool> deleteLine(int lineId) async {
    try {
      // Set qty to 0 — triggers Odoo's own cleanup of stock moves
      await OdooSessionManager.callKwWithCompany({
        'model': 'sale.order.line',
        'method': 'write',
        'args': [
          [lineId],
          {'product_uom_qty': 0},
        ],
        'kwargs': {},
      });
      /// Attempt hard delete; ignore error if Odoo already removed it or disallows it
      try {
        await OdooSessionManager.callKwWithCompany({
          'model': 'sale.order.line',
          'method': 'unlink',
          'args': [
            [lineId]
          ],
          'kwargs': {},
        });
      } catch (e) {

        /// Line may have been auto-removed by qty=0 write or order is locked — that's fine
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
