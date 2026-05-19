import 'dart:developer';
import '../../../core/services/odoo_session_manager.dart';
import '../model/task_filter.dart';
import '../model/task_model.dart';

class TaskPageResult {
  final List<TaskModel> tasks;
  final int total;
  const TaskPageResult({required this.tasks, required this.total});
}

class TaskService {
  /// Returns one self-contained Odoo domain expression (a List) per filter.
  /// Multi-term filters (e.g. overdue needs two conditions ANDed) are wrapped
  /// with explicit '&' so they read as a single logical unit when OR-chained.
  List<dynamic> _filterExpr(TaskFilterBy f, int userId, String today, String tomorrow, String weekEnd) {
    switch (f) {
      case TaskFilterBy.openTasks:
        return ['!', '|', '|',
          ['stage_id.name', 'ilike', 'done'],
          ['stage_id.name', 'ilike', 'complete'],
          ['stage_id.name', 'ilike', 'cancel'],
        ];
      case TaskFilterBy.closedTasks:
        return ['|', '|',
          ['stage_id.name', 'ilike', 'done'],
          ['stage_id.name', 'ilike', 'complete'],
          ['stage_id.name', 'ilike', 'cancel'],
        ];
      case TaskFilterBy.myTasks:
        return [['user_ids', 'in', [userId]]];
      case TaskFilterBy.unassigned:
        return [['user_ids', '=', false]];
      case TaskFilterBy.stageNew:
        return [['stage_id.name', 'ilike', 'new']];
      case TaskFilterBy.stagePlanned:
        return [['stage_id.name', 'ilike', 'plan']];
      case TaskFilterBy.stageInProgress:
        return ['|',
          ['stage_id.name', 'ilike', 'progress'],
          ['stage_id.name', 'ilike', 'ongoing'],
        ];
      case TaskFilterBy.stageDone:
        return ['|',
          ['stage_id.name', 'ilike', 'done'],
          ['stage_id.name', 'ilike', 'complete'],
        ];
      case TaskFilterBy.stageCancelled:
        return [['stage_id.name', 'ilike', 'cancel']];
      case TaskFilterBy.priorityHigh:
        return [['priority', '=', '3']];
      case TaskFilterBy.priorityMedium:
        return [['priority', '=', '2']];
      case TaskFilterBy.priorityNormal:
        return ['|',
          ['priority', '=', '0'],
          ['priority', '=', '1'],
        ];
      case TaskFilterBy.withDeadline:
        return [['date_deadline', '!=', false]];
      case TaskFilterBy.overdue:
        // AND of two conditions — wrap with explicit '&'
        return ['&',
          ['date_deadline', '!=', false],
          ['date_deadline', '<', today],
        ];
      case TaskFilterBy.dueToday:
        return ['&',
          ['date_deadline', '>=', today],
          ['date_deadline', '<',  tomorrow],
        ];
      case TaskFilterBy.dueThisWeek:
        return ['&',
          ['date_deadline', '>=', today],
          ['date_deadline', '<=', weekEnd],
        ];
    }
  }

  /// OR-chains all per-filter expressions into a single domain fragment.
  /// With N expressions, Odoo needs N-1 '|' operators prepended.
  Future<List<dynamic>> _buildFilterDomain(
    Set<TaskFilterBy> filters,
    int userId,
  ) async {
    final now      = DateTime.now();
    final todayDt  = DateTime(now.year, now.month, now.day);
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    final today    = fmt(todayDt);
    final tomorrow = fmt(todayDt.add(const Duration(days: 1)));
    final weekEnd  = fmt(todayDt.add(const Duration(days: 7)));

    final exprs = filters
        .map((f) => _filterExpr(f, userId, today, tomorrow, weekEnd))
        .toList();

    if (exprs.isEmpty) return [];

    // Single filter — just return its expression
    if (exprs.length == 1) {
      log('[TaskService] filter domain: ${exprs.first}');
      return exprs.first;
    }

    // Multiple filters — prepend (N-1) '|' operators then flatten all expressions
    final result = <dynamic>[
      for (int i = 0; i < exprs.length - 1; i++) '|',
      ...exprs.expand((e) => e),
    ];
    log('[TaskService] filter domain (OR of ${exprs.length}): $result');
    return result;
  }

