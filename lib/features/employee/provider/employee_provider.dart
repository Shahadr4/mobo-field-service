
import 'package:flutter/foundation.dart';
import '../model/employee_filter.dart';
import '../model/employee_model.dart';
import '../service/employee_service.dart';

class AssigneeProvider extends ChangeNotifier {
  final AssigneeService _service;

  AssigneeProvider({AssigneeService? service})
      : _service = service ?? AssigneeService();

  static const int _pageSize = 40;

  List<AssigneeModel> _assignees = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;
  String _search = '';
  Set<AssigneeFilterBy> _filters = {};
  AssigneeGroupBy _groupBy = AssigneeGroupBy.none;
  int _currentPage = 1;
  int _totalCount = 0;

  List<AssigneeModel> get assignees => _assignees;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  String get search => _search;
  Set<AssigneeFilterBy> get filters => _filters;
  AssigneeGroupBy get groupBy => _groupBy;
  int get currentPage => _currentPage;
  int get totalCount => _totalCount;
  int get pageSize => _pageSize;
  int get totalPages => (_totalCount / _pageSize).ceil().clamp(1, 99999);
  bool get canGoNext => _currentPage < totalPages;
  bool get canGoPrev => _currentPage > 1;
  bool get hasActiveFilter =>
      _filters.isNotEmpty || _groupBy != AssigneeGroupBy.none;

  String get paginationText {
    if (_totalCount == 0) return '0 / 0';
    final from = (_currentPage - 1) * _pageSize + 1;
    final to = (_currentPage * _pageSize < _totalCount)
        ? _currentPage * _pageSize
        : _totalCount;
    return '$from–$to / $_totalCount';
  }

  Map<String, List<AssigneeModel>> get grouped {
    if (_groupBy == AssigneeGroupBy.none) return {'': _assignees};
    final map = <String, List<AssigneeModel>>{};
    for (final a in _assignees) {
      (map[_groupKey(a)] ??= []).add(a);
    }
    return map;
  }

  String _groupKey(AssigneeModel a) {
    switch (_groupBy) {
      case AssigneeGroupBy.department:
        return a.department.isNotEmpty ? a.department : 'No Department';
      case AssigneeGroupBy.jobTitle:
        return a.jobTitle.isNotEmpty ? a.jobTitle : 'No Job Title';
      case AssigneeGroupBy.manager:
        return a.manager.isNotEmpty ? a.manager : 'No Manager';
      case AssigneeGroupBy.none:
        return '';
    }
  }

  Future<void> fetchAssignees() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.fetchAssigneesPaged(
        search: _search,
        filters: _filters,
        offset: (_currentPage - 1) * _pageSize,
        limit: _pageSize,
      );
      _assignees = result.assignees;
      _totalCount = result.total;
      _hasFetched = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSearch(String v) async {
    _search = v;
    _currentPage = 1;
    await fetchAssignees();
  }

  Future<void> setFilters(Set<AssigneeFilterBy> f) async {
    _filters = {...f};
    _currentPage = 1;
    await fetchAssignees();
  }

  void setGroupBy(AssigneeGroupBy g) {
    _groupBy = g;
    notifyListeners();
  }

  Future<void> clearFilters() async {
    _filters.clear();
    _groupBy = AssigneeGroupBy.none;
    _currentPage = 1;
    await fetchAssignees();
  }

  Future<void> goToPage(int page) async {
    if (page < 1 || page > totalPages) return;
    _currentPage = page;
    await fetchAssignees();
  }

  Future<void> nextPage() => goToPage(_currentPage + 1);
  Future<void> prevPage() => goToPage(_currentPage - 1);

  void reset() {
    _assignees = [];
    _isLoading = false;
    _error = null;
    _hasFetched = false;
    _search = '';
    _filters = {};
    _groupBy = AssigneeGroupBy.none;
    _currentPage = 1;
    _totalCount = 0;
    notifyListeners();
  }

  Future<void> refresh() async {
    _search = '';
    _currentPage = 1;
    await fetchAssignees();
  }
}
