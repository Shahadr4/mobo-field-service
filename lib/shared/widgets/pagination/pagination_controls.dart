import 'package:flutter/material.dart';

/// Reusable pagination controls widget with prev/next buttons and page info
class PaginationControls extends StatelessWidget {
  final bool canGoToPreviousPage;
  final bool canGoToNextPage;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final String paginationText;
  final bool isDark;
  final ThemeData theme;

  const PaginationControls({
    super.key,
    required this.canGoToPreviousPage,
    required this.canGoToNextPage,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.paginationText,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final Color disabled = isDark ? Colors.white.withOpacity(0.28) : Colors.black.withOpacity(0.28);
    final Color iconActive = theme.primaryColor;
    final Color iconInactive = disabled;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Center pill displaying 1-2/2 style text
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.25)
                    : Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            paginationText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF4B5563),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Prev chevron (to the right of pill as in screenshot)
        InkWell(
          onTap: canGoToPreviousPage ? onPreviousPage : null,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.chevron_left,
              size: 20,
              color: canGoToPreviousPage ? iconActive : iconInactive,
            ),
          ),
        ),

        const SizedBox(width: 6),

        // Next chevron
        InkWell(
          onTap: canGoToNextPage ? onNextPage : null,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.chevron_right,
              size: 20,
              color: canGoToNextPage ? iconActive : iconInactive,
            ),
          ),
        ),
      ],
    );
  }
}
