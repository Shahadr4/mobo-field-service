
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_feild_service/features/employee/model/employee_model.dart';
import 'package:mobo_feild_service/features/employee/model/employee_stats_model.dart';

/// Minimal Odoo employee record returned by the API.
Map<String, dynamic> baseEmployeeMap() => {
      'id': 7,
      'name': 'Jane Smith',
      'email': 'jane@example.com',
      'phone': '+441234567890',
      'job_title': 'Field Engineer',
      'department': 'Operations',
      'manager': 'John Doe',
    };

void main() {
  /// ── Group: AssigneeModel.fromMap ───────────────────────────────────────────

  group('AssigneeModel.fromMap', () {
    test('parses id as integer', () {
      final model = AssigneeModel.fromMap(baseEmployeeMap());
      expect(model.id, 7);
    });

    test('parses name correctly', () {
      final model = AssigneeModel.fromMap(baseEmployeeMap());
      expect(model.name, 'Jane Smith');
    });

    test('parses email correctly', () {
      final model = AssigneeModel.fromMap(baseEmployeeMap());
      expect(model.email, 'jane@example.com');
    });

    test('parses phone correctly', () {
      final model = AssigneeModel.fromMap(baseEmployeeMap());
      expect(model.phone, '+441234567890');
    });

    test('parses jobTitle correctly', () {
      final model = AssigneeModel.fromMap(baseEmployeeMap());
      expect(model.jobTitle, 'Field Engineer');
    });

    test('parses department correctly', () {
      final model = AssigneeModel.fromMap(baseEmployeeMap());
      expect(model.department, 'Operations');
    });

    test('parses manager correctly', () {
      final model = AssigneeModel.fromMap(baseEmployeeMap());
      expect(model.manager, 'John Doe');
    });

    test('defaults avatar to empty list', () {
      final model = AssigneeModel.fromMap(baseEmployeeMap());
      expect(model.avatar, isEmpty);
    });

    test("treats Odoo 'false' string as empty for email", () {
      final map = baseEmployeeMap()..['email'] = 'false';
      final model = AssigneeModel.fromMap(map);
      expect(model.email, '');
    });

    test("treats Odoo 'false' string as empty for phone", () {
      final map = baseEmployeeMap()..['phone'] = 'false';
      final model = AssigneeModel.fromMap(map);
      expect(model.phone, '');
    });

    test("treats Odoo 'false' string as empty for jobTitle", () {
      final map = baseEmployeeMap()..['job_title'] = 'false';
      final model = AssigneeModel.fromMap(map);
      expect(model.jobTitle, '');
    });

    test("treats Odoo 'false' string as empty for department", () {
      final map = baseEmployeeMap()..['department'] = 'false';
      final model = AssigneeModel.fromMap(map);
      expect(model.department, '');
    });

    test("treats Odoo 'false' string as empty for manager", () {
      final map = baseEmployeeMap()..['manager'] = 'false';
      final model = AssigneeModel.fromMap(map);
      expect(model.manager, '');
    });

    test('treats null fields as empty strings', () {
      final map = baseEmployeeMap()
        ..['email'] = null
        ..['phone'] = null
        ..['job_title'] = null;
      final model = AssigneeModel.fromMap(map);
      expect(model.email, '');
      expect(model.phone, '');
      expect(model.jobTitle, '');
    });

    test('handles float id via num cast', () {
      final map = baseEmployeeMap()..['id'] = 7.0;
      final model = AssigneeModel.fromMap(map);
      expect(model.id, 7);
    });
  });

  /// ── Group: AssigneeModel.copyWithAvatar ────────────────────────────────────

  group('AssigneeModel.copyWithAvatar', () {
    test('returns a new instance with the provided avatar bytes', () {
      final original = AssigneeModel.fromMap(baseEmployeeMap());
      final bytes = [0x89, 0x50, 0x4E, 0x47];
      final updated = original.copyWithAvatar(bytes);

      expect(updated.avatar, bytes);
    });

    test('preserves all other fields when avatar is replaced', () {
      final original = AssigneeModel.fromMap(baseEmployeeMap());
      final updated = original.copyWithAvatar([1, 2, 3]);

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.email, original.email);
      expect(updated.phone, original.phone);
      expect(updated.jobTitle, original.jobTitle);
      expect(updated.department, original.department);
      expect(updated.manager, original.manager);
    });

    test('original avatar remains unchanged after copyWithAvatar', () {
      final original = AssigneeModel.fromMap(baseEmployeeMap());
      original.copyWithAvatar([1, 2, 3]);
      expect(original.avatar, isEmpty);
    });

    test('accepts empty avatar list', () {
      final original = AssigneeModel.fromMap(baseEmployeeMap());
      final updated = original.copyWithAvatar([]);
      expect(updated.avatar, isEmpty);
    });
  });

  /// ── Group: EmployeeStats ───────────────────────────────────────────────────

  group('EmployeeStats', () {
    test('stores all values correctly', () {
      const stats = EmployeeStats(
        assignedTasks: 10,
        activeTasks: 4,
        completedTasks: 5,
        cancelledTasks: 1,
        totalHours: 120.5,
        thisMonthHours: 40.0,
      );

      expect(stats.assignedTasks, 10);
      expect(stats.activeTasks, 4);
      expect(stats.completedTasks, 5);
      expect(stats.cancelledTasks, 1);
      expect(stats.totalHours, 120.5);
      expect(stats.thisMonthHours, 40.0);
    });

    test('EmployeeStats.empty initialises all values to zero', () {
      const stats = EmployeeStats.empty();

      expect(stats.assignedTasks, 0);
      expect(stats.activeTasks, 0);
      expect(stats.completedTasks, 0);
      expect(stats.cancelledTasks, 0);
      expect(stats.totalHours, 0.0);
      expect(stats.thisMonthHours, 0.0);
    });

    test('two EmployeeStats.empty() are identical via const', () {
      const a = EmployeeStats.empty();
      const b = EmployeeStats.empty();
      expect(identical(a, b), isTrue);
    });

    test('accepts fractional hours values', () {
      const stats = EmployeeStats(
        assignedTasks: 1,
        activeTasks: 1,
        completedTasks: 0,
        cancelledTasks: 0,
        totalHours: 0.25,
        thisMonthHours: 0.25,
      );
      expect(stats.totalHours, closeTo(0.25, 0.001));
    });
  });
}
