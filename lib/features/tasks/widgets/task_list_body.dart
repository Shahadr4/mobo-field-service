import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../model/task_filter.dart';
import '../model/task_model.dart';
import '../pages/task_detail_screen.dart';
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
    final bg = widget.isDark ? const Color(0xFF1E2028) : Colors.white;
    final divider = widget.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: widget.isDark ? 0.18 : 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.tasks.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: widget.isDark
                            ? Colors.white38
                            : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expandable task rows ──────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  Divider(height: 1, thickness: 1, color: divider),
                  ...List.generate(widget.tasks.length, (i) {
                    final task = widget.tasks[i];
                    final isLast = i == widget.tasks.length - 1;
                    return Column(
                      children: [
                        _TaskRow(task: task, isDark: widget.isDark),
                        if (!isLast)
                          Divider(
                              height: 1,
                              thickness: 1,
                              indent: 16,
                              color: divider),
                      ],
                    );
                  }),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Flat task row (used inside group tile) ────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final TaskModel task;
  final bool isDark;

  const _TaskRow({required this.task, required this.isDark});

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
    final subtitleColor = isDark ? Colors.white38 : Colors.black38;

    return InkWell(
      onTap: () async {
        final provider = context.read<TaskProvider>();
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
        );
        if (result is TaskModel && context.mounted) {
          provider.updateTaskInMemory(result);
        } else if (result == true && context.mounted) {
          provider.refresh();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + stage badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (task.priority > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            task.priority,
                            (_) => const Icon(Icons.star_rounded,
                                size: 13, color: Color(0xFFFFB800)),
                          ),
                        ),
                      if (task.stageName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: stageColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            task.stageName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: stageColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (task.partnerName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(task.partnerName,
                        style:
                            TextStyle(fontSize: 12, color: subtitleColor)),
                  ],
                  if (task.scheduledStart.isNotEmpty ||
                      task.scheduledEnd.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (task.scheduledStart.isNotEmpty)
                          task.scheduledStart,
                        if (task.scheduledEnd.isNotEmpty) task.scheduledEnd,
                      ].join('  →  '),
                      style:
                          TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
