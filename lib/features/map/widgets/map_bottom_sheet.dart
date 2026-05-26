import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/const/app_colors.dart';
import '../../dashboard/model/dashboard_task_model.dart';
import '../../tasks/pages/task_detail_screen.dart';
import '../../tasks/services/task_service.dart';
import '../provider/map_provider.dart';
import 'map_shared_widgets.dart';

/// ── Task list sheet (multiple tasks at a cluster) ─────────────────────────────

class MapTaskListSheet extends StatelessWidget {
  final TaskCluster cluster;
  final bool isDark;
  final VoidCallback onClose;

  const MapTaskListSheet({
    super.key,
    required this.cluster,
    required this.isDark,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedTask01,
                      color: primaryColor,
                      size: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cluster.tasks.length} Tasks at this location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (cluster.tasks.first.partnerAddress.isNotEmpty)
                        Text(
                          cluster.tasks.first.partnerAddress,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.07),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: cluster.tasks.length,
              separatorBuilder: (_, i) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, i) =>
                  MapClusterTile(task: cluster.tasks[i], isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Individual cluster tile ───────────────────────────────────────────────────

class MapClusterTile extends StatefulWidget {
  final DashboardTask task;
  final bool isDark;

  const MapClusterTile({super.key, required this.task, required this.isDark});

  @override
  State<MapClusterTile> createState() => _MapClusterTileState();
}

class _MapClusterTileState extends State<MapClusterTile> {
  bool _loading = false;

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    final task = await TaskService().fetchTaskById(widget.task.id);
    if (!mounted) return;
    setState(() => _loading = false);
    if (task != null) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = widget.isDark;
    final color = stageColor(task.stageName);

    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 12, top: 3),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (task.partnerName.isNotEmpty) ...[
                        Icon(Icons.person_outline_rounded,
                            size: 11,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            task.partnerName,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (task.deadline.isNotEmpty) ...[
                        Icon(Icons.calendar_today_outlined,
                            size: 11,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 3),
                        Text(
                          task.deadline,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (task.scheduledStart.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 11,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 3),
                        Text(
                          task.scheduledStart +
                              (task.scheduledEnd.isNotEmpty
                                  ? ' – ${task.scheduledEnd}'
                                  : ''),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primaryColor),
                  )
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Open',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
