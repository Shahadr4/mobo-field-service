import 'package:flutter/material.dart';
import '../../../../core/const/app_colors.dart';
import '../../model/employee_stats_model.dart';

class EmployeeHoursRow extends StatelessWidget {
  final EmployeeStats stats;
  final bool isDark;
  final Color cardBg;
  final BoxShadow shadow;

  const EmployeeHoursRow({
    super.key,
    required this.stats,
    required this.isDark,
    required this.cardBg,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HoursTile(
            label: 'Total Hours',
            description: 'All time logged hours',
            hours: stats.totalHours,
            icon: Icons.access_time_rounded,
            iconColor: const Color(0xFF3B82F6),
            bgColor: const Color(0xFFEFF6FF),
            darkBgColor: const Color(0xFF1A2535),
            darkIconColor: const Color(0xFF60A5FA),
            isDark: isDark,
            cardBg: cardBg,
            shadow: shadow,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HoursTile(
            label: 'This Month',
            description: 'Hours logged this month',
            hours: stats.thisMonthHours,
            icon: Icons.calendar_month_rounded,
            iconColor: primaryColor,
            bgColor: const Color(0xFFFFF1F4),
            darkBgColor: const Color(0xFF25111A),
            darkIconColor: const Color(0xFFE05C7A),
            isDark: isDark,
            cardBg: cardBg,
            shadow: shadow,
          ),
        ),
      ],
    );
  }
}

class _HoursTile extends StatelessWidget {
  final String label;
  final String description;
  final double hours;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color darkBgColor;
  final Color darkIconColor;
  final bool isDark;
  final Color cardBg;
  final BoxShadow shadow;

  const _HoursTile({
    required this.label,
    required this.description,
    required this.hours,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.darkBgColor,
    required this.darkIconColor,
    required this.isDark,
    required this.cardBg,
    required this.shadow,
  });

  String _fmt(double h) {
    final totalMin = (h * 60).round();
    final hh = totalMin ~/ 60;
    final mm = totalMin % 60;
    if (hh == 0) return '${mm}m';
    if (mm == 0) return '${hh}h';
    return '${hh}h ${mm}m';
  }

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
                  _fmt(hours),
                  style: TextStyle(
                    fontSize: 22,
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
            child: Icon(
              icon,
              size: 24,
              color: isDark ? darkIconColor : iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
