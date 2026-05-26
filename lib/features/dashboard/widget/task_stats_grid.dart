import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../provider/task_stats_provider.dart';
import 'task_stats_shimmer.dart';

class TaskStatsGrid extends StatelessWidget {
  const TaskStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskStatsProvider>(
      builder: (context, provider, _) {
        if ((!provider.isInitialized && provider.isLoading) ||
            provider.isRefreshing) {
          return const TaskStatsShimmer();
        }

        final s = provider.stats;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ── Section header ──────────────────────────────────────────
            const Text(
              'Task Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            /// ── Stat cards 2×2 ─────────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _StatCard(
                  label: 'Active',
                  description: 'Currently in progress',
                  count: s.activeTasks,
                  icon: HugeIcons.strokeRoundedFolder01,
                  iconColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                  darkBgColor: const Color(0xFF1A2535),
                  darkIconColor: const Color(0xFF60A5FA),
                ),
                _StatCard(
                  label: 'Assigned',
                  description: 'Total assigned to you',
                  count: s.assignedTasks,
                  icon: HugeIcons.strokeRoundedClipboard,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  darkBgColor: const Color(0xFF251E10),
                  darkIconColor: const Color(0xFFFBBF24),
                ),
                _StatCard(
                  label: 'Completed',
                  description: 'Finished successfully',
                  count: s.completedTasks,
                  icon: HugeIcons.strokeRoundedTaskDone01,
                  iconColor: const Color(0xFF22C55E),
                  bgColor: const Color(0xFFF0FDF4),
                  darkBgColor: const Color(0xFF112318),
                  darkIconColor: const Color(0xFF4ADE80),
                ),
                _StatCard(
                  label: 'Total',
                  description: 'All company tasks',
                  count: s.totalTasks,
                  icon: HugeIcons.strokeRoundedTask01,
                  iconColor: const Color(0xFFC03355),
                  bgColor: const Color(0xFFFFF1F4),
                  darkBgColor: const Color(0xFF25111A),
                  darkIconColor: const Color(0xFFE05C7A),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// ── Performance chart card ──────────────────────────────────
            _PerformanceCard(stats: s),
          ],
        );
      },
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final dynamic stats;
  const _PerformanceCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int assigned = stats.assignedTasks as int;
    final int active = stats.activeTasks as int;
    final int completed = stats.completedTasks as int;

    final double completionRate =
        assigned > 0 ? (completed / assigned).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC03355).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    size: 18, color: Color(0xFFC03355)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Performance',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Based on assigned tasks',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// Ring + bars side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// Completion ring
              _CompletionRing(rate: completionRate, isDark: isDark),

              const SizedBox(width: 24),

              /// Bar breakdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BarRow(
                      label: 'Assigned',
                      value: assigned,
                      max: assigned > 0 ? assigned : 1,
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _BarRow(
                      label: 'Active',
                      value: active,
                      max: assigned > 0 ? assigned : 1,
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _BarRow(
                      label: 'Completed',
                      value: completed,
                      max: assigned > 0 ? assigned : 1,
                      color: const Color(0xFF22C55E),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Completion ring

class _CompletionRing extends StatelessWidget {
  final double rate;
  final bool isDark;
  const _CompletionRing({required this.rate, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: CustomPaint(
        painter: _RingPainter(rate: rate, isDark: isDark),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(rate * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Done',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double rate;
  final bool isDark;
  const _RingPainter({required this.rate, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 9.0;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = isDark
            ? const Color(0xFF2A2D36)
            : const Color(0xFFF1F3F5)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (rate <= 0) return;

    // Fill arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * rate,
      false,
      Paint()
        ..color = const Color(0xFF22C55E)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.rate != rate;
}

class _BarRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  final bool isDark;

  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (value / max).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (_, constraints) {
            return Stack(
              children: [
                // Track
                Container(
                  height: 7,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2D36)
                        : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  height: 7,
                  width: constraints.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String description;
  final int count;
  final List<List<dynamic>> icon;
  final Color iconColor;
  final Color bgColor;
  final Color darkBgColor;
  final Color darkIconColor;

  const _StatCard({
    required this.label,
    required this.description,
    required this.count,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.darkBgColor,
    required this.darkIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? darkBgColor : bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(
              icon: icon,
              size: 24,
              color: isDark ? darkIconColor : iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
