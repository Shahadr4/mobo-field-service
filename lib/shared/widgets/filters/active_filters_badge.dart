import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Active filters badge styled to match
/// lib/features/inventory/pages/inventory_products_list_screen.dart
/// Behavior:
/// - If count == 0 and hasGroupBy == false: shows "No filters applied" text
/// - If count == 0 and hasGroupBy == true: renders nothing
/// - If count > 0: renders a solid pill with icon + "<count> active"
class ActiveFiltersBadge extends StatelessWidget {
  final int count;
  final ThemeData theme;
  final bool hasGroupBy;

  const ActiveFiltersBadge({
    super.key,
    required this.count,
    required this.theme,
    this.hasGroupBy = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    if (count == 0) {
      if (hasGroupBy) {
        // Suppress the text when grouped (match inventory behavior)
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No filters applied',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white70 : Colors.black,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(icon:
          HugeIcons.strokeRoundedFilterHorizontal,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '$count active',
            style: TextStyle(
              fontSize: 12,
              // Keep exact contrast behavior from reference implementation
              color: isDark ? Colors.black : Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
