/// Centralized route constants for the application.
///
/// This class contains all route paths used throughout the app.
/// Using constants prevents typos and makes refactoring easier.
///
/// Example usage:
/// ```dart
/// Navigator.pushNamed(context, AppRoutes.home);
/// Navigator.pushNamed(context, AppRoutes.login, arguments: {'url': url, 'database': db});
/// ```
class AppRoutes {
  // Private constructor to prevent instantiation
  AppRoutes._();

  // ==================== Auth & Setup Routes ====================

  /// Splash screen - shown on app launch
  static const String splash = '/';

  /// Server setup screen - configure Odoo server connection
  static const String serverSetup = '/server_setup';

  /// Login/credentials screen - enter username and password
  /// Requires arguments: {'url': String, 'database': String}
  static const String login = '/login';

  /// Add account screen - add additional Odoo account
  static const String addAccount = '/add_account';

  /// App lock screen - biometric/PIN authentication
  static const String appLock = '/app_lock';

  /// Reset password screen
  static const String resetPassword = '/reset_password';

  // ==================== Main App Routes ====================

  /// App entry point - handles authentication check and routing
  static const String app = '/app';

  /// Home scaffold - main app container with bottom navigation
  static const String home = '/home';

  // ==================== Feature Routes ====================

  /// Dashboard screen
  static const String dashboard = '/dashboard';

  /// Inventory products list screen
  static const String inventory = '/inventory';

  /// Inventory product detail screen
  /// Requires arguments: {'productId': int}
  static const String inventoryProductDetail = '/inventory_product_detail';

  /// Transfer home screen
  static const String transfer = '/transfer';

  /// Transfer list screen
  static const String transferList = '/transfer_list';

  /// Transfer detail screen
  /// Requires arguments: transfer data
  static const String transferDetail = '/transfer_detail';

  /// Transfer form screen (create/edit)
  static const String transferForm = '/transfer_form';

  /// Inventory adjustment list screen
  static const String adjustment = '/adjustment';

  /// Move history screen
  static const String moveHistory = '/move_history';

  /// Move history detail screen
  /// Requires arguments: move data
  static const String moveHistoryDetail = '/move_history_detail';

  /// Profile screen
  static const String profile = '/profile';

  /// Settings screen
  static const String settings = '/settings';

  /// View stock screen
  /// Requires arguments: product data
  static const String viewStock = '/view_stock';

  /// Replenishment screen
  /// Optional arguments: {'initialSearchQuery': String}
  static const String replenishment = '/replenishment';
}
