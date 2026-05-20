import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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
    notifyListeners();
  }

  void refresh() {
    _state = MapLoadState.idle;
    _tasks = [];
    _selectedCluster = null;
    _userPosition = null;
    _viewMode = MapViewMode.map;
    load();
  }
}
