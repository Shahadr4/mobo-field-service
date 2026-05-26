import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../model/employee_stats_model.dart';

class EmployeeDonutChart extends StatelessWidget {
  final EmployeeStats stats;
  final bool isDark;
  final Color cardBg;
  final BoxShadow shadow;

  const EmployeeDonutChart({
    super.key,
    required this.stats,
    required this.isDark,
    required this.cardBg,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final total = stats.assignedTasks;
    final segments = [
      _Segment('Active', stats.activeTasks, const Color(0xFF3B82F6)),
      _Segment('Completed', stats.completedTasks, Colors.green),
      _Segment('Cancelled', stats.cancelledTasks, const Color(0xFFEF4444)),
    ];

    return Container(
      width: double.infinity,
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Distribution of task statuses',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          if (total == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No tasks assigned yet',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      segments: segments,
                      total: total,
                      isDark: isDark,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _LegendRow(
                                segment: s,
                                total: total,
                                isDark: isDark,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Segment {
  final String label;
  final int value;
  final Color color;
  const _Segment(this.label, this.value, this.color);
}

class _LegendRow extends StatelessWidget {
  final _Segment segment;
  final int total;
  final bool isDark;

  const _LegendRow({
    required this.segment,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (segment.value / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: segment.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            segment.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Text(
          '${segment.value}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$pct%',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_Segment> segments;
  final int total;
  final bool isDark;

  const _DonutPainter({
    required this.segments,
    required this.total,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeW = radius * 0.30;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeW / 2);

    /// Background track
    canvas.drawCircle(
      center,
      radius - strokeW / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
    );

    double startAngle = -math.pi / 2;
    const gap = 0.04;

    for (final seg in segments) {
      if (seg.value == 0) continue;
      final sweep = (seg.value / total) * 2 * math.pi - gap;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..color = seg.color,
      );
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total || old.isDark != isDark;
}
