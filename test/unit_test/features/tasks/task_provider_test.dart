
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_feild_service/features/tasks/model/task_filter.dart';
import 'package:mobo_feild_service/features/tasks/model/task_model.dart';
import 'package:mobo_feild_service/features/tasks/provider/task_provider.dart';
import 'package:mobo_feild_service/features/tasks/services/task_service.dart';

///  Mock

class MockTaskService extends Mock implements TaskService {}

///  Fixtures

const _fsmSettings = (warrantyEnabled: false, worksheetEnabled: false);

TaskModel makeTask({
  int id = 1,
  String name = 'Fix pump',
  String stageName = 'New',
  String assigneeName = 'Alice',
  String projectName = 'Project A',
  int priority = 0,
  String deadline = '2030-12-31',
}) =>
    TaskModel(
      id: id,
      name: name,
      projectName: projectName,
      stageName: stageName,
      assigneeName: assigneeName,
      createDate: '2024-01-01',
      partnerName: 'Client',
      partnerStreet: '1 Main St',
      partnerCity: 'Dubai',
      partnerCountry: 'UAE',
      partnerPhone: '',
      scheduledStart: '',
      scheduledEnd: '',
      deadline: deadline,
      priority: priority,
      description: '',
      allocatedHours: 0,
      effectiveHours: 0,
      remainingHours: 0,
      tagNames: '',
      underWarranty: false,
    );

TaskPageResult pageResult({List<TaskModel>? tasks, int total = 10}) =>
    TaskPageResult(tasks: tasks ?? [makeTask()], total: total);

