import 'dart:developer';
import '../../../core/services/odoo_session_manager.dart';
import '../model/project_item_model.dart';

class TimesheetService {
  // ── Fetch FSM tasks ───────────────────────────────────────────────────────

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
      log('[TimesheetService] ⚠️ fetchProjects error: $e');
      return [];
    }
  }

  // ── Start: create analytic line + timer.timer directly ───────────────────
  //
  // We bypass project.task.action_timer_start because it is guarded by
  // display_timesheet_timer (requires allow_timesheets + analytic_account_active
  // + user has employee), which may silently do nothing via RPC.
  // Instead we replicate what _create_record_to_start_timer + _create_timer do.

  Future<int?> startTimer(int taskId) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) return null;

      // Resolve project_id for this task
      final tasks = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', taskId]
          ]
        ],
        'kwargs': {
          'fields': ['id', 'project_id'],
          'limit': 1,
        },
      });
      if (tasks is! List || tasks.isEmpty) return null;

      final projectRaw = tasks[0]['project_id'];
      final projectId = projectRaw is List ? (projectRaw[0] as num).toInt() : null;
      if (projectId == null) return null;

      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Step 1 — create account.analytic.line (timesheet record)
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

      // Step 2 — create timer.timer and start it
      // res_model/res_id point to the analytic line
      // parent_res_model/parent_res_id point to the task (for user_timer_id lookup)
      final dt = DateTime.now().toUtc();
      final now =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      await OdooSessionManager.callKwWithCompany({
        'model': 'timer.timer',
        'method': 'create',
        'args': [
          {
            'res_model': 'account.analytic.line',
            'res_id': tsId,
            'parent_res_model': 'project.task',
            'parent_res_id': taskId,
            'user_id': session.userId,
            'timer_start': now,
          }
        ],
        'kwargs': {},
      });

      log('[TimesheetService] ▶ timer started task=$taskId timesheet=$tsId');
      return tsId;
    } catch (e) {
      log('[TimesheetService] ⚠️ startTimer error: $e');
      return null;
    }
  }

  // ── Stop: clear timer + write unit_amount on analytic line ───────────────

  Future<bool> stopTimer({
    required int taskId,
    required int timesheetId,
    required Duration elapsed,
    required String description,
  }) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) return false;

      // Find the timer.timer record for this task + user
      final timers = await OdooSessionManager.callKwWithCompany({
        'model': 'timer.timer',
        'method': 'search_read',
        'args': [
          [
            ['res_model', '=', 'account.analytic.line'],
            ['res_id', '=', timesheetId],
            ['user_id', '=', session.userId],
          ]
        ],
        'kwargs': {
          'fields': ['id'],
          'limit': 1,
        },
      });

      if (timers is List && timers.isNotEmpty) {
        final timerId = (timers[0]['id'] as num).toInt();
        // Clear the timer (stops the running indicator in backend)
        await OdooSessionManager.callKwWithCompany({
          'model': 'timer.timer',
          'method': 'write',
          'args': [
            [timerId],
            {'timer_start': false, 'timer_pause': false}
          ],
          'kwargs': {},
        });
        log('[TimesheetService] ⏹ timer cleared id=$timerId');
      }

      // Send exact elapsed seconds as fractional hours
      final unitAmount = elapsed.inSeconds / 3600.0;

      log("unit time  ===. $unitAmount");
      // Write unit_amount + description directly on the analytic line
      await OdooSessionManager.callKwWithCompany({
        'model': 'account.analytic.line',
        'method': 'write',
        'args': [
          [timesheetId],
          {
            'unit_amount': unitAmount,
            'name': description.isEmpty ? '/' : description,
          }
        ],
        'kwargs': {},
      });

      log('[TimesheetService] ✅ timesheet saved id=$timesheetId '
          'elapsed=${elapsed.inSeconds}s unitAmount=$unitAmount');
      return true;
    } catch (e) {
      log('[TimesheetService] ⚠️ stopTimer error: $e');
      return false;
    }
  }

  // ── Cancel: stop timer + delete the analytic line ─────────────────────────

  Future<void> cancelTimer({
    required int timesheetId,
    required int taskId,
  }) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) return;

      // Stop and unlink the timer.timer record
      final timers = await OdooSessionManager.callKwWithCompany({
        'model': 'timer.timer',
        'method': 'search_read',
        'args': [
          [
            ['res_model', '=', 'account.analytic.line'],
            ['res_id', '=', timesheetId],
            ['user_id', '=', session.userId],
          ]
        ],
        'kwargs': {
          'fields': ['id'],
          'limit': 1,
        },
      });

      if (timers is List && timers.isNotEmpty) {
        final timerId = (timers[0]['id'] as num).toInt();
        await OdooSessionManager.callKwWithCompany({
          'model': 'timer.timer',
          'method': 'unlink',
          'args': [
            [timerId]
          ],
          'kwargs': {},
        });
      }

      // Delete the analytic line — nothing to keep
      await OdooSessionManager.callKwWithCompany({
        'model': 'account.analytic.line',
        'method': 'unlink',
        'args': [
          [timesheetId]
        ],
        'kwargs': {},
      });

      log('[TimesheetService]  cancelled timesheet=$timesheetId task=$taskId');
    } catch (e) {
      log('[TimesheetService]  cancelTimer error: $e');
    }
  }
}
