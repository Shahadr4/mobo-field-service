import 'package:flutter/foundation.dart';
import '../model/dashboard_task_model.dart';
import '../services/dashboard_task_service.dart';

class DashboardTaskProvider extends ChangeNotifier {
  final DashboardTaskService _service = DashboardTaskService();

  static const tabs = ['New', 'Nearby','In Progress', 'Planned', 'Done',  'Assigned'];

  int _tabIndex = 0;
  int get tabIndex => _tabIndex;
  String get currentTab => tabs[_tabIndex];

  final Map<int, List<DashboardTask>> _cache = {};
  bool _isLoading = false;
  String? _error;

  List<DashboardTask> get tasks => _cache[_tabIndex] ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> selectTab(int index) async {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
    if (!_cache.containsKey(index)) {
      await _load(index);
    }
  }

  Future<void> init() async {
    await _load(0);
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
