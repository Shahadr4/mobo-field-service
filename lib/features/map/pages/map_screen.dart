import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../dashboard/model/dashboard_task_model.dart';
import '../provider/map_provider.dart';
import '../widgets/map_list_task_card.dart';
import '../widgets/map_nav_widgets.dart';
import '../widgets/map_pin.dart';
import '../widgets/map_task_card.dart';
import '../widgets/map_top_bar.dart';

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

  MapProvider? _providerRef;
  LatLng? _lastFollowedPos;
  bool _arrivalShown = false;

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
      _providerRef = provider;
      provider.addListener(_onProviderChange);
      if (provider.state == MapLoadState.idle) provider.load();
    });
  }

  void _onProviderChange() {
    final provider = _providerRef;
    if (provider == null || !mounted) return;

    if (provider.isNavigating && provider.userLatLng != null) {
      final p = provider.userLatLng!;
      if (_lastFollowedPos == null ||
          _lastFollowedPos!.latitude != p.latitude ||
          _lastFollowedPos!.longitude != p.longitude) {
        _lastFollowedPos = p;
        try {
          _mapController.move(p, 17);
        } catch (_) {}
      }
      if (provider.arrived && !_arrivalShown) {
        _arrivalShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showArrivalDialog(provider);
        });
      }
    } else {
      _lastFollowedPos = null;
      _arrivalShown = false;
    }
  }

  void _showArrivalDialog(MapProvider provider) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.flag_rounded, color: Color(0xFF22C55E), size: 40),
          title: const Text("You've arrived"),
          content: Text(
            provider.navTask?.partnerAddress.isNotEmpty == true
                ? provider.navTask!.partnerAddress
                : 'You are at the destination.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                provider.stopNavigation();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _providerRef?.removeListener(_onProviderChange);
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

  void _jumpToTask(DashboardTask task, MapProvider provider) {
    provider.setViewMode(MapViewMode.map);

    final lat = task.partnerLat;
    final lng = task.partnerLng;
    if (!lat.isFinite || !lng.isFinite) return;

    final cluster = provider.clusters.firstWhere(
      (c) => c.tasks.any((t) => t.id == task.id),
      orElse: () => TaskCluster(
        position: LatLng(lat, lng),
        tasks: [task],
      ),
    );

    final pos = cluster.position;
    if (!pos.latitude.isFinite || !pos.longitude.isFinite) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(pos, 15);
      } catch (_) {}
      _selectCluster(cluster, provider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, provider, _) {
        if (provider.state == MapLoadState.loaded &&
            provider.pendingJumpTaskId != null) {
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
              if (mounted) provider.setPendingJumpTaskId(null);
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

  /// ── Loading / error / permission

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
            const Text(
              'Location Access Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
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

  /// ── Map view

  Widget _buildMapView(MapProvider provider) {
    final userLatLng = provider.userLatLng!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clusters = provider.clusters;
    final isNav = provider.isNavigating;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLatLng,
            initialZoom: 13,
            minZoom: 4,
            maxZoom: 18,
            onTap: (tap, pos) {
              if (!isNav) _selectCluster(null, provider);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.mobo_feild_service',
            ),
            if (!isNav)
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
                    strokeWidth: isNav ? 6 : 4.5,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (!isNav)
                  ...clusters.map((c) => _buildClusterMarker(c, provider)),
                if (isNav && provider.navDestination != null)
                  _buildDestinationMarker(provider.navDestination!),
                _buildUserMarker(
                    userLatLng, heading: isNav ? provider.userHeading : null),
              ],
            ),
          ],
        ),

        /// Top bar (hidden in nav mode)
        if (!isNav)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: MapTopBar(provider: provider, isDark: isDark),
          ),

        /// Nav banner
        if (isNav)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: MapNavTopBanner(
              task: provider.navTask,
              distanceMeters: provider.routeDistanceMeters,
              durationSeconds: provider.routeDurationSeconds,
              isDark: isDark,
              onClose: () => provider.stopNavigation(),
            ),
          ),

        /// My-location FAB
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: isNav
              ? 110
              : (provider.selectedCluster != null ? 280 : 24),
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'map_locate',
            onPressed: () {
              try {
                _mapController.move(userLatLng, isNav ? 17 : 13);
              } catch (_) {}
            },
            backgroundColor: Colors.white,
            foregroundColor: primaryColor,
            elevation: 4,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),

        /// Nav bottom bar
        if (isNav)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: MapNavBottomBar(
              isDark: isDark,
              onStop: () => provider.stopNavigation(),
              onExternal: () => _openExternalNav(provider),
            ),
          ),

        /// Cluster bottom sheet
        if (!isNav)
          SlideTransition(
            position: _sheetSlide,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: provider.selectedCluster != null
                  ? MapClusterSwiper(
                      tasks: provider.selectedCluster!.tasks,
                      isDark: isDark,
                      onClose: () => _selectCluster(null, provider),
                      onStartNavigation: (task) =>
                          _startNavigation(task, provider),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  /// ── List view

  Widget _buildListView(MapProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: MapTopBar(provider: provider, isDark: isDark),
        ),
        const SizedBox(height: 8),

        /// Search bar
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
                    canGoToNextPage:
                        provider.currentPage < provider.totalPages,
                    onPreviousPage: () =>
                        provider.setPage(provider.currentPage - 1),
                    onNextPage: () =>
                        provider.setPage(provider.currentPage + 1),
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

        /// Task list
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
                  itemBuilder: (context, i) => MapListTaskCard(
                    task: provider.paginatedTasks[i],
                    isDark: isDark,
                    onLocate: () =>
                        _jumpToTask(provider.paginatedTasks[i], provider),
                  ),
                ),
        ),
      ],
    );
  }

  /// ── Marker builders
  Marker _buildUserMarker(LatLng pos, {double? heading}) {
    return Marker(
      point: pos,
      width: 60,
      height: 60,
      child: MapUserDot(heading: heading),
    );
  }

  Marker _buildDestinationMarker(LatLng pos) {
    return Marker(
      point: pos,
      width: 40,
      height: 50,
      alignment: const Alignment(0, -1),
      child: const MapPinShape(
        isSelected: true,
        child: MapDestinationPinChild(),
      ),
    );
  }

  Marker _buildClusterMarker(TaskCluster cluster, MapProvider provider) {
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
          child: MapPinShape(
            isSelected: isSelected,
            badge: count > 1 ? count : null,
            child: MapClusterPinChild(isSelected: isSelected),
          ),
        ),
      ),
    );
  }

  /// ── Navigation helpers

  Future<void> _startNavigation(DashboardTask task, MapProvider provider) async {
    final result = await provider.startNavigation(task);
    if (!mounted) return;
    switch (result) {
      case NavStartResult.ok:
        _sheetAnim.reverse();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final lat = task.partnerLat;
          final lng = task.partnerLng;
          if (!lat.isFinite || !lng.isFinite) return;
          try {
            _mapController.move(LatLng(lat, lng), 17);
          } catch (_) {}
        });
        return;
      case NavStartResult.noCoords:
        _offerExternalNav(
          task,
          title: 'In-app navigation unavailable',
          message: task.partnerAddress.isNotEmpty
              ? 'This task has no precise coordinates. You can navigate to this location using Google Maps.'
              : 'This task has no location data.',
        );
        return;
      case NavStartResult.noUserLocation:
        _offerExternalNav(
          task,
          title: 'Your location is unavailable',
          message:
              'We couldn\'t get your current position. You can still navigate to this location using Google Maps.',
        );
        return;
      case NavStartResult.routeUnavailable:
        _offerExternalNav(
          task,
          title: 'No route found',
          message:
              'We couldn\'t plot a route to this location right now. You can navigate to this location using Google Maps.',
        );
        return;
    }
  }

  void _offerExternalNav(
    DashboardTask task, {
    required String title,
    required String message,
  }) {
    final hasAnyLocation = (task.partnerLat.isFinite &&
            task.partnerLng.isFinite &&
            task.partnerLat != 0.0 &&
            task.partnerLng != 0.0) ||
        task.partnerAddress.isNotEmpty;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.info_outline_rounded,
              color: primaryColor, size: 36),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: primaryColor),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: 10,),
                if (hasAnyLocation)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _launchExternalNav(task);
                      },
                       label: const Text('Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchExternalNav(DashboardTask task) async {
    Uri uri;
    final lat = task.partnerLat;
    final lng = task.partnerLng;
    final hasCoords = lat.isFinite && lng.isFinite && (lat != 0.0 || lng != 0.0);
    if (hasCoords) {
      uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else if (task.partnerAddress.isNotEmpty) {
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(task.partnerAddress)}');
    } else {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openExternalNav(MapProvider provider) async {
    final task = provider.navTask;
    if (task == null) return;
    Uri uri;
    if (task.partnerLat != 0.0 && task.partnerLng != 0.0) {
      uri = Uri.parse(
          'google.navigation:q=${task.partnerLat},${task.partnerLng}&mode=d');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${task.partnerLat},${task.partnerLng}');
    } else if (task.partnerAddress.isNotEmpty) {
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(task.partnerAddress)}');
    } else {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
