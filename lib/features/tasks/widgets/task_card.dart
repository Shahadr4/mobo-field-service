import 'package:flutter/material.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../model/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isDark;

  const TaskCard({super.key, required this.task, required this.isDark});

  Color _stageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('progress') || s.contains('ongoing')) {
      return const Color(0xFF06B6D4);
    }
    if (s.contains('done') || s.contains('complete')) {
      return const Color(0xFF22C55E);
    }
    if (s.contains('approve')) return const Color(0xFF22C55E);
    if (s.contains('cancel')) return const Color(0xFFEF4444);
    if (s.contains('plan')) return const Color(0xFFF59E0B);
    if (s.contains('new')) return const Color(0xFF3B82F6);
    return primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final stageColor = _stageColor(task.stageName);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (task.stageName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.12),

                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task.stageName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: stageColor,
                      ),
                    ),
                  ),
                Icon(Icons.more_vert_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black38),
              ],
            ),
            const SizedBox(height: 10),
            if (task.assigneeName.isNotEmpty)
              Text(
                task.assigneeName,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            if (task.assigneeName.isNotEmpty) const SizedBox(height: 4),
            if (task.projectName.isNotEmpty)
              Text(
                task.projectName,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Created Date',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                Text(
                  task.createDate,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
