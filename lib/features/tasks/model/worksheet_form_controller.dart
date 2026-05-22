import 'package:flutter/material.dart';
import 'worksheet_field_model.dart';

/// Holds the live form values and text controllers for every field.
/// Field values are stored in [values] keyed by field name.
/// Text-based fields also get a [TextEditingController] in [textControllers].
class WorksheetFormController {
  final List<WorksheetFieldMeta> fields;

  /// Current form values. Types vary by field:
  ///  - char / text / html  → String
  ///  - integer             → int
  ///  - float               → double
  ///  - boolean             → bool
  ///  - selection           → String (technical value)
  ///  - date                → String 'YYYY-MM-DD'
  ///  - datetime            → String 'YYYY-MM-DD HH:MM:SS'
  ///  - many2one            → [id, name] or null
  ///  - many2many           → List<[id, name]>
  ///  - binary              → String (base64) or null
  final Map<String, dynamic> values = {};

  final Map<String, TextEditingController> textControllers = {};

  WorksheetFormController({required this.fields});

  /// Seed from a fetched Odoo record map.
  void loadFromRecord(Map<String, dynamic> record) {
    for (final f in fields) {
      final raw = record[f.name];
      values[f.name] = _coerce(f, raw);
      _syncTextController(f);
    }
  }

  /// Initialise with empty / default values when there is no existing record.
  void loadDefaults() {
    for (final f in fields) {
      values[f.name] = _defaultFor(f);
      _syncTextController(f);
    }
  }

  /// Update a field value and sync its text controller if applicable.
  void set(String fieldName, dynamic value) {
    values[fieldName] = value;
    final f = fields.firstWhere((x) => x.name == fieldName,
        orElse: () => WorksheetFieldMeta(name: fieldName, label: '', type: 'char'));
    _syncTextController(f);
  }

  /// Build the write-vals map for Odoo (omits binary — handled separately).
  Map<String, dynamic> buildWriteVals() {
    final out = <String, dynamic>{};
    for (final f in fields) {
      if (f.readonly) continue;
      final v = values[f.name];
      switch (f.type) {
        case 'many2one':
          out[f.name] = (v is List && v.isNotEmpty) ? (v[0] as num).toInt() : false;
        case 'many2many':
          final ids = (v is List)
              ? v.map((e) => (e is List && e.isNotEmpty) ? (e[0] as num).toInt() : e).whereType<int>().toList()
              : <int>[];
          out[f.name] = [[6, 0, ids]];
        case 'binary':
          // binary sent separately via _buildBinaryVals
          break;
        case 'integer':
          out[f.name] = v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);
        case 'float':
          out[f.name] = v is double ? v : (double.tryParse(v?.toString() ?? '') ?? 0.0);
        case 'boolean':
          out[f.name] = v == true;
        case 'html':
          final text = v?.toString().trim() ?? '';
          out[f.name] = text.isEmpty ? false : '<p>$text</p>';
        default:
          out[f.name] = v ?? false;
      }
    }
    return out;
  }

  /// Build write-vals for binary fields only (base64 string → sent as-is).
  Map<String, dynamic> buildBinaryVals() {
    final out = <String, dynamic>{};
    for (final f in fields) {
      if (f.type == 'binary' && !f.readonly) {
        final v = values[f.name];
        out[f.name] = (v != null && v.toString().isNotEmpty) ? v : false;
      }
    }
    return out;
  }

  /// Validate required fields. Returns list of label strings that are empty.
  List<String> validate() {
    final errors = <String>[];
    for (final f in fields) {
      if (!f.required) continue;
      final v = values[f.name];
      bool empty = false;
      switch (f.type) {
        case 'many2one':
          empty = v == null || (v is List && v.isEmpty) || v == false;
        case 'many2many':
          empty = v == null || (v is List && v.isEmpty);
        case 'binary':
          empty = v == null || v.toString().isEmpty;
        case 'boolean':
          empty = v != true; // required boolean must be checked (true)
        default:
          empty = v == null || v.toString().trim().isEmpty || v == false;
      }
      if (empty) errors.add(f.label);
    }
    return errors;
  }

  void dispose() {
    for (final c in textControllers.values) {
      c.dispose();
    }
    textControllers.clear();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  dynamic _coerce(WorksheetFieldMeta f, dynamic raw) {
    if (raw == false || raw == null) return _defaultFor(f);
    switch (f.type) {
      case 'boolean':
        return raw == true;
      case 'integer':
        return raw is int ? raw : (int.tryParse(raw.toString()) ?? 0);
      case 'float':
        return raw is double ? raw : (double.tryParse(raw.toString()) ?? 0.0);
      case 'many2one':
        return raw is List ? raw : null;
      case 'many2many':
        return raw is List ? raw : [];
      case 'binary':
        return raw is String && raw.isNotEmpty ? raw : null;
      case 'html':
        return _stripHtml(raw.toString()); // store plain text internally
      default:
        return raw.toString();
    }
  }

  static final _htmlTagRe = RegExp(r'<[^>]*>');

  /// Remove all HTML tags and decode basic entities for plain-text editing.
  static String _stripHtml(String html) {
    return html
        .replaceAll(_htmlTagRe, '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  dynamic _defaultFor(WorksheetFieldMeta f) {
    switch (f.type) {
      case 'boolean':  return false;
      case 'integer':  return 0;
      case 'float':    return 0.0;
      case 'many2one': return null;
      case 'many2many':return [];
      case 'binary':   return null;
      default:         return '';
    }
  }

  void _syncTextController(WorksheetFieldMeta f) {
    if (!_isTextBased(f.type)) return;
    final ctrl = textControllers.putIfAbsent(f.name, TextEditingController.new);
    final v = values[f.name];
    final text = (v == null || v == false) ? '' : v.toString();
    if (ctrl.text != text) {
      ctrl.text = text;
      ctrl.selection = TextSelection.collapsed(offset: text.length);
    }
  }

  bool _isTextBased(String type) =>
      type == 'char' || type == 'text' || type == 'html' ||
      type == 'integer' || type == 'float';
}
