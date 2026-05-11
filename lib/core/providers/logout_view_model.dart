import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../../main.dart';
import '../const/app_colors.dart';
import '../services/session_service.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../shared/widgets/loaders/loading_widget.dart';
import '../../app/app_entry.dart';
import '../routing/page_transition.dart';

class LogoutViewModel extends ChangeNotifier {
  Future<void> confirmLogout(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Confirm Logout',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
        ),
        content: Text(
          'Are you sure you want to log out? Your session will be ended.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? Colors.grey[300]
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    foregroundColor:primaryColor,
                    backgroundColor: Colors.white,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: primaryColor,
                        width: 1,
                      ),
                    ),

                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                       primaryColor ,
                    foregroundColor:
                        isDark ? Colors.white : Theme.of(context).colorScheme.onError,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: isDark ? 0 : 2,
                  ),
                  child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          SizedBox(height: 10,),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _performLogout(context);
    }
  }

  Future<void> _performLogout(BuildContext context) async {
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = isDark ? Colors.white : Theme.of(context).colorScheme.primary;
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Builder(
                      builder: (_) {
                        final reduceMotion = context.read<SettingsProvider>().reduceMotion;
                        if (reduceMotion) {
                          return Icon(Icons.hourglass_empty_rounded, color: color, size: 50);
                        }
                        return LoadingWidget(
                          size: 50,
                          color: color,
                          variant: LoadingVariant.staggeredDots,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Logging out...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we process your request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Small delay to let the dialog render smoothly
    await Future.delayed(const Duration(milliseconds: 900));

   // providerResetKey.value++;
    // Perform logout using SessionService
    await context.read<SessionService>().logout();




    // Close dialog
    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.of(dialogContext!).pop();
    }

    // Navigate to AppEntry (root decides next screen based on session state)
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        dynamicRoute(context, const AppEntry()),
        (route) => false,
      );
      CustomSnackbar.showSuccess(context, 'Logged out successfully');
    }
  }
}
