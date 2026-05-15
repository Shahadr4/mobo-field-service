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
        // "Task Overview" title
        SkeletonLine(width: 110, height: 16),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon badge
          SkeletonBox(
            height: 36,
            width: 36,
            borderRadius: BorderRadius.circular(10),
          ),
          // Count + label
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              SkeletonLine(width: 36, height: 20),
              SizedBox(height: 5),
              SkeletonLine(width: 70, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}
