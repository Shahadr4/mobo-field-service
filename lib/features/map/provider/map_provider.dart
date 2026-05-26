import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../dashboard/model/dashboard_task_model.dart';
import '../../dashboard/services/dashboard_task_service.dart';

enum MapLoadState { idle, loading, loaded, error, permissionDenied }
enum MapViewMode { map, list }
enum NavStartResult { ok, noCoords, noUserLocation, routeUnavailable }

bool _isValidLatLng(double lat, double lng) {
  return lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0.0 && lng == 0.0);
}

/// A group of tasks that share (approximately) the same map location.
class TaskCluster {
  final LatLng position;
  final List<DashboardTask> tasks;
  const TaskCluster({required this.position, required this.tasks});
  bool get isSingle => tasks.length == 1;
}

class MapProvider extends ChangeNotifier {
  final DashboardTaskService _service = DashboardTaskService();

  MapLoadState _state = MapLoadState.idle;
  MapLoadState get state => _state;

  Position? _userPosition;
  Position? get userPosition => _userPosition;

  LatLng? get userLatLng {
    final p = _userPosition;
    if (p == null) return null;
    if (!_isValidLatLng(p.latitude, p.longitude)) return null;
    return LatLng(p.latitude, p.longitude);
  }

  List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => _routePoints;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  static const int _pageSize = 40;

  List<DashboardTask> get filteredTasks {
    if (_searchQuery.isEmpty) {
      return _tasks;
    }
    final q = _searchQuery.toLowerCase();
    return _tasks.where((t) {
      return t.name.toLowerCase().contains(q) ||
          t.partnerName.toLowerCase().contains(q) ||
          t.partnerAddress.toLowerCase().contains(q) ||
          t.projectName.toLowerCase().contains(q) ||
          t.stageName.toLowerCase().contains(q);
    }).toList();
  }

  int get totalPages {
    final count = filteredTasks.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }

  String get paginationText {
    final count = filteredTasks.length;
    if (count == 0) return '0 / 0';
    final from = (_currentPage - 1) * _pageSize + 1;
    final to   = (_currentPage * _pageSize < count)
        ? _currentPage * _pageSize
        : count;
    return '$from–$to / $count';
  }