void main() {
  late MockTaskService mockService;
  late TaskProvider provider;

  setUp(() {
    mockService = MockTaskService();
    provider = TaskProvider(service: mockService);
    /// Stub fetchFsmSettings to always return defaults unless overridden.
    when(() => mockService.fetchFsmSettings())
        .thenAnswer((_) async => _fsmSettings);
    when(() => mockService.fetchStages()).thenAnswer((_) async => ['New', 'In Progress', 'Done']);
  });

  tearDown(() => provider.dispose());

  ///  Initial state

  group('TaskProvider – initial state', () {
    test('tasks is empty', () => expect(provider.tasks, isEmpty));
    test('isLoading is false', () => expect(provider.isLoading, isFalse));
    test('error is null', () => expect(provider.error, isNull));
    test('hasFetched is false', () => expect(provider.hasFetched, isFalse));
    test('search is empty', () => expect(provider.search, ''));
    test('selectedStage is "All"', () => expect(provider.selectedStage, 'All'));
    test('selectedFilters contains myTasks', () {
      expect(provider.selectedFilters, contains(TaskFilterBy.myTasks));
    });
    test('groupBy is none', () => expect(provider.groupBy, TaskGroupBy.none));
    test('currentPage is 1', () => expect(provider.currentPage, 1));
    test('totalCount is 0', () => expect(provider.totalCount, 0));
    test('canGoNext is false', () => expect(provider.canGoNext, isFalse));
    test('canGoPrev is false', () => expect(provider.canGoPrev, isFalse));
  });

  ///  fetchTasks – success

  group('TaskProvider.fetchTasks – success', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async => pageResult(
            tasks: [makeTask(id: 1), makeTask(id: 2)],
            total: 2,
          ));
    });

    test('populates tasks list', () async {
      await provider.fetchTasks();
      expect(provider.tasks.length, 2);
    });

    test('sets totalCount correctly', () async {
      await provider.fetchTasks();
      expect(provider.totalCount, 2);
    });

    test('sets hasFetched to true', () async {
      await provider.fetchTasks();
      expect(provider.hasFetched, isTrue);
    });

    test('isLoading is false after fetch', () async {
      await provider.fetchTasks();
      expect(provider.isLoading, isFalse);
    });

    test('error is null after success', () async {
      await provider.fetchTasks();
      expect(provider.error, isNull);
    });

    test('notifies listeners with isLoading=true then false', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));
      await provider.fetchTasks();
      expect(states, containsAllInOrder([true, false]));
    });
  });

  ///fetchTasks – error
  group('TaskProvider.fetchTasks – error', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenThrow(Exception('timeout'));
    });

    test('sets error message', () async {
      await provider.fetchTasks();
      expect(provider.error, isNotNull);
    });

    test('isLoading is false after error', () async {
      await provider.fetchTasks();
      expect(provider.isLoading, isFalse);
    });

    test('tasks remain empty after error', () async {
      await provider.fetchTasks();
      expect(provider.tasks, isEmpty);
    });
  });

  /// fetchTasks – no-op while loading

  group('TaskProvider.fetchTasks – no-op guard', () {
    test('concurrent call is ignored while loading', () async {
      final completer = Future<void>.delayed(const Duration(milliseconds: 10));
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async {
        await completer;
        return pageResult();
      });

      final f1 = provider.fetchTasks();
      final f2 = provider.fetchTasks(); /// concurrent — should be dropped
      await Future.wait([f1, f2]);
      verify(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).called(1);
    });
  });

  ///  setSearch

  group('TaskProvider.setSearch', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async => pageResult());
    });

    test('updates search field', () async {
      await provider.setSearch('pump');
      expect(provider.search, 'pump');
    });

    test('resets currentPage to 1', () async {
      await provider.goToPage(2);
      await provider.setSearch('pump');
      expect(provider.currentPage, 1);
    });

    test('triggers a new fetch', () async {
      await provider.setSearch('pump');
      verify(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).called(1);
    });
  });

  /// setStage

  group('TaskProvider.setStage', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async => pageResult());
    });

    test('updates selectedStage', () async {
      await provider.setStage('Done');
      expect(provider.selectedStage, 'Done');
    });

    test('resets currentPage to 1', () async {
      await provider.setStage('Done');
      expect(provider.currentPage, 1);
    });
  });

  ///  setFilters / clearFilters / toggleMyTasks

  group('TaskProvider filters', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async => pageResult());
    });

    test('setFilters replaces the filter set', () async {
      await provider.setFilters({TaskFilterBy.overdue});
      expect(provider.selectedFilters, {TaskFilterBy.overdue});
    });

    test('clearFilters empties filters and resets groupBy', () async {
      await provider.setFilters({TaskFilterBy.overdue});
      provider.setGroupBy(TaskGroupBy.stage);
      await provider.clearFilters();
      expect(provider.selectedFilters, isEmpty);
      expect(provider.groupBy, TaskGroupBy.none);
    });

    test('hasActiveFilter is true when filter set is non-empty', () async {
      await provider.setFilters({TaskFilterBy.overdue});
      expect(provider.hasActiveFilter, isTrue);
    });

    test('hasActiveFilter is true when groupBy is not none', () async {
      await provider.clearFilters();
      provider.setGroupBy(TaskGroupBy.stage);
      expect(provider.hasActiveFilter, isTrue);
    });

    test('toggleMyTasks(true) adds myTasks filter', () async {
      await provider.setFilters({});
      await provider.toggleMyTasks(true);
      expect(provider.selectedFilters, contains(TaskFilterBy.myTasks));
    });

    test('toggleMyTasks(false) removes myTasks filter', () async {
      await provider.toggleMyTasks(false);
      expect(provider.selectedFilters, isNot(contains(TaskFilterBy.myTasks)));
    });
  });

  ///  setGroupBy / grouped

  group('TaskProvider.setGroupBy / grouped', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async => TaskPageResult(
            tasks: [
              makeTask(id: 1, stageName: 'New'),
              makeTask(id: 2, stageName: 'Done'),
              makeTask(id: 3, stageName: 'New'),
            ],
            total: 3,
          ));
    });

    test('grouped returns single empty-key map when groupBy is none', () async {
      await provider.fetchTasks();
      expect(provider.grouped.keys.single, '');
    });

    test('grouped by stage produces correct keys', () async {
      await provider.fetchTasks();
      provider.setGroupBy(TaskGroupBy.stage);
      expect(provider.grouped.keys, containsAll(['New', 'Done']));
    });

    test('grouped by stage puts tasks into correct buckets', () async {
      await provider.fetchTasks();
      provider.setGroupBy(TaskGroupBy.stage);
      expect(provider.grouped['New']?.length, 2);
      expect(provider.grouped['Done']?.length, 1);
    });

    test('grouped by priority uses star labels', () async {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async => TaskPageResult(
            tasks: [
              makeTask(id: 1, priority: 3),
              makeTask(id: 2, priority: 0),
            ],
            total: 2,
          ));
      await provider.fetchTasks();
      provider.setGroupBy(TaskGroupBy.priority);
      expect(provider.grouped.keys, contains('★★★ High'));
      expect(provider.grouped.keys, contains('No Priority'));
    });

    test('setGroupBy notifies listeners', () async {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.setGroupBy(TaskGroupBy.project);
      expect(notified, isTrue);
    });
  });

  ///pagination

  group('TaskProvider pagination', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async =>
          pageResult(tasks: [makeTask()], total: 80));
    });

    test('totalPages is ceil(total / pageSize)', () async {
      await provider.fetchTasks(); /// total=80, pageSize=40
      expect(provider.totalPages, 2);
    });

    test('canGoNext is true when not on last page', () async {
      await provider.fetchTasks();
      expect(provider.canGoNext, isTrue);
    });

    test('canGoPrev is false on first page', () async {
      await provider.fetchTasks();
      expect(provider.canGoPrev, isFalse);
    });

    test('goToPage advances to the given page', () async {
      await provider.fetchTasks();
      await provider.goToPage(2);
      expect(provider.currentPage, 2);
    });

    test('nextPage increments currentPage', () async {
      await provider.fetchTasks();
      await provider.nextPage();
      expect(provider.currentPage, 2);
    });

    test('prevPage on page 2 goes back to 1', () async {
      await provider.fetchTasks();
      await provider.goToPage(2);
      await provider.prevPage();
      expect(provider.currentPage, 1);
    });

    test('goToPage out of range is ignored', () async {
      await provider.fetchTasks();
      await provider.goToPage(99);
      expect(provider.currentPage, 1);
    });

    test('paginationText shows correct range', () async {
      await provider.fetchTasks();
      expect(provider.paginationText, '1–40 / 80');
    });
  });

  /// updateTaskInMemory

  group('TaskProvider.updateTaskInMemory', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async => TaskPageResult(
            tasks: [makeTask(id: 1, name: 'Old Name')],
            total: 1,
          ));
    });

    test('replaces the matching task in the list', () async {
      await provider.fetchTasks();
      final updated = makeTask(id: 1, name: 'New Name');
      provider.updateTaskInMemory(updated);
      expect(provider.tasks.first.name, 'New Name');
    });

    test('notifies listeners after update', () async {
      await provider.fetchTasks();
      var notified = false;
      provider.addListener(() => notified = true);
      provider.updateTaskInMemory(makeTask(id: 1, name: 'Changed'));
      expect(notified, isTrue);
    });

    test('does nothing when task id is not in the list', () async {
      await provider.fetchTasks();
      final originalName = provider.tasks.first.name;
      provider.updateTaskInMemory(makeTask(id: 999, name: 'Ghost'));
      expect(provider.tasks.first.name, originalName);
    });
  });

  ///  reset

  group('TaskProvider.reset', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async => pageResult());
    });

    test('clears tasks list', () async {
      await provider.fetchTasks();
      provider.reset();
      expect(provider.tasks, isEmpty);
    });

    test('restores selectedStage to "All"', () async {
      await provider.setStage('Done');
      provider.reset();
      expect(provider.selectedStage, 'All');
    });

    test('restores selectedFilters to {myTasks}', () async {
      await provider.setFilters({});
      provider.reset();
      expect(provider.selectedFilters, {TaskFilterBy.myTasks});
    });

    test('restores groupBy to none', () {
      provider.setGroupBy(TaskGroupBy.stage);
      provider.reset();
      expect(provider.groupBy, TaskGroupBy.none);
    });

    test('restores currentPage to 1', () async {
      await provider.fetchTasks();
      await provider.goToPage(2);
      provider.reset();
      expect(provider.currentPage, 1);
    });

    test('notifies listeners on reset', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.reset();
      expect(notified, isTrue);
    });
  });

  /// refresh
  group('TaskProvider.refresh', () {
    setUp(() {
      when(() => mockService.fetchTasksPaged(
            search: any(named: 'search'),
            stageFilter: any(named: 'stageFilter'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            includeWarranty: any(named: 'includeWarranty'),
            includeWorksheet: any(named: 'includeWorksheet'),
          )).thenAnswer((_) async => pageResult());
    });

    test('resets search and page then reloads', () async {
      await provider.setSearch('pump');
      await provider.refresh();
      expect(provider.search, '');
      expect(provider.currentPage, 1);
    });
  });
}
