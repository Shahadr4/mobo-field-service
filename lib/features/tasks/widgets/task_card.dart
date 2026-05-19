import 'package:flutter/material.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../model/task_model.dart';
import '../pages/task_detail_screen.dart';
import 'package:provider/provider.dart';
import '../provider/task_provider.dart';

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

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(task: task),
          ),
        );
        if (result is TaskModel && context.mounted) {
          context.read<TaskProvider>().updateTaskInMemory(result);
        } else if (result == true && context.mounted) {
          context.read<TaskProvider>().refresh();
        }
      },
      child: Container(
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
                if (task.priority > 0) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      task.priority,
                      (index) => const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFFFB800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
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
            const SizedBox(height: 6),
            if (task.partnerName.isNotEmpty)
              Text(task.partnerName,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
            if (task.partnerName.isNotEmpty) const SizedBox(height: 4),
            if (task.scheduledStart.isNotEmpty || task.scheduledEnd.isNotEmpty)
              Text(
                [
                  if (task.scheduledStart.isNotEmpty) task.scheduledStart,
                  if (task.scheduledEnd.isNotEmpty) task.scheduledEnd,
                ].join('  →  '),
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
              ),
            if (task.scheduledStart.isNotEmpty || task.scheduledEnd.isNotEmpty)
              const SizedBox(height: 4),

          ],
        ),
      ),
      ),
    );
  }
}


