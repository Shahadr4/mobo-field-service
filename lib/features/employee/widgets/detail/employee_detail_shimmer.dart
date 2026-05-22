import 'package:flutter/material.dart';
import '../../../../shared/widgets/loaders/shimmer_skeleton.dart';

class EmployeeDetailShimmer extends StatelessWidget {
  const EmployeeDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final border = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    );

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero card shimmer ──────────────────────────────────────
          _CardShell(
            cardBg: cardBg,
            border: border,
            shadow: shadow,
            child: Column(
              children: [
                // Avatar
                SkeletonBox(
                  height: 88,
                  width: 88,
                  borderRadius: BorderRadius.circular(88 * 0.22),
                ),
                const SizedBox(height: 14),
                // Name
                const SkeletonLine(width: 160, height: 18),
                const SizedBox(height: 10),
                // Job title badge
                SkeletonBox(
                  height: 26,
                  width: 100,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Meta chips row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SkeletonLine(width: 90, height: 12),
                    const SizedBox(width: 20),
                    const SkeletonLine(width: 80, height: 12),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Contact card shimmer ───────────────────────────────────
          _CardShell(
            cardBg: cardBg,
            border: border,
            shadow: shadow,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _ContactRowShimmer(),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 66,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                _ContactRowShimmer(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Section title shimmer ──────────────────────────────────
          const SkeletonLine(width: 160, height: 16),
          const SizedBox(height: 12),

          // ── Hours row shimmer ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                  child: _CardShell(
                cardBg: cardBg,
                border: border,
                shadow: shadow,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonLine(width: 60, height: 22),
                          SizedBox(height: 6),
                          SkeletonLine(width: 80, height: 13),
                          SizedBox(height: 5),
                          SkeletonLine(width: 110, height: 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SkeletonBox(
                        height: 44,
                        width: 44,
                        borderRadius: BorderRadius.circular(12)),
                  ],
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _CardShell(
                cardBg: cardBg,
                border: border,
                shadow: shadow,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonLine(width: 60, height: 22),
                          SizedBox(height: 6),
                          SkeletonLine(width: 80, height: 13),
                          SizedBox(height: 5),
                          SkeletonLine(width: 110, height: 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SkeletonBox(
                        height: 44,
                        width: 44,
                        borderRadius: BorderRadius.circular(12)),
                  ],
                ),
              )),
            ],
          ),

          const SizedBox(height: 12),

          // ── Stats grid shimmer (matches dashboard TaskStatsShimmer) ─
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: List.generate(
              4,
              (_) => _StatCardShimmer(
                  cardBg: cardBg, border: border, shadow: shadow),
            ),
          ),

          const SizedBox(height: 16),

          // ── Donut chart card shimmer ───────────────────────────────
          _CardShell(
            cardBg: cardBg,
            border: border,
            shadow: shadow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 120, height: 15),
                const SizedBox(height: 6),
                const SkeletonLine(width: 180, height: 11),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Donut placeholder
                    SkeletonBox(
                      height: 130,
                      width: 130,
                      borderRadius: BorderRadius.circular(65),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _LegendShimmer(),
                          SizedBox(height: 14),
                          _LegendShimmer(),
                          SizedBox(height: 14),
                          _LegendShimmer(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final Widget child;
  final Color cardBg;
  final Color border;
  final BoxShadow shadow;
  final EdgeInsetsGeometry padding;

  const _CardShell({
    required this.child,
    required this.cardBg,
    required this.border,
    required this.shadow,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [shadow],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _ContactRowShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SkeletonBox(
              height: 36, width: 36, borderRadius: BorderRadius.circular(10)),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: 40, height: 10),
                SizedBox(height: 5),
                SkeletonLine(width: 160, height: 13),
              ],
            ),
          ),
          const SkeletonLine(width: 14, height: 14),
        ],
      ),
    );
  }
}

class _StatCardShimmer extends StatelessWidget {
  final Color cardBg;
  final Color border;
  final BoxShadow shadow;

  const _StatCardShimmer({
    required this.cardBg,
    required this.border,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [shadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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

class _LegendShimmer extends StatelessWidget {
  const _LegendShimmer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SkeletonBox(
            height: 10, width: 10, borderRadius: BorderRadius.circular(5)),
        const SizedBox(width: 8),
        const Expanded(child: SkeletonLine(height: 12)),
        const SizedBox(width: 8),
        const SkeletonLine(width: 24, height: 12),
      ],
    );
  }
}
