import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';

/// Maps raw Odoo exceptions to user-friendly messages.
///
/// This is intentionally light-weight and string-based because most errors
/// surface as stringified exceptions from the HTTP layer (werkzeug NotFound,
/// KeyError on model names, etc.).
class OdooErrorMapper {
  static String toUserMessage(Object error) {
    final raw = error.toString();

    // Connectivity and reachability
    if (error is NoInternetException) {
      return 'No internet connection. Please check Wi‑Fi or mobile data and try again.';
    }
    if (error is ServerUnreachableException) {
      return 'Cannot reach the server. Please verify the server URL and your network connection.';
    }

    // Common 404 from /web/dataset with KeyError for models
    final modelKeyErr = RegExp(r"KeyError: '([a-zA-Z0-9_.]+)'");
    final match = modelKeyErr.firstMatch(raw);
    if (match != null) {
      final model = match.group(1) ?? '';
      final hint = _moduleHintForModel(model);
      final message = StringBuffer(
        'Missing Module: The "$model" data model is not available.\n\n',
      );
      if (hint != null) {
        message.write(hint);
      } else {
        message.write(
          'This feature requires a module that is not installed on your Odoo server.',
        );
      }
      message.write(
        '\n\nPlease contact your administrator to install the required app.',
      );
      return message.toString();
    }

    // Check for model not found in error message
    if (raw.contains('model') &&
        (raw.contains('not found') || raw.contains('does not exist'))) {
      return 'Required module not found. The feature you\'re trying to access requires an Odoo app that is not installed. Please contact your administrator.';
    }

    // werkzeug 404 without explicit KeyError
    if (raw.contains('werkzeug.exceptions.NotFound') ||
        raw.contains('404 Not Found')) {

      return 'Server resource not found. This may indicate:\n'
          '• Missing Odoo modules/apps\n'
          '• Insufficient permissions\n'
          '• Incorrect server configuration\n\n'
          'Please verify your access rights and installed apps.';
    }

    // Access rights / permissions
    if (raw.contains('Access Denied') || raw.contains('AccessError')) {

      return 'Access Denied. You don\'t have permission to access this feature. Please contact your administrator to grant the necessary access rights.';
    }

    // Authentication/session issues
    if (raw.contains('authentication') ||
        (raw.contains('uid') && raw.contains('context'))) {
      return 'Authentication failed or your session is invalid. Please sign in again and retry.';
    }

    // Database errors
    if (raw.contains('database') && raw.contains('not exist')) {

      return 'Database not found. Please verify your database name and server configuration.';
    }

    // Default fallback keeps it short
    return 'Unexpected server error. Please try again or contact support.';
  }

  static String? _moduleHintForModel(String model) {
    switch (model) {
      // Inventory/Stock related
      case 'stock.picking':
      case 'stock.picking.type':
        return '📦 Required App: Inventory\n'
            'This feature needs the "Inventory" app to manage stock transfers and operations.';

      case 'stock.move':
      case 'stock.move.line':
        return '📦 Required App: Inventory\n'
            'This feature needs the "Inventory" app to track stock movements.';

      case 'stock.quant':
      case 'stock.location':
      case 'stock.warehouse':
        return '📦 Required App: Inventory\n'
            'This feature needs the "Inventory" app to manage warehouses and stock quantities.';

      // Product related
      case 'product.product':
      case 'product.template':
        return '🏷️ Required App: Product (Sales/Inventory)\n'
            'This feature needs the "Product" module which comes with Sales or Inventory apps.';

      case 'product.category':
        return '🏷️ Required App: Product\n'
            'This feature needs product categorization which comes with Sales or Inventory apps.';

      // Manufacturing
      case 'mrp.production':
      case 'mrp.bom':
      case 'mrp.workcenter':
        return '🏭 Required App: Manufacturing\n'
            'This feature needs the "Manufacturing" app to manage production orders.';

      // Purchase
      case 'purchase.order':
      case 'purchase.order.line':
        return '🛒 Required App: Purchase\n'
            'This feature needs the "Purchase" app to manage supplier orders.';

      // Sales
      case 'sale.order':
      case 'sale.order.line':
        return '💰 Required App: Sales\n'
            'This feature needs the "Sales" app to manage customer orders.';

      // Accounting
      case 'account.move':
      case 'account.invoice':
        return '💳 Required App: Accounting\n'
            'This feature needs the "Accounting" app to manage invoices and journal entries.';

      // HR/Attendance
      case 'hr.employee':
      case 'hr.attendance':
        return '👥 Required App: HR/Attendance\n'
            'This feature needs the "Employees" or "Attendance" app.';

      // Partners/Contacts
      case 'res.partner':
        return '👤 Required App: Contacts\n'
            'This feature needs the "Contacts" app (usually installed by default).';

      default:
        return null;
    }
  }

}
