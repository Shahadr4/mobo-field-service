class TaskModel {
  final int id;
  final String name;
  final String projectName;
  final String stageName;
  final String assigneeName;
  final String createDate;

  const TaskModel({
    required this.id,
    required this.name,
    required this.projectName,
    required this.stageName,
    required this.assigneeName,
    required this.createDate,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    String rel(dynamic v) {
      if (v == false || v == null) return '';
      if (v is List && v.length >= 2) return v[1].toString();
      return v.toString();
    }

    String assignees(dynamic v) {
      if (v == false || v == null) return '';
      if (v is List) {
        return v
            .whereType<List>()
            .map((e) => e.length >= 2 ? e[1].toString() : '')
            .where((s) => s.isNotEmpty)
            .join(', ');
      }
      return '';
    }

    // Parse "2026-05-12 10:30:00" → "2026-05-12"
    String parseDate(dynamic v) {
      if (v == false || v == null) return '';
      final s = v.toString();
      return s.length >= 10 ? s.substring(0, 10) : s;
    }

    return TaskModel(
      id: (map['id'] as num).toInt(),
      name: map['name']?.toString() ?? '',
      projectName: rel(map['project_id']),
      stageName: rel(map['stage_id']),
      assigneeName: assignees(map['user_ids']),
      createDate: parseDate(map['create_date']),
    );
  }
}
