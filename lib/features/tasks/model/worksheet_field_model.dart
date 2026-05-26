/// Represents a single Odoo field from fields_get() response.
class WorksheetFieldMeta {
  final String name;
  final String label;
  final String type;
  final bool required;
  final bool readonly;
  final List<List<dynamic>> selection; /// [['value', 'Label'], ...]
  final String? relation; /// for many2one / many2many
  final int? size; /// for char

  const WorksheetFieldMeta({
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.readonly = false,
    this.selection = const [],
    this.relation,
    this.size,
  });

  factory WorksheetFieldMeta.fromMap(String fieldName, Map<String, dynamic> m) {
    final sel = (m['selection'] as List?)
            ?.map((e) => e as List<dynamic>)
            .toList() ??
        [];
    return WorksheetFieldMeta(
      name: fieldName,
      label: m['string']?.toString() ?? fieldName,
      type: m['type']?.toString() ?? 'char',
      required: m['required'] == true,
      readonly: m['readonly'] == true,
      selection: sel,
      relation: m['relation']?.toString(),
      size: m['size'] is int ? m['size'] as int : null,
    );
  }
}

/// Represents one option in a many2one / many2many relation list.
class RelationOption {
  final int id;
  final String name;
  const RelationOption({required this.id, required this.name});
}
