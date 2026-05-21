import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../model/dashboard_task_model.dart';
import '../provider/dashboard_task_provider.dart';
import '../services/location_map_service.dart';
import '../../tasks/services/task_service.dart';
import '../../tasks/pages/task_detail_screen.dart';

class DashboardTaskTabs extends StatelessWidget {
  const DashboardTaskTabs({super.key});

  @override
  Widget build(BuildContext context) => const _DashboardTaskTabsView();
}

class _DashboardTaskTabsView extends StatelessWidget {
  const _DashboardTaskTabsView();

  Future<void> _onRefresh(BuildContext context) async {
    final provider = context.read<DashboardTaskProvider>();
    await provider.selectTabAndRefresh(0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<DashboardTaskProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                'My Tasks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Tab bar ──────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Row(
            children: List.generate(
              DashboardTaskProvider.tabs.length,
              (i) => _TabChip(
                label: DashboardTaskProvider.tabs[i],
                selected: p.tabIndex == i,
                isDark: isDark,
                onTap: () => context.read<DashboardTaskProvider>().selectTab(i),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Content ──────────────────────────────────────────────
        _TabContent(p: p, isDark: isDark),
        const SizedBox(height: 16),
      ],
    );
  }
}



class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.black
              : (isDark ? const Color(0xFF2A2D36) : const Color(0xFFF5F5F7)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (isDark ? Colors.white24 : const Color(0xFFCCCCCC)),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  final DashboardTaskProvider p;
  final bool isDark;

  const _TabContent({required this.p, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (p.isLoading) {
      return SizedBox(
        height: 300,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => _ShimmerTaskCard(isDark: isDark),
        ),
      );
    }

    if (p.tasks.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/lotties/empty ghost.json',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 4),
              Text(
                'No tasks found',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nothing here for this stage',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        itemCount: p.tasks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _DashboardTaskCard(
          key: ValueKey(p.tasks[i].id),
          task: p.tasks[i],
          isDark: isDark,
        ),
      ),
    );
  }
}

class _ShimmerTaskCard extends StatelessWidget {
  final bool isDark;
  const _ShimmerTaskCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? const Color(0xFF2A2D36) : const Color(0xFFE0E0E0);
    final highlight = isDark ? const Color(0xFF3A3D46) : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: SizedBox(
        width: 180,
        height: 300,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map image placeholder
              Container(
                height: 140,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stage badge row
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 44,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Title line 1
                      Container(
                        width: double.infinity,
                        height: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 6),
                      // Title line 2
                      Container(
                        width: 120,
                        height: 14,
                        color: Colors.white,
                      ),
                      const Spacer(),
                      // Time row
                      Container(
                        width: 140,
                        height: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      // Location row
                      Container(
                        width: 110,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
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

class _DashboardTaskCard extends StatefulWidget {
  final DashboardTask task;
  final bool isDark;

  const _DashboardTaskCard({super.key, required this.task, required this.isDark});

  @override
  State<_DashboardTaskCard> createState() => _DashboardTaskCardState();
}

class _DashboardTaskCardState extends State<_DashboardTaskCard> {
  MapTileInfo? _tileInfo;
  bool _mapLoading = true;
  bool _navLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  Future<void> _loadMap() async {
    final info = await LocationMapService.getTileInfo(widget.task.partnerAddress);
    if (mounted) setState(() { _tileInfo = info; _mapLoading = false; });
  }

  Future<void> _navigateToDetail() async {
    if (_navLoading) return;
    setState(() => _navLoading = true);
    final provider = context.read<DashboardTaskProvider>();
    final task = await TaskService().fetchTaskById(
      widget.task.id,
      includeWarranty:  provider.warrantyEnabled,
      includeWorksheet: provider.worksheetEnabled,
    );
    if (!mounted) return;
    setState(() => _navLoading = false);
    if (task != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TaskDetailScreen(task: task),
      ));
    }
  }


  Color _stageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('progress') || s.contains('ongoing')) return const Color(0xFF06B6D4);
    if (s.contains('done') || s.contains('complete')) return const Color(0xFF22C55E);
    if (s.contains('approve')) return const Color(0xFF22C55E);
    if (s.contains('cancel')) return const Color(0xFFEF4444);
    if (s.contains('plan')) return const Color(0xFFF59E0B);
    if (s.contains('new')) return const Color(0xFF3B82F6);
    return primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = widget.isDark;
    final stageColor = _stageColor(task.stageName);



    return GestureDetector(
      onTap: _navigateToDetail,
      child: SizedBox(
        width: 180,
        height: 300,
        child: Stack(
        children: [
          Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2028) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Map image ─────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: _buildMapImage(isDark, stageColor),
              ),
            ),
            // ── Info ──────────────────────────────────────────────
            Expanded(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stage badge + priority star
                  Row(
                    children: [
                      if (task.stageName.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: stageColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              task.stageName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: stageColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) => Icon(
                          i < task.priority
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color: i < task.priority
                              ? const Color(0xFFF59E0B)
                              : (isDark ? Colors.white24 : Colors.black26),
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  // Task name
                  Text(
                    task.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Planned time: "9:00 AM → 11:00 AM"
                  if (task.scheduledStart.isNotEmpty || task.scheduledEnd.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 12,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            [
                              if (task.scheduledStart.isNotEmpty) task.scheduledStart,
                              if (task.scheduledEnd.isNotEmpty) task.scheduledEnd,
                            ].join(' → '),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (task.scheduledStart.isNotEmpty || task.scheduledEnd.isNotEmpty)
                    const SizedBox(height: 5),
                  // Location line
                  if (task.partnerName.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            task.partnerName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            ),
          ],
        ),
          ),
          // Loading overlay while fetching task detail
          if (_navLoading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildMapImage(bool isDark, Color stageColor) {
    final bg = isDark ? const Color(0xFF2A2D36) : const Color(0xFFF0F0F0);

    if (_mapLoading) {
      return Container(
        color: bg,
        child: const Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
          ),
        ),
      );
    }

    if (_tileInfo == null) {
      return Container(
        color: bg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 28,
                color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 4),
            Text('No location',
                style: TextStyle(fontSize: 10,
                    color: isDark ? Colors.white24 : Colors.black26)),
          ],
        ),
      );
    }

    // 3×3 grid of 256px tiles clipped to card width
    // Center tile contains the pin location
    final info = _tileInfo!;
    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 3×3 tile grid
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (row) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (col) {
                    final dx = col - 1;
                    final dy = row - 1;
                    return CachedNetworkImage(
                      imageUrl: info.tileUrl(dx, dy),
                      width: 256,
                      height: 256,
                      fit: BoxFit.cover,
                      httpHeaders: const {'User-Agent': 'MoboFieldService/1.0'},
                      placeholder: (_, _) => Container(
                          width: 256, height: 256, color: bg),
                      errorWidget: (_, _, _) => Container(
                          width: 256, height: 256, color: bg),
                    );
                  }),
                );
              }),
            ),
            // Pin at exact pixel position within 3×3 grid
            Positioned(
              left: 256 + info.pixelOffsetX - 12,
              top: 256 + info.pixelOffsetY - 28,
              child: Icon(Icons.location_on_rounded,
                  size: 28, color: primaryColor,
                  shadows: const [
                    Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}
