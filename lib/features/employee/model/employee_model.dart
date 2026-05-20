class AssigneeModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String jobTitle;
  final String department;
  final String manager;
  final List<int> avatar;

  const AssigneeModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.jobTitle,
    required this.department,
    required this.manager,
    required this.avatar,
  });

  factory AssigneeModel.fromMap(Map<String, dynamic> m) {
    String str(dynamic v) => (v is String && v != 'false') ? v : '';

    return AssigneeModel(
      id: (m['id'] as num).toInt(),
      name: str(m['name']),
      email: str(m['email']),
      phone: str(m['phone']),
      jobTitle: str(m['job_title']),
      department: str(m['department']),
      manager: str(m['manager']),
      avatar: [],
    );
  }

  AssigneeModel copyWithAvatar(List<int> bytes) => AssigneeModel(
        id: id,
        name: name,
        email: email,
        phone: phone,
        jobTitle: jobTitle,
        department: department,
        manager: manager,
        avatar: bytes,
      );
}
