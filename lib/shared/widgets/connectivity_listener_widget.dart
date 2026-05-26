import 'package:flutter/material.dart';
import '../../core/services/offline_error_handler.dart';

/// A widget that wraps the app and listens to connectivity changes globally.
/// Shows snackbar notifications when connectivity changes occur.
class ConnectivityListenerWidget extends StatefulWidget {
  final Widget child;

  const ConnectivityListenerWidget({super.key, required this.child});

  @override
  State<ConnectivityListenerWidget> createState() =>
      _ConnectivityListenerWidgetState();
}

class _ConnectivityListenerWidgetState
    extends State<ConnectivityListenerWidget> {
  @override
  void initState() {
    super.initState();
    /// Initialize the offline error handler with context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OfflineErrorHandler.instance.initialize(context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    /// Update context when dependencies change (e.g., navigation)
    OfflineErrorHandler.instance.updateContext(context);
  }

  @override
  void dispose() {
    /// Note: We don't dispose the singleton here as it's used app-wide
    /// It will be disposed when the app is closed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
