class TaskStats {
  final int activeTasks;
  final int assignedTasks;
  final int completedTasks;
  final int totalTasks;

  const TaskStats({
    required this.activeTasks,
    required this.assignedTasks,
    required this.completedTasks,
    required this.totalTasks,
  });

  const TaskStats.empty()
      : activeTasks = 0,
        assignedTasks = 0,
        completedTasks = 0,
        totalTasks = 0;
}
