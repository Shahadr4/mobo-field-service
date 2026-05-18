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
            Text(
              'Task Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color:  Colors.black87,
              ),
            ),
            SizedBox(height: 16,),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _StatCard(
                  label: 'Active Task',
                  description: 'Task you are working on',
                  count: s.activeTasks,
                  icon: HugeIcons.strokeRoundedFolder01,
                  iconColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                  darkBgColor: const Color(0xFF1A2535),
                  darkIconColor: const Color(0xFF60A5FA),
                ),
                _StatCard(
                  label: 'Assigned Tasks',
                  description: 'Total Assigned to you',
                  count: s.assignedTasks,
                  icon: HugeIcons.strokeRoundedClipboard,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  darkBgColor: const Color(0xFF251E10),
                  darkIconColor: const Color(0xFFFBBF24),
                ),
                _StatCard(
                  label: 'Completed',
                  description: 'Tasks finished successfully',
                  count: s.completedTasks,
                  icon: HugeIcons.strokeRoundedTaskDone01,
                  iconColor: const Color(0xFF22C55E),
                  bgColor: const Color(0xFFF0FDF4),
                  darkBgColor: const Color(0xFF112318),
                  darkIconColor: const Color(0xFF4ADE80),
                ),
                _StatCard(
                  label: 'Total Tasks',
                  description: 'All tasks assigned to the company',
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
          // Left: count + title + description
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
          // Right: icon centered vertically
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
