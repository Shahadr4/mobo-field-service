import 'package:flutter/material.dart';

import '../../../core/const/app_colors.dart';
import '../../dashboard/model/dashboard_task_model.dart';
import '../../tasks/pages/task_detail_screen.dart';
import '../../tasks/services/task_service.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import 'map_shared_widgets.dart';

/// ── Single task bottom card ───────────────────────────────────────────────────

class MapSingleTaskCard extends StatefulWidget {
  final DashboardTask task;
  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback? onStartNavigation;
  final int? index;
  final int? totalCount;

  const MapSingleTaskCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.onClose,
    this.onStartNavigation,
    this.index,
    this.totalCount,
  });

  @override
  State<MapSingleTaskCard> createState() => _MapSingleTaskCardState();
}

class _MapSingleTaskCardState extends State<MapSingleTaskCard> {
  bool _navLoading = false;

  void _startNavigation() {
    final hasLocation = (widget.task.partnerLat != 0.0 &&
            widget.task.partnerLng != 0.0) ||
        widget.task.partnerAddress.isNotEmpty;
    if (!hasLocation) {
      CustomSnackbar.showWarning(context, 'No location available for this task');
      return;
    }
    if (widget.task.partnerLat == 0.0 && widget.task.partnerLng == 0.0) {
      CustomSnackbar.showInfo(
          context, 'Task has no coordinates — open in Google Maps instead');
      return;
    }
    widget.onStartNavigation?.call();
  }

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
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Stage + priority + close row
            Row(
              children: [
                if (widget.index != null &&
                    widget.totalCount != null &&
                    widget.totalCount! > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      '${widget.index! + 1} of ${widget.totalCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (task.stageName.isNotEmpty)
                  MapStageBadge(label: task.stageName, color: color),
                const SizedBox(width: 8),
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
                const Spacer(),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 15,
                        color: isDark ? Colors.white54 : Colors.black45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (task.partnerName.isNotEmpty)
                  MapInfoChip(
                    icon: Icons.person_outline_rounded,
                    text: task.partnerName,
                    isDark: isDark,
                  ),
                if (task.deadline.isNotEmpty)
                  MapInfoChip(
                    icon: Icons.calendar_today_outlined,
                    text: task.deadline,
                    isDark: isDark,
                    accent: isOverdue(task.deadline),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: MapOpenTaskButton(onTap: _openTask, loading: _navLoading),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: MapNavigateButton(onTap: _startNavigation),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ── Cluster swiper (multiple tasks at same pin) ───────────────────────────────

class MapClusterSwiper extends StatefulWidget {
  final List<DashboardTask> tasks;
  final bool isDark;
  final VoidCallback onClose;
  final void Function(DashboardTask)? onStartNavigation;

  const MapClusterSwiper({
    super.key,
    required this.tasks,
    required this.isDark,
    required this.onClose,
    this.onStartNavigation,
  });

  @override
  State<MapClusterSwiper> createState() => _MapClusterSwiperState();
}

class _MapClusterSwiperState extends State<MapClusterSwiper> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    if (!mounted) return;
    final page = _pageController.page?.round() ?? 0;
    if (_currentPage != page) setState(() => _currentPage = page);
  }

  double _calculateCardHeight(DashboardTask task) {
    double height = 154.0;

    if (task.name.length > 28) {
      height += 46.0;
    } else {
      height += 24.0;
    }

    int chipCount = 0;
    if (task.partnerName.isNotEmpty) chipCount++;
    if (task.deadline.isNotEmpty) chipCount++;
    if (task.partnerAddress.isNotEmpty) chipCount++;
    if (task.scheduledStart.isNotEmpty || task.scheduledEnd.isNotEmpty) chipCount += 2;

    if (chipCount <= 0) {
      height += 0.0;
    } else if (chipCount <= 2) {
      height += 40.0;
    } else if (chipCount <= 4) {
      height += 80.0;
    } else {
      height += 120.0;
    }

    return height + 24.0;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    if (tasks.isEmpty) return const SizedBox.shrink();

    if (tasks.length == 1) {
      return MapSingleTaskCard(
        task: tasks.first,
        isDark: widget.isDark,
        onClose: widget.onClose,
        onStartNavigation: widget.onStartNavigation == null
            ? null
            : () => widget.onStartNavigation!(tasks.first),
      );
    }

    final activeTask = tasks[_currentPage < tasks.length ? _currentPage : 0];
    final activeHeight = _calculateCardHeight(activeTask);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          tween: Tween<double>(begin: activeHeight, end: activeHeight),
          builder: (context, height, child) =>
              SizedBox(height: height, child: child),
          child: PageView.builder(
            controller: _pageController,
            itemCount: tasks.length,
            itemBuilder: (context, index) => Align(
              alignment: Alignment.topCenter,
              child: MapSingleTaskCard(
                task: tasks[index],
                isDark: widget.isDark,
                onClose: widget.onClose,
                index: index,
                totalCount: tasks.length,
                onStartNavigation: widget.onStartNavigation == null
                    ? null
                    : () => widget.onStartNavigation!(tasks[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
