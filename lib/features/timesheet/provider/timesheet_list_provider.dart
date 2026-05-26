import 'package:flutter/foundation.dart';

import '../model/timesheet_entry_model.dart';
import '../services/timesheet_list_service.dart';

class TimesheetListProvider extends ChangeNotifier {
  final TimesheetListService _service;

  TimesheetListProvider({TimesheetListService? service})
      : _service = service ?? TimesheetListService();

  /// ── State ──────────────────────────────────────────────────────────────────
  List<TimesheetEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  int _currentPage = 1;
  int _totalCount = 0;

  String _search = '';
  TimesheetDateFilter _dateFilter = TimesheetDateFilter.all;
  TimesheetGroupBy _groupBy = TimesheetGroupBy.none;

  /// ── Getters ────────────────────────────────────────────────────────────────
  List<TimesheetEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  int get currentPage => _currentPage;
  int get totalCount => _totalCount;
  String get search => _search;
  TimesheetDateFilter get dateFilter => _dateFilter;
  TimesheetGroupBy get groupBy => _groupBy;

  int get totalPages =>
      (_totalCount / TimesheetListService.pageSize).ceil().clamp(1, 999999);
  bool get canGoPrev => _currentPage > 1;
  bool get canGoNext => _currentPage < totalPages;

  String get paginationText {
    if (_totalCount == 0) return '0';
    final start = (_currentPage - 1) * TimesheetListService.pageSize + 1;
    final end = (start + _entries.length - 1).clamp(start, _totalCount);
    return '$start–$end / $_totalCount';
  }

  bool get hasActiveFilter => _dateFilter != TimesheetDateFilter.all;

  /// Grouped entries map — only populated when groupBy != none.
  /// Keys are sorted by group label (date-based groups are sorted chronologically).
  Map<String, List<TimesheetEntry>> get grouped {
    if (_groupBy == TimesheetGroupBy.none) return {};
    final map = <String, List<TimesheetEntry>>{};
    for (final e in _entries) {
      final key = e.groupKey(_groupBy);
      (map[key] ??= []).add(e);
    }
    return map;
  }

  double get totalHours =>
      _entries.fold(0.0, (sum, e) => sum + e.hours);

  /// ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _currentPage = 1;
    await _load();
  }

  void reset() {
    _entries = [];
    _isLoading = false;
    _error = null;
    _hasFetched = false;
    _currentPage = 1;
    _totalCount = 0;
    _search = '';
    _dateFilter = TimesheetDateFilter.all;
    _groupBy = TimesheetGroupBy.none;
    notifyListeners();
  }

  Future<void> refresh() async {
    _currentPage = 1;
    await _load();
  }

  /// ── Search ─────────────────────────────────────────────────────────────────
  Future<void> setSearch(String value) async {
    if (_search == value) return;
    _search = value;
    _currentPage = 1;
    await _load();
  }

  /// ── Date filter ────────────────────────────────────────────────────────────
  Future<void> setDateFilter(TimesheetDateFilter f) async {
    if (_dateFilter == f) return;
    _dateFilter = f;
    _currentPage = 1;
    await _load();
  }

  /// ── Group by ───────────────────────────────────────────────────────────────
  void setGroupBy(TimesheetGroupBy g) {
    if (_groupBy == g) return;
    _groupBy = g;
    notifyListeners();
  }

  /// ── Pagination ─────────────────────────────────────────────────────────────
  Future<void> nextPage() async {
    if (!canGoNext) return;
    _currentPage++;
    await _load();
  }

  Future<void> prevPage() async {
    if (!canGoPrev) return;
    _currentPage--;
    await _load();
  }

  /// ── Clear ──────────────────────────────────────────────────────────────────
  Future<void> clearFilters() async {
    _dateFilter = TimesheetDateFilter.all;
    _search = '';
    _groupBy = TimesheetGroupBy.none;
    _currentPage = 1;
    await _load();
  }

  Future<void> refreshAndClearSearch() async {
    _search = '';
    _currentPage = 1;
    await _load();
  }

  /// ── Internal load ──────────────────────────────────────────────────────────
  Future<void> _load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final (count, entries) = await _service.fetchPaged(
        page: _currentPage,
        search: _search,
        dateFilter: _dateFilter,
      );
      _totalCount = count;
      _entries = entries;
      _hasFetched = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
