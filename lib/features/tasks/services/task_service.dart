import 'dart:developer';
import '../../../core/services/odoo_session_manager.dart';
import '../model/task_model.dart';

class TaskService {
  Future<List<TaskModel>> fetchTasks({
    String? stageFilter,
    String? search,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return [];

    final userId = session.userId;

    final domain = <dynamic>[
      ['is_fsm', '=', true],

      ['project_id', '!=', false],
      ['has_template_ancestor', '=', false],
      ['display_in_project', '=', true],
    ];

    if (search != null && search.trim().isNotEmpty) {
      domain.add(['name', 'ilike', search.trim()]);
    }

    if (stageFilter != null && stageFilter != 'All') {
      domain.add(['stage_id.name', 'ilike', stageFilter]);
    }

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'project_id',
            'stage_id',
            'user_ids',
            'date_deadline',
            'create_date',
          ],
          'order': 'name asc',
          'limit': 200,
        },
      });

      if (result is! List) return [];
      return result
          .whereType<Map<String, dynamic>>()
          .map(TaskModel.fromMap)
          .toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchTasks error: $e');
      return [];
    }
  }

  Future<List<String>> fetchStages() async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return [];

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task.type',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['name'],
          'order': 'sequence asc',
          'limit': 50,
        },
      });

      if (result is! List) return [];
      return result
          .whereType<Map<String, dynamic>>()
          .map((e) => e['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchStages error: $e');
      return [];
    }
  }
}
