import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../dashboard/model/dashboard_task_model.dart';
import '../../dashboard/services/dashboard_task_service.dart';

enum MapLoadState { idle, loading, loaded, error, permissionDenied }
enum MapViewMode { map, list }

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

  LatLng? get userLatLng => _userPosition != null
      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
      : null;

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
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          _routePoints = coordinates
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();
          notifyListeners();
        }
      }
    } catch (_) {
      _routePoints = [];
      notifyListeners();
    }
  }

  List<DashboardTask> _tasks = [];
  List<DashboardTask> get tasks => _tasks;

  // Clusters: tasks grouped by identical coordinates
  List<TaskCluster> get clusters => _buildClusters(_tasks);

  // Selected cluster (shown in bottom sheet)
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
      // Round to 5 decimal places (~1m precision) to group truly co-located tasks
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
    _selectedCluster = cluster;
    if (cluster != null) {
      fetchRoute(cluster.position);
    } else {
      _routePoints = [];
    }
    notifyListeners();
  }

  void refresh() {
    _state = MapLoadState.idle;
    _tasks = [];
    _selectedCluster = null;
    _routePoints = [];
    _searchQuery = '';
    _currentPage = 1;
    _userPosition = null;
    _viewMode = MapViewMode.map;
    load();
  }
}
