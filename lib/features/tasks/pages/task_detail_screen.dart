import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import '../../../core/services/odoo_session_manager.dart';
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
import '../widgets/detail/products_content.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';
import '../../map/provider/map_provider.dart';
import 'sign_report_screen.dart';
import 'worksheet_screen.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:mobo_feild_service/shared/widgets/loaders/loading_widget.dart';

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
  String? _overlayLoadingMessage;

  // FSM feature flags — false until confirmed by settings fetch
  bool _showWarrantySection   = false;
  bool _showWorksheetSection  = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _fetchFsmSettings();
  }

  Future<void> _fetchFsmSettings() async {
    final settings = await _service.fetchFsmSettings();
    if (mounted) {
      setState(() {
        _showWarrantySection  = settings.warrantyEnabled;
        _showWorksheetSection = settings.worksheetEnabled;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final fresh = await _service.fetchTaskById(
      _task.id,
      includeWarranty:  _showWarrantySection,
      includeWorksheet: _showWorksheetSection,
    );
    if (mounted) {
      setState(() {
        if (fresh != null) {
          _task = fresh;
          _isUpdated = true;
        }
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

  void _handleLocation() {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    mapProvider.setActiveHomeTab(3); // Switch to Map tab
    mapProvider.setPendingJumpTaskId(_task.id); // Queue the task ID to jump to
    Navigator.pop(context); // Close the detail screen
  }

  Future<void> _handleSignReport() async {
    setState(() => _overlayLoadingMessage = 'Loading worksheet...');
    try {
      final result = await _service.fetchWorksheetPreviewUrl(_task.id);
      if (!mounted) return;
      setState(() => _overlayLoadingMessage = null);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignReport(
            url: result.url,
            sessionId: result.sessionId,
            taskName: _task.name,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _overlayLoadingMessage = null);
        CustomSnackbar.showError(context, 'Failed to load worksheet: ${e.toString()}');
      }
    }
  }

  Future<void> _handleSendReport() async {
    setState(() => _overlayLoadingMessage = 'Generating report...');
    try {
      final file = await _service.downloadTaskReport(_task.id);
      if (!mounted) return;

      if (file == null) {
        throw Exception("Could not download report file.");
      }

      setState(() => _overlayLoadingMessage = 'Preparing email...');

      final Email email = Email(
        body: 'Please find attached the field service report for task "${_task.name}".',
        subject: 'Field Service Report: ${_task.name}',
        recipients: _task.partnerEmail.isNotEmpty ? [_task.partnerEmail] : [],
        attachmentPaths: [file.path],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);

      if (!mounted) return;
      setState(() => _overlayLoadingMessage = null);
      CustomSnackbar.showSuccess(context, 'Email composer opened with attached report.');
    } catch (e) {
      if (mounted) {
        setState(() => _overlayLoadingMessage = null);
        CustomSnackbar.showError(
          context,
          'Failed to send report: ${e.toString()}',
        );
      }
    }
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

    return Stack(
      children: [
        Scaffold(

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
          if ((_task.isFsm || _task.partnerId != null) &&
              _task.allowWorksheets &&
              _task.worksheetTemplateId != null &&
              !_task.hasTemplateAncestor &&
              !_task.hasProjectTemplate)
            IconButton(
              padding: EdgeInsets.zero,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedTask02,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorksheetScreen(
                      taskId: _task.id,
                      taskName: _task.name,
                    ),
                  ),
                );
              },
            ),

          IconButton(
            padding: EdgeInsets.zero,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedPencilEdit02,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            onPressed: () async {
              final provider = context.read<TaskProvider>();
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditTaskScreen(task: _task)),
              );
              if (!mounted) return;
              if (updated is TaskModel) {
                setState(() {
                  _task = updated;
                  _isUpdated = true;
                  _refreshKey++;
                });
                provider.updateTaskInMemory(updated);
              }
            },
          ),
          _TaskActionMenu(
            task: _task,
            isDark: isDark,
            onMarkAsDone: _handleMarkAsDone,
            onSignReport: _handleSignReport,
            onSendReport: _handleSendReport,
            onLocation: _handleLocation,
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
                            onTimerSaved: _refresh,
                          ),
                          const SizedBox(height: 16),

                          // Pill tabs
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
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
                                if (_task.allowMaterial &&
                                    !_task.hasTemplateAncestor &&
                                    !_task.hasProjectTemplate) ...[
                                  const SizedBox(width: 10),
                                  TaskPillTab(
                                    label: 'Products',
                                    selected: _tabIndex == 3,
                                    isDark: isDark,
                                    onTap: () => setState(() => _tabIndex = 3),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

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
                                showWarrantySection: _showWarrantySection,
                                showWorksheetSection: _showWorksheetSection,
                              )
                            : _tabIndex == 1
                            ? TimesheetContent(
                                key: ValueKey('ts$_refreshKey'),
                                task: _task,
                                isDark: isDark,
                              )
                            : _tabIndex == 2
                            ? SubtasksContent(
                                key: ValueKey('sub$_refreshKey'),
                                task: _task,
                                isDark: isDark,
                              )
                            : ProductsContent(
                                key: ValueKey('prod$_refreshKey'),
                                task: _task,
                                isDark: isDark,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ),
        if (_overlayLoadingMessage != null)
          LoadingWidget(
            message: _overlayLoadingMessage,
            overlay: true,
          ),
      ],
    );
  }
}

enum _TaskAction { signReport, sendReport, markAsDone, location }

class _TaskActionMenu extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  final VoidCallback onMarkAsDone;
  final VoidCallback onSignReport;
  final VoidCallback onSendReport;
  final VoidCallback onLocation;

  const _TaskActionMenu({
    required this.task,
    required this.isDark,
    required this.onMarkAsDone,
    required this.onSignReport,
    required this.onSendReport,
    required this.onLocation,
  });

  @override
  Widget build(BuildContext context) {
      final showSignReport = task.displaySignReport &&
        !task.hasTemplateAncestor &&
        !task.hasProjectTemplate;
    final showSendReport = task.displaySendReport &&
        !task.hasTemplateAncestor &&
        !task.hasProjectTemplate;
    final showMarkAsDone = task.displayMarkAsDone &&
        !task.hasTemplateAncestor &&
        !task.hasProjectTemplate;

    return PopupMenuButton<_TaskAction>(
      color: Colors.white,
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: isDark ? Colors.white54 : Colors.black,
      ),
      onSelected: (action) {
        switch (action) {
          case _TaskAction.signReport:
            onSignReport();
          case _TaskAction.sendReport:
            onSendReport();
          case _TaskAction.markAsDone:
            onMarkAsDone();
          case _TaskAction.location:
            onLocation();
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
        const PopupMenuItem(
          value: _TaskAction.location,
          child: Row(
            children: [
              Text('Location'),
            ],
          ),
        ),
      ],
    );
  }
}
