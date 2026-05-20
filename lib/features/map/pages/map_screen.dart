import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../dashboard/model/dashboard_task_model.dart';
import '../../dashboard/services/location_map_service.dart';
import '../../tasks/pages/task_detail_screen.dart';
import '../../tasks/services/task_service.dart';
import '../provider/map_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _sheetAnim;
  late final Animation<Offset> _sheetSlide;

  @override
  void initState() {
    super.initState();
    _sheetAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetAnim, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapProvider>();
      if (provider.state == MapLoadState.idle) provider.load();
    });
  }

  @override
  void dispose() {
    _sheetAnim.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _selectCluster(TaskCluster? cluster, MapProvider provider) {
    provider.selectCluster(cluster);
    if (cluster != null) {
      _sheetAnim.forward();
    } else {
      _sheetAnim.reverse();
    }
  }

  /// Called from the task list: switch to map and fly to the pin
  void _jumpToTask(DashboardTask task, MapProvider provider) {
    provider.setViewMode(MapViewMode.map);

    // Find the cluster this task belongs to
    final cluster = provider.clusters.firstWhere(
      (c) => c.tasks.any((t) => t.id == task.id),
      orElse: () => TaskCluster(
        position: LatLng(task.partnerLat, task.partnerLng),
        tasks: [task],
      ),
    );

    // Animate after the view has switched
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(cluster.position, 15);
      _selectCluster(cluster, provider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, provider, _) {
        if (provider.state == MapLoadState.loaded && provider.pendingJumpTaskId != null) {
          final taskId = provider.pendingJumpTaskId!;
          final matches = provider.tasks.where((t) => t.id == taskId);
          if (matches.isNotEmpty) {
            final task = matches.first;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                provider.setPendingJumpTaskId(null);
                _jumpToTask(task, provider);
              }
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                provider.setPendingJumpTaskId(null);
              }
            });
          }
        }

        switch (provider.state) {
          case MapLoadState.idle:
          case MapLoadState.loading:
            return _buildLoading();
          case MapLoadState.permissionDenied:
            return _buildPermissionDenied(provider);
          case MapLoadState.error:
            return _buildError(provider);
          case MapLoadState.loaded:
            return provider.isListMode
                ? _buildListView(provider)
                : _buildMapView(provider);
        }
      },
    );
  }

  // ── Loading / error / permission ─────────────────────────────────────────

  Widget _buildLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 16),
          Text(
            'Fetching your location…',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied(MapProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedLocation01,
              size: 64,
              color: Colors.grey[400]!,
            ),
            const SizedBox(height: 16),
            const Text('Location Access Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Enable location permission to view nearby tasks on the map.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(MapProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[300]),
          const SizedBox(height: 12),
          const Text('Something went wrong', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: provider.refresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Map view ─────────────────────────────────────────────────────────────

  Widget _buildMapView(MapProvider provider) {
    final userLatLng = provider.userLatLng!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clusters = provider.clusters;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLatLng,
            initialZoom: 13,
            minZoom: 4,
            maxZoom: 18,
            onTap: (tap, pos) => _selectCluster(null, provider),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.mobo_feild_service',
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: userLatLng,
                  radius: 10000,
                  useRadiusInMeter: true,
                  color: primaryColor.withValues(alpha: 0.07),
                  borderColor: primaryColor.withValues(alpha: 0.4),
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),
            if (provider.routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: provider.routePoints,
                    color: primaryColor,
                    strokeWidth: 4.5,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                ...clusters.map((c) => _buildClusterPin(c, provider)),
                _buildUserDot(userLatLng),
              ],
            ),
          ],
        ),

        // Top bar
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _buildTopBar(provider, isDark),
        ),

        // My-location FAB
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: provider.selectedCluster != null ? 280 : 24,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'map_locate',
            onPressed: () => _mapController.move(userLatLng, 13),
            backgroundColor: Colors.white,
            foregroundColor: primaryColor,
            elevation: 4,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),

        // Cluster bottom sheet
        SlideTransition(
          position: _sheetSlide,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: provider.selectedCluster != null
                ? _ClusterSingleTaskSwiper(
                    cluster: provider.selectedCluster!,
                    isDark: isDark,
                    onClose: () => _selectCluster(null, provider),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  // ── List view ─────────────────────────────────────────────────────────────

  Widget _buildListView(MapProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Top bar (same style, different mode)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _buildTopBar(provider, isDark),
        ),
        const SizedBox(height: 8),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2028) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: provider.setSearchQuery,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search tasks by name...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.clear_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                            size: 18,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),

                  child: Center(
                    child: PaginationControls(
                      canGoToPreviousPage: provider.currentPage > 1,
                      canGoToNextPage: provider.currentPage < provider.totalPages,
                      onPreviousPage: () => provider.setPage(provider.currentPage - 1),
                      onNextPage: () => provider.setPage(provider.currentPage + 1),
                      paginationText: provider.paginationText,
                      isDark: isDark,
                      theme: Theme.of(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),

        // Task list
        Expanded(
          child: provider.paginatedTasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.searchQuery.isNotEmpty
                            ? Icons.search_off_rounded
                            : Icons.location_off_outlined,
                        size: 56,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        provider.searchQuery.isNotEmpty
                            ? 'No results match your search'
                            : 'No tasks found',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                      if (provider.searchQuery.isEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'No tasks assigned to you have locations',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white24 : Colors.black38,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: provider.paginatedTasks.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ListTaskCard(
                    task: provider.paginatedTasks[i],
                    isDark: isDark,
                    onLocate: () => _jumpToTask(provider.paginatedTasks[i], provider),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Top bar (shared between map & list view) ──────────────────────────────

  Widget _buildTopBar(MapProvider provider, bool isDark) {
    final total = provider.filteredTasks.length;
    final isMap = !provider.isListMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMapsLocation01,
                color: primaryColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'My Tasks',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  total == 0
                      ? 'No tasks assigned'
                      : '$total task${total == 1 ? '' : 's'} assigned',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Map / List toggle
          _ViewToggle(
            isMap: isMap,
            isDark: isDark,
            onToggle: () => provider.setViewMode(
              isMap ? MapViewMode.list : MapViewMode.map,
            ),
          ),
          const SizedBox(width: 6),
          // Refresh
          GestureDetector(
            onTap: provider.refresh,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.refresh_rounded,
                  size: 17,
                  color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  // ── Markers ──────────────────────────────────────────────────────────────

  Marker _buildUserDot(LatLng pos) {
    return Marker(
      point: pos,
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2563EB),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildClusterPin(TaskCluster cluster, MapProvider provider) {
    final isSelected = provider.selectedCluster?.position.latitude ==
            cluster.position.latitude &&
        provider.selectedCluster?.position.longitude ==
            cluster.position.longitude;
    final count = cluster.tasks.length;

    return Marker(
      point: cluster.position,
      width: isSelected ? 56 : 48,
      height: isSelected ? 70 : 60,
      alignment: const Alignment(0, -1),
      child: GestureDetector(
        onTap: () {
          _selectCluster(cluster, provider);
          _mapController.move(cluster.position, 15);
        },
        child: AnimatedScale(
          scale: isSelected ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: _PinShape(
            isSelected: isSelected,
            badge: count > 1 ? count : null,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedTask01,
              size: isSelected ? 20 : 17,
              color: isSelected ? Colors.white : primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── View toggle button ────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool isMap;
  final bool isDark;
  final VoidCallback onToggle;

  const _ViewToggle({
    required this.isMap,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMap ? Icons.list_rounded : Icons.map_outlined,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              isMap ? 'List' : 'Map',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── List view task card ───────────────────────────────────────────────────────

class _ListTaskCard extends StatefulWidget {
  final DashboardTask task;
  final bool isDark;
  final VoidCallback onLocate;

  const _ListTaskCard({
    required this.task,
    required this.isDark,
    required this.onLocate,
  });

  @override
  State<_ListTaskCard> createState() => _ListTaskCardState();
}

class _ListTaskCardState extends State<_ListTaskCard> {
  bool _navLoading = false;

  Color _stageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('progress') || s.contains('ongoing')) return const Color(0xFF06B6D4);
    if (s.contains('done') || s.contains('complete')) return const Color(0xFF22C55E);
    if (s.contains('cancel')) return const Color(0xFFEF4444);
    if (s.contains('plan')) return const Color(0xFFF59E0B);
    if (s.contains('new')) return const Color(0xFF3B82F6);
    return primaryColor;
  }

  bool _isOverdue(String deadline) {
    final d = DateTime.tryParse(deadline);
    return d != null && d.isBefore(DateTime.now());
  }

  Future<void> _openTask() async {
    if (_navLoading) return;
    setState(() => _navLoading = true);
    final task = await TaskService().fetchTaskById(widget.task.id);
    if (!mounted) return;
    setState(() => _navLoading = false);
    if (task != null) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = widget.isDark;
    final stageColor = _stageColor(task.stageName);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stage badge + priority
                Row(
                  children: [
                    // Task name
                    Text(
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
                    const Spacer(),
                    if (task.stageName.isNotEmpty)
                      _StageBadge(label: task.stageName, color: stageColor),
                    SizedBox(width: 10,),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (i) => Icon(
                          i < task.priority
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
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

                // Info rows
                if (task.partnerName.isNotEmpty)
                  _Row(
                    icon: Icons.person_outline_rounded,
                    text: task.partnerName,
                    isDark: isDark,
                  ),
                if (task.deadline.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _Row(
                    icon: Icons.calendar_today_outlined,
                    text: task.deadline,
                    isDark: isDark,
                    textColor: _isOverdue(task.deadline)
                        ? const Color(0xFFEF4444)
                        : null,
                  ),
                ],
                if (task.scheduledStart.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _Row(
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
                  _Row(
                    icon: Icons.location_on_outlined,
                    text: task.partnerAddress,
                    isDark: isDark,
                    maxLines: 2,
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons row
                Row(
                  children: [
                    // Show on map button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onLocate,
                        icon: const Icon(Icons.map_outlined, size: 14),
                        label: const Text('Show on Map'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(
                              color: primaryColor.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Open task button
                    Expanded(
                      child: Stack(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _openTask,
                            icon: const Icon(Icons.open_in_new_rounded,
                                size: 14),
                            label: const Text('Open Task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 9),
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
                                  color:
                                      primaryColor.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
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
        ],
      ),
    );
  }
}

// ── Pin shape ─────────────────────────────────────────────────────────────────

class _PinShape extends StatelessWidget {
  final bool isSelected;
  final Widget child;
  final int? badge;

  const _PinShape({
    required this.isSelected,
    required this.child,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: _PinPainter(isSelected: isSelected),
          child: Padding(
            padding: EdgeInsets.only(bottom: isSelected ? 18 : 15),
            child: Center(child: child),
          ),
        ),
        if (badge != null && badge! > 1)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  badge! > 9 ? '9+' : '$badge',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PinPainter extends CustomPainter {
  final bool isSelected;
  const _PinPainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final fillColor = isSelected ? primaryColor : Colors.white;
    final paint = Paint()..color = fillColor..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 0 : 2.5;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final cx = size.width / 2;
    final headR = size.width * 0.42;
    final tipY = size.height - 2;
    final headCY = headR + (isSelected ? 2.0 : 1.5);

    final path = ui.Path();
    path.addOval(Rect.fromCircle(center: Offset(cx, headCY), radius: headR));
    path.moveTo(cx - headR * 0.35, headCY + headR * 0.75);
    path.quadraticBezierTo(
        cx, tipY + 2, cx + headR * 0.35, headCY + headR * 0.75);
    path.close();

    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(path, paint);
    if (!isSelected) canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.isSelected != isSelected;
}

// ── Single task bottom card ───────────────────────────────────────────────────

class _SingleTaskCard extends StatefulWidget {
  final DashboardTask task;
  final bool isDark;
  final VoidCallback onClose;
  final int? index;
  final int? totalCount;

  const _SingleTaskCard({
    required this.task,
    required this.isDark,
    required this.onClose,
    this.index,
    this.totalCount,
  });

  @override
  State<_SingleTaskCard> createState() => _SingleTaskCardState();
}

class _SingleTaskCardState extends State<_SingleTaskCard> {
  bool _navLoading = false;

  Future<void> _launchNavigation() async {
    Uri uri;
    if (widget.task.partnerLat != 0.0 && widget.task.partnerLng != 0.0) {
      uri = Uri.parse('google.navigation:q=${widget.task.partnerLat},${widget.task.partnerLng}&mode=d');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${widget.task.partnerLat},${widget.task.partnerLng}');
    } else if (widget.task.partnerAddress.isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(widget.task.partnerAddress)}');
    } else {
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTask() async {
    if (_navLoading) return;
    setState(() => _navLoading = true);
    final task = await TaskService().fetchTaskById(widget.task.id);
    if (!mounted) return;
    setState(() => _navLoading = false);
    if (task != null) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)));
    }
  }

  Color _stageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('progress') || s.contains('ongoing')) return const Color(0xFF06B6D4);
    if (s.contains('done') || s.contains('complete')) return const Color(0xFF22C55E);
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
    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final tileBg =
        isDark ? const Color(0xFF2A2D36) : const Color(0xFFF0F0F0);

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stage + priority + close
                Row(
                  children: [
                    if (widget.index != null && widget.totalCount != null && widget.totalCount! > 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1),
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
                      _StageBadge(label: task.stageName, color: stageColor),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (i) => Icon(
                          i < task.priority
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
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
                            color:
                                isDark ? Colors.white54 : Colors.black45),
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
                      _InfoChip(
                          icon: Icons.person_outline_rounded,
                          text: task.partnerName,
                          isDark: isDark),
                    if (task.deadline.isNotEmpty)
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        text: task.deadline,
                        isDark: isDark,
                        accent: _isOverdue(task.deadline),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _OpenTaskButton(onTap: _openTask, loading: _navLoading),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _NavigateButton(onTap: _launchNavigation),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isOverdue(String deadline) {
    final d = DateTime.tryParse(deadline);
    return d != null && d.isBefore(DateTime.now());
  }


}

class _ClusterSingleTaskSwiper extends StatefulWidget {
  final TaskCluster cluster;
  final bool isDark;
  final VoidCallback onClose;

  const _ClusterSingleTaskSwiper({
    required this.cluster,
    required this.isDark,
    required this.onClose,
  });

  @override
  State<_ClusterSingleTaskSwiper> createState() => _ClusterSingleTaskSwiperState();
}

class _ClusterSingleTaskSwiperState extends State<_ClusterSingleTaskSwiper> {
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
    if (_currentPage != page) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  void didUpdateWidget(_ClusterSingleTaskSwiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cluster.position.latitude != widget.cluster.position.latitude ||
        oldWidget.cluster.position.longitude != widget.cluster.position.longitude) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  double _calculateCardHeight(DashboardTask task) {
    double height = 154.0; // Base height for margins, padding, buttons, and stage row with safety margins
    
    // Title height estimation
    if (task.name.length > 28) {
      height += 46.0; // 2 lines
    } else {
      height += 24.0; // 1 line
    }

    // Chips height estimation
    int chipCount = 0;
    if (task.partnerName.isNotEmpty) chipCount++;
    if (task.deadline.isNotEmpty) chipCount++;
    if (task.partnerAddress.isNotEmpty) chipCount++;
    if (task.scheduledStart.isNotEmpty || task.scheduledEnd.isNotEmpty) {
      // Long date/time chip takes up equivalent of 2 chips of space
      chipCount += 2;
    }

    if (chipCount == 0) {
      height += 0.0;
    } else if (chipCount <= 2) {
      height += 40.0;
    } else if (chipCount <= 4) {
      height += 80.0;
    } else {
      height += 120.0;
    }

    return height + 24.0; // Safe layout density buffer
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.cluster.tasks;
    if (tasks.isEmpty) return const SizedBox.shrink();

    if (tasks.length == 1) {
      return _SingleTaskCard(
        task: tasks.first,
        isDark: widget.isDark,
        onClose: widget.onClose,
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
          builder: (context, height, child) {
            return SizedBox(
              height: height,
              child: child,
            );
          },
          child: PageView.builder(
            controller: _pageController,
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              return Align(
                alignment: Alignment.topCenter,
                child: _SingleTaskCard(
                  task: tasks[index],
                  isDark: widget.isDark,
                  onClose: widget.onClose,
                  index: index,
                  totalCount: tasks.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Multi-task cluster sheet ──────────────────────────────────────────────────

class _TaskListSheet extends StatelessWidget {
  final TaskCluster cluster;
  final bool isDark;
  final VoidCallback onClose;

  const _TaskListSheet({
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
                        size: 17),
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
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38),
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
                    child: Icon(Icons.close_rounded,
                        size: 15,
                        color: isDark ? Colors.white54 : Colors.black45),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.07)),
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
                  _ClusterTile(task: cluster.tasks[i], isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClusterTile extends StatefulWidget {
  final DashboardTask task;
  final bool isDark;

  const _ClusterTile({required this.task, required this.isDark});

  @override
  State<_ClusterTile> createState() => _ClusterTileState();
}

class _ClusterTileState extends State<_ClusterTile> {
  bool _loading = false;

  Color _stageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('progress') || s.contains('ongoing')) return const Color(0xFF06B6D4);
    if (s.contains('done') || s.contains('complete')) return const Color(0xFF22C55E);
    if (s.contains('cancel')) return const Color(0xFFEF4444);
    if (s.contains('plan')) return const Color(0xFFF59E0B);
    if (s.contains('new')) return const Color(0xFF3B82F6);
    return primaryColor;
  }

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    final task = await TaskService().fetchTaskById(widget.task.id);
    if (!mounted) return;
    setState(() => _loading = false);
    if (task != null) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = widget.isDark;
    final stageColor = _stageColor(task.stageName);

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
              decoration:
                  BoxDecoration(color: stageColor, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (task.partnerName.isNotEmpty) ...[
                        Icon(Icons.person_outline_rounded,
                            size: 11,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(task.partnerName,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (task.deadline.isNotEmpty) ...[
                        Icon(Icons.calendar_today_outlined,
                            size: 11,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 3),
                        Text(task.deadline,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                      ],
                    ],
                  ),
                  if (task.scheduledStart.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
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
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black54)),
                    ]),
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
                        strokeWidth: 2, color: primaryColor))
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Open',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor)),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final Color? textColor;
  final int maxLines;

  const _Row({
    required this.icon,
    required this.text,
    required this.isDark,
    this.textColor,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? (isDark ? Colors.white54 : Colors.black54);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: color),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _StageBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StageBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final bool accent;
  final int maxLines;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.isDark,
    this.accent = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = accent
        ? const Color(0xFFEF4444)
        : (isDark ? Colors.white70 : Colors.black54);
    final bgColor = accent
        ? const Color(0xFFEF4444).withValues(alpha: 0.08)
        : (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.w500),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _OpenTaskButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;

  const _OpenTaskButton({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Stack(
        children: [
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded, size: 16),
                SizedBox(width: 6),
                Text('Open Task',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          if (loading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavigateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NavigateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: primaryColor, width: 1.5),
          foregroundColor: primaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(44),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.navigation_rounded, size: 16),
            SizedBox(width: 4),
            Text('Open Map',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
