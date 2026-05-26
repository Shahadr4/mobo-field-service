import 'dart:async';
import 'package:flutter/foundation.dart';
import '../model/project_item_model.dart';
import '../services/timesheet_service.dart';

class TimesheetProvider extends ChangeNotifier {
  final TimesheetService _service;

  TimesheetProvider({TimesheetService? service})
      : _service = service ?? TimesheetService();

  ///  Task list

  List<ProjectItem> _tasks = [];
  bool _isLoading = false;
  String? _error;
  String _query = '';

  List<ProjectItem> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get query => _query;


  ///  Filtered Task list

  List<ProjectItem> get filtered {
    if (_query.isEmpty) return _tasks;
    final q = _query.toLowerCase();
    return _tasks
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.projectName.toLowerCase().contains(q))
        .toList();
  }

  void setQuery(String v) {
    _query = v;
    notifyListeners();
  }

  Future<void> fetchTasks() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tasks = await _service.fetchProjects();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ── Global Active Timer State
  int? _activeTaskId;
  int? _activeTimesheetId;
  Duration _activeElapsed = Duration.zero;
  bool _isTimerRunning = false;
  bool _isTimerPaused = false;
  ProjectItem? _activeTask;
  Timer? _globalTicker;

  int? get activeTaskId => _activeTaskId;
  int? get activeTimesheetId => _activeTimesheetId;
  Duration get activeElapsed => _activeElapsed;
  bool get isTimerRunning => _isTimerRunning;
  bool get isTimerPaused => _isTimerPaused;
  ProjectItem? get activeTask => _activeTask;
  /// ── Global Active Timer State

  void startGlobalTimer(ProjectItem task, int timesheetId) {
    _globalTicker?.cancel();
    _activeTaskId = task.id;
    _activeTimesheetId = timesheetId;
    _activeElapsed = Duration.zero;
    _isTimerRunning = true;
    _isTimerPaused = false;
    _activeTask = task;

    _globalTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _activeElapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  ///Timer operations
  void pauseGlobalTimer() {
    _globalTicker?.cancel();
    _isTimerPaused = true;
    notifyListeners();
  }

  void resumeGlobalTimer() {
    _globalTicker?.cancel();
    _isTimerPaused = false;
    _globalTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _activeElapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  void clearGlobalTimer() {
    _globalTicker?.cancel();
    _activeTaskId = null;
    _activeTimesheetId = null;
    _activeElapsed = Duration.zero;
    _isTimerRunning = false;
    _isTimerPaused = false;
    _activeTask = null;
    notifyListeners();
  }

  ///Timer operations
  Future<void> autoStopAndSaveRunningTimer() async {
    if (_activeTaskId == null || _activeTimesheetId == null) return;

    final taskId = _activeTaskId!;
    final timesheetId = _activeTimesheetId!;
    final elapsed = _activeElapsed;
    final taskName = _activeTask?.name ?? 'Task';

    clearGlobalTimer();

    try {
      await _service.stopTimer(
        taskId: taskId,
        timesheetId: timesheetId,
        elapsed: elapsed,
        description: 'Completed: $taskName',
      );
    } catch (e) {
    }
  }


  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  /// Returns the created timesheet (analytic line) id, or null on failure.
  Future<int?> startTimer(int taskId) => _service.startTimer(taskId);

  Future<bool> stopTimer({
    required int taskId,
    required int timesheetId,
    required Duration elapsed,
    required String description,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      final ok = await _service.stopTimer(
        taskId: taskId,
        timesheetId: timesheetId,
        elapsed: elapsed,
        description: description,
      );
      if (!ok) _error = 'Failed to save timesheet.';
      return ok;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> cancelTimer({
    required int timesheetId,
    required int taskId,
  }) =>
      _service.cancelTimer(timesheetId: timesheetId, taskId: taskId);

  void reset() {
    _globalTicker?.cancel();
    _activeTaskId = null;
    _activeTimesheetId = null;
    _activeElapsed = Duration.zero;
    _isTimerRunning = false;
    _isTimerPaused = false;
    _activeTask = null;
    _tasks = [];
    _query = '';
    _error = null;
    _isLoading = false;
    _isSubmitting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _globalTicker?.cancel();
    super.dispose();
  }
}
