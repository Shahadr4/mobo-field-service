import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../provider/check_in_provider.dart';
import 'check_in_shimmer.dart';

class CheckInWidget extends StatefulWidget {
  const CheckInWidget({super.key});

  @override
  State<CheckInWidget> createState() => _CheckInWidgetState();
}

class _CheckInWidgetState extends State<CheckInWidget> {
  Future<void> _handleToggle(
    BuildContext context,
    CheckInProvider provider,
  ) async {
    final wasCheckedIn = provider.isCheckedIn;
    await provider.toggle();
    if (!context.mounted) return;

    if (provider.error != null) {
      CustomSnackbar.showError(context, provider.error!);
    } else if (wasCheckedIn) {
      CustomSnackbar.show(
        context: context,
        title: 'Checked Out',
        message: 'You have successfully checked out.',
        type: SnackbarType.info,
      );
    } else {
      CustomSnackbar.show(
        context: context,
        title: 'Checked In',
        message:
            'Welcome! You are now checked in at ${provider.formattedCheckInTime}.',
        type: SnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CheckInProvider>(
      builder: (context, provider, _) {
        if (provider.isInitializing || provider.isRefreshing) {
          return const CheckInShimmer();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2028) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2A2D36)
                  : const Color(0xFFEEEEEE),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _StatusIcon(
                isCheckedIn: provider.isCheckedIn,
                isDark: isDark,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatusInfo(provider: provider, isDark: isDark),
              ),
              _ActionButton(
                isCheckedIn: provider.isCheckedIn,
                isLoading: provider.isLoading,
                onTap: provider.isLoading
                    ? null
                    : () => _handleToggle(context, provider),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isCheckedIn;
  final bool isDark;

  const _StatusIcon({required this.isCheckedIn, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: (isDark
                    ? const Color(0xFF2A2D36)
                    : const Color(0xFFF4F4F4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: HugeIcon(
            icon:  HugeIcons.strokeRoundedCheckmarkCircle01,
            size: 22,
            color:(isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),

      ],
    );
  }
}

class _StatusInfo extends StatelessWidget {
  final CheckInProvider provider;
  final bool isDark;

  const _StatusInfo({required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          provider.isCheckedIn ? 'Checked In' : 'Checked Out',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 0.1,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          provider.isCheckedIn
              ? provider.formattedCheckInTime
              : 'Tap to check in',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool isCheckedIn;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.isCheckedIn,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isCheckedIn ? (isDark ? Colors.white : Colors.black87) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: isLoading
              ? (isCheckedIn ? Colors.transparent : Colors.black38)
              : (isCheckedIn ? Colors.transparent : Colors.black),
          borderRadius: BorderRadius.circular(10),
          border: isCheckedIn
              ? Border.all(
                  color: isDark ? Colors.white24 : Colors.black,
                  width: 0.5,
                )
              : null,
        ),
        child: isLoading
            ? SizedBox(
                width: 68,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isCheckedIn
                          ? (isDark ? Colors.white70 : Colors.black54)
                          : Colors.white,
                    ),
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: isCheckedIn
                        ? HugeIcons.strokeRoundedLogout01
                        : HugeIcons.strokeRoundedLogin01,
                    size: 15,
                    color: textColor,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isCheckedIn ? 'Check Out' : 'Check In',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.1,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
