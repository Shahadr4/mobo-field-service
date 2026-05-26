
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_feild_service/features/timesheet/model/timesheet_entry_model.dart';

/// Baseline Odoo timesheet line record.
Map<String, dynamic> baseTimesheetMap() => {
      'id': 100,
      'task_id': [55, 'Fix Boiler'],
      'project_id': [10, 'Maintenance'],
      'name': 'Inspection and repair',
      'unit_amount': 2.5,
      'date': '2024-06-15',
    };

void main() {
  ///  Group: TimesheetEntry.fromMap

  group('TimesheetEntry.fromMap', () {
    test('parses id correctly', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.id, 100);
    });

    test('extracts taskName from many2one list', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.taskName, 'Fix Boiler');
    });

    test('extracts projectName from many2one list', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.projectName, 'Maintenance');
    });

    test('uses name field as description', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.description, 'Inspection and repair');
    });

    test('parses hours from unit_amount as double', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.hours, 2.5);
    });

    test('parses date as YYYY-MM-DD string', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.date, '2024-06-15');
    });

    test('extracts taskId from many2one list', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.taskId, 55);
    });

    test('extracts projectId from many2one list', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.projectId, 10);
    });

    test("treats '/' name as empty description", () {
      final map = baseTimesheetMap()..['name'] = '/';
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.description, '');
    });

    test('treats false name as empty description', () {
      final map = baseTimesheetMap()..['name'] = false;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.description, '');
    });

    test('returns 0.0 hours when unit_amount is absent', () {
      final map = baseTimesheetMap()..remove('unit_amount');
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.hours, 0.0);
    });

    test('returns empty taskName when task_id is false', () {
      final map = baseTimesheetMap()..['task_id'] = false;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.taskName, '');
    });

    test('returns 0 taskId when task_id is false', () {
      final map = baseTimesheetMap()..['task_id'] = false;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.taskId, 0);
    });

    test('handles integer unit_amount (no decimal)', () {
      final map = baseTimesheetMap()..['unit_amount'] = 3;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.hours, 3.0);
    });
  });

  ///  Group: formattedHours

  group('TimesheetEntry.formattedHours', () {
    test('formats whole hours without minutes', () {
      final map = baseTimesheetMap()..['unit_amount'] = 3.0;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.formattedHours, '3h');
    });

    test('formats minutes-only when hours < 1', () {
      final map = baseTimesheetMap()..['unit_amount'] = 0.5;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.formattedHours, '30m');
    });

    test('formats hours and minutes together', () {
      final map = baseTimesheetMap()..['unit_amount'] = 1.5;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.formattedHours, '1h 30m');
    });

    test('formats 0 hours as 0m', () {
      final map = baseTimesheetMap()..['unit_amount'] = 0.0;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.formattedHours, '0m');
    });

    test('formats 2h 15m correctly', () {
      final map = baseTimesheetMap()..['unit_amount'] = 2.25;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.formattedHours, '2h 15m');
    });

    test('formats 8 whole hours correctly', () {
      final map = baseTimesheetMap()..['unit_amount'] = 8.0;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.formattedHours, '8h');
    });
  });

  ///  Group: groupKey

  group('TimesheetEntry.groupKey', () {
    test('groupKey by task returns taskName', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.groupKey(TimesheetGroupBy.task), 'Fix Boiler');
    });

    test('groupKey by task returns "No Task" when taskName empty', () {
      final map = baseTimesheetMap()..['task_id'] = false;
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.groupKey(TimesheetGroupBy.task), 'No Task');
    });

    test('groupKey by day returns YYYY-MM-DD', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.groupKey(TimesheetGroupBy.day), '2024-06-15');
    });

    test('groupKey by week returns "Week DD/MM – DD/MM" format', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      final key = entry.groupKey(TimesheetGroupBy.week);
      expect(key, startsWith('Week '));
      expect(key, contains('–'));
    });

    test('groupKey by month returns "Mon YYYY" format', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.groupKey(TimesheetGroupBy.month), 'Jun 2024');
    });

    test('groupKey by quarter returns "Q2 2024" for June', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.groupKey(TimesheetGroupBy.quarter), 'Q2 2024');
    });

    test('groupKey by year returns 4-digit year string', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.groupKey(TimesheetGroupBy.year), '2024');
    });

    test('groupKey by none returns empty string', () {
      final entry = TimesheetEntry.fromMap(baseTimesheetMap());
      expect(entry.groupKey(TimesheetGroupBy.none), '');
    });

    test('quarter Q1 for January', () {
      final map = baseTimesheetMap()..['date'] = '2024-01-20';
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.groupKey(TimesheetGroupBy.quarter), 'Q1 2024');
    });

    test('quarter Q3 for September', () {
      final map = baseTimesheetMap()..['date'] = '2024-09-05';
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.groupKey(TimesheetGroupBy.quarter), 'Q3 2024');
    });

    test('quarter Q4 for December', () {
      final map = baseTimesheetMap()..['date'] = '2024-12-01';
      final entry = TimesheetEntry.fromMap(map);
      expect(entry.groupKey(TimesheetGroupBy.quarter), 'Q4 2024');
    });

    test('week groupKey returns date range including Monday', () {
      /// 2024-06-17 is a Monday.
      final map = baseTimesheetMap()..['date'] = '2024-06-17';
      final entry = TimesheetEntry.fromMap(map);
      final key = entry.groupKey(TimesheetGroupBy.week);
      /// Monday 17/06 → Sunday 23/06
      expect(key, contains('17/06'));
      expect(key, contains('23/06'));
    });
  });

  /// Group: TimesheetGroupBy labels

  group('TimesheetGroupBy.label extension', () {
    test('none label is "None"', () {
      expect(TimesheetGroupBy.none.label, 'None');
    });

    test('task label is "Task"', () {
      expect(TimesheetGroupBy.task.label, 'Task');
    });

    test('day label is "Day"', () {
      expect(TimesheetGroupBy.day.label, 'Day');
    });

    test('week label is "Week"', () {
      expect(TimesheetGroupBy.week.label, 'Week');
    });

    test('month label is "Month"', () {
      expect(TimesheetGroupBy.month.label, 'Month');
    });

    test('quarter label is "Quarter"', () {
      expect(TimesheetGroupBy.quarter.label, 'Quarter');
    });

    test('year label is "Year"', () {
      expect(TimesheetGroupBy.year.label, 'Year');
    });
  });

  ///  Group: TimesheetDateFilter labels

  group('TimesheetDateFilter.label extension', () {
    test('all label is "All"', () {
      expect(TimesheetDateFilter.all.label, 'All');
    });

    test('today label is "Today"', () {
      expect(TimesheetDateFilter.today.label, 'Today');
    });

    test('yesterday label is "Yesterday"', () {
      expect(TimesheetDateFilter.yesterday.label, 'Yesterday');
    });

    test('thisWeek label is "This Week"', () {
      expect(TimesheetDateFilter.thisWeek.label, 'This Week');
    });

    test('thisMonth label is "This Month"', () {
      expect(TimesheetDateFilter.thisMonth.label, 'This Month');
    });

    test('all filter values have non-empty labels', () {
      for (final f in TimesheetDateFilter.values) {
        expect(f.label, isNotEmpty, reason: '${f.name} label is empty');
      }
    });
  });
}
