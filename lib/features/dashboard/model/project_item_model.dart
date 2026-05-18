class ProjectItem {
  final int id;
  final String name;
  final String projectName;
  final String stageName;

  const ProjectItem({
    required this.id,
    required this.name,
    required this.projectName,
    this.stageName = '',
  });

  factory ProjectItem.fromMap(Map<String, dynamic> map) {
    String rel(dynamic v) {
      if (v == false || v == null) return '';
      if (v is List && v.length == 2) return v[1].toString();
      return v.toString();
    }

    return ProjectItem(
      id: (map['id'] as num).toInt(),
      name: map['name']?.toString() ?? '',
      projectName: rel(map['project_id']),
      stageName: rel(map['stage_id']),
    );
  }
}
