import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';

import '../provider/task_provider.dart';
import 'task_card.dart';

class TaskListBody extends StatelessWidget {
  const TaskListBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<TaskProvider>();

    if (p.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5),
      );
    }

    if (p.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.grey.shade400, size: 40),
            const SizedBox(height: 12),
            Text(
              'Failed to load tasks',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<TaskProvider>().fetchTasks(),
              child: const Text('Retry', style: TextStyle(color: primaryColor)),
            ),
          ],
        ),
      );
    }

    if (p.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedTask01,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            Text(
              p.search.isNotEmpty
                  ? 'No tasks match "${p.search}"'
                  : 'No tasks found',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () => context.read<TaskProvider>().refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        itemCount: p.tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => TaskCard(task: p.tasks[i], isDark: isDark),
      ),
    );
  }
}
