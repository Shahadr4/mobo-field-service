import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../model/task_model.dart';
import 'edit_task_screen.dart';
import 'package:provider/provider.dart';
import '../provider/task_provider.dart';
import '../services/task_service.dart';
import '../widgets/detail/task_detail_shimmer.dart';
import '../widgets/detail/task_hours_bottom_sheet.dart';
import '../widgets/detail/task_info_card.dart';
import '../widgets/detail/task_pill_tab.dart';
import '../widgets/detail/subtasks_content.dart';
import '../widgets/detail/info_content.dart';
import '../widgets/detail/timesheet_content.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';

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
  bool _isUpdated = false;

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
    if (s.contains('progress') || s.contains('ongoing'))
      return const Color(0xFF06B6D4);
    if (s.contains('done') || s.contains('complete'))
      return const Color(0xFF22C55E);
    if (s.contains('approve')) return const Color(0xFF22C55E);
    if (s.contains('cancel')) return const Color(0xFFEF4444);
    if (s.contains('plan')) return const Color(0xFFF59E0B);
    if (s.contains('new')) return const Color(0xFF3B82F6);
    return primaryColor;
  }

  Future<void> _handleMarkAsDone() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Mark as Done'),
        content: const Text('Are you sure you want to mark this task as done?'),
        actions: [
          OutlinedButton(
              style: OutlinedButton.styleFrom(

                side: BorderSide(color: primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                 shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),

              onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    final result = await _service.markTaskAsDone(_task.id);
    if (!mounted) return;
    if (result == null) {
      setState(() => _isUpdated = true);
      context.read<TaskProvider>().fetchTasks();
      await _refresh();
      if (!mounted) return;
      CustomSnackbar.showSuccess(context, 'Task marked as done');
    } else {
      setState(() => _isLoading = false);
      CustomSnackbar.showError(context, result);
    }
  }

  Future<void> _handleSignReport() async {
    CustomSnackbar.showInfo(context, 'Sign report feature coming soon');
  }

  Future<void> _handleSendReport() async {
    CustomSnackbar.showInfo(context, 'Send report feature coming soon');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stageColor = _stageColor(_task.stageName);
    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    );

    // Bottom sheet height: 2 rows × 48 + remaining row 60 + safe area bottom
    final bottomSheetH =
        48.0 + 48.0 + 60.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(

      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context, _isUpdated ? _task : null),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
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
          IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditTaskScreen(task: _task)),
              );
              if (updated is TaskModel) {
                setState(() {
                  _task = updated;
                  _isUpdated = true;
                });
                if (mounted) {
                  context.read<TaskProvider>().updateTaskInMemory(updated);
                }
                _refresh();
              }
            },
          ),
          _TaskActionMenu(
            task: _task,
            isDark: isDark,
            onMarkAsDone: _handleMarkAsDone,
            onSignReport: _handleSignReport,
            onSendReport: _handleSendReport,
          ),
          const SizedBox(width: 8),
        ],
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      bottomSheet: _isLoading
          ? TaskHoursBottomSheetShimmer(isDark: isDark)
          : TaskHoursBottomSheet(task: _task, isDark: isDark),
      body: _isLoading
          ? TaskDetailShimmer(isDark: isDark)
          : RefreshIndicator(
              onRefresh: _refresh,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
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

                    // ── Tab content ───────
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        bottomSheetH + 16,
                      ),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 250),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [shadow],
                        ),
                        child: _tabIndex == 0
                            ? InfoContent(
                                key: ValueKey(_refreshKey),
                                task: _task,
                                isDark: isDark,
                              )
                            : _tabIndex == 1
                            ? TimesheetContent(
                                key: ValueKey('ts$_refreshKey'),
                                task: _task,
                                isDark: isDark,
                              )
                            : SubtasksContent(
                                key: ValueKey('sub$_refreshKey'),
                                task: _task,
                                isDark: isDark,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

enum _TaskAction { signReport, sendReport, markAsDone }

class _TaskActionMenu extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  final VoidCallback onMarkAsDone;
  final VoidCallback onSignReport;
  final VoidCallback onSendReport;

  const _TaskActionMenu({
    required this.task,
    required this.isDark,
    required this.onMarkAsDone,
    required this.onSignReport,
    required this.onSendReport,
  });

  @override
  Widget build(BuildContext context) {
    // Odoo conditions:
    // visible = display_X_secondary == true AND has_template_ancestor == false AND has_project_template == false
    final showSignReport = task.displaySignReport &&
        !task.hasTemplateAncestor &&
        !task.hasProjectTemplate;
    final showSendReport = task.displaySendReport &&
        !task.hasTemplateAncestor &&
        !task.hasProjectTemplate;
    final showMarkAsDone = task.displayMarkAsDone &&
        !task.hasTemplateAncestor &&
        !task.hasProjectTemplate;

    if (!showSignReport && !showSendReport && !showMarkAsDone) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_TaskAction>(
      color: Colors.white,
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
      onSelected: (action) {
        switch (action) {
          case _TaskAction.signReport:
            onSignReport();
          case _TaskAction.sendReport:
            onSendReport();
          case _TaskAction.markAsDone:
            onMarkAsDone();
        }
      },
      itemBuilder: (_) => [
        if (showSignReport)
          const PopupMenuItem(
            value: _TaskAction.signReport,
            child: Row(
              children: [

                Text('Sign Report'),
              ],
            ),
          ),
        if (showSendReport)
          const PopupMenuItem(
            value: _TaskAction.sendReport,
            child: Row(
              children: [
                               Text('Send Report'),
              ],
            ),
          ),
        if (showMarkAsDone)
          const PopupMenuItem(
            value: _TaskAction.markAsDone,
            child: Row(
              children: [
                             Text('Mark as Done'),
              ],
            ),
          ),
      ],
    );
  }
}
