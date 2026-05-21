import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TimesheetShimmerList extends StatelessWidget {
  final bool isDark;

  const TimesheetShimmerList({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? const Color(0xFF2A2D36) : const Color(0xFFE0E0E0);
    final highlight =
        isDark ? const Color(0xFF3A3D46) : const Color(0xFFF5F5F5);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 8,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
