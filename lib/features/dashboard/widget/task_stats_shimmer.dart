import 'package:flutter/material.dart';
import '../../../shared/widgets/loaders/shimmer_skeleton.dart';

class TaskStatsShimmer extends StatelessWidget {
  const TaskStatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// "Task Overview" title
        SkeletonLine(width: 110, height: 16),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: List.generate(4, (_) => _StatCardShimmer(isDark: isDark)),
        ),
      ],
    );
  }
}

class _StatCardShimmer extends StatelessWidget {
  final bool isDark;
  const _StatCardShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// Left: count + label + description lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                SkeletonLine(width: 40, height: 28),
                SizedBox(height: 8),
                SkeletonLine(width: 80, height: 12),
                SizedBox(height: 6),
                SkeletonLine(width: 110, height: 10),
                SizedBox(height: 3),
                SkeletonLine(width: 80, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 10),
          /// Right: icon badge
          SkeletonBox(
            height: 44,
            width: 44,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }
}
