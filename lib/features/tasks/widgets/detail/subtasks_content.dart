import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:shimmer/shimmer.dart';

import '../../model/task_model.dart';
import '../../services/task_service.dart';
import '../../pages/task_detail_screen.dart';

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

  String _assignees(dynamic v) {
    if (v == false || v == null || v is! List) return '';
    return v
        .whereType<List>()
        .map((e) => e.length >= 2 ? e[1].toString() : '')
        .where((s) => s.isNotEmpty)
        .join(', ');
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
    final isDark   = widget.isDark;
    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

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

    return Column(
      children: [
        // ── Header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TASK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white54 : Colors.black54,
                  )),
              Text('VIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white54 : Colors.black54,
                  )),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: divColor),

        // ── Scrollable tiles ─────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            physics: const ClampingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (_, i) => _SubtaskTile(
              taskId:   (items[i]['id'] as num).toInt(),
              name:     items[i]['name']?.toString() ?? '',
              assignee: _assignees(items[i]['user_ids']),
              deadline: _fmtDate(items[i]['date_deadline']),
              isDark:   isDark,
            ),
          ),
        ),

        // ── Pinned count footer ──────────────────────────────────
        Divider(height: 1, thickness: 1, color: divColor),
        Container(
          color: primaryColor.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Subtasks',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${items.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubtaskTile extends StatefulWidget {
  final int taskId;
  final String name;
  final String assignee;
  final String deadline;
  final bool isDark;

  const _SubtaskTile({
    required this.taskId,
    required this.name,
    required this.assignee,
    required this.deadline,
    required this.isDark,
  });

  @override
  State<_SubtaskTile> createState() => _SubtaskTileState();
}

class _SubtaskTileState extends State<_SubtaskTile> {
  bool _loading = false;

  Future<void> _navigate() async {
    if (_loading) return;
    setState(() => _loading = true);
    final task = await TaskService().fetchTaskById(widget.taskId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (task != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TaskDetailScreen(task: task),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark;
    final subText = isDark ? Colors.white38 : Colors.black45;
    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    return Column(
      children: [
        InkWell(
          onTap: _navigate,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (widget.assignee.isNotEmpty || widget.deadline.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 2,
                          children: [
                            if (widget.assignee.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_outline_rounded,
                                      size: 12, color: subText),
                                  const SizedBox(width: 3),
                                  Text(widget.assignee,
                                      style: TextStyle(
                                          fontSize: 11, color: subText)),
                                ],
                              ),
                            if (widget.deadline.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 11, color: subText),
                                  const SizedBox(width: 3),
                                  Text(widget.deadline,
                                      style: TextStyle(
                                          fontSize: 11, color: subText)),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _loading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaryColor),
                      )
                    : Icon(Icons.remove_red_eye_outlined,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.black38),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: divColor,
            indent: 18, endIndent: 18),
      ],
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

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        itemCount: 3,
        itemBuilder: (context, i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 110,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
