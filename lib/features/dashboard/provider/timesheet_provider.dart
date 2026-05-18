import 'package:flutter/foundation.dart';
import '../model/project_item_model.dart';
import '../services/timesheet_service.dart';

class TimesheetProvider extends ChangeNotifier {
  final TimesheetService _service = TimesheetService();

  // ── Task list ─────────────────────────────────────────────────────────────

  List<ProjectItem> _tasks = [];
  bool _isLoading = false;
  String? _error;
  String _query = '';

  List<ProjectItem> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get query => _query;

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

  // ── Timer operations ──────────────────────────────────────────────────────

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
    _tasks = [];
    _query = '';
    _error = null;
    _isLoading = false;
    _isSubmitting = false;
  }
}
