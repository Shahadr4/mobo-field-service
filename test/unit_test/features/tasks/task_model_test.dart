
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_feild_service/features/tasks/model/task_model.dart';

/// Minimal valid Odoo task record used as a baseline across all tests.
Map<String, dynamic> baseTaskMap() => {
      'id': 42,
      'name': 'Install air conditioner',
      'project_id': [7, 'HVAC Project'],
      'stage_id': [2, 'New'],
      'user_names': 'Alice',
      'create_date': '2024-06-01 09:00:00',
      'partner_id': [15, 'Star Hotel'],
      'partner_street': '5 Palm Road',
      'partner_city': 'Dubai',
      'partner_country': 'UAE',
      'partner_phone': '+971501234567',
      'partner_email': 'info@starhotel.ae',
      'planned_date_begin': '2024-06-10 08:00:00',
      'date_deadline': '2024-06-15 17:00:00',
      'priority': '2',
      'description': 'Install AC unit on floor 3.',
      'allocated_hours': 8.0,
      'effective_hours': 3.5,
      'remaining_hours': 4.5,
      'tag_names': 'urgent, hvac',
      'under_warranty': true,
      'worksheet_template_id': [1, 'Service Sheet'],
      'display_send_report_secondary': true,
      'display_sign_report_secondary': false,
      'display_mark_as_done_secondary': true,
      'has_template_ancestor': false,
      'has_project_template': true,
      'allow_material': true,
      'is_fsm': true,
      'allow_worksheets': true,
      'worksheet_count': 2,
      'user_ids': [5, 6],
      'tag_ids': [10, 11, 12],
    };

