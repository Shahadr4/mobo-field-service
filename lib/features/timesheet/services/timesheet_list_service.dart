import 'dart:developer';

import '../../../core/services/odoo_session_manager.dart';
import '../model/timesheet_entry_model.dart';

class TimesheetListService {
  static const int pageSize = 40;

  /// Returns [count, entries] for the given page.
  Future<(int, List<TimesheetEntry>)> fetchPaged({
    required int page,
    required String search,
    required TimesheetDateFilter dateFilter,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return (0, <TimesheetEntry>[]);

    final userId = session.userId;
    final domain = _buildDomain(userId, search, dateFilter);

    try {
      final offset = (page - 1) * pageSize;

      // Run count and data fetch in parallel
      final results = await Future.wait([
        OdooSessionManager.callKwWithCompany({
          'model': 'account.analytic.line',
          'method': 'search_count',
          'args': [domain],
          'kwargs': {},
        }),
        OdooSessionManager.callKwWithCompany({
          'model': 'account.analytic.line',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': [
              'id', 'name', 'task_id', 'project_id',
              'unit_amount', 'date',
            ],
            'order': 'date desc, id desc',
            'limit': pageSize,
            'offset': offset,
          },
        }),
      ]);

      final count = (results[0] as num?)?.toInt() ?? 0;
      final raw = results[1];
      if (raw is! List) return (count, <TimesheetEntry>[]);

      final entries = raw
          .whereType<Map<String, dynamic>>()
          .map(TimesheetEntry.fromMap)
          .toList();

      return (count, entries);
    } catch (e) {
      log('[TimesheetListService] fetchPaged error: $e');
      return (0, <TimesheetEntry>[]);
    }
  }

  List<dynamic> _buildDomain(
    int userId,
    String search,
    TimesheetDateFilter dateFilter,
  ) {
    // Base: FSM tasks only, assigned to current user
    final domain = <dynamic>[
      ['task_id.is_fsm', '=', true],
      ['task_id.project_id', '!=', false],
      ['task_id.has_template_ancestor', '=', false],
      ['task_id.display_in_project', '=', true],
      ['user_id', '=', userId],
    ];

    // Search by task name or description
    if (search.trim().isNotEmpty) {
      final q = search.trim();
      domain.addAll(<dynamic>[
        '|',
        ['task_id.name', 'ilike', q],
        ['name', 'ilike', q],
      ]);
    }

    // Date filter
    final dateRange = _dateRange(dateFilter);
    if (dateRange != null) {
      domain.add(['date', '>=', dateRange.$1]);
      domain.add(['date', '<=', dateRange.$2]);
    }

    return domain;
  }

  (String, String)? _dateRange(TimesheetDateFilter f) {
    final now = DateTime.now();
    switch (f) {
      case TimesheetDateFilter.all:
        return null;
      case TimesheetDateFilter.today:
        final s = _fmt(now);
        return (s, s);
      case TimesheetDateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        final s = _fmt(y);
        return (s, s);
      case TimesheetDateFilter.thisWeek:
        final mon = now.subtract(Duration(days: now.weekday - 1));
        final sun = mon.add(const Duration(days: 6));
        return (_fmt(mon), _fmt(sun));
      case TimesheetDateFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return (_fmt(start), _fmt(end));
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
