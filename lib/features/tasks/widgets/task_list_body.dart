import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../model/task_filter.dart';
import '../model/task_model.dart';
import '../provider/task_provider.dart';
import 'task_card.dart';

class TaskListBody extends StatelessWidget {
  const TaskListBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p      = context.watch<TaskProvider>();

    if (p.isLoading) {
      return _TaskShimmerList(isDark: isDark);
    }

    if (p.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.grey.shade400, size: 40),
            const SizedBox(height: 12),
            Text('Failed to load tasks',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<TaskProvider>().fetchTasks(),
              child:
                  const Text('Retry', style: TextStyle(color: primaryColor)),
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
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final grouped = p.grouped;
    final isGrouped = p.groupBy != TaskGroupBy.none;

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () => context.read<TaskProvider>().refresh(),
      child: isGrouped
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: grouped.entries.map((entry) {
                return _GroupExpansionTile(
                  label: entry.key,
                  tasks: entry.value,
                  isDark: isDark,
                );
              }).toList(),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              itemCount: grouped['']?.length ?? 0,
              itemBuilder: (_, i) {
                final task = grouped['']![i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TaskCard(task: task, isDark: isDark),
                );
              },
            ),
    );
  }
}

// ── Shimmer loading list ──────────────────────────────────────────────────────

class _TaskShimmerList extends StatelessWidget {
  final bool isDark;
  const _TaskShimmerList({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base      = isDark ? const Color(0xFF2A2D36) : const Color(0xFFE8E8E8);
    final highlight = isDark ? const Color(0xFF3A3D48) : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor:      base,
      highlightColor: highlight,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        itemCount: 8,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 64,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 11,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Group expansion tile ──────────────────────────────────────────────────────

class _GroupExpansionTile extends StatefulWidget {
  final String label;
  final List<TaskModel> tasks;
  final bool isDark;

  const _GroupExpansionTile({
    required this.label,
    required this.tasks,
    required this.isDark,
  });

  @override
  State<_GroupExpansionTile> createState() => _GroupExpansionTileState();
}

class _GroupExpansionTileState extends State<_GroupExpansionTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final divColor = widget.isDark
        ? const Color(0xFF2A2D36)
        : const Color(0xFFEEEEEE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ───────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: widget.isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.tasks.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Divider(color: divColor)),
              ],
            ),
          ),
        ),

        // ── Collapsible task cards ────────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(
            children: widget.tasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TaskCard(task: task, isDark: widget.isDark),
            )).toList(),
          ),
          secondChild: const SizedBox.shrink(),
        ),

        const SizedBox(height: 4),
      ],
    );
  }
}