void main() {

  group('TaskModel.fromMap – scalar fields', () {
    test('parses id correctly', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.id, 42);
    });

    test('parses name correctly', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.name, 'Install air conditioner');
    });

    test('parses project name from many2one list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.projectName, 'HVAC Project');
    });

    test('parses stage name from many2one list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.stageName, 'New');
    });

    test('parses assigneeName from user_names string', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.assigneeName, 'Alice');
    });

    test('parses createDate as YYYY-MM-DD prefix', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.createDate, '2024-06-01');
    });

    test('parses partner name from many2one list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.partnerName, 'Star Hotel');
    });

    test('parses partnerStreet correctly', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.partnerStreet, '5 Palm Road');
    });

    test('parses partnerCity correctly', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.partnerCity, 'Dubai');
    });

    test('parses partnerCountry correctly', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.partnerCountry, 'UAE');
    });

    test('parses partnerPhone correctly', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.partnerPhone, '+971501234567');
    });

    test('parses partnerEmail correctly', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.partnerEmail, 'info@starhotel.ae');
    });

    test('parses priority as integer', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.priority, 2);
    });

    test('parses description as string', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.description, 'Install AC unit on floor 3.');
    });

    test('parses allocatedHours as double', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.allocatedHours, 8.0);
    });

    test('parses effectiveHours as double', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.effectiveHours, 3.5);
    });

    test('parses remainingHours as double', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.remainingHours, 4.5);
    });

    test('parses tagNames as string', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.tagNames, 'urgent, hvac');
    });
  });

  group('TaskModel.fromMap – boolean flags', () {
    test('parses underWarranty as true', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.underWarranty, isTrue);
    });

    test('parses displaySendReport as true', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.displaySendReport, isTrue);
    });

    test('parses displaySignReport as false', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.displaySignReport, isFalse);
    });

    test('parses displayMarkAsDone as true', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.displayMarkAsDone, isTrue);
    });

    test('parses allowMaterial as true', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.allowMaterial, isTrue);
    });

    test('parses isFsm as true', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.isFsm, isTrue);
    });

    test('parses allowWorksheets as true', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.allowWorksheets, isTrue);
    });

    test('parses hasProjectTemplate as true', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.hasProjectTemplate, isTrue);
    });

    test('parses worksheetCount as integer', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.worksheetCount, 2);
    });
  });


  group('TaskModel.fromMap – relational IDs', () {
    test('extracts projectId from many2one list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.projectId, 7);
    });

    test('extracts stageId from many2one list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.stageId, 2);
    });

    test('extracts partnerId from many2one list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.partnerId, 15);
    });

    test('extracts worksheetTemplateId from many2one list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.worksheetTemplateId, 1);
    });

    test('extracts worksheetTemplateName from many2one list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.worksheetTemplateName, 'Service Sheet');
    });

    test('extracts assigneeIds from many2many id list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.assigneeIds, [5, 6]);
    });

    test('extracts tagIds from many2many id list', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.tagIds, [10, 11, 12]);
    });

    test('returns null projectId when project_id is false', () {
      final map = baseTaskMap()..['project_id'] = false;
      final task = TaskModel.fromMap(map);
      expect(task.projectId, isNull);
    });

    test('returns null worksheetTemplateId when field is false', () {
      final map = baseTaskMap()..['worksheet_template_id'] = false;
      final task = TaskModel.fromMap(map);
      expect(task.worksheetTemplateId, isNull);
    });

    test('returns empty assigneeIds when user_ids is absent', () {
      final map = baseTaskMap()..remove('user_ids');
      final task = TaskModel.fromMap(map);
      expect(task.assigneeIds, isEmpty);
    });
  });


  group('TaskModel.fromMap – missing/null field defaults', () {
    test('defaults allocatedHours to 0.0 when absent', () {
      final map = baseTaskMap()..remove('allocated_hours');
      final task = TaskModel.fromMap(map);
      expect(task.allocatedHours, 0.0);
    });

    test('defaults priority to 0 when field absent', () {
      final map = baseTaskMap()..remove('priority');
      final task = TaskModel.fromMap(map);
      expect(task.priority, 0);
    });

    test('defaults description to empty string when field is not a String', () {
      final map = baseTaskMap()..['description'] = false;
      final task = TaskModel.fromMap(map);
      expect(task.description, '');
    });

    test('defaults underWarranty to false when field absent', () {
      final map = baseTaskMap()..remove('under_warranty');
      final task = TaskModel.fromMap(map);
      expect(task.underWarranty, isFalse);
    });

    test('produces empty scheduledStart when planned_date_begin is false', () {
      final map = baseTaskMap()..['planned_date_begin'] = false;
      final task = TaskModel.fromMap(map);
      expect(task.scheduledStart, '');
    });

    test('plannedDateBegin is null when planned_date_begin is false', () {
      final map = baseTaskMap()..['planned_date_begin'] = false;
      final task = TaskModel.fromMap(map);
      expect(task.plannedDateBegin, isNull);
    });
  });


  group('TaskModel.partnerAddress', () {
    test('joins non-empty address parts with comma separator', () {
      final task = TaskModel.fromMap(baseTaskMap());
      expect(task.partnerAddress, '5 Palm Road, Dubai, UAE');
    });

    test('omits empty parts from address', () {
      final map = baseTaskMap()
        ..['partner_street'] = ''
        ..['partner_city'] = 'Dubai';
      final task = TaskModel.fromMap(map);
      expect(task.partnerAddress, 'Dubai, UAE');
    });

    test('returns empty string when all address fields are empty', () {
      final map = baseTaskMap()
        ..['partner_street'] = ''
        ..['partner_city'] = ''
        ..['partner_country'] = '';
      final task = TaskModel.fromMap(map);
      expect(task.partnerAddress, '');
    });
  });


  group('TaskModel.copyWith', () {
    test('returns a new instance with updated name', () {
      final original = TaskModel.fromMap(baseTaskMap());
      final copy = original.copyWith(name: 'Updated Task');
      expect(copy.name, 'Updated Task');
      expect(original.name, 'Install air conditioner');
    });

    test('preserves unchanged fields', () {
      final original = TaskModel.fromMap(baseTaskMap());
      final copy = original.copyWith(priority: 3);
      expect(copy.id, original.id);
      expect(copy.projectName, original.projectName);
      expect(copy.stageName, original.stageName);
      expect(copy.partnerName, original.partnerName);
    });

    test('can update multiple fields at once', () {
      final original = TaskModel.fromMap(baseTaskMap());
      final copy = original.copyWith(
        name: 'New Name',
        priority: 0,
        underWarranty: false,
      );
      expect(copy.name, 'New Name');
      expect(copy.priority, 0);
      expect(copy.underWarranty, isFalse);
    });

    test('copyWith with no arguments produces equivalent object', () {
      final original = TaskModel.fromMap(baseTaskMap());
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.allocatedHours, original.allocatedHours);
    });

    test('can update assigneeIds list', () {
      final original = TaskModel.fromMap(baseTaskMap());
      final copy = original.copyWith(assigneeIds: [99]);
      expect(copy.assigneeIds, [99]);
    });
  });
}
