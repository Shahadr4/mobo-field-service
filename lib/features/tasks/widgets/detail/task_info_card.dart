import 'package:flutter/material.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../../model/task_model.dart';

class TaskInfoCard extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  final Color stageColor;

  const TaskInfoCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.stageColor,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [shadow],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.name,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (task.stageName.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    task.stageName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: stageColor,
                    ),
                  ),
                ),
            ],
          ),
          if (task.assigneeName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.assigneeName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (task.projectName.isNotEmpty)
            Text(
              task.projectName,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (task.partnerName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              task.partnerName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black87,
              ),
            ),
          ],
          if (task.partnerAddress.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              task.partnerAddress,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
          if (task.scheduledStart.isNotEmpty || task.scheduledEnd.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (task.scheduledStart.isNotEmpty) task.scheduledStart,
                if (task.scheduledEnd.isNotEmpty) task.scheduledEnd,
              ].join(' → '),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.blue,
              ),
            ),
          ],

        ],
      ),
    );
  }
}
