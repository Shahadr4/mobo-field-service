import 'package:flutter/foundation.dart';
import '../model/task_model.dart';
import '../services/task_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _service = TaskService();

  List<TaskModel> _tasks = [];
  List<String> _stages = [];
  bool _isLoading = false;
  String? _error;
  String _search = '';
  String _selectedStage = 'All';

  List<TaskModel> get tasks => _tasks;
  List<String> get stages => _stages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get search => _search;
  String get selectedStage => _selectedStage;

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
      _tasks = await _service.fetchTasks(
        search: _search,
        stageFilter: _selectedStage,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSearch(String v) async {
    _search = v;
    await fetchTasks();
  }

  Future<void> setStage(String stage) async {
    _selectedStage = stage;
    await fetchTasks();
  }

  Future<void> refresh() async {
    _search = '';
    _selectedStage = 'All';
    await fetchTasks();
  }
}
