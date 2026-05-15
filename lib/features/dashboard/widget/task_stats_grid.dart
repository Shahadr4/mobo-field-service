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
        // Show shimmer on first load and on pull-to-refresh
        if ((!provider.isInitialized && provider.isLoading) ||
            provider.isRefreshing) {
          return const TaskStatsShimmer();
        }

        final s = provider.stats;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Task Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _StatCard(
                  label: 'Active Tasks',
                  count: s.activeTasks,
                  icon: HugeIcons.strokeRoundedTaskDaily01,
                  iconColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                  darkBgColor: const Color(0xFF1A2535),
                  darkIconColor: const Color(0xFF60A5FA),
                ),
                _StatCard(
                  label: 'Assigned Tasks',
                  count: s.assignedTasks,
                  icon: HugeIcons.strokeRoundedTaskAdd01,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  darkBgColor: const Color(0xFF251E10),
                  darkIconColor: const Color(0xFFFBBF24),
                ),
                _StatCard(
                  label: 'Completed',
                  count: s.completedTasks,
                  icon: HugeIcons.strokeRoundedTaskDone01,
                  iconColor: const Color(0xFF22C55E),
                  bgColor: const Color(0xFFF0FDF4),
                  darkBgColor: const Color(0xFF112318),
                  darkIconColor: const Color(0xFF4ADE80),
                ),
                _StatCard(
                  label: 'Total Tasks',
                  count: s.totalTasks,
                  icon: HugeIcons.strokeRoundedTask01,
                  iconColor: const Color(0xFFC03355),
                  bgColor: const Color(0xFFFFF1F4),
                  darkBgColor: const Color(0xFF25111A),
                  darkIconColor: const Color(0xFFE05C7A),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final List<List<dynamic>> icon;
  final Color iconColor;
  final Color bgColor;
  final Color darkBgColor;
  final Color darkIconColor;

  const _StatCard({
    required this.label,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? darkBgColor : bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: icon,
              size: 18,
              color: isDark ? darkIconColor : iconColor,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.1,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
