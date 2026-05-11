import 'package:flutter/material.dart';

enum SnackbarType { info, success, warning, error }

class CustomSnackbar {
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(context, title, message, type, duration);
  }

  static void _showSnackBar(
      BuildContext context,
      String title,
      String message,
      SnackbarType type,
      Duration duration,
      ) {
    if (!context.mounted) {
      debugPrint('CustomSnackbar: Context not mounted, skipping');
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('CustomSnackbar: No ScaffoldMessenger found');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _getColorsForType(type, isDark);

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 10,
        ),
        content: _SnackBarContent(
          title: title,
          message: message,
          isDark: isDark,
          colors: colors,
          onClose: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  static _SnackbarColors _getColorsForType(SnackbarType type, bool isDark) {
    switch (type) {
      case SnackbarType.info:
        return _SnackbarColors(
          icon: Icons.info_outline,
          iconColor: Colors.blue[300]!,
          iconBackgroundColor: Colors.blue.withValues(alpha: 0.2),
          backgroundColor:
          isDark ? const Color(0xFF2D3748) : const Color(0xFF4A5568),
        );
      case SnackbarType.success:
        return _SnackbarColors(
          icon: Icons.check_circle_outline,
          iconColor: Colors.green[300]!,
          iconBackgroundColor: Colors.green.withValues(alpha: 0.2),
          backgroundColor:
          isDark ? const Color(0xFF2D4A3D) : const Color(0xFF4A6B5A),
        );
      case SnackbarType.warning:
        return _SnackbarColors(
          icon: Icons.warning_outlined,
          iconColor: Colors.orange[300]!,
          iconBackgroundColor: Colors.orange.withValues(alpha: 0.2),
          backgroundColor:
          isDark ? const Color(0xFF4A3D2D) : const Color(0xFF6B5A4A),
        );
      case SnackbarType.error:
        return _SnackbarColors(
          icon: Icons.error_outline,
          iconColor: Colors.red[300]!,
          iconBackgroundColor: Colors.red.withValues(alpha: 0.2),
          backgroundColor:
          isDark ? const Color(0xFF4A2D2D) : const Color(0xFF6B4A4A),
        );
    }
  }

  // ===== Helper methods (UNCHANGED) =====

  static void showSuccess(BuildContext context, String message) {
    show(
      context: context,
      title: 'Success',
      message: message,
      type: SnackbarType.success,
    );
  }

  static void showError(BuildContext context, String message) {
    show(
      context: context,
      title: 'Error',
      message: message,
      type: SnackbarType.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      title: 'Info',
      message: message,
      type: SnackbarType.info,
    );
  }

  static void showWarning(BuildContext context, String message) {
    show(
      context: context,
      title: 'Warning',
      message: message,
      type: SnackbarType.warning,
      duration: const Duration(seconds: 4),
    );
  }

  static void showOffline(BuildContext context) {
    show(
      context: context,
      title: 'You are offline',
      message:
      'No internet connection. Please check your Wi-Fi or mobile data.',
      type: SnackbarType.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void showServerUnreachable(BuildContext context) {
    show(
      context: context,
      title: 'Server unreachable',
      message:
      'Cannot reach the server. Please verify the server URL and your network connection.',
      type: SnackbarType.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void showNetworkError(BuildContext context, String message) {
    show(
      context: context,
      title: 'Network Error',
      message: message,
      type: SnackbarType.error,
      duration: const Duration(seconds: 5),
    );
  }
}

/// ===== UI WIDGET =====

class _SnackBarContent extends StatelessWidget {
  final String title;
  final String message;
  final bool isDark;
  final _SnackbarColors colors;
  final VoidCallback onClose;

  const _SnackBarContent({
    required this.title,
    required this.message,
    required this.isDark,
    required this.colors,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                colors.icon,
                size: 16,
                color: colors.iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                      isDark ? Colors.grey[300] : Colors.grey[100],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: Icon(
                Icons.close,
                size: 16,
                color:
                isDark ? Colors.grey[300] : Colors.grey[100],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnackbarColors {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color backgroundColor;

  _SnackbarColors({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.backgroundColor,
  });
}
