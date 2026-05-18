import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../model/task_model.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  int _tabIndex = 0;

  Color _stageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('progress') || s.contains('ongoing')) return const Color(0xFF06B6D4);
    if (s.contains('done') || s.contains('complete'))    return const Color(0xFF22C55E);
    if (s.contains('approve'))                           return const Color(0xFF22C55E);
    if (s.contains('cancel'))                            return const Color(0xFFEF4444);
    if (s.contains('plan'))                              return const Color(0xFFF59E0B);
    if (s.contains('new'))                               return const Color(0xFF3B82F6);
    return primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final task   = widget.task;
    final stageColor = _stageColor(task.stageName);
    final pageBg  = isDark ? const Color(0xFF13151C) : Colors.white;
    final cardBg  = isDark ? const Color(0xFF1E2028) : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: isDark ? Colors.white : Colors.black),
          ),
        ),
        title: Text(
          'Task Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Icon(Icons.edit_outlined,
                size: 20,
                color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      bottomSheet: _BottomSheet(task: task, isDark: isDark),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            // ── Main info card ────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.22 : 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task name + stage badge
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
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
                  // Assignee
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
                  // Project name
                  if (task.projectName.isNotEmpty)
                    Row(
                      children: [
                        Text(
                          task.projectName,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  // Customer
                  if (task.partnerName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('Customer : '),
                        Text(
                          task.partnerName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  // Location
                  if (task.partnerAddress.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Location : '),
                        Expanded(
                          child: Text(
                            task.partnerAddress,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Scheduled time
                  if (task.scheduledStart.isNotEmpty ||
                      task.scheduledEnd.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('Time : '),
                        Text(
                          [
                            if (task.scheduledStart.isNotEmpty)
                              task.scheduledStart,
                            if (task.scheduledEnd.isNotEmpty)
                              task.scheduledEnd,
                          ].join(' → '),
                          style:
                              const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Deadline in blue
                  if (task.deadline.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.deadline,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Pill tabs ─────────────────────────────────────
            Row(
              children: [
                _PillTab(
                  label: 'Subtasks',
                  selected: _tabIndex == 0,
                  isDark: isDark,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 10),
                _PillTab(
                  label: 'Description',
                  selected: _tabIndex == 1,
                  isDark: isDark,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                const SizedBox(width: 10),
                _PillTab(
                  label: 'Timeline',
                  selected: _tabIndex == 2,
                  isDark: isDark,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Tab content card ──────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.22 : 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _tabIndex == 0
                    ? _SubtasksContent(isDark: isDark)
                    : _tabIndex == 1
                        ? _DescriptionContent(task: task, isDark: isDark)
                        : _TimelineContent(task: task, isDark: isDark),
              ),
            ),

            // space so content doesn't hide behind bottom sheet
            const SizedBox(height: 150),
          ],
        ),
      ),
    );
  }
}

// ── Pill tab ──────────────────────────────────────────────────────────────────

class _PillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _PillTab({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : Colors.black)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (isDark ? Colors.white24 : const Color(0xFFCCCCCC)),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

// ── Subtasks ──────────────────────────────────────────────────────────────────

class _SubtasksContent extends StatelessWidget {
  final bool isDark;
  const _SubtasksContent({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset('assets/lotties/empty ghost.json',
              width: 130, height: 130, fit: BoxFit.contain),
          Text(
            'No subtasks',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Description ───────────────────────────────────────────────────────────────

class _DescriptionContent extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  const _DescriptionContent({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (task.description.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/lotties/empty ghost.json',
                width: 130, height: 130, fit: BoxFit.contain),
            Text(
              'No description',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Text(
        task.description,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _TimelineContent extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  const _TimelineContent({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 13,
      color: isDark ? Colors.white54 : Colors.black45,
    );
    final valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : Colors.black87,
    );
    final divColor =
        isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    final rows = <_Row>[
      if (task.scheduledStart.isNotEmpty) _Row('Start', task.scheduledStart),
      if (task.scheduledEnd.isNotEmpty)   _Row('End', task.scheduledEnd),
      if (task.deadline.isNotEmpty)       _Row('Deadline', task.deadline),
      if (task.partnerName.isNotEmpty)    _Row('Customer', task.partnerName),
      if (task.partnerAddress.isNotEmpty) _Row('Location', task.partnerAddress),
      if (task.partnerPhone.isNotEmpty)   _Row('Phone', task.partnerPhone),
    ];

    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/lotties/empty ghost.json',
                width: 130, height: 130, fit: BoxFit.contain),
            Text('No timeline data',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(rows[i].label, style: labelStyle),
                  ),
                  Expanded(child: Text(rows[i].value, style: valueStyle)),
                ],
              ),
            ),
            if (i < rows.length - 1)
              Divider(height: 1, thickness: 1, color: divColor),
          ],
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  const _BottomSheet({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final labelColor = isDark ? Colors.white54 : Colors.black54;
    final valueColor = isDark ? Colors.white : Colors.black87;
    final divColor =
        isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Allocated Hours
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Allocated Hours',
                      style: TextStyle(
                          color: labelColor,
                          fontWeight: FontWeight.w500)),
                  Text(task.allocatedHours.toStringAsFixed(2),
                      style: TextStyle(
                          color: valueColor,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: divColor,
                indent: 20, endIndent: 20),
            const SizedBox(height: 10),
            // Effective Hours
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Effective Hours',
                      style: TextStyle(
                          color: labelColor,
                          fontWeight: FontWeight.w500)),
                  Text(task.effectiveHours.toStringAsFixed(2),
                      style: TextStyle(
                          color: valueColor,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // Remaining Hours — solid pink bar
            Container(
              color: primaryColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remaining Hours',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(task.remainingHours.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
