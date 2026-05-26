import 'package:flutter/material.dart';
import '../../features/login/pages/server_setup_screen.dart';
import '../../features/login/pages/credentials_screen.dart';
import '../../features/login/pages/add_account_screen.dart';
import '../../features/login/pages/app_lock_screen.dart';
import '../../features/login/pages/reset_password_screen.dart';
import '../../app/app_entry.dart';

import '../../features/profile/pages/profile_screen.dart';
import '../../features/settings/pages/settings_screen.dart';
import 'app_routes.dart';

/// Generates routes for the application.
///
/// This class handles all route generation in a centralized location,
/// making it easier to manage navigation and ensure consistency.
class RouteGenerator {
  /// Private constructor to prevent instantiation
  RouteGenerator._();

  /// Generates a route based on the provided [RouteSettings].
  ///
  /// Returns a [MaterialPageRoute] for the requested route, or an error
  /// route if the route name is not recognized.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    /// Extract arguments if any
    final args = settings.arguments;

    switch (settings.name) {

      case AppRoutes.serverSetup:
        return MaterialPageRoute(
          builder: (_) => const ServerSetupScreen(),
          settings: settings,
        );

      case AppRoutes.login:
        /// Login requires URL and database arguments
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => CredentialsScreen(
              url: args['url'] as String? ?? '',
              database: args['database'] as String? ?? '',
            ),
            settings: settings,
          );
        }
        /// Fallback if arguments are missing
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
        /// App lock requires onAuthenticationSuccess callback
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

      ///Main App Routes
      case AppRoutes.app:
        return MaterialPageRoute(
          builder: (_) => const AppEntry(),
          settings: settings,
        );


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



      /// Error Route

      default:
        /// Return error route for undefined routes
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
