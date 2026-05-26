
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_feild_service/features/dashboard/model/dashboard_task_model.dart';

/// Returns a minimal valid raw map as returned by the Odoo JSON-RPC API.
Map<String, dynamic> baseMap() => {
      'id': 1,
      'name': 'Fix water pump',
      'project_id': [10, 'Maintenance Project'],
      'stage_id': [3, 'In Progress'],
      'user_ids': [
        [5, 'Alice'],
        [6, 'Bob'],
      ],
      'partner_id': [20, 'ACME Corp'],
      'partner_street': '12 Baker Street',
      'partner_city': 'London',
      'partner_country': 'UK',
      'date_deadline': '2030-12-31',
      'planned_date_begin': '2030-12-01 08:00:00',
      'priority': '1',
      'partner_lat': 51.5074,
      'partner_lng': -0.1278,
    };

void main() {
  /// ── Group: fromMap ─────────────────────────────────────────────────────────

  group('DashboardTask.fromMap', () {
    test('parses id as integer', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.id, 1);
    });

    test('parses name correctly', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.name, 'Fix water pump');
    });

    test('extracts project name from many2one list', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.projectName, 'Maintenance Project');
    });

    test('extracts stage name from many2one list', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.stageName, 'In Progress');
    });

    test('joins multiple assignee names with comma', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.assigneeName, 'Alice, Bob');
    });

    test('extracts partner name from many2one list', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.partnerName, 'ACME Corp');
    });

    test('assembles partner address from street, city, country', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.partnerAddress, '12 Baker Street, London, UK');
    });

    test('parses deadline as YYYY-MM-DD string', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.deadline, '2030-12-31');
    });

    test('parses scheduled start as 12-hour time string', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.scheduledStart, isNotEmpty);
      expect(task.scheduledStart, matches(RegExp(r'\d+:\d{2} (AM|PM)')));
    });

    test('parses priority as integer', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.priority, 1);
    });

    test('parses partner lat/lng as doubles', () {
      final task = DashboardTask.fromMap(baseMap());
      expect(task.partnerLat, closeTo(51.5074, 0.0001));
      expect(task.partnerLng, closeTo(-0.1278, 0.0001));
    });

    test('returns empty assigneeName when user_ids is false', () {
      final map = baseMap()..['user_ids'] = false;
      final task = DashboardTask.fromMap(map);
      expect(task.assigneeName, '');
    });

    test('returns empty projectName when project_id is false', () {
      final map = baseMap()..['project_id'] = false;
      final task = DashboardTask.fromMap(map);
      expect(task.projectName, '');
    });

    test('returns 0.0 lat/lng when partner_lat/lng are absent', () {
      final map = baseMap()
        ..remove('partner_lat')
        ..remove('partner_lng');
      final task = DashboardTask.fromMap(map);
      expect(task.partnerLat, 0.0);
      expect(task.partnerLng, 0.0);
    });

    test('returns empty deadline when date_deadline is false', () {
      final map = baseMap()..['date_deadline'] = false;
      final task = DashboardTask.fromMap(map);
      expect(task.deadline, '');
    });

    test('handles float id via num cast', () {
      final map = baseMap()..['id'] = 42.0;
      final task = DashboardTask.fromMap(map);
      expect(task.id, 42);
    });

    test('omits empty address segments from partnerAddress', () {
      final map = baseMap()
        ..['partner_street'] = ''
        ..['partner_city'] = ''
        ..['partner_country'] = 'UK';
      final task = DashboardTask.fromMap(map);
      expect(task.partnerAddress, 'UK');
    });

    test('produces empty partnerAddress when all address fields are null', () {
      final map = baseMap()
        ..['partner_street'] = null
        ..['partner_city'] = null
        ..['partner_country'] = null;
      final task = DashboardTask.fromMap(map);
      expect(task.partnerAddress, '');
    });

    test('returns empty scheduledStart when planned_date_begin is false', () {
      final map = baseMap()..['planned_date_begin'] = false;
      final task = DashboardTask.fromMap(map);
      expect(task.scheduledStart, '');
    });

    test('returns empty assigneeName when user_ids is empty list', () {
      final map = baseMap()..['user_ids'] = <dynamic>[];
      final task = DashboardTask.fromMap(map);
      expect(task.assigneeName, '');
    });

    test('defaults priority to 0 when priority field is missing', () {
      final map = baseMap()..remove('priority');
      final task = DashboardTask.fromMap(map);
      expect(task.priority, 0);
    });
  });

  /// ── Group: withCoords ──────────────────────────────────────────────────────

  group('DashboardTask.withCoords', () {
    test('returns new instance with updated coordinates', () {
      final original = DashboardTask.fromMap(baseMap());
      final updated = original.withCoords(10.0, 20.0);

      expect(updated.partnerLat, 10.0);
      expect(updated.partnerLng, 20.0);
    });

    test('preserves all other fields when coords are replaced', () {
      final original = DashboardTask.fromMap(baseMap());
      final updated = original.withCoords(10.0, 20.0);

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.projectName, original.projectName);
      expect(updated.stageName, original.stageName);
      expect(updated.assigneeName, original.assigneeName);
      expect(updated.partnerName, original.partnerName);
      expect(updated.partnerAddress, original.partnerAddress);
      expect(updated.deadline, original.deadline);
      expect(updated.priority, original.priority);
    });

    test('does not mutate the original instance', () {
      final original = DashboardTask.fromMap(baseMap());
      original.withCoords(99.0, 99.0);
      expect(original.partnerLat, closeTo(51.5074, 0.0001));
    });
  });

  /// ── Group: daysRemaining ───────────────────────────────────────────────────

  group('DashboardTask.daysRemaining', () {
    test('returns null when deadline is empty', () {
      final map = baseMap()..['date_deadline'] = false;
      final task = DashboardTask.fromMap(map);
      expect(task.daysRemaining, isNull);
    });

    test('returns positive value for a far-future deadline', () {
      final task = DashboardTask.fromMap(baseMap()); // deadline 2030-12-31
      expect(task.daysRemaining, greaterThan(0));
    });

    test('returns negative value for a past deadline', () {
      final map = baseMap()..['date_deadline'] = '2000-01-01';
      final task = DashboardTask.fromMap(map);
      expect(task.daysRemaining, lessThan(0));
    });

    test('returns null when deadline is not a valid date string', () {
      final map = baseMap()..['date_deadline'] = 'not-a-date';
      final task = DashboardTask.fromMap(map);
      /// "not-a-date" has length < 10 so deadline becomes 'not-a-dat'
      /// which fails DateTime.tryParse — daysRemaining should be null.
      expect(task.daysRemaining, isNull);
    });
  });
}
