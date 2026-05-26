class TimesheetEntry {
  final int id;
  final String taskName;
  final String projectName;
  final String description;
  final double hours;
  final String date; /// 'YYYY-MM-DD'
  final int taskId;
  final int projectId;

  const TimesheetEntry({
    required this.id,
    required this.taskName,
    required this.projectName,
    required this.description,
    required this.hours,
    required this.date,
    required this.taskId,
    required this.projectId,
  });

  factory TimesheetEntry.fromMap(Map<String, dynamic> m) {
    String rel(dynamic v) {
      if (v == false || v == null) return '';
      if (v is List && v.length >= 2) return v[1].toString();
      return v.toString();
    }

    int relId(dynamic v) {
      if (v is List && v.isNotEmpty) return (v[0] as num).toInt();
      return 0;
    }

    return TimesheetEntry(
      id: (m['id'] as num).toInt(),
      taskName: rel(m['task_id']),
      projectName: rel(m['project_id']),
      description: m['name'] is String && m['name'] != '/' ? m['name'] as String : '',
      hours: (m['unit_amount'] as num?)?.toDouble() ?? 0.0,
      date: m['date']?.toString() ?? '',
      taskId: relId(m['task_id']),
      projectId: relId(m['project_id']),
    );
  }

  String get formattedHours {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Returns the display group key for a given groupBy mode.
  String groupKey(TimesheetGroupBy groupBy) {
    switch (groupBy) {
      case TimesheetGroupBy.task:
        return taskName.isEmpty ? 'No Task' : taskName;
      case TimesheetGroupBy.day:
        return date.length >= 10 ? date.substring(0, 10) : date;
      case TimesheetGroupBy.week:
        return _weekLabel(date);
      case TimesheetGroupBy.month:
        return _monthLabel(date);
      case TimesheetGroupBy.quarter:
        return _quarterLabel(date);
      case TimesheetGroupBy.year:
        return date.length >= 4 ? date.substring(0, 4) : date;
      case TimesheetGroupBy.none:
        return '';
    }
  }

  static String _weekLabel(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    /// Monday of the week
    final mon = dt.subtract(Duration(days: dt.weekday - 1));
    final sun = mon.add(const Duration(days: 6));
    return 'Week ${_d(mon)} – ${_d(sun)}';
  }

  static String _monthLabel(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.year}';
  }

  static String _quarterLabel(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    final q = ((dt.month - 1) ~/ 3) + 1;
    return 'Q$q ${dt.year}';
  }

  static String _d(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
}

enum TimesheetGroupBy { none, task, day, week, month, quarter, year }

enum TimesheetDateFilter { all, today, yesterday, thisWeek, thisMonth }

extension TimesheetDateFilterLabel on TimesheetDateFilter {
  String get label {
    switch (this) {
      case TimesheetDateFilter.all: return 'All';
      case TimesheetDateFilter.today: return 'Today';
      case TimesheetDateFilter.yesterday: return 'Yesterday';
      case TimesheetDateFilter.thisWeek: return 'This Week';
      case TimesheetDateFilter.thisMonth: return 'This Month';
    }
  }
}

extension TimesheetGroupByLabel on TimesheetGroupBy {
  String get label {
    switch (this) {
      case TimesheetGroupBy.none: return 'None';
      case TimesheetGroupBy.task: return 'Task';
      case TimesheetGroupBy.day: return 'Day';
      case TimesheetGroupBy.week: return 'Week';
      case TimesheetGroupBy.month: return 'Month';
      case TimesheetGroupBy.quarter: return 'Quarter';
      case TimesheetGroupBy.year: return 'Year';
    }
  }
}
