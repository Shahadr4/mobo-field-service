import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../exceptions/odoo_error_mapper.dart';
import 'connectivity_service.dart';


/// Centralized error manager that analyzes errors and returns appropriate error info
class ErrorManager {
  /// Analyze an error and return structured error information
  static ErrorInfo analyzeError(Object error) {
    final errorString = error.toString();

    // Check for module/model not found errors (PRIORITY CHECK)
    if (_isModuleError(errorString)) {
      return _createModuleError(errorString);
    }

    // Check for connectivity errors
    if (error is NoInternetException) {
      return ErrorInfo(
        type: ErrorType.network,
        title: 'No Internet Connection',
        message: 'Please check your Wi-Fi or mobile data and try again.',
        icon: Icons.wifi_off_rounded,
        color: Colors.blue.shade700,
      );
    }

    if (error is ServerUnreachableException) {
      return ErrorInfo(
        type: ErrorType.network,
        title: 'Server Unreachable',
        message:
            'Cannot connect to the server. Please check your network connection and server URL.',
        icon: Icons.cloud_off_rounded,
        color: Colors.orange.shade700,
      );
    }

    // Check for authentication errors
    if (_isAuthError(errorString)) {
      return ErrorInfo(
        type: ErrorType.authentication,
        title: 'Authentication Failed',
        message:
            'Your session has expired or credentials are invalid. Please sign in again.',
        icon: CupertinoIcons.lock,
        color: Colors.red.shade700,
      );
    }

    // Check for permission/access errors
    if (_isAccessError(errorString)) {
      return ErrorInfo(
        type: ErrorType.permission,
        title: 'Access Denied',
        message:
            'You don\'t have permission to access this feature. Please contact your administrator.',
        icon: Icons.block_rounded,
        color: Colors.red.shade700,
      );
    }

    // Default to server error
    return ErrorInfo(
      type: ErrorType.server,
      title: 'Server Error',
      message: OdooErrorMapper.toUserMessage(error),
      icon: Icons.error_outline_rounded,
      color: Colors.red.shade700,
    );
  }

  static bool _isModuleError(String error) {
    final lowerError = error.toLowerCase();

    // Check for various module error patterns
    return error.contains('KeyError') ||
        lowerError.contains('data model') &&
            lowerError.contains('not available') ||
        lowerError.contains('missing module') ||
        lowerError.contains('model') && lowerError.contains('not found') ||
        lowerError.contains('model') && lowerError.contains('does not exist') ||
        // Specific stock/inventory patterns
        lowerError.contains('stock.') &&
            (lowerError.contains('not') || lowerError.contains('error')) ||
        lowerError.contains('product.') &&
            (lowerError.contains('not') || lowerError.contains('error')) ||
        // Odoo module patterns
        lowerError.contains('module') && lowerError.contains('not installed') ||
        lowerError.contains('app') && lowerError.contains('not installed') ||
        // werkzeug 404 with model reference
        lowerError.contains('404') &&
            (lowerError.contains('stock') || lowerError.contains('product')) ||
        // Required app patterns
        lowerError.contains('required app') ||
        lowerError.contains('required module');
  }

  static bool _isAuthError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('authentication') ||
        lowerError.contains('session') && lowerError.contains('invalid') ||
        lowerError.contains('uid') && lowerError.contains('context');
  }

  static bool _isAccessError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('access denied') ||
        lowerError.contains('accesserror') ||
        lowerError.contains('permission') && lowerError.contains('denied');
  }

  static ErrorInfo _createModuleError(String errorString) {
    // Extract model name if present
    String? modelName;
    String? moduleName;

    // Try to extract from KeyError pattern
    final keyErrorMatch = RegExp(
      r"KeyError: '([a-zA-Z0-9_.]+)'",
    ).firstMatch(errorString);
    if (keyErrorMatch != null) {
      modelName = keyErrorMatch.group(1);
    }

    // Try to extract from "data model" pattern
    if (modelName == null) {
      final modelMatch = RegExp(
        r'"([a-zA-Z0-9_.]+)" data model',
      ).firstMatch(errorString);
      if (modelMatch != null) {
        modelName = modelMatch.group(1);
      }
    }

    // Try to extract from error string containing model names
    if (modelName == null) {
      final stockMatch = RegExp(
        r'(stock\.[a-zA-Z0-9_.]+)',
      ).firstMatch(errorString);
      if (stockMatch != null) {
        modelName = stockMatch.group(1);
      }
    }

    if (modelName == null) {
      final productMatch = RegExp(
        r'(product\.[a-zA-Z0-9_.]+)',
      ).firstMatch(errorString);
      if (productMatch != null) {
        modelName = productMatch.group(1);
      }
    }

    // Map model to module name
    if (modelName != null) {
      moduleName = _getModuleNameFromModel(modelName);
    } else {
      // Try to infer from error message
      final lowerError = errorString.toLowerCase();
      if (lowerError.contains('stock') ||
          lowerError.contains('inventory') ||
          lowerError.contains('warehouse')) {
        moduleName = 'Inventory';
        modelName = 'stock';
      } else if (lowerError.contains('product')) {
        moduleName = 'Product';
        modelName = 'product';
      }
    }

    final displayModuleName = moduleName ?? 'Required Module';
    final displayModelName = modelName ?? 'a required data model';

    return ErrorInfo(
      type: ErrorType.moduleNotInstalled,
      title: 'Module Not Installed',
      message:
          'Missing Module: The "$displayModelName" data model is not available.\n\n'
          '📦 Required App: $displayModuleName\n'
          'This feature needs the "$displayModuleName" app to be installed on your Odoo server.\n\n'
          'Please contact your administrator to install the required app.',
      icon: Icons.extension_off_rounded,
      color: Colors.orange.shade700,
      moduleName: displayModuleName,
      modelName: modelName,
    );
  }

  static String _getModuleNameFromModel(String model) {
    final lowerModel = model.toLowerCase();

    // Inventory/Stock models
    if (lowerModel.startsWith('stock.') || lowerModel == 'stock') {
      return 'Inventory';
    }

    // Product models
    if (lowerModel.startsWith('product.') || lowerModel == 'product') {
      return 'Product';
    }

    // Manufacturing models
    if (lowerModel.startsWith('mrp.')) {
      return 'Manufacturing';
    }

    // Sales models
    if (lowerModel.startsWith('sale.')) {
      return 'Sales';
    }

    // Purchase models
    if (lowerModel.startsWith('purchase.')) {
      return 'Purchase';
    }

    // Accounting models
    if (lowerModel.startsWith('account.')) {
      return 'Accounting';
    }

    // HR models
    if (lowerModel.startsWith('hr.')) {
      return 'HR';
    }

    // Partners/Contacts
    if (lowerModel == 'res.partner') {
      return 'Contacts';
    }

    return 'Unknown Module';
  }
}

/// Structured error information
class ErrorInfo {
  final ErrorType type;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String? moduleName;
  final String? modelName;

  const ErrorInfo({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.moduleName,
    this.modelName,
  });
}

/// Error types
enum ErrorType {
  moduleNotInstalled,
  network,
  server,
  authentication,
  permission,
  noData,
  general,
}
