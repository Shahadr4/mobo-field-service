import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../model/task_model.dart';
import '../services/task_service.dart';
import '../widgets/detail/task_detail_shimmer.dart';
import '../widgets/detail/task_hours_bottom_sheet.dart';
import '../widgets/detail/task_info_card.dart';
import '../widgets/detail/task_pill_tab.dart';
import '../widgets/detail/subtasks_content.dart';
import '../widgets/detail/info_content.dart';
import '../widgets/detail/timesheet_content.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _service = TaskService();
  late TaskModel _task;
  bool _isLoading = false;
  int _tabIndex = 0;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final fresh = await _service.fetchTaskById(_task.id);
    if (mounted) {
      setState(() {
        if (fresh != null) _task = fresh;
        _refreshKey++;
        _isLoading = false;
      });
    }
  }

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
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final stageColor = _stageColor(_task.stageName);
    final pageBg     = isDark ? const Color(0xFF13151C) : const Color(0xFFF4F6FA);
    final cardBg     = isDark ? const Color(0xFF1E2028) : Colors.white;
    final shadow     = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    );

    // Bottom sheet height: 2 rows × 48 + remaining row 60 + safe area bottom
    final bottomSheetH = 48.0 + 48.0 + 60.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(

      appBar: AppBar(

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
      bottomSheet: _isLoading
          ? TaskHoursBottomSheetShimmer(isDark: isDark)
          : TaskHoursBottomSheet(task: _task, isDark: isDark),
      body: _isLoading
          ? TaskDetailShimmer(isDark: isDark)
          : RefreshIndicator(
              onRefresh: _refresh,
              color: primaryColor,
              child: Column(
              children: [
                // ── Scrollable top section ───────────────────────
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info card
                        TaskInfoCard(
                          task: _task,
                          isDark: isDark,
                          stageColor: stageColor,
                        ),
                        const SizedBox(height: 16),

                        // Pill tabs
                        Row(
                          children: [
                            TaskPillTab(
                              label: 'Info',
                              selected: _tabIndex == 0,
                              isDark: isDark,
                              onTap: () => setState(() => _tabIndex = 0),
                            ),
                            const SizedBox(width: 10),
                            TaskPillTab(
                              label: 'Timesheet',
                              selected: _tabIndex == 1,
                              isDark: isDark,
                              onTap: () => setState(() => _tabIndex = 1),
                            ),
                            const SizedBox(width: 10),
                            TaskPillTab(
                              label: 'Subtasks',
                              selected: _tabIndex == 2,
                              isDark: isDark,
                              onTap: () => setState(() => _tabIndex = 2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // ── Tab content — fills all remaining space ───────
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        16, 0, 16, bottomSheetH + 12),
                    child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [shadow],
                      ),
                      child: _tabIndex == 0
                          ? InfoContent(key: ValueKey(_refreshKey), task: _task, isDark: isDark)
                          : _tabIndex == 1
                              ? TimesheetContent(key: ValueKey('ts$_refreshKey'), task: _task, isDark: isDark)
                              : SubtasksContent(key: ValueKey('sub$_refreshKey'), task: _task, isDark: isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
