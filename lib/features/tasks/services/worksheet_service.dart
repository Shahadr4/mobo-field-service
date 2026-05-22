import 'dart:developer';
import '../../../core/services/odoo_session_manager.dart';
import '../model/worksheet_field_model.dart';

// Fields we never render — system internals + the task back-link
// (task is already known from navigation context).
const _kSkipFields = {
  'id',
  'create_uid',
  'create_date',
  'write_uid',
  'write_date',
  '__last_update',
  'display_name',
  'x_project_task_id',
  'project_task_id',
};

class WorksheetActionResult {
  final String resModel;
  final Map<String, dynamic> context;
  final List<dynamic> views;

  const WorksheetActionResult({
    required this.resModel,
    required this.context,
    required this.views,
  });
}

class WorksheetService {
  /// Step 1 — call action_fsm_worksheet to get res_model + context.
  Future<WorksheetActionResult?> fetchWorksheetAction(int taskId) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'action_fsm_worksheet',
        'args': [
          [taskId]
        ],
        'kwargs': {},
      });
      if (result is! Map) return null;
      final m = Map<String, dynamic>.from(result);
      final resModel = m['res_model']?.toString() ?? '';
      if (resModel.isEmpty) return null;
      final ctx = m['context'] is Map
          ? Map<String, dynamic>.from(m['context'] as Map)
          : <String, dynamic>{};
      final views = m['views'] is List ? m['views'] as List : [];
      return WorksheetActionResult(resModel: resModel, context: ctx, views: views);
    } catch (e) {
      log('[WorksheetService] fetchWorksheetAction error: $e');
      return null;
    }
  }

  /// Step 2a — get the ordered list of field names from the Odoo form view.
  /// Uses get_views() (Odoo 16+) with fallback to fields_view_get() (Odoo 14/15).
  /// Returns field names in the order they appear in the form, or empty set
  /// if neither call succeeds (caller falls back to all fields_get fields).
  Future<List<String>> fetchFormViewFieldOrder(String model) async {
    // Try get_views first (Odoo 16+)
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'get_views',
        'args': [
          [[false, 'form']]
        ],
        'kwargs': {},
      });
      if (result is Map) {
        final views = result['views'];
        if (views is Map) {
          final formView = views['form'];
          if (formView is Map) {
            final arch = formView['arch']?.toString() ?? '';
            return _parseFieldsFromArch(arch);
          }
        }
      }
    } catch (_) {}

    // Fallback: fields_view_get (Odoo 14/15)
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'fields_view_get',
        'args': [],
        'kwargs': {'view_type': 'form'},
      });
      if (result is Map) {
        final arch = result['arch']?.toString() ?? '';
        return _parseFieldsFromArch(arch);
      }
    } catch (_) {}

    return [];
  }

  /// Parse field names in order from an XML arch string.
  List<String> _parseFieldsFromArch(String arch) {
    final names = <String>[];
    // Match <field name="xxx" ...> — order-preserving
    final re = RegExp(r'<field[^>]+name="([^"]+)"', unicode: true);
    for (final m in re.allMatches(arch)) {
      final name = m.group(1)!;
      if (!_kSkipFields.contains(name) && !names.contains(name)) {
        names.add(name);
      }
    }
    return names;
  }

  /// Step 2b — get field metadata, filtered and ordered by the form view.
  Future<List<WorksheetFieldMeta>> fetchFieldsMeta(String model) async {
    // Get form-view field order first
    final viewOrder = await fetchFormViewFieldOrder(model);

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'fields_get',
        'args': [],
        'kwargs': {
          'attributes': [
            'string',
            'type',
            'required',
            'readonly',
            'selection',
            'relation',
            'size',
          ],
        },
      });
      if (result is! Map) return [];

      final allMeta = <String, WorksheetFieldMeta>{};
      result.forEach((key, value) {
        final name = key.toString();
        if (_kSkipFields.contains(name)) return;
        if (value is Map) {
          allMeta[name] =
              WorksheetFieldMeta.fromMap(name, Map<String, dynamic>.from(value));
        }
      });

      if (viewOrder.isNotEmpty) {
        // Return only fields present in the form view, in view order
        return viewOrder
            .where((name) => allMeta.containsKey(name))
            .map((name) => allMeta[name]!)
            .toList();
      }

      // Fallback: return all non-system fields
      return allMeta.values.toList();
    } catch (e) {
      log('[WorksheetService] fetchFieldsMeta error: $e');
      return [];
    }
  }

  /// Step 3 — search_read the worksheet record for this task.
  /// Returns the raw map (may be empty if not yet created).
  Future<Map<String, dynamic>?> fetchRecord(
    String model,
    int taskId,
    List<WorksheetFieldMeta> fields,
  ) async {
    try {
      final fieldNames = fields.map((f) => f.name).toList();
      final result = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'search_read',
        'args': [
          [
            ['x_project_task_id', '=', taskId]
          ]
        ],
        'kwargs': {
          'fields': fieldNames,
          'limit': 1,
        },
      });
      if (result is List && result.isNotEmpty) {
        return Map<String, dynamic>.from(result.first as Map);
      }
      return null;
    } catch (e) {
      log('[WorksheetService] fetchRecord error: $e');
      return null;
    }
  }

  /// Fetch relation options (name_search / search_read) for many2one / many2many.
  Future<List<RelationOption>> fetchRelationOptions(
    String model, {
    String query = '',
    int limit = 80,
  }) async {
    try {
      final domain = query.trim().isEmpty
          ? []
          : [
              ['name', 'ilike', query.trim()]
            ];
      final result = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name'],
          'limit': limit,
          'order': 'name asc',
        },
      });
      if (result is! List) return [];
      return result
          .whereType<Map>()
          .map((r) => RelationOption(
                id: (r['id'] as num).toInt(),
                name: r['name']?.toString() ?? '',
              ))
          .toList();
    } catch (e) {
      log('[WorksheetService] fetchRelationOptions error: $e');
      return [];
    }
  }

  /// Write (update) an existing worksheet record.
  Future<String?> writeRecord(
    String model,
    int recordId,
    Map<String, dynamic> vals,
  ) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'write',
        'args': [
          [recordId],
          vals,
        ],
        'kwargs': {},
      });
      return result == true ? null : 'Failed to save worksheet.';
    } catch (e) {
      log('[WorksheetService] writeRecord error: $e');
      return e.toString();
    }
  }

  /// Create a new worksheet record.
  Future<({String? error, int? id})> createRecord(
    String model,
    Map<String, dynamic> vals,
  ) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'create',
        'args': [vals],
        'kwargs': {},
      });
      if (result is int) return (error: null, id: result);
      if (result is num) return (error: null, id: result.toInt());
      return (error: 'Unexpected create response.', id: null);
    } catch (e) {
      log('[WorksheetService] createRecord error: $e');
      return (error: e.toString(), id: null);
    }
  }
}
