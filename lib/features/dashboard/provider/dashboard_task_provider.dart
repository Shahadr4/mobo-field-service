import 'package:flutter/foundation.dart';
import '../model/dashboard_task_model.dart';
import '../services/dashboard_task_service.dart';
import '../../tasks/services/task_service.dart';

class DashboardTaskProvider extends ChangeNotifier {
  final DashboardTaskService _service = DashboardTaskService();
  final TaskService _taskService = TaskService();

  static const tabs = ['New', 'Nearby','In Progress', 'Planned', 'Done',  'Assigned'];

  int _tabIndex = 0;
  int get tabIndex => _tabIndex;
  String get currentTab => tabs[_tabIndex];

  final Map<int, List<DashboardTask>> _cache = {};
  bool _isLoading = false;
  String? _error;

  bool _warrantyEnabled   = false;
  bool _worksheetEnabled  = false;
  bool _fsmSettingsFetched = false;

  bool get warrantyEnabled  => _warrantyEnabled;
  bool get worksheetEnabled => _worksheetEnabled;

  List<DashboardTask> get tasks => _cache[_tabIndex] ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadFsmSettings() async {
    if (_fsmSettingsFetched) return;
    final s = await _taskService.fetchFsmSettings();
    _warrantyEnabled   = s.warrantyEnabled;
    _worksheetEnabled  = s.worksheetEnabled;
    _fsmSettingsFetched = true;
  }

  Future<void> selectTab(int index) async {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
    if (!_cache.containsKey(index)) {
      await _load(index);
    }
  }

  Future<void> init() async {
    if (_cache.containsKey(0) && _fsmSettingsFetched) return;
    await Future.wait([_loadFsmSettings(), _load(0)]);
  }

  void reset() {
    _tabIndex = 0;
    _cache.clear();
    _isLoading = false;
    _error = null;
    _warrantyEnabled = false;
    _worksheetEnabled = false;
    _fsmSettingsFetched = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _cache.clear();
    await _load(_tabIndex);
  }

  Future<void> selectTabAndRefresh(int index) async {
    _tabIndex = index;
    _cache.clear();
    notifyListeners();
    await _load(index);
  }

  Future<void> _load(int index) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _cache[index] = await _service.fetchByTab(tabs[index]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
