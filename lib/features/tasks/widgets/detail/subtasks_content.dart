import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await TaskService().fetchSubtasks(widget.task.id);
    if (mounted) setState(() { _subtasks = data; _loading = false; });
  }


  String _fmtDate(dynamic v) {
    if (v == null || v == false) return '';
    final s = v.toString();
    if (s.length < 10) return s;
    final parts = s.substring(0, 10).split('-');
    if (parts.length < 3) return s.substring(0, 10);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    return '${months[(m - 1).clamp(0, 11)]} $d, ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    if (_loading) return _SubtasksShimmer(isDark: isDark);

    final items = _subtasks ?? [];

    if (items.isEmpty) {
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

    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    return Column(
      children: [
        // ── Table header ─────────────────────────────────────────
        _TableHeader(isDark: isDark),

        // ── Scrollable rows ──────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (_, i) => _SubtaskRow(
              index:    i + 1,
              taskId:   (items[i]['id'] as num).toInt(),
              name:     items[i]['name']?.toString() ?? '',
              assignee: items[i]['user_names']?.toString() ?? '',
              deadline: _fmtDate(items[i]['date_deadline']),
              isDark:   isDark,
              isLast:   i == items.length - 1,
            ),
          ),
        ),

        // ── Pinned count footer ──────────────────────────────────
        Divider(height: 1, thickness: 1, color: divColor),
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Subtasks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),

                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final bool isDark;
  const _TableHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white54 : Colors.black54,
      letterSpacing: 0.3,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text('#', style: style)),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: Text('Task', style: style)),
              Expanded(flex: 3, child: Text('Assignee', style: style)),
              Expanded(flex: 3, child: Text('Deadline', style: style)),
              SizedBox(
                width: 52,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('View', style: style),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: divColor),
      ],
    );
  }
}

// ── Single table row ──────────────────────────────────────────────────────────

class _SubtaskRow extends StatefulWidget {
  final int index;
  final int taskId;
  final String name;
  final String assignee;
  final String deadline;
  final bool isDark;
  final bool isLast;

  const _SubtaskRow({
    required this.index,
    required this.taskId,
    required this.name,
    required this.assignee,
    required this.deadline,
    required this.isDark,
    required this.isLast,
  });

  @override
  State<_SubtaskRow> createState() => _SubtaskRowState();
}

class _SubtaskRowState extends State<_SubtaskRow> {
  bool _navigating = false;

  Future<void> _navigate() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    final task = await TaskService().fetchTaskById(widget.taskId);
    if (!mounted) return;
    setState(() => _navigating = false);
    if (task != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TaskDetailScreen(task: task),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = widget.isDark;
    final divColor  = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);
    final cellStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black87,
    );
    final subStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white54 : Colors.black45,
    );

    return Column(
      children: [
        InkWell(
          onTap: _navigate,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // index
                SizedBox(
                  width: 24,
                  child: Text(
                    '${widget.index}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // task name
                Expanded(
                  flex: 4,
                  child: Text(
                    widget.name.isNotEmpty ? widget.name : '—',
                    style: cellStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // assignee
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.assignee.isNotEmpty ? widget.assignee : '—',
                    style: subStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // deadline
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.deadline.isNotEmpty ? widget.deadline : '—',
                    style: subStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // view button
                SizedBox(
                  width: 52,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _navigating
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: primaryColor),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'View',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!widget.isLast)
          Divider(height: 1, thickness: 1, color: divColor, indent: 18, endIndent: 18),
      ],
    );
  }
}

// ── Shimmer ───────────────────────────────────────────────────────────────────

class _SubtasksShimmer extends StatelessWidget {
  final bool isDark;
  const _SubtasksShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base      = isDark ? const Color(0xFF252830) : const Color(0xFFE8E8EC);
    final highlight = isDark ? const Color(0xFF32353F) : const Color(0xFFF4F4F8);
    final divColor  = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        children: [
          // header
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
          // rows
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
    );
  }
}
