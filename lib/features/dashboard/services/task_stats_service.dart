import 'dart:developer';
import '../../../core/services/odoo_session_manager.dart';
import '../model/task_stats_model.dart';

class TaskStatsService {
  /// Fetches field service task counts for the current user.
  /// project.task with is_fsm=true is the Odoo Field Service task model.
  Future<TaskStats> fetchTaskStats() async {
    log('[TaskStatsService] ▶ fetchTaskStats()');

    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) {
      log('[TaskStatsService] ❌ No session');
      return const TaskStats.empty();
    }

    final userId = session.userId;

    // Base domain: field service tasks assigned to this user
    final baseDomain = [
      ['is_fsm', '=', true],
      ['user_ids', 'in', [userId]],
      ['project_id', '!=', false],
      ['has_template_ancestor', '=', false],
      ['display_in_project', '=', true]
    ];

    // Detect which "done/closed" field exists on this Odoo version:
    // Odoo 16/17 uses fsm_done, Odoo 18/19 uses state='done' or stage fold.
    // We probe fsm_done first; if absent fall back to stage_id.fold.
    final hasFsmDone = await _fieldExists('project.task', 'fsm_done');
    log('[TaskStatsService] hasFsmDone=$hasFsmDone');

    final List<dynamic> doneDomain = hasFsmDone
        ? [...baseDomain, ['fsm_done', '=', true]]
        : [...baseDomain, ['stage_id.fold', '=', true]];

    final List<dynamic> activeDomain = hasFsmDone
        ? [...baseDomain, ['fsm_done', '=', false]]
        : [...baseDomain, ['stage_id.fold', '=', false]];

    // Run all 4 counts in parallel
    final results = await Future.wait([
      _count(activeDomain),
      _count(baseDomain),
      _count(doneDomain),
      _count([
        ['is_fsm', '=', true],
        ['project_id', '!=', false],
        ['has_template_ancestor', '=', false],
        ['display_in_project', '=', true]
      ]),
    ]);

    final stats = TaskStats(
      activeTasks:    results[0],
      assignedTasks:  results[1],
      completedTasks: results[2],
      totalTasks:     results[3],
    );

    log('[TaskStatsService] ✅ active=${stats.activeTasks} '
        'assigned=${stats.assignedTasks} '
        'done=${stats.completedTasks} '
        'total=${stats.totalTasks}');

    return stats;
  }

  /// Returns true if [fieldName] exists on [model] in this Odoo instance.
  Future<bool> _fieldExists(String model, String fieldName) async {
    try {
      final result = await OdooSessionManager.safeCallKw({
        'model': model,
        'method': 'fields_get',
        'args': [[fieldName]],
        'kwargs': {'attributes': ['string']},
      });
      return result is Map && result.containsKey(fieldName);
    } catch (_) {
      return false;
    }
  }

  Future<int> _count(List<dynamic> domain) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      return (result as num?)?.toInt() ?? 0;
    } catch (e) {
      log('[TaskStatsService] ⚠️ count error: $e');
      return 0;
    }
  }
}
