import 'package:flutter/material.dart';
import '../../../shared/widgets/loaders/shimmer_skeleton.dart';

class CheckInShimmer extends StatelessWidget {
  const CheckInShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon box with status dot — matches _StatusIcon
          Stack(
            clipBehavior: Clip.none,
            children: [
              SkeletonBox(
                height: 44,
                width: 44,
                borderRadius: BorderRadius.circular(12),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2D36)
                        : const Color(0xFFE0E0E0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E2028) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Status label + subtitle — matches _StatusInfo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLine(width: 96, height: 14),
                SizedBox(height: 7),
                SkeletonLine(width: 64, height: 11),
              ],
            ),
          ),
          // Action button pill — matches _ActionButton
          SkeletonBox(
            height: 38,
            width: 112,
            borderRadius: BorderRadius.circular(50),
          ),
        ],
      ),
    );
  }
}
