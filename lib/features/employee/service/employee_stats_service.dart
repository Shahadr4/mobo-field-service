import 'dart:developer';
import '../../../core/services/odoo_session_manager.dart';
import '../model/employee_stats_model.dart';

class EmployeeStatsService {
  Future<EmployeeStats> fetchStats(int userId) async {
    log('[EmployeeStatsService] fetchStats for user=$userId');

    final baseDomain = [
      ['is_fsm', '=', true],
      ['user_ids', 'in', [userId]],
      ['project_id', '!=', false],
      ['has_template_ancestor', '=', false],
      ['display_in_project', '=', true],
    ];

    final doneDomain = [
      ...baseDomain,
      '|',
      ['stage_id.name', 'ilike', 'done'],
      ['stage_id.name', 'ilike', 'complete'],
    ];

    final cancelDomain = [
      ...baseDomain,
      ['stage_id.name', 'ilike', 'cancel'],
    ];

    final activeDomain = [
      ...baseDomain,
      '!',
      '|',
      '|',
      ['stage_id.name', 'ilike', 'done'],
      ['stage_id.name', 'ilike', 'complete'],
      ['stage_id.name', 'ilike', 'cancel'],
    ];

    final now = DateTime.now();
    final monthStart =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01 00:00:00';

    try {
      final results = await Future.wait([

        _count(baseDomain),
        _count(activeDomain),
        _count(doneDomain),
        _count(cancelDomain),
        _sumHours([
          ['task_id.is_fsm', '=', true],
          ['user_id', '=', userId],
          ['project_id', '!=', false],
        ]),
        // 5 — hours this month
        _sumHours([
          ['task_id.is_fsm', '=', true],
          ['user_id', '=', userId],
          ['project_id', '!=', false],
          ['date', '>=', monthStart],
        ]),
      ]);

      return EmployeeStats(
        assignedTasks: results[0] as int,
        activeTasks: results[1] as int,
        completedTasks: results[2] as int,
        cancelledTasks: results[3] as int,
        totalHours: results[4] as double,
        thisMonthHours: results[5] as double,
      );
    } catch (e) {
      log('[EmployeeStatsService] ⚠️ error: $e');
      return const EmployeeStats.empty();
    }
  }

  Future<int> _count(List<dynamic> domain) async {
    try {
      final r = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      return (r as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<double> _sumHours(List<dynamic> domain) async {
    try {
      final r = await OdooSessionManager.callKwWithCompany({
        'model': 'account.analytic.line',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['unit_amount'],
          'limit': 0,
        },
      });
      if (r is! List) return 0;
      return r.fold<double>(
        0,
        (sum, e) => sum + ((e['unit_amount'] as num?)?.toDouble() ?? 0),
      );
    } catch (_) {
      return 0;
    }
  }
}
