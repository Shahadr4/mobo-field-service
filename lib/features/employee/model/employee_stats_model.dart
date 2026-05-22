class EmployeeStats {
  final int assignedTasks;
  final int activeTasks;
  final int completedTasks;
  final int cancelledTasks;
  final double totalHours;
  final double thisMonthHours;

  const EmployeeStats({
    required this.assignedTasks,
    required this.activeTasks,
    required this.completedTasks,
    required this.cancelledTasks,
    required this.totalHours,
    required this.thisMonthHours,
  });

  const EmployeeStats.empty()
      : assignedTasks = 0,
        activeTasks = 0,
        completedTasks = 0,
        cancelledTasks = 0,
        totalHours = 0,
        thisMonthHours = 0;
}
