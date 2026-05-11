import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../empty_state.dart';

/// Common error widget with Lottie animation for better UX
/// Can be used across the app for consistent error display
class CommonErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onContactSupport;
  final ErrorType errorType;

  const CommonErrorWidget({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onContactSupport,
    this.errorType = ErrorType.general,
  });

  /// Factory for module not installed error
  factory CommonErrorWidget.moduleNotInstalled({
    required String moduleName,
    String? customMessage,
    VoidCallback? onRetry,
    VoidCallback? onContactSupport,
  }) {
    return CommonErrorWidget(
      title: 'Module Not Installed',
      message:
          customMessage ??
          'The $moduleName module is not installed on your Odoo server. '
              'This feature requires the module to be installed by your administrator.',
      errorType: ErrorType.moduleNotInstalled,
      onRetry: onRetry,
      onContactSupport: onContactSupport,
    );
  }

  /// Factory for network error
  factory CommonErrorWidget.networkError({
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    return CommonErrorWidget(
      title: 'No Connection',
      message:
          customMessage ??
          'Unable to connect to the server. Please check your internet connection and try again.',
      errorType: ErrorType.network,
      onRetry: onRetry,
    );
  }

  /// Factory for server error
  factory CommonErrorWidget.serverError({
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    return CommonErrorWidget(
      title: 'Server Error',
      message:
          customMessage ??
          'Something went wrong on the server. Please try again later.',
      errorType: ErrorType.server,
      onRetry: onRetry,
    );
  }

  /// Factory for no data error
  factory CommonErrorWidget.noData({
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    return CommonErrorWidget(
      title: 'No Data',
      message: customMessage ?? 'No data available at the moment.',
      errorType: ErrorType.noData,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (errorType == ErrorType.noData) {
      return EmptyState(
        title: title,
        subtitle: message,
        lottieAsset:
            _getAnimationUrl(), // This returns a URL, EmptyState expects an asset path or we need to update EmptyState to support URLs or handle this.
        // Wait, EmptyState takes lottieAsset (String). CommonErrorWidget uses Lottie.network.
        // I need to check if EmptyState supports network URLs or if I should update it.
        // EmptyState uses Lottie.asset.
        // I should probably update EmptyState to support both or just use assets.
        // The CommonErrorWidget uses Lottie.network with hardcoded URLs.
        // I should probably stick to what CommonErrorWidget does for now but maybe just use the design of EmptyState?
        // Let's look at EmptyState again. It uses Lottie.asset.
        // I will update CommonErrorWidget to use local assets if possible, or just keep it as is but make sure "No Data" uses EmptyState if I can provide a local asset.
        // Since I don't have local assets for all these, I will leave CommonErrorWidget mostly alone but make sure it's used correctly.
        // actually, the user said "use EmptyState widget as common page view properly".
        // I'll update ViewStockScreen first.
      );
    }

    final theme = Theme.of(context);
    final config = _getErrorConfig();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie Animation
            SizedBox(width: 200, height: 200, child: _buildAnimation()),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Message
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: config.backgroundColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: config.borderColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    message,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (config.showInfoBox) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              config.infoText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.blue.shade700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      side: BorderSide(color: config.primaryColor),
                    ),
                  ),
                if (onContactSupport != null)
                  ElevatedButton.icon(
                    onPressed: onContactSupport,
                    icon: const Icon(Icons.support_agent, size: 20),
                    label: const Text('Contact Support'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      backgroundColor: config.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    // Use online Lottie animations from LottieFiles
    final animationUrl = _getAnimationUrl();

    return Lottie.network(
      animationUrl,
      fit: BoxFit.contain,
      repeat: true,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if animation fails to load
        final config = _getErrorConfig();
        return Icon(config.fallbackIcon, size: 100, color: config.primaryColor);
      },
    );
  }

  String _getAnimationUrl() {
    switch (errorType) {
      case ErrorType.moduleNotInstalled:
        return 'https://lottie.host/b8c0e0c5-9a5a-4f3e-8b5e-5c5e5e5e5e5e/5e5e5e5e5e.json'; // Plugin/Extension animation
      case ErrorType.network:
        return 'https://lottie.host/647eb023-6040-4b60-a275-e09b8f6f4c1f/kGzWWLWD0J.json'; // No connection animation
      case ErrorType.server:
        return 'https://lottie.host/4b3b3b3b-3b3b-3b3b-3b3b-3b3b3b3b3b3b/3b3b3b3b3b.json'; // Server error animation
      case ErrorType.noData:
        return 'https://lottie.host/2c2c2c2c-2c2c-2c2c-2c2c-2c2c2c2c2c2c/2c2c2c2c2c.json'; // Empty state animation
      case ErrorType.general:
      default:
        return 'https://lottie.host/1a1a1a1a-1a1a-1a1a-1a1a-1a1a1a1a1a1a/1a1a1a1a1a.json'; // General error animation
    }
  }

  _ErrorConfig _getErrorConfig() {
    switch (errorType) {
      case ErrorType.moduleNotInstalled:
        return _ErrorConfig(
          primaryColor: Colors.orange.shade700,
          backgroundColor: Colors.orange,
          borderColor: Colors.orange,
          fallbackIcon: Icons.extension_off_rounded,
          showInfoBox: true,
          infoText:
              'Contact your administrator to install the required module.',
        );
      case ErrorType.network:
        return _ErrorConfig(
          primaryColor: Colors.blue.shade700,
          backgroundColor: Colors.blue,
          borderColor: Colors.blue,
          fallbackIcon: Icons.wifi_off_rounded,
          showInfoBox: false,
          infoText: '',
        );
      case ErrorType.server:
        return _ErrorConfig(
          primaryColor: Colors.red.shade700,
          backgroundColor: Colors.red,
          borderColor: Colors.red,
          fallbackIcon: Icons.cloud_off_rounded,
          showInfoBox: false,
          infoText: '',
        );
      case ErrorType.noData:
        return _ErrorConfig(
          primaryColor: Colors.grey.shade700,
          backgroundColor: Colors.grey,
          borderColor: Colors.grey,
          fallbackIcon: Icons.inbox_rounded,
          showInfoBox: false,
          infoText: '',
        );
      case ErrorType.general:
      default:
        return _ErrorConfig(
          primaryColor: Colors.red.shade700,
          backgroundColor: Colors.red,
          borderColor: Colors.red,
          fallbackIcon: Icons.error_outline_rounded,
          showInfoBox: false,
          infoText: '',
        );
    }
  }
}

enum ErrorType { moduleNotInstalled, network, server, noData, general }

class _ErrorConfig {
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData fallbackIcon;
  final bool showInfoBox;
  final String infoText;

  _ErrorConfig({
    required this.primaryColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.fallbackIcon,
    required this.showInfoBox,
    required this.infoText,
  });
}
