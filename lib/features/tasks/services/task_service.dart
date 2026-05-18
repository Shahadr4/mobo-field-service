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
            'partner_id',
            'planned_date_begin',
            'date_deadline',
            'create_date',
            'priority',
            'description',
            'allocated_hours',
            'effective_hours',
          ],
          'order': 'name asc',
          'limit': 200,
        },
      });

      if (result is! List) return [];

      final tasks = result.whereType<Map<String, dynamic>>().toList();

      // Collect unique partner IDs
      final partnerIds = tasks
          .map((t) => t['partner_id'])
          .where((v) => v is List && (v as List).isNotEmpty)
          .map((v) => (v[0] as num).toInt())
          .toSet()
          .toList();

      final Map<int, Map<String, dynamic>> partnerMap = {};
      if (partnerIds.isNotEmpty) {
        final partners = await OdooSessionManager.callKwWithCompany({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [
            [['id', 'in', partnerIds]]
          ],
          'kwargs': {
            'fields': ['id', 'street', 'city', 'country_id', 'phone'],
          },
        });

        if (partners is List) {
          for (final p in partners.whereType<Map<String, dynamic>>()) {
            final id = (p['id'] as num).toInt();
            final countryRaw = p['country_id'];
            partnerMap[id] = {
              'street': p['street'] is String ? p['street'] : '',
              'city': p['city'] is String ? p['city'] : '',
              'country': countryRaw is List && countryRaw.length >= 2
                  ? countryRaw[1].toString()
                  : '',
              'phone': p['phone'] is String ? p['phone'] : '',
            };
          }
        }
      }

      return tasks.map((t) {
        final partnerRaw = t['partner_id'];
        if (partnerRaw is List && partnerRaw.isNotEmpty) {
          final pid = (partnerRaw[0] as num).toInt();
          final addr = partnerMap[pid];
          if (addr != null) {
            t['partner_street']  = addr['street'];
            t['partner_city']    = addr['city'];
            t['partner_country'] = addr['country'];
            t['partner_phone']   = addr['phone'];
          }
        }
        return TaskModel.fromMap(t);
      }).toList();
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
