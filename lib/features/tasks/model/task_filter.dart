enum TaskFilterBy {
  /// Status
  openTasks,
  closedTasks,
  myTasks,
  unassigned,
  /// Stage
  stageNew,
  stagePlanned,
  stageInProgress,
  stageDone,
  stageCancelled,
  /// Priority
  priorityHigh,
  priorityMedium,
  priorityNormal,
  /// Time
  withDeadline,
  overdue,
  dueToday,
  dueThisWeek,
}

enum TaskGroupBy { none, stage, assignee, project, priority, deadline }
