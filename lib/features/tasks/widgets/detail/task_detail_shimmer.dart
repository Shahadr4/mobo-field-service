import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'shimmer_bone.dart';

class TaskDetailShimmer extends StatelessWidget {
  final bool isDark;
  const TaskDetailShimmer({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base      = isDark ? const Color(0xFF252830) : const Color(0xFFE8E8EC);
    final highlight = isDark ? const Color(0xFF32353F) : const Color(0xFFF4F4F8);
    final cardBg    = isDark ? const Color(0xFF1E2028) : Colors.white;
    final shadow    = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16,
            MediaQuery.of(context).padding.bottom + 180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [shadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShimmerBone(width: 160, height: 22, base: base),
                      const Spacer(),
                      ShimmerBone(width: 60, height: 26, base: base, radius: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ShimmerBone(width: 120, height: 16, base: base),
                  const SizedBox(height: 8),
                  ShimmerBone(width: 180, height: 14, base: base),
                  const SizedBox(height: 6),
                  ShimmerBone(width: 220, height: 14, base: base),
                  const SizedBox(height: 6),
                  ShimmerBone(width: 140, height: 14, base: base),
                  const SizedBox(height: 12),
                  ShimmerBone(width: 90, height: 14, base: base),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ShimmerBone(width: 104, height: 38, base: base, radius: 30),
                const SizedBox(width: 10),
                ShimmerBone(width: 98, height: 38, base: base, radius: 30),
                const SizedBox(width: 10),
                ShimmerBone(width: 88, height: 38, base: base, radius: 30),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [shadow],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBone(width: double.infinity, height: 14, base: base),
                  const SizedBox(height: 10),
                  ShimmerBone(width: 200, height: 14, base: base),
                  const SizedBox(height: 10),
                  ShimmerBone(width: double.infinity, height: 14, base: base),
                  const SizedBox(height: 10),
                  ShimmerBone(width: 160, height: 14, base: base),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
