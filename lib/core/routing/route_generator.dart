import 'package:flutter/material.dart';
import '../../features/login/pages/server_setup_screen.dart';
import '../../features/login/pages/credentials_screen.dart';
import '../../features/login/pages/add_account_screen.dart';
import '../../features/login/pages/app_lock_screen.dart';
import '../../features/login/pages/reset_password_screen.dart';
import '../../app/app_entry.dart';

import '../../features/profile/pages/profile_screen.dart';
import '../../features/settings/pages/settings_screen.dart';

// import '../../shared/widgets/splash/splash_screen.dart';
import 'app_routes.dart';

/// Generates routes for the application.
///
/// This class handles all route generation in a centralized location,
/// making it easier to manage navigation and ensure consistency.
class RouteGenerator {
  // Private constructor to prevent instantiation
  RouteGenerator._();

  /// Generates a route based on the provided [RouteSettings].
  ///
  /// Returns a [MaterialPageRoute] for the requested route, or an error
  /// route if the route name is not recognized.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Extract arguments if any
    final args = settings.arguments;

    switch (settings.name) {
      // ==================== Auth & Setup Routes ====================

      // case AppRoutes.splash:
      //   return MaterialPageRoute(
      //     builder: (_) => const SplashScreen(),
      //     settings: settings,
      //   );

      case AppRoutes.serverSetup:
        return MaterialPageRoute(
          builder: (_) => const ServerSetupScreen(),
          settings: settings,
        );

      case AppRoutes.login:
        // Login requires URL and database arguments
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => CredentialsScreen(
              url: args['url'] as String? ?? '',
              database: args['database'] as String? ?? '',
            ),
            settings: settings,
          );
        }
        // Fallback if arguments are missing
        return MaterialPageRoute(
          builder: (_) => const CredentialsScreen(url: '', database: ''),
          settings: settings,
        );

      case AppRoutes.addAccount:
        return MaterialPageRoute(
          builder: (_) => const AddAccountScreen(),
          settings: settings,
        );

      case AppRoutes.appLock:
        // App lock requires onAuthenticationSuccess callback
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => AppLockScreen(
              onAuthenticationSuccess:
                  args['onAuthenticationSuccess'] as VoidCallback? ?? () {},
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => AppLockScreen(onAuthenticationSuccess: () {}),
          settings: settings,
        );

      case AppRoutes.resetPassword:
        return MaterialPageRoute(
          builder: (_) => const ResetPasswordScreen(),
          settings: settings,
        );

      // ==================== Main App Routes ====================

      case AppRoutes.app:
        return MaterialPageRoute(
          builder: (_) => const AppEntry(),
          settings: settings,
        );

      /*
      case AppRoutes.inventoryProductDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        final productId = args?['productId'];
        if (productId == null) {
          return MaterialPageRoute(
            builder: (_) => const _ErrorRoute(
              routeName: 'Missing productId for inventory product detail',
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => InventoryProductDetailScreen(
            productId: int.parse(productId.toString()),
          ),
          settings: settings,
        );

      case AppRoutes.replenishment:
        final args = settings.arguments as Map<String, dynamic>?;
        final initialSearchQuery = args?['initialSearchQuery'] as String?;
        return MaterialPageRoute(
          builder: (_) =>
              ReplenishmentListScreen(initialSearchQuery: initialSearchQuery),
          settings: settings,
        );

      case AppRoutes.transfer:
        return MaterialPageRoute(
          builder: (_) => const TransferListScreen(),
          settings: settings,
        );

      case AppRoutes.transferList:
        return MaterialPageRoute(
          builder: (_) => const TransferListScreen(),
          settings: settings,
        );

      case AppRoutes.transferDetail:
        // Transfer detail requires transfer data (InternalTransfer object)
        if (args is InternalTransfer) {
          return MaterialPageRoute(
            builder: (_) => TransferDetailScreen(transfer: args),
            settings: settings,
          );
        } else if (args is Map<String, dynamic>) {
          // Handle Map arguments (e.g., from LastOpenedProvider)
          try {
            final transfer = InternalTransfer.fromJson(args);
            return MaterialPageRoute(
              builder: (_) => TransferDetailScreen(transfer: transfer),
              settings: settings,
            );
          } catch (e) {
            debugPrint('Error parsing transfer arguments: $e');
          }
        }
        // Fallback to error route if args are invalid
        return MaterialPageRoute(
          builder: (_) =>
              _ErrorRoute(routeName: settings.name ?? 'Transfer Detail'),
          settings: settings,
        );

      case AppRoutes.transferForm:
        // Transfer form can accept optional transfer data for editing
        if (args == null || args is InternalTransfer) {
          return MaterialPageRoute(
            builder: (_) =>
                TransferFormScreen(transfer: args as InternalTransfer?),
            settings: settings,
          );
        }
        // Fallback to error route if args are invalid
        return MaterialPageRoute(
          builder: (_) =>
              _ErrorRoute(routeName: settings.name ?? 'Transfer Form'),
          settings: settings,
        );

      case AppRoutes.adjustment:
        return MaterialPageRoute(
          builder: (_) => const InventoryAdjustmentListScreen(),
          settings: settings,
        );

      case AppRoutes.moveHistory:
        return MaterialPageRoute(
          builder: (_) => const MoveHistoryScreen(),
          settings: settings,
        );

      case AppRoutes.moveHistoryDetail:
        // Move history detail requires MoveHistoryItem data
        if (args is MoveHistoryItem) {
          return MaterialPageRoute(
            builder: (_) => MoveHistoryDetailScreen(item: args),
            settings: settings,
          );
        }
        // Fallback to error route if args are invalid
        return MaterialPageRoute(
          builder: (_) =>
              _ErrorRoute(routeName: settings.name ?? 'Move History Detail'),
          settings: settings,
        );
      */

      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );

      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );

      /*
      case AppRoutes.viewStock:
        // View stock requires product ID and name
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => ViewStockScreen(
              productId: args['productId'] as int? ?? 0,
              productName: args['productName'] as String? ?? 'Unknown',
            ),
            settings: settings,
          );
        }
        // Fallback to error route if args are invalid
        return MaterialPageRoute(
          builder: (_) => _ErrorRoute(routeName: settings.name ?? 'View Stock'),
          settings: settings,
        );
      */

      // ==================== Error Route ====================

      default:
        // Return error route for undefined routes
        return MaterialPageRoute(
          builder: (_) => _ErrorRoute(routeName: settings.name ?? 'Unknown'),
          settings: settings,
        );
    }
  }
}

/// Error screen shown when navigating to an undefined route.
class _ErrorRoute extends StatelessWidget {
  final String routeName;

  const _ErrorRoute({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Route Not Found',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'The route "$routeName" is not defined.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
