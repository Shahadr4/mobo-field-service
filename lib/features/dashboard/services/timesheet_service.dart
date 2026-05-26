
import '../../../core/services/odoo_session_manager.dart';
import '../model/project_item_model.dart';

class TimesheetService {

  Future<List<ProjectItem>> fetchProjects() async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return [];

    final userId = session.userId;

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [
            ['is_fsm', '=', true],
            ['user_ids', 'in', [userId]],
            ['project_id', '!=', false],
            if (session.version?.contains('19') == true)
              ['has_template_ancestor', '=', false],
            ['display_in_project', '=', true],
          ]
        ],
        'kwargs': {
          'fields': ['id', 'name', 'project_id', 'stage_id'],
          'order': 'name asc',
          'limit': 200,
        },
      });
      if (result is! List) return [];
      return result
          .whereType<Map<String, dynamic>>()
          .map(ProjectItem.fromMap)
          .toList();
    } catch (e) {
      return [];
    }
  }


  Future<int?> startTimer(int taskId) => _manualStart(taskId);

  Future<int?> _manualStart(int taskId) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) return null;

      final tasks = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [['id', '=', taskId]]
        ],
        'kwargs': {'fields': ['id', 'project_id'], 'limit': 1},
      });
      if (tasks is! List || tasks.isEmpty) return null;

      final projectRaw = tasks[0]['project_id'];
      final projectId =
          projectRaw is List ? (projectRaw[0] as num).toInt() : null;
      if (projectId == null) return null;

      final today = DateTime.now().toIso8601String().substring(0, 10);

      final timesheetId = await OdooSessionManager.callKwWithCompany({
        'model': 'account.analytic.line',
        'method': 'create',
        'args': [
          {
            'task_id': taskId,
            'project_id': projectId,
            'date': today,
            'name': '/',
            'user_id': session.userId,
          }
        ],
        'kwargs': {},
      });

      if (timesheetId == null) return null;
      final tsId = (timesheetId as num).toInt();

      /// timer_start must be UTC in 'YYYY-MM-DD HH:MM:SS' format (no T, no Z)
      final dt = DateTime.now().toUtc();
      String pad(int n) => n.toString().padLeft(2, '0');
      final now = '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
          '${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}';

      await OdooSessionManager.callKwWithCompany({
        'model': 'timer.timer',
        'method': 'create',
        'args': [
          {
            'res_model': 'account.analytic.line',
            'res_id': tsId,
            if(session.version?.contains('19') == true)  'parent_res_model': 'project.task',
        if(session.version?.contains('19') == true)    'parent_res_id': taskId,
            'user_id': session.userId,
            'timer_start': now,
          }
        ],
        'kwargs': {},
      });

      return tsId;
    } catch (e) {
      return null;
    }
  }

  /// ── Stop: call action_timer_stop → wizard → action_save_timesheet ─────────

  Future<bool> stopTimer({
    required int taskId,
    required int timesheetId,
    required Duration elapsed,
    required String description,
  }) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) return false;


      final realId = timesheetId < 0 ? -timesheetId : timesheetId;
      final unitAmount = elapsed.inSeconds / 3600.0;

      /// Step 1 — find and clear the timer.timer record directly
      /// (action_timer_stop opens a wizard in the web UI, doesn't stop via RPC cleanly)
      final timers = await OdooSessionManager.callKwWithCompany({
        'model': 'timer.timer',
        'method': 'search_read',
        'args': [
          [
            ['res_model', '=', 'account.analytic.line'],
            ['res_id', '=', realId],
            ['user_id', '=', session.userId],
          ]
        ],
        'kwargs': {'fields': ['id'], 'limit': 1},
      });

      if (timers is List && timers.isNotEmpty) {
        final timerId = (timers[0]['id'] as num).toInt();
        await OdooSessionManager.callKwWithCompany({
          'model': 'timer.timer',
          'method': 'unlink',
          'args': [[timerId]],
          'kwargs': {},
        });
      }

      /// Step 2 — write unit_amount + description on the analytic line
      await OdooSessionManager.callKwWithCompany({
        'model': 'account.analytic.line',
        'method': 'write',
        'args': [
          [realId],
          {
            'unit_amount': unitAmount,
            'name': description.isEmpty ? '/' : description,
          }
        ],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// ── Manual log: create analytic line with explicit hours + date ──────────

  Future<bool> logManual({
    required int taskId,
    required double hours,
    required DateTime date,
    required String description,
  }) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) return false;

      final tasks = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [['id', '=', taskId]]
        ],
        'kwargs': {'fields': ['id', 'project_id'], 'limit': 1},
      });
      if (tasks is! List || tasks.isEmpty) return false;

      final projectRaw = tasks[0]['project_id'];
      final projectId =
          projectRaw is List ? (projectRaw[0] as num).toInt() : null;
      if (projectId == null) return false;

      String pad(int n) => n.toString().padLeft(2, '0');
      final dateStr =
          '${date.year}-${pad(date.month)}-${pad(date.day)}';

      await OdooSessionManager.callKwWithCompany({
        'model': 'account.analytic.line',
        'method': 'create',
        'args': [
          {
            'task_id': taskId,
            'project_id': projectId,
            'date': dateStr,
            'unit_amount': hours,
            'name': description.isEmpty ? '/' : description,
            'user_id': session.userId,
          }
        ],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// ── Cancel: stop timer + delete the analytic line ─────────────────────────

  Future<void> cancelTimer({
    required int timesheetId,
    required int taskId,
  }) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) return;

      final realId = timesheetId < 0 ? -timesheetId : timesheetId;

      /// Unlink the timer.timer record
      final timers = await OdooSessionManager.callKwWithCompany({
        'model': 'timer.timer',
        'method': 'search_read',
        'args': [
          [
            ['res_model', '=', 'account.analytic.line'],
            ['res_id', '=', realId],
            ['user_id', '=', session.userId],
          ]
        ],
        'kwargs': {'fields': ['id'], 'limit': 1},
      });

      if (timers is List && timers.isNotEmpty) {
        final timerId = (timers[0]['id'] as num).toInt();
        await OdooSessionManager.callKwWithCompany({
          'model': 'timer.timer',
          'method': 'unlink',
          'args': [[timerId]],
          'kwargs': {},
        });
      }

      /// Delete the analytic line
      await OdooSessionManager.callKwWithCompany({
        'model': 'account.analytic.line',
        'method': 'unlink',
        'args': [[realId]],
        'kwargs': {},
      });

    } catch (e) {
    }
  }
}
