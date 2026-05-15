import 'package:flutter/material.dart';
import '../model/task_stats_model.dart';
import '../services/task_stats_service.dart';

class TaskStatsProvider extends ChangeNotifier {
  final TaskStatsService _service = TaskStatsService();

  TaskStats _stats = const TaskStats.empty();
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;

  TaskStats get stats => _stats;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;

  /// Resets state so the next fetch() triggers a fresh load with shimmer.
  void reset() {
    _isInitialized = false;
    _isLoading = false;
    _isRefreshing = false;
    _stats = const TaskStats.empty();
    _error = null;
    notifyListeners();
  }

  /// Initial load — shows full shimmer skeleton. No-op if already loaded.
  Future<void> fetch() async {
    if (_isInitialized || _isLoading || _isRefreshing) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _service.fetchTaskStats();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[TaskStatsProvider] ❌ fetch error: $e');
      _error = 'Failed to load task overview.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh — keeps existing data visible, no shimmer.
  Future<void> refresh() async {
    if (_isLoading || _isRefreshing) return;
    _isRefreshing = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _service.fetchTaskStats();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[TaskStatsProvider] ❌ refresh error: $e');
      _error = 'Failed to refresh task overview.';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
