import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? lottieAsset; // e.g. assets/lottie/empty_box.json
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.lottieAsset,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget illustration;
    if (lottieAsset != null && lottieAsset!.isNotEmpty) {
      illustration = Lottie.asset(
        lottieAsset!,
        width: 220,
        height: 220,
        repeat: true,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) {
          return Icon(
            icon ?? Icons.inbox_outlined,
            size: 96,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          );
        },
      );
    } else {
      illustration = Icon(
        icon ?? Icons.inbox_outlined,
        size: 96,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      );
    }

    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration,
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
