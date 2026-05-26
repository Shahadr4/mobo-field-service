
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_feild_service/features/tasks/model/task_filter.dart';

void main() {
  /// ── Group: TaskFilterBy enum ───────────────────────────────────────────────

  group('TaskFilterBy enum', () {
    test('contains myTasks value', () {
      expect(TaskFilterBy.values, contains(TaskFilterBy.myTasks));
    });

    test('contains openTasks value', () {
      expect(TaskFilterBy.values, contains(TaskFilterBy.openTasks));
    });

    test('contains closedTasks value', () {
      expect(TaskFilterBy.values, contains(TaskFilterBy.closedTasks));
    });

    test('contains overdue value', () {
      expect(TaskFilterBy.values, contains(TaskFilterBy.overdue));
    });

    test('contains priorityHigh value', () {
      expect(TaskFilterBy.values, contains(TaskFilterBy.priorityHigh));
    });

    test('has expected total number of filter options', () {
      /// 16 filters defined in the enum — update if enum grows.
      expect(TaskFilterBy.values.length, 16);
    });

    test('all filter values have unique names', () {
      final names = TaskFilterBy.values.map((e) => e.name).toSet();
      expect(names.length, TaskFilterBy.values.length);
    });
  });

  /// ── Group: TaskGroupBy enum ────────────────────────────────────────────────

  group('TaskGroupBy enum', () {
    test('contains none value', () {
      expect(TaskGroupBy.values, contains(TaskGroupBy.none));
    });

    test('contains stage value', () {
      expect(TaskGroupBy.values, contains(TaskGroupBy.stage));
    });

    test('contains assignee value', () {
      expect(TaskGroupBy.values, contains(TaskGroupBy.assignee));
    });

    test('contains project value', () {
      expect(TaskGroupBy.values, contains(TaskGroupBy.project));
    });

    test('contains priority value', () {
      expect(TaskGroupBy.values, contains(TaskGroupBy.priority));
    });

    test('contains deadline value', () {
      expect(TaskGroupBy.values, contains(TaskGroupBy.deadline));
    });

    test('has 6 group options (none + 5 meaningful groups)', () {
      expect(TaskGroupBy.values.length, 6);
    });

    test('none is the first/default value', () {
      expect(TaskGroupBy.values.first, TaskGroupBy.none);
    });
  });
}