  Future<TaskPageResult> fetchTasksPaged({
    String? stageFilter,
    String? search,
    Set<TaskFilterBy> filters = const {},
    int offset = 0,
    int limit  = 40,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return const TaskPageResult(tasks: [], total: 0);

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

    if (filters.isNotEmpty) {
      final filterClauses = await _buildFilterDomain(filters, session.userId);
      domain.addAll(filterClauses);
    }

    log('[TaskService] fetchTasksPaged domain: $domain  offset=$offset limit=$limit');

    try {
      // Fetch total count and page data in parallel
      final futures = await Future.wait([
        OdooSessionManager.callKwWithCompany({
          'model': 'project.task',
          'method': 'search_count',
          'args': [domain],
          'kwargs': {},
        }),
        OdooSessionManager.callKwWithCompany({
          'model': 'project.task',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': [
              'id', 'name', 'project_id', 'stage_id', 'user_ids', 'partner_id',
              'planned_date_begin', 'date_deadline', 'create_date', 'priority',
              'description', 'allocated_hours', 'effective_hours',
              'remaining_hours', 'tag_ids', 'under_warranty',
            ],
            'order': 'name asc',
            'limit': limit,
            'offset': offset,
          },
        }),
      ]);

      final total  = (futures[0] as num?)?.toInt() ?? 0;
      final result = futures[1];

      if (result is! List) return TaskPageResult(tasks: [], total: total);

      final tasks = result.whereType<Map<String, dynamic>>().toList();
      await _enrichTasks(tasks);
      return TaskPageResult(
        tasks: tasks.map(TaskModel.fromMap).toList(),
        total: total,
      );
    } catch (e) {
      log('[TaskService] ⚠️ fetchTasksPaged error: $e');
      return const TaskPageResult(tasks: [], total: 0);
    }
  }

  Future<void> _enrichTasks(List<Map<String, dynamic>> tasks) async {
    // Resolve partner addresses
    final partnerIds = tasks
        .map((t) => t['partner_id'])
        .where((v) => v is List && v.isNotEmpty)
        .map((v) => (v[0] as num).toInt())
        .toSet()
        .toList();

    if (partnerIds.isNotEmpty) {
      final partners = await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [[['id', 'in', partnerIds]]],
        'kwargs': {'fields': ['id', 'street', 'city', 'country_id', 'phone']},
      });
      if (partners is List) {
        final map = <int, Map<String, dynamic>>{};
        for (final p in partners.whereType<Map<String, dynamic>>()) {
          final id = (p['id'] as num).toInt();
          final countryRaw = p['country_id'];
          map[id] = {
            'street':  p['street']  is String ? p['street']  : '',
            'city':    p['city']    is String ? p['city']    : '',
            'country': countryRaw is List && countryRaw.length >= 2 ? countryRaw[1].toString() : '',
            'phone':   p['phone']   is String ? p['phone']   : '',
          };
        }
        for (final t in tasks) {
          final raw = t['partner_id'];
          if (raw is List && raw.isNotEmpty) {
            final addr = map[(raw[0] as num).toInt()];
            if (addr != null) {
              t['partner_street']  = addr['street'];
              t['partner_city']    = addr['city'];
              t['partner_country'] = addr['country'];
              t['partner_phone']   = addr['phone'];
            }
          }
        }
      }
    }

    // Resolve user names for user_ids (Odoo returns flat int list from search_read)
    final allUserIds = tasks
        .expand((t) => t['user_ids'] is List ? (t['user_ids'] as List) : <dynamic>[])
        .whereType<int>()
        .toSet()
        .toList();

    if (allUserIds.isNotEmpty) {
      final users = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[['id', 'in', allUserIds]]],
        'kwargs': {'fields': ['id', 'name']},
      });
      if (users is List) {
        final userMap = <int, String>{};
        for (final u in users.whereType<Map<String, dynamic>>()) {
          userMap[(u['id'] as num).toInt()] = u['name']?.toString() ?? '';
        }
        for (final t in tasks) {
          final ids = t['user_ids'];
          if (ids is List) {
            final names = ids.whereType<int>()
                .map((id) => userMap[id] ?? '')
                .where((s) => s.isNotEmpty)
                .join(', ');
            t['user_names'] = names;
          }
        }
      }
    }

    // Resolve tag names
    final allTagIds = tasks
        .expand((t) => t['tag_ids'] is List ? (t['tag_ids'] as List) : <dynamic>[])
        .whereType<int>()
        .toSet()
        .toList();

    if (allTagIds.isNotEmpty) {
      final tags = await OdooSessionManager.callKwWithCompany({
        'model': 'project.tags',
        'method': 'search_read',
        'args': [[['id', 'in', allTagIds]]],
        'kwargs': {'fields': ['id', 'name']},
      });
      if (tags is List) {
        final tagMap = <int, String>{};
        for (final tag in tags.whereType<Map<String, dynamic>>()) {
          tagMap[(tag['id'] as num).toInt()] = tag['name']?.toString() ?? '';
        }
        for (final t in tasks) {
          final ids = t['tag_ids'];
          if (ids is List) {
            t['tag_names'] = ids.whereType<int>()
                .map((id) => tagMap[id] ?? '')
                .where((s) => s.isNotEmpty)
                .join(', ');
          }
        }
      }
    }
  }

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
            'remaining_hours',
            'tag_ids',
            'under_warranty',
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
          .where((v) => v is List && v.isNotEmpty)
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

      // Collect unique tag IDs across all tasks
      final allTagIds = tasks
          .expand((t) => t['tag_ids'] is List ? (t['tag_ids'] as List) : <dynamic>[])
          .whereType<int>()
          .toSet()
          .toList();

      final Map<int, String> tagMap = {};
      if (allTagIds.isNotEmpty) {
        final tags = await OdooSessionManager.callKwWithCompany({
          'model': 'project.tags',
          'method': 'search_read',
          'args': [[['id', 'in', allTagIds]]],
          'kwargs': {'fields': ['id', 'name']},
        });
        if (tags is List) {
          for (final tag in tags.whereType<Map<String, dynamic>>()) {
            tagMap[(tag['id'] as num).toInt()] = tag['name']?.toString() ?? '';
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
        final tagIds = t['tag_ids'];
        if (tagIds is List) {
          t['tag_names'] = tagIds
              .whereType<int>()
              .map((id) => tagMap[id] ?? '')
              .where((s) => s.isNotEmpty)
              .join(', ');
        }
        return TaskModel.fromMap(t);
      }).toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchTasks error: $e');
      return [];
    }
  }

  Future<TaskModel?> fetchTaskById(int id) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [['id', '=', id]]
        ],
        'kwargs': {
          'fields': [
            'id', 'name', 'project_id', 'stage_id', 'user_ids', 'partner_id',
            'planned_date_begin', 'date_deadline', 'create_date', 'priority',
            'description', 'allocated_hours', 'effective_hours',
            'remaining_hours', 'tag_ids', 'under_warranty',
          ],
          'limit': 1,
        },
      });

      if (result is! List || result.isEmpty) return null;
      final t = Map<String, dynamic>.from(result.first as Map);

      final partnerRaw = t['partner_id'];
      if (partnerRaw is List && partnerRaw.isNotEmpty) {
        final pid = (partnerRaw[0] as num).toInt();
        final partners = await OdooSessionManager.callKwWithCompany({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [
            [['id', '=', pid]]
          ],
          'kwargs': {
            'fields': ['id', 'street', 'city', 'country_id', 'phone'],
            'limit': 1,
          },
        });
        if (partners is List && partners.isNotEmpty) {
          final p = partners.first as Map<String, dynamic>;
          final countryRaw = p['country_id'];
          t['partner_street']  = p['street'] is String ? p['street'] : '';
          t['partner_city']    = p['city'] is String ? p['city'] : '';
          t['partner_country'] = countryRaw is List && countryRaw.length >= 2
              ? countryRaw[1].toString() : '';
          t['partner_phone']   = p['phone'] is String ? p['phone'] : '';
        }
      }
      // Resolve user names
      final userIds = t['user_ids'];
      if (userIds is List && userIds.isNotEmpty) {
        final ids = userIds.whereType<int>().toList();
        if (ids.isNotEmpty) {
          final users = await OdooSessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'search_read',
            'args': [[['id', 'in', ids]]],
            'kwargs': {'fields': ['id', 'name']},
          });
          if (users is List) {
            final userMap = <int, String>{};
            for (final u in users.whereType<Map<String, dynamic>>()) {
              userMap[(u['id'] as num).toInt()] = u['name']?.toString() ?? '';
            }
            t['user_names'] = ids
                .map((id) => userMap[id] ?? '')
                .where((s) => s.isNotEmpty)
                .join(', ');
          }
        }
      }

      // Resolve tag names
      final tagIds = t['tag_ids'];
      if (tagIds is List && tagIds.isNotEmpty) {
        final ids = tagIds.whereType<int>().toList();
        final tags = await OdooSessionManager.callKwWithCompany({
          'model': 'project.tags',
          'method': 'search_read',
          'args': [[['id', 'in', ids]]],
          'kwargs': {'fields': ['id', 'name']},
        });
        if (tags is List) {
          t['tag_names'] = tags
              .whereType<Map<String, dynamic>>()
              .map((tag) => tag['name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .join(', ');
        }
      }

      return TaskModel.fromMap(t);
    } catch (e) {
      log('[TaskService] ⚠️ fetchTaskById error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSubtasks(int taskId) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [['parent_id', '=', taskId]]
        ],
        'kwargs': {
          'fields': ['id', 'name', 'stage_id', 'user_ids', 'date_deadline', 'priority'],
          'order': 'name asc',
        },
      });
      if (result is! List) return [];
      final tasks = result.whereType<Map<String, dynamic>>().toList();

      // Resolve user names for subtasks
      final allUserIds = tasks
          .expand((t) => t['user_ids'] is List ? (t['user_ids'] as List) : <dynamic>[])
          .whereType<int>()
          .toSet()
          .toList();

      if (allUserIds.isNotEmpty) {
        final users = await OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'search_read',
          'args': [[['id', 'in', allUserIds]]],
          'kwargs': {'fields': ['id', 'name']},
        });
        if (users is List) {
          final userMap = <int, String>{};
          for (final u in users.whereType<Map<String, dynamic>>()) {
            userMap[(u['id'] as num).toInt()] = u['name']?.toString() ?? '';
          }
          for (final t in tasks) {
            final ids = t['user_ids'];
            if (ids is List) {
              t['user_names'] = ids.whereType<int>()
                  .map((id) => userMap[id] ?? '')
                  .where((s) => s.isNotEmpty)
                  .join(', ');
            }
          }
        }
      }

      return tasks;
    } catch (e) {
      log('[TaskService] ⚠️ fetchSubtasks error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchTimesheets(int taskId) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'account.analytic.line',
        'method': 'search_read',
        'args': [
          [['task_id', '=', taskId]]
        ],
        'kwargs': {
          'fields': ['id', 'date', 'name', 'unit_amount', 'user_id'],
          'order': 'date desc',
        },
      });
      if (result is! List) return [];
      return result.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchTimesheets error: $e');
      return [];
    }
  }

  /// Returns list of [{'id': int, 'name': String}] FSM projects.
  Future<List<Map<String, dynamic>>> fetchProjects() async {
    try {
      final comapnyId = await OdooSessionManager.getSelectedCompanyId();
      if (comapnyId == null) return [];

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.project',
        'method': 'search_read',
        'args': [[['is_fsm', '=', true]]],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      },companyId: comapnyId,allowedCompanyIds: [comapnyId]);
      if (result is! List) return [];
      return result.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchProjects error: $e');
      return [];
    }
  }

  /// Returns list of [{'id': int, 'name': String}] stage types.
  Future<List<Map<String, dynamic>>> fetchStageObjects({int? projectId}) async {
    try {
      final companyid = await OdooSessionManager.getSelectedCompanyId();
      if (companyid == null) return [];

      final domain = <dynamic>[];
      if (projectId != null) {
        domain.add(['project_ids', '=', projectId]);
      }

      final result = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'project.task.type',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': ['id', 'name'],
            'order': 'sequence asc',
          },
        },
        companyId: companyid,
        allowedCompanyIds: [companyid],
      );
      if (result is! List) return [];
      log("[TaskService] fetchStageObjects result: $result");
      return result.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchStageObjects error: $e');
      return [];
    }
  }

  /// Returns list of [{'id': int, 'name': String}] active internal users.
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[['active', '=', true], ['share', '=', false]]],
        'kwargs': {'fields': ['id', 'name'], 'order': 'name asc', 'limit': 200},
      });
      if (result is! List) return [];
      return result.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchUsers error: $e');
      return [];
    }
  }

  /// Returns list of [{'id': int, 'name': String}] customers/partners.
  Future<List<Map<String, dynamic>>> fetchCustomers({String search = ''}) async {
    try {
      final domain = <dynamic>[['customer_rank', '>', 0]];
      if (search.trim().isNotEmpty) domain.add(['name', 'ilike', search.trim()]);
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {'fields': ['id', 'name', 'phone'], 'order': 'name asc', 'limit': 100},
      });
      if (result is! List) return [];
      return result.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchCustomers error: $e');
      return [];
    }
  }

  /// Returns list of [{'id': int, 'name': String}] worksheet templates.
  Future<List<Map<String, dynamic>>> fetchWorksheetTemplates() async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'worksheet.template',
        'method': 'search_read',
        'args': [[['active', '=', true]]],
        'kwargs': {'fields': ['id', 'name'], 'order': 'name asc', 'limit': 100},
      });
      if (result is! List) return [];
      return result.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchWorksheetTemplates error: $e');
      return [];
    }
  }

  /// Returns list of [{'id': int, 'name': String}] project tags.
  Future<List<Map<String, dynamic>>> fetchTags() async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.tags',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {'fields': ['id', 'name'], 'order': 'name asc', 'limit': 200},
      });
      if (result is! List) return [];
      return result.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[TaskService] ⚠️ fetchTags error: $e');
      return [];
    }
  }

  /// Creates a new FSM task. Returns the new task id or null on failure.
  Future<int?> createTask({
    required String name,
    required int projectId,
    int? stageId,
    String? deadline,
    List<int> assigneeIds = const [],
    int? partnerId,
    double allocatedHours = 0,
    bool underWarranty = false,
    DateTime? plannedDateBegin,
    DateTime? plannedDateEnd,
    List<int> tagIds = const [],
    int? worksheetTemplateId,
    String? description,
    int priority = 0,
  }) async {
    try {
      String fmtDt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:00';

      final vals = <String, dynamic>{
        'name': name,
        'project_id': projectId,
        'is_fsm': true,
      };
      if (priority > 0) vals['priority'] = priority.toString();
      if (description != null && description.isNotEmpty) vals['description'] = description;
      if (stageId != null) vals['stage_id'] = stageId;
      if (plannedDateEnd != null) {
        vals['date_deadline'] = '${plannedDateEnd.year}-${plannedDateEnd.month.toString().padLeft(2,'0')}-${plannedDateEnd.day.toString().padLeft(2,'0')}';
      } else if (deadline != null && deadline.isNotEmpty) {
        vals['date_deadline'] = deadline;
      }
      if (assigneeIds.isNotEmpty) vals['user_ids'] = [
        [6, 0, assigneeIds]
      ];
      if (partnerId != null) vals['partner_id'] = partnerId;
      if (allocatedHours > 0) vals['allocated_hours'] = allocatedHours;
      if (underWarranty) vals['under_warranty'] = true;
      if (tagIds.isNotEmpty) vals['tag_ids'] = [
        [6, 0, tagIds]
      ];
      if (worksheetTemplateId != null) vals['worksheet_template_id'] = worksheetTemplateId;
      if (plannedDateBegin != null) vals['planned_date_begin'] = fmtDt(plannedDateBegin);

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'create',
        'args': [vals],
        'kwargs': {},
      });
      log('[TaskService] createTask result: $result');
      return (result as num?)?.toInt();
    } catch (e) {
      log('[TaskService] ⚠️ createTask error: $e');
      return null;
    }
  }

  /// Updates an existing FSM task. Returns null on success, or an error message on failure.
  Future<String?> updateTask({
    required int taskId,
    String? name,
    int? projectId,
    int? stageId,
    List<int>? assigneeIds,
    int? partnerId,
    double? allocatedHours,
    bool? underWarranty,
    DateTime? plannedDateBegin,
    DateTime? plannedDateEnd,
    List<int>? tagIds,
    int? worksheetTemplateId,
    String? description,
    int? priority,
  }) async {
    try {
      String fmtDt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:00';

      final vals = <String, dynamic>{};
      if (name != null) vals['name'] = name;
      if (projectId != null) vals['project_id'] = projectId;
      if (stageId != null) vals['stage_id'] = stageId;
      if (description != null) vals['description'] = description;
      if (priority != null) vals['priority'] = priority.toString();
      if (plannedDateEnd != null) {
        vals['date_deadline'] = '${plannedDateEnd.year}-${plannedDateEnd.month.toString().padLeft(2,'0')}-${plannedDateEnd.day.toString().padLeft(2,'0')}';
      }
      if (assigneeIds != null) {
        vals['user_ids'] = [
          [6, 0, assigneeIds]
        ];
      }
      if (partnerId != null) vals['partner_id'] = partnerId;
      if (allocatedHours != null) vals['allocated_hours'] = allocatedHours;
      if (underWarranty != null) vals['under_warranty'] = underWarranty;
      if (tagIds != null) {
        vals['tag_ids'] = [
          [6, 0, tagIds]
        ];
      }
      if (worksheetTemplateId != null) vals['worksheet_template_id'] = worksheetTemplateId;
      if (plannedDateBegin != null) vals['planned_date_begin'] = fmtDt(plannedDateBegin);

      if (vals.isEmpty) return null;

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'write',
        'args': [
          [taskId],
          vals
        ],
        'kwargs': {},
      });
      log('[TaskService] updateTask result: $result');
      if (result == true) return null;
      return 'Failed to update task.';
    } catch (e) {
      log('[TaskService] ⚠️ updateTask error: $e');
      final errStr = e.toString();
      if (errStr.contains('planned start date must be before') ||
          errStr.contains('planned_dates_check')) {
        return 'The planned start date must be before the planned end date (which is registered as midnight in your Odoo database planning settings).';
      }
      return errStr;
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
