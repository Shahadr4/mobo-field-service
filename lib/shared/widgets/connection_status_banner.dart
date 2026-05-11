import 'package:flutter/material.dart';
import '../../core/services/connectivity_service.dart';

class ConnectionStatusBanner extends StatefulWidget implements PreferredSizeWidget {
  const ConnectionStatusBanner({super.key});

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();

  @override
  Size get preferredSize => const Size.fromHeight(22);
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  bool _online = true;
  bool _serverReachable = true;
  late final Stream<bool> _internetStream;
  late final Stream<bool> _serverStream;

  @override
  void initState() {
    super.initState();
    _internetStream = ConnectivityService.instance.onInternetChanged;
    _serverStream = ConnectivityService.instance.onServerChanged;
    // seed initial values asynchronously
    ConnectivityService.instance.hasInternetAccess().then((v) {
      if (mounted) setState(() => _online = v);
    });
    // server seed uses lastKnownServerReachable
    _serverReachable = ConnectivityService.instance.lastKnownServerReachable;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<bool>(
      stream: _internetStream,
      initialData: _online,
      builder: (context, internetSnap) {
        final online = internetSnap.data ?? true;
        return StreamBuilder<bool>(
          stream: _serverStream,
          initialData: _serverReachable,
          builder: (context, serverSnap) {
            final serverOk = serverSnap.data ?? true;
            // If fully OK, hide
            if (online && serverOk) return const SizedBox();
            // Choose message/state
            final bool showOffline = !online;
            final String message = showOffline
                ? "You're offline. Check your internet connection."
                : "Can't reach your Odoo server. Verify the server URL or try again later.";
            return Container(
              height: 22,
              width: double.infinity,
              alignment: Alignment.center,
              color: isDark ? const Color(0xFF3B2C2C) : const Color(0xFFFFEAEA),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFFFB3B3) : const Color(0xFFB00020),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
