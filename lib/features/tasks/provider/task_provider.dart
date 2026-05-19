import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../model/task_filter.dart';
import '../model/task_model.dart';
import '../services/task_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _service = TaskService();

  static const int _pageSize = 40;

  List<TaskModel>   _tasks           = [];
  List<String>      _stages          = [];
  bool              _isLoading       = false;
  String?           _error;
  String            _search          = '';
  String            _selectedStage   = 'All';
  Set<TaskFilterBy> _selectedFilters = {};
  TaskGroupBy       _groupBy         = TaskGroupBy.none;
  int               _currentPage     = 1;
  int               _totalCount      = 0;

  List<TaskModel>   get tasks           => _tasks;
  List<String>      get stages          => _stages;
  bool              get isLoading       => _isLoading;
  String?           get error           => _error;
  String            get search          => _search;
  String            get selectedStage   => _selectedStage;
  Set<TaskFilterBy> get selectedFilters => _selectedFilters;
  TaskGroupBy       get groupBy         => _groupBy;
  int               get currentPage     => _currentPage;
  int               get totalCount      => _totalCount;
  int               get pageSize        => _pageSize;
  int               get totalPages      => (_totalCount / _pageSize).ceil().clamp(1, 99999);
  bool              get canGoNext       => _currentPage < totalPages;
  bool              get canGoPrev       => _currentPage > 1;
  String get paginationText {
    if (_totalCount == 0) return '0 / 0';
    final from = (_currentPage - 1) * _pageSize + 1;
    final to   = (_currentPage * _pageSize < _totalCount)
        ? _currentPage * _pageSize
        : _totalCount;
    return '$from–$to / $_totalCount';
  }

  bool get hasActiveFilter =>
      _selectedFilters.isNotEmpty || _groupBy != TaskGroupBy.none;

  Map<String, List<TaskModel>> get grouped {
    if (_groupBy == TaskGroupBy.none) return {'': _tasks};
    final map = <String, List<TaskModel>>{};
    for (final t in _tasks) {
      (map[_groupKey(t)] ??= []).add(t);
    }
    return map;
  }

  String _groupKey(TaskModel t) {
    switch (_groupBy) {
      case TaskGroupBy.stage:
        return t.stageName.isNotEmpty ? t.stageName : 'No Stage';
      case TaskGroupBy.assignee:
        return t.assigneeName.isNotEmpty ? t.assigneeName : 'Unassigned';
      case TaskGroupBy.project:
        return t.projectName.isNotEmpty ? t.projectName : 'No Project';
      case TaskGroupBy.priority:
        if (t.priority >= 3) return '★★★ High';
        if (t.priority == 2) return '★★  Medium';
        if (t.priority == 1) return '★   Normal';
        return 'No Priority';
      case TaskGroupBy.deadline:
        if (t.deadline.isEmpty) return 'No Deadline';
        final d = DateTime.tryParse(t.deadline);
        if (d == null) return 'No Deadline';
        final now = DateTime.now();
        if (d.isBefore(now)) return 'Overdue';
        final diff = d.difference(now).inDays;
        if (diff == 0) return 'Today';
        if (diff <= 7) return 'This Week';
        if (diff <= 30) return 'This Month';
        return 'Later';
      case TaskGroupBy.none:
        return '';
    }
  }

  Future<void> init() async {
    await Future.wait([fetchStages(), fetchTasks()]);
  }

  Future<void> fetchStages() async {
    try {
      final result = await _service.fetchStages();
      _stages = ['All', ...result];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchTasks() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      log('[TaskProvider] fetchTasks page=$_currentPage filters=$_selectedFilters');
      final result = await _service.fetchTasksPaged(
        search: _search,
        stageFilter: _selectedStage,
        filters: _selectedFilters,
        offset: (_currentPage - 1) * _pageSize,
        limit: _pageSize,
      );
      _tasks      = result.tasks;
      _totalCount = result.total;
      log('[TaskProvider] got ${_tasks.length} tasks, total=$_totalCount');
    } catch (e) {
      _error = e.toString();
      log('[TaskProvider] fetchTasks error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSearch(String v) async {
    _search      = v;
    _currentPage = 1;
    await fetchTasks();
  }

  Future<void> setStage(String stage) async {
    _selectedStage = stage;
    _currentPage   = 1;
    await fetchTasks();
  }

  Future<void> goToPage(int page) async {
    if (page < 1 || page > totalPages) return;
    _currentPage = page;
    await fetchTasks();
  }

  Future<void> nextPage() => goToPage(_currentPage + 1);
  Future<void> prevPage() => goToPage(_currentPage - 1);

  Future<void> setFilters(Set<TaskFilterBy> filters) async {
    _selectedFilters = {...filters};
    _currentPage     = 1;
    await fetchTasks();
  }

  void setGroupBy(TaskGroupBy v) {
    _groupBy = v;
    notifyListeners();
  }

  Future<void> clearFilters() async {
    _selectedFilters.clear();
    _groupBy     = TaskGroupBy.none;
    _currentPage = 1;
    await fetchTasks();
  }

  Future<void> refresh() async {
    _search        = '';
    _selectedStage = 'All';
    _currentPage   = 1;
    await fetchTasks();
  }

  void updateTaskInMemory(TaskModel updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }
}
