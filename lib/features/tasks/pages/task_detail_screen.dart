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
    final pageBg     = isDark ? const Color(0xFF13151C) : Colors.white;
    final cardBg     = isDark ? const Color(0xFF1E2028) : Colors.white;
    final shadow     = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    );

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
      bottomSheet: _isLoading
          ? TaskHoursBottomSheetShimmer(isDark: isDark)
          : TaskHoursBottomSheet(task: _task, isDark: isDark),
      body: _isLoading
          ? TaskDetailShimmer(isDark: isDark)
          : LayoutBuilder(
              builder: (context, constraints) {
                // Fixed height for tab card = available body height
                // minus top padding, info card (~190), tabs row (~44), spacings, bottom sheet (~160)
                final tabHeight = constraints.maxHeight -
                    MediaQuery.of(context).padding.top -
                    16 - // top padding
                    190 - // info card approx
                    16 - // gap
                    44 - // pill tabs row
                    12 - // gap
                    160; // bottom sheet clearance

                final safeTabHeight = tabHeight.clamp(200.0, double.infinity);

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                              label: 'Information',
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
                        const SizedBox(height: 15),

                        // Tab content card — fixed height, scrolls internally
                        SizedBox(
                          height: safeTabHeight,
                          child: Container(
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [shadow],
                            ),
                            child: _tabIndex == 0
                                ? InfoContent(task: _task, isDark: isDark)
                                : _tabIndex == 1
                                    ? TimesheetContent(task: _task, isDark: isDark)
                                    : SubtasksContent(task: _task, isDark: isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
