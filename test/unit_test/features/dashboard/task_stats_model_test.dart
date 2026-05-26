
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_feild_service/features/dashboard/model/task_stats_model.dart';

void main() {
  group('TaskStats', () {
    test('stores all provided values correctly', () {
      const stats = TaskStats(
        activeTasks: 5,
        assignedTasks: 10,
        completedTasks: 3,
        totalTasks: 18,
      );

      expect(stats.activeTasks, 5);
      expect(stats.assignedTasks, 10);
      expect(stats.completedTasks, 3);
      expect(stats.totalTasks, 18);
    });

    test('TaskStats.empty initialises all counts to zero', () {
      const stats = TaskStats.empty();

      expect(stats.activeTasks, 0);
      expect(stats.assignedTasks, 0);
      expect(stats.completedTasks, 0);
      expect(stats.totalTasks, 0);
    });

    test('two TaskStats with same values are equal via const identity', () {
      const a = TaskStats(
        activeTasks: 1,
        assignedTasks: 2,
        completedTasks: 3,
        totalTasks: 6,
      );
      const b = TaskStats(
        activeTasks: 1,
        assignedTasks: 2,
        completedTasks: 3,
        totalTasks: 6,
      );
      /// Dart const objects with identical values are the same instance.
      expect(identical(a, b), isTrue);
    });

    test('accepts zero values for all fields', () {
      const stats = TaskStats(
        activeTasks: 0,
        assignedTasks: 0,
        completedTasks: 0,
        totalTasks: 0,
      );
      expect(stats.totalTasks, 0);
    });

    test('accepts large integer values without overflow', () {
      const stats = TaskStats(
        activeTasks: 1000000,
        assignedTasks: 2000000,
        completedTasks: 500000,
        totalTasks: 3500000,
      );
      expect(stats.totalTasks, 3500000);
    });
  });
}
