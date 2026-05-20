import 'dart:convert';
import 'dart:developer';
import '../../../core/services/odoo_session_manager.dart';
import '../model/employee_filter.dart';
import '../model/employee_model.dart';

class AssigneePageResult {
  final List<AssigneeModel> assignees;
  final int total;
  const AssigneePageResult({required this.assignees, required this.total});
  static const empty = AssigneePageResult(assignees: [], total: 0);
}

class AssigneeService {
  Future<AssigneePageResult> fetchAssigneesPaged({
    required String search,
    required Set<AssigneeFilterBy> filters,
    required int offset,
    required int limit,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();

    // Base domain: internal active users only
    final domain = <dynamic>[
      ['active', '=', true],
      ['share', '=', false],
    ];

    if (filters.contains(AssigneeFilterBy.archived)) {
      // Replace active=true with active=false
      domain[0] = ['active', '=', false];
    }

    if (filters.contains(AssigneeFilterBy.myDepartment) && session != null) {
      try {
        final empRaw = await OdooSessionManager.callKwWithCompany({
          'model': 'hr.employee',
          'method': 'search_read',
          'args': [[['user_id', '=', session.userId]]],
          'kwargs': {'fields': ['department_id'], 'limit': 1},
        });
        if (empRaw is List && empRaw.isNotEmpty) {
          final deptRaw = empRaw.first['department_id'];
          if (deptRaw is List && deptRaw.isNotEmpty) {
            final deptId = (deptRaw[0] as num).toInt();
            // Get user IDs in this department via hr.employee
            final deptEmps = await OdooSessionManager.callKwWithCompany({
              'model': 'hr.employee',
              'method': 'search_read',
              'args': [[['department_id', '=', deptId], ['user_id', '!=', false]]],
              'kwargs': {'fields': ['user_id']},
            });
            if (deptEmps is List) {
              final userIds = deptEmps
                  .whereType<Map<String, dynamic>>()
                  .map((e) {
                    final u = e['user_id'];
                    return (u is List && u.isNotEmpty)
                        ? (u[0] as num).toInt()
                        : null;
                  })
                  .whereType<int>()
                  .toList();
              domain.add(['id', 'in', userIds]);
            }
          }
        }
      } catch (_) {}
    }

    if (filters.contains(AssigneeFilterBy.myTeam) && session != null) {
      try {
        final empRaw = await OdooSessionManager.callKwWithCompany({
          'model': 'hr.employee',
          'method': 'search_read',
          'args': [[['user_id', '=', session.userId]]],
          'kwargs': {'fields': ['id'], 'limit': 1},
        });
        if (empRaw is List && empRaw.isNotEmpty) {
          final managerId = (empRaw.first['id'] as num).toInt();
          final teamEmps = await OdooSessionManager.callKwWithCompany({
            'model': 'hr.employee',
            'method': 'search_read',
            'args': [[['parent_id', '=', managerId], ['user_id', '!=', false]]],
            'kwargs': {'fields': ['user_id']},
          });
          if (teamEmps is List) {
            final userIds = teamEmps
                .whereType<Map<String, dynamic>>()
                .map((e) {
                  final u = e['user_id'];
                  return (u is List && u.isNotEmpty)
                      ? (u[0] as num).toInt()
                      : null;
                })
                .whereType<int>()
                .toList();
            domain.add(['id', 'in', userIds]);
          }
        }
      } catch (_) {}
    }

    if (search.isNotEmpty) {
      domain.add(['name', 'ilike', search]);
    }

    log('[AssigneeService] domain=$domain offset=$offset limit=$limit');

    try {
      final futures = await Future.wait([
        OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'search_count',
          'args': [domain],
          'kwargs': {},
        }),
        OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': ['id', 'name', 'email', 'phone'],
            'order': 'name asc',
            'limit': limit,
            'offset': offset,
          },
        }),
      ]);

      final total = (futures[0] as num?)?.toInt() ?? 0;
      final raw = futures[1];
      if (raw is! List) return AssigneePageResult.empty;

      final rawList = raw.whereType<Map<String, dynamic>>().toList();
      final userIds = rawList.map((r) => (r['id'] as num).toInt()).toList();

      // Enrich with job_title, department, and manager from hr.employee
      final empMap = await _fetchEmployeeDetails(userIds);

      final assignees = rawList.map((r) {
        final uid = (r['id'] as num).toInt();
        final emp = empMap[uid];
        return AssigneeModel.fromMap({
          ...r,
          'job_title': emp?['job_title'] ?? '',
          'department': emp?['department'] ?? '',
          'manager': emp?['manager'] ?? '',
        });
      }).toList();

      // Fetch avatars from res.users image_128
      final avatarMap = await _fetchAvatars(userIds);
      final enriched = assignees
          .map((a) => avatarMap.containsKey(a.id)
              ? a.copyWithAvatar(avatarMap[a.id]!)
              : a)
          .toList();

      return AssigneePageResult(assignees: enriched, total: total);
    } catch (e) {
      log('[AssigneeService] error: $e');
      return AssigneePageResult.empty;
    }
  }

  Future<Map<int, Map<String, String>>> _fetchEmployeeDetails(
      List<int> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [[['user_id', 'in', userIds]]],
        'kwargs': {
          'fields': ['user_id', 'job_title', 'department_id', 'parent_id'],
        },
      });
      if (result is! List) return {};
      final map = <int, Map<String, String>>{};
      for (final r in result.whereType<Map<String, dynamic>>()) {
        final userRaw = r['user_id'];
        if (userRaw is! List || userRaw.isEmpty) continue;
        final uid = (userRaw[0] as num).toInt();
        final deptRaw = r['department_id'];
        final managerRaw = r['parent_id'];
        map[uid] = {
          'job_title': (r['job_title'] is String && r['job_title'] != 'false')
              ? r['job_title'] as String
              : '',
          'department': (deptRaw is List && deptRaw.length >= 2)
              ? deptRaw[1].toString()
              : '',
          'manager': (managerRaw is List && managerRaw.length >= 2)
              ? managerRaw[1].toString()
              : '',
        };
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<Map<int, List<int>>> _fetchAvatars(List<int> ids) async {
    if (ids.isEmpty) return {};
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[['id', 'in', ids]]],
        'kwargs': {'fields': ['id', 'image_128']},
      });
      if (result is! List) return {};
      final map = <int, List<int>>{};
      for (final r in result.whereType<Map<String, dynamic>>()) {
        final id = (r['id'] as num).toInt();
        final img = r['image_128'];
        if (img is String && img.isNotEmpty && img != 'false') {
          try {
            map[id] = base64Decode(img);
          } catch (_) {}
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
