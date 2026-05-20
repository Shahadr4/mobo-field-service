enum AssigneeFilterBy {
  myDepartment,
  myTeam,
  archived,
}

enum AssigneeGroupBy {
  none,
  department,
  jobTitle,
  manager;

  String get label => switch (this) {
        AssigneeGroupBy.none => 'None',
        AssigneeGroupBy.department => 'Department',
        AssigneeGroupBy.jobTitle => 'Job Title',
        AssigneeGroupBy.manager => 'Manager',
      };
}
