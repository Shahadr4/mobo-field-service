import 'package:flutter/material.dart';

import '../../../core/const/app_colors.dart';
import '../../dashboard/model/dashboard_task_model.dart';
import '../../tasks/pages/task_detail_screen.dart';
import '../../tasks/services/task_service.dart';
import 'map_shared_widgets.dart';

/// ── List-view task card ───────────────────────────────────────────────────────

class MapListTaskCard extends StatefulWidget {
  final DashboardTask task;
  final bool isDark;
  final VoidCallback onLocate;

  const MapListTaskCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.onLocate,
  });

  @override
  State<MapListTaskCard> createState() => _MapListTaskCardState();
}

class _MapListTaskCardState extends State<MapListTaskCard> {
  bool _navLoading = false;

  Future<void> _openTask() async {
    if (_navLoading) return;
    setState(() => _navLoading = true);
    final task = await TaskService().fetchTaskById(widget.task.id);
    if (!mounted) return;
    setState(() => _navLoading = false);
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
    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Title + stage badge + priority
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.stageName.isNotEmpty)
                  MapStageBadge(label: task.stageName, color: color),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (i) => Icon(
                      i < task.priority ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 13,
                      color: i < task.priority
                          ? const Color(0xFFF59E0B)
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// Info rows
            if (task.partnerName.isNotEmpty)
              MapInfoRow(
                icon: Icons.person_outline_rounded,
                text: task.partnerName,
                isDark: isDark,
              ),
            if (task.deadline.isNotEmpty) ...[
              const SizedBox(height: 5),
              MapInfoRow(
                icon: Icons.calendar_today_outlined,
                text: task.deadline,
                isDark: isDark,
                textColor:
                    isOverdue(task.deadline) ? const Color(0xFFEF4444) : null,
              ),
            ],
            if (task.scheduledStart.isNotEmpty) ...[
              const SizedBox(height: 5),
              MapInfoRow(
                icon: Icons.access_time_rounded,
                text: task.scheduledStart +
                    (task.scheduledEnd.isNotEmpty
                        ? '  →  ${task.scheduledEnd}'
                        : ''),
                isDark: isDark,
              ),
            ],
            if (task.partnerAddress.isNotEmpty) ...[
              const SizedBox(height: 5),
              MapInfoRow(
                icon: Icons.location_on_outlined,
                text: task.partnerAddress,
                isDark: isDark,
                maxLines: 2,
              ),
            ],

            const SizedBox(height: 12),

            /// Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onLocate,
                    icon: const Icon(Icons.map_outlined, size: 14),
                    label: const Text('Show on Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openTask,
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('Open Task'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          minimumSize: const Size.fromHeight(0),
                        ),
                      ),
                      if (_navLoading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
