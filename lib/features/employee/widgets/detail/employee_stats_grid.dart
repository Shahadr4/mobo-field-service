import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../model/employee_stats_model.dart';

class EmployeeStatsGrid extends StatelessWidget {
  final EmployeeStats stats;

  const EmployeeStatsGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [

      _Item(
        label: 'Active Tasks',
        description: 'Tasks currently in progress',
        count: stats.activeTasks,
        icon: HugeIcons.strokeRoundedFolder01,
        iconColor: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
        darkBgColor: const Color(0xFF1A2535),
        darkIconColor: const Color(0xFF60A5FA),
      ),
      _Item(
        label: 'Completed',
        description: 'Tasks finished successfully',
        count: stats.completedTasks,
        icon: HugeIcons.strokeRoundedTaskDone01,
        iconColor: const Color(0xFF22C55E),
        bgColor: const Color(0xFFF0FDF4),
        darkBgColor: const Color(0xFF112318),
        darkIconColor: const Color(0xFF4ADE80),
      ),
      _Item(
        label: 'Assigned Tasks',
        description: 'Total tasks assigned to this user',
        count: stats.assignedTasks,
        icon: HugeIcons.strokeRoundedClipboard,
        iconColor: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFFFBEB),
        darkBgColor: const Color(0xFF251E10),
        darkIconColor: const Color(0xFFFBBF24),
      ),
      _Item(
        label: 'Cancelled',
        description: 'Tasks that were cancelled',
        count: stats.cancelledTasks,
        icon: HugeIcons.strokeRoundedTask01,
        iconColor: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFEF2F2),
        darkBgColor: const Color(0xFF2A1010),
        darkIconColor: const Color(0xFFF87171),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: items
          .map((item) => _StatCard(item: item, isDark: isDark))
          .toList(),
    );
  }
}

class _Item {
  final String label;
  final String description;
  final int count;
  final List<List<dynamic>> icon;
  final Color iconColor;
  final Color bgColor;
  final Color darkBgColor;
  final Color darkIconColor;

  const _Item({
    required this.label,
    required this.description,
    required this.count,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.darkBgColor,
    required this.darkIconColor,
  });
}

class _StatCard extends StatelessWidget {
  final _Item item;
  final bool isDark;

  const _StatCard({required this.item, required this.isDark});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.count}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
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
              color: isDark ? item.darkBgColor : item.bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(
              icon: item.icon,
              size: 24,
              color: isDark ? item.darkIconColor : item.iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