  List<DashboardTask> get paginatedTasks {
    final list = filteredTasks;
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= list.length) return [];
    final endIndex = startIndex + _pageSize;
    return list.sublist(
      startIndex,
      endIndex > list.length ? list.length : endIndex,
    );
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1;
    notifyListeners();
  }

  void setPage(int page) {
    if (page < 1 || page > totalPages) return;
    _currentPage = page;
    notifyListeners();
  }

  Future<void> fetchRoute(LatLng destination) async {
    final start = userLatLng;
    if (start == null) return;

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          _routePoints = coordinates
              .map((c) {
                final lat = (c[1] as num?)?.toDouble() ?? double.nan;
                final lng = (c[0] as num?)?.toDouble() ?? double.nan;
                return _isValidLatLng(lat, lng) ? LatLng(lat, lng) : null;
              })
              .whereType<LatLng>()
              .toList();
          _routeDistanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
          _routeDurationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;
          notifyListeners();
        }
      }
    } catch (_) {
      _routePoints = [];
      _routeDistanceMeters = 0;
      _routeDurationSeconds = 0;
      notifyListeners();
    }
  }


  /// Result of attempting to start in-app navigation.
  /// - [ok]: nav started.
  /// - [noCoords]: task has no lat/lon (can still open external maps if address present).
  /// - [noUserLocation]: user position unknown.
  /// - [routeUnavailable]: OSRM couldn't return a route.
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;

  DashboardTask? _navTask;
  DashboardTask? get navTask => _navTask;

  LatLng? _navDestination;
  LatLng? get navDestination => _navDestination;

  double _routeDistanceMeters = 0;
  double get routeDistanceMeters => _routeDistanceMeters;

  double _routeDurationSeconds = 0;
  double get routeDurationSeconds => _routeDurationSeconds;

  double _userHeading = 0;
  double get userHeading => _userHeading;

  bool _arrived = false;
  bool get arrived => _arrived;

  StreamSubscription<Position>? _positionSub;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);
  static const _distance = Distance();
  static const double _offRouteThresholdMeters = 50;
  static const double _arrivalThresholdMeters = 30;
  static const Duration _rerouteCooldown = Duration(seconds: 10);

  Future<NavStartResult> startNavigation(DashboardTask task) async {
    if (!_isValidLatLng(task.partnerLat, task.partnerLng)) {
      return NavStartResult.noCoords;
    }
    final user = userLatLng;
    if (user == null || !_isValidLatLng(user.latitude, user.longitude)) {
      return NavStartResult.noUserLocation;
    }
    _navTask = task;
    _navDestination = LatLng(task.partnerLat, task.partnerLng);
    _isNavigating = true;
    _arrived = false;
    _selectedCluster = null;
    await fetchRoute(_navDestination!);
    if (_routePoints.isEmpty) {
      /// Route fetch failed — roll back nav state.
      _isNavigating = false;
      _navTask = null;
      _navDestination = null;
      notifyListeners();
      return NavStartResult.routeUnavailable;
    }
    _startPositionStream();
    notifyListeners();
    return NavStartResult.ok;
  }

  void stopNavigation() {
    _isNavigating = false;
    _navTask = null;
    _navDestination = null;
    _routePoints = [];
    _routeDistanceMeters = 0;
    _routeDurationSeconds = 0;
    _arrived = false;
    _positionSub?.cancel();
    _positionSub = null;
    notifyListeners();
  }

  void _startPositionStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position pos) {
    if (!_isValidLatLng(pos.latitude, pos.longitude)) return;
    _userPosition = pos;
    if (pos.heading.isFinite && pos.heading >= 0) _userHeading = pos.heading;

    if (_isNavigating && _navDestination != null) {
      final user = LatLng(pos.latitude, pos.longitude);

      /// Arrival check
      final distToDest = _distance.as(LengthUnit.Meter, user, _navDestination!);
      if (distToDest <= _arrivalThresholdMeters && !_arrived) {
        _arrived = true;
        notifyListeners();
        return;
      }

      /// Off-route check + cooldown-guarded reroute
      if (_routePoints.isNotEmpty) {
        final offBy = _distanceFromRoute(user);
        final now = DateTime.now();
        if (offBy > _offRouteThresholdMeters &&
            now.difference(_lastReroute) > _rerouteCooldown) {
          _lastReroute = now;
          fetchRoute(_navDestination!);
        } else {
          /// Update remaining distance/ETA from current position
          _updateRemaining(user);
        }
      }
    }
    notifyListeners();
  }

  double _distanceFromRoute(LatLng p) {
    double best = double.infinity;
    for (final r in _routePoints) {
      final d = _distance.as(LengthUnit.Meter, p, r);
      if (d < best) best = d;
    }
    return best;
  }

  void _updateRemaining(LatLng user) {
    if (_routePoints.length < 2) return;
    /// Find closest segment index, then sum remaining segment lengths.
    int closest = 0;
    double bestD = double.infinity;
    for (var i = 0; i < _routePoints.length; i++) {
      final d = _distance.as(LengthUnit.Meter, user, _routePoints[i]);
      if (d < bestD) {
        bestD = d;
        closest = i;
      }
    }
    double remaining = bestD;
    for (var i = closest; i < _routePoints.length - 1; i++) {
      remaining += _distance.as(
        LengthUnit.Meter,
        _routePoints[i],
        _routePoints[i + 1],
      );
    }
    /// Preserve ETA pace using original speed ratio.
    if (_routeDistanceMeters > 0) {
      final speed = _routeDistanceMeters /
          (_routeDurationSeconds == 0 ? 1 : _routeDurationSeconds);
      _routeDurationSeconds = speed > 0 ? remaining / speed : 0;
    }
    _routeDistanceMeters = remaining;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  List<DashboardTask> _tasks = [];
  List<DashboardTask> get tasks => _tasks;

  /// Clusters: tasks grouped by identical coordinates
  List<TaskCluster> get clusters => _buildClusters(_tasks);

  /// Selected cluster (shown in bottom sheet)
  TaskCluster? _selectedCluster;
  TaskCluster? get selectedCluster => _selectedCluster;

  MapViewMode _viewMode = MapViewMode.map;
  MapViewMode get viewMode => _viewMode;
  bool get isListMode => _viewMode == MapViewMode.list;

  void setViewMode(MapViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }

  String? _error;
  String? get error => _error;

  List<TaskCluster> _buildClusters(List<DashboardTask> tasks) {
    final Map<String, List<DashboardTask>> map = {};
    for (final t in tasks) {
      if (!_isValidLatLng(t.partnerLat, t.partnerLng)) continue;
      /// Round to 5 decimal places (~1m precision) to group truly co-located tasks
      final key = '${t.partnerLat.toStringAsFixed(5)},${t.partnerLng.toStringAsFixed(5)}';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map.entries.map((e) {
      final first = e.value.first;
      return TaskCluster(
        position: LatLng(first.partnerLat, first.partnerLng),
        tasks: e.value,
      );
    }).toList();
  }

  Future<void> load() async {
    _state = MapLoadState.loading;
    _error = null;
    notifyListeners();

    final pos = await _getPosition();
    if (pos == null) {
      _state = MapLoadState.permissionDenied;
      notifyListeners();
      return;
    }
    _userPosition = pos;

    try {
      _tasks = await _service.fetchMyTasksWithPosition(pos);
      _state = MapLoadState.loaded;
    } catch (e) {
      _error = e.toString();
      _state = MapLoadState.error;
    }

    notifyListeners();
  }

  Future<Position?> _getPosition() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  void selectCluster(TaskCluster? cluster) {
    if (_isNavigating) return;
    _selectedCluster = cluster;
    if (cluster != null) {
      fetchRoute(cluster.position);
    } else {
      _routePoints = [];
      _routeDistanceMeters = 0;
      _routeDurationSeconds = 0;
    }
    notifyListeners();
  }

  void refresh() {
    stopNavigation();
    _state = MapLoadState.idle;
    _tasks = [];
    _selectedCluster = null;
    _routePoints = [];
    _routeDistanceMeters = 0;
    _routeDurationSeconds = 0;
    _searchQuery = '';
    _currentPage = 1;
    _userPosition = null;
    _viewMode = MapViewMode.map;
    load();
  }

  int _activeHomeTab = 0;
  int get activeHomeTab => _activeHomeTab;

  void setActiveHomeTab(int index) {
    if (_activeHomeTab == index) return;
    _activeHomeTab = index;
    notifyListeners();
  }

  void resetTab() {
    if (_activeHomeTab == 0) return;
    _activeHomeTab = 0;
    refresh();
    notifyListeners();
  }

  void reset() {
    stopNavigation();
    _state = MapLoadState.idle;
    _tasks = [];
    _selectedCluster = null;
    _routePoints = [];
    _routeDistanceMeters = 0;
    _routeDurationSeconds = 0;
    _searchQuery = '';
    _currentPage = 1;
    _userPosition = null;
    _viewMode = MapViewMode.map;
    _activeHomeTab = 0;
    _pendingJumpTaskId = null;
    notifyListeners();
  }

  int? _pendingJumpTaskId;
  int? get pendingJumpTaskId => _pendingJumpTaskId;

  void setPendingJumpTaskId(int? id) {
    _pendingJumpTaskId = id;
    notifyListeners();
  }
}
