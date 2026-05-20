import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:shimmer/shimmer.dart';

import '../../model/task_model.dart';
import '../../services/task_service.dart';
import '../../pages/task_detail_screen.dart';
import 'shimmer_bone.dart';


class SubtasksContent extends StatefulWidget {
  final TaskModel task;
  final bool isDark;
  const SubtasksContent({super.key, required this.task, required this.isDark});

  @override
  State<SubtasksContent> createState() => _SubtasksContentState();
}

class _SubtasksContentState extends State<SubtasksContent> {
  List<Map<String, dynamic>>? _subtasks;
  bool _loading = true;
  final ScrollController _horizontalController = ScrollController();

  bool _navigating = false;
  int? _navigatingTaskId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await TaskService().fetchSubtasks(widget.task.id);
    if (mounted) {
      setState(() {
        _subtasks = data;
        _loading = false;
      });
    }
  }

  Future<void> _navigate(int taskId) async {
    if (_navigating) return;
    setState(() {
      _navigating = true;
      _navigatingTaskId = taskId;
    });
    final task = await TaskService().fetchTaskById(taskId);
    if (!mounted) return;
    setState(() {
      _navigating = false;
      _navigatingTaskId = null;
    });
    if (task != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailScreen(task: task),
        ),
      );
    } else {
      CustomSnackbar.showError(context, 'Could not open subtask details.');
    }
  }

  void _showAddSubtaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSubtaskSheet(
        parentTask: widget.task,
        isDark: widget.isDark,
        onCreated: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    if (_loading) return _SubtasksShimmer(isDark: isDark);

    final items = _subtasks ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Add Subtask button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddSubtaskSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Subtask'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        if (items.isEmpty)
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset('assets/lotties/empty ghost.json',
                    width: 100, height: 100, fit: BoxFit.contain),
                const SizedBox(height: 8),
                Text(
                  'No subtasks',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  thumbVisibility: WidgetStateProperty.all(true),
                  trackVisibility: WidgetStateProperty.all(true),
                  thickness: WidgetStateProperty.all(6),
                  radius: const Radius.circular(5),
                  thumbColor: WidgetStateProperty.all(
                    isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  trackColor: WidgetStateProperty.all(
                    isDark ? Colors.grey[800] : Colors.grey[100],
                  ),
                  trackBorderColor: WidgetStateProperty.all(
                    isDark ? Colors.grey[700] : Colors.grey[100],
                  ),
                  interactive: true,
                  crossAxisMargin: 4,
                  mainAxisMargin: 8,
                ),
              ),
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black26
                            : Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Table(
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      columnWidths: const {
                        0: FixedColumnWidth(50),
                        1: FixedColumnWidth(200),
                        2: FixedColumnWidth(100),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFF8F9FA),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                          children: [
                            _headerCell('#', isDark),
                            _headerCell('Name', isDark),
                            _headerCell('Action', isDark),
                          ],
                        ),
                        ...items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final line = entry.value;

                          final taskName = line['name']?.toString() ?? '';
                          final taskId = line['id'] as int?;

                          final isNavigatingThis =
                              _navigating && _navigatingTaskId == taskId;

                          return TableRow(
                            children: [
                              _dataCell('${index + 1}.', isDark),
                              _dataCell(taskName.isNotEmpty ? taskName : '—', isDark),
                              TableCell(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      onTap: taskId != null
                                          ? () => _navigate(taskId)
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: isNavigatingThis
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  TableCell _headerCell(String text, bool isDark) => TableCell(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
      );

  TableCell _dataCell(String text, bool isDark, {Color? color}) => TableCell(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: color ?? (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}

// ── Add Subtask Bottom Sheet ──────────────────────────────────────────────────

class _AddSubtaskSheet extends StatefulWidget {
  final TaskModel parentTask;
  final bool isDark;
  final VoidCallback onCreated;

  const _AddSubtaskSheet({
    required this.parentTask,
    required this.isDark,
    required this.onCreated,
  });

  @override
  State<_AddSubtaskSheet> createState() => _AddSubtaskSheetState();
}

class _AddSubtaskSheetState extends State<_AddSubtaskSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final id = await TaskService().createTask(
      name: _nameCtrl.text.trim(),
      projectId: widget.parentTask.projectId!,
      parentId: widget.parentTask.id,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (id != null) {
      Navigator.pop(context);
      widget.onCreated();
      CustomSnackbar.showSuccess(context, 'Subtask created successfully');
    } else {
      CustomSnackbar.showError(context, 'Failed to create subtask. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final labelColor = isDark ? Colors.white70 : Colors.black87;
    final borderColor = isDark ? Colors.white24 : Colors.grey.shade300;
    final fillColor = isDark ? const Color(0xFF252830) : const Color(0xFFF8F9FA);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_task,
                            color: primaryColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Subtask',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              widget.parentTask.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Name field
                  Text('Task Name *',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: labelColor)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter subtask name',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 14),
                      filled: true,
                      fillColor: fillColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFEF4444), width: 1.5),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Description field
                  Text('Description',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: labelColor)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter description (optional)',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 14),
                      filled: true,
                      fillColor: fillColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _saving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                isDark ? Colors.white70 : Colors.black54,
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Create',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtasksShimmer extends StatelessWidget {
  final bool isDark;
  const _SubtasksShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base      = isDark ? const Color(0xFF252830) : const Color(0xFFE8E8EC);
    final highlight = isDark ? const Color(0xFF32353F) : const Color(0xFFF4F4F8);
    final divColor  = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  ShimmerBone(width: 16, height: 12, base: base),
                  const SizedBox(width: 8),
                  Expanded(flex: 4, child: ShimmerBone(width: 36, height: 12, base: base)),
                  Expanded(flex: 3, child: ShimmerBone(width: 55, height: 12, base: base)),
                  Expanded(flex: 3, child: ShimmerBone(width: 55, height: 12, base: base)),
                  ShimmerBone(width: 36, height: 12, base: base),
                ],
              ),
            ),
            Divider(height: 1, color: divColor),
            for (int i = 0; i < 4; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                child: Row(
                  children: [
                    ShimmerBone(width: 16, height: 13, base: base),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: ShimmerBone(width: 90, height: 13, base: base)),
                    Expanded(flex: 3, child: ShimmerBone(width: 70, height: 13, base: base)),
                    Expanded(flex: 3, child: ShimmerBone(width: 60, height: 13, base: base)),
                    ShimmerBone(width: 42, height: 26, base: base, radius: 20),
                  ],
                ),
              ),
              if (i < 3) Divider(height: 1, color: divColor, indent: 18, endIndent: 18),
            ],
            Divider(height: 1, color: divColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBone(width: 90, height: 13, base: base),
                  ShimmerBone(width: 28, height: 26, base: base, radius: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
