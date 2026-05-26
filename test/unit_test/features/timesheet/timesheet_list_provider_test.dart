
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_feild_service/features/timesheet/model/timesheet_entry_model.dart';
import 'package:mobo_feild_service/features/timesheet/provider/timesheet_list_provider.dart';
import 'package:mobo_feild_service/features/timesheet/services/timesheet_list_service.dart';



class MockTimesheetListService extends Mock implements TimesheetListService {}

///  Fixtures

TimesheetEntry makeEntry({
  int id = 1,
  String taskName = 'Fix pump',
  String projectName = 'Maintenance',
  double hours = 2.0,
  String date = '2024-06-15',
}) =>
    TimesheetEntry(
      id: id,
      taskName: taskName,
      projectName: projectName,
      description: 'Work done',
      hours: hours,
      date: date,
      taskId: 10,
      projectId: 20,
    );

/// Returns a stub [(count, entries)] result.
(int, List<TimesheetEntry>) pagedResult({
  List<TimesheetEntry>? entries,
  int count = 5,
}) =>
    (count, entries ?? [makeEntry()]);

void main() {
  setUpAll(() {
    registerFallbackValue(TimesheetDateFilter.all);
  });

  late MockTimesheetListService mockService;
  late TimesheetListProvider provider;

  setUp(() {
    mockService = MockTimesheetListService();
    provider = TimesheetListProvider(service: mockService);
  });

  tearDown(() => provider.dispose());

  /// Initial state

  group('TimesheetListProvider – initial state', () {
    test('entries is empty', () => expect(provider.entries, isEmpty));
    test('isLoading is false', () => expect(provider.isLoading, isFalse));
    test('error is null', () => expect(provider.error, isNull));
    test('hasFetched is false', () => expect(provider.hasFetched, isFalse));
    test('currentPage is 1', () => expect(provider.currentPage, 1));
    test('totalCount is 0', () => expect(provider.totalCount, 0));
    test('search is empty', () => expect(provider.search, ''));
    test('dateFilter is all', () =>
        expect(provider.dateFilter, TimesheetDateFilter.all));
    test('groupBy is none', () =>
        expect(provider.groupBy, TimesheetGroupBy.none));
    test('canGoNext is false', () => expect(provider.canGoNext, isFalse));
    test('canGoPrev is false', () => expect(provider.canGoPrev, isFalse));
    test('hasActiveFilter is false', () => expect(provider.hasActiveFilter, isFalse));
    test('totalHours is 0.0', () => expect(provider.totalHours, 0.0));
  });

  ///  init – success

  group('TimesheetListProvider.init – success', () {
    setUp(() {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => pagedResult(
            entries: [makeEntry(id: 1), makeEntry(id: 2)],
            count: 2,
          ));
    });

    test('populates entries list', () async {
      await provider.init();
      expect(provider.entries.length, 2);
    });

    test('sets totalCount correctly', () async {
      await provider.init();
      expect(provider.totalCount, 2);
    });

    test('sets hasFetched to true', () async {
      await provider.init();
      expect(provider.hasFetched, isTrue);
    });

    test('isLoading is false after init', () async {
      await provider.init();
      expect(provider.isLoading, isFalse);
    });

    test('error remains null on success', () async {
      await provider.init();
      expect(provider.error, isNull);
    });

    test('resets currentPage to 1 before loading', () async {
      await provider.init();
      expect(provider.currentPage, 1);
    });

    test('notifies with isLoading=true then false', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));
      await provider.init();
      expect(states, containsAllInOrder([true, false]));
    });
  });

  ///  init – error

  group('TimesheetListProvider.init – error', () {
    setUp(() {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenThrow(Exception('server error'));
    });

    test('sets error message', () async {
      await provider.init();
      expect(provider.error, isNotNull);
    });

    test('isLoading is false after error', () async {
      await provider.init();
      expect(provider.isLoading, isFalse);
    });

    test('entries remain empty after error', () async {
      await provider.init();
      expect(provider.entries, isEmpty);
    });
  });

  /// setSearch

  group('TimesheetListProvider.setSearch', () {
    setUp(() {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => pagedResult());
    });

    test('updates search field', () async {
      await provider.setSearch('pump');
      expect(provider.search, 'pump');
    });

    test('resets currentPage to 1', () async {
      await provider.setSearch('pump');
      expect(provider.currentPage, 1);
    });

    test('is a no-op when search value is unchanged', () async {
      await provider.setSearch('pump');
      await provider.setSearch('pump'); /// duplicate — skipped
      verify(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).called(1);
    });

    test('triggers a new fetch', () async {
      await provider.setSearch('valve');
      verify(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).called(1);
    });
  });

  /// setDateFilter

  group('TimesheetListProvider.setDateFilter', () {
    setUp(() {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => pagedResult());
    });

    test('updates dateFilter field', () async {
      await provider.setDateFilter(TimesheetDateFilter.today);
      expect(provider.dateFilter, TimesheetDateFilter.today);
    });

    test('resets page to 1', () async {
      await provider.setDateFilter(TimesheetDateFilter.thisWeek);
      expect(provider.currentPage, 1);
    });

    test('hasActiveFilter is true when dateFilter is not all', () async {
      await provider.setDateFilter(TimesheetDateFilter.thisMonth);
      expect(provider.hasActiveFilter, isTrue);
    });

    test('hasActiveFilter is false when dateFilter is all', () async {
      await provider.setDateFilter(TimesheetDateFilter.today);
      await provider.setDateFilter(TimesheetDateFilter.all);
      expect(provider.hasActiveFilter, isFalse);
    });

    test('is a no-op when same filter is set again', () async {
      await provider.setDateFilter(TimesheetDateFilter.today);
      await provider.setDateFilter(TimesheetDateFilter.today);
      verify(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).called(1);
    });
  });

  ///  setGroupBy / grouped

  group('TimesheetListProvider.setGroupBy / grouped', () {
    setUp(() {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => (
                3,
                [
                  makeEntry(id: 1, taskName: 'Task A', date: '2024-06-15'),
                  makeEntry(id: 2, taskName: 'Task B', date: '2024-06-15'),
                  makeEntry(id: 3, taskName: 'Task A', date: '2024-06-16'),
                ],
              ));
    });

    test('grouped is empty map when groupBy is none', () async {
      await provider.init();
      expect(provider.grouped, isEmpty);
    });

    test('grouped by task produces correct keys', () async {
      await provider.init();
      provider.setGroupBy(TimesheetGroupBy.task);
      expect(provider.grouped.keys, containsAll(['Task A', 'Task B']));
    });

    test('grouped by task puts entries in correct buckets', () async {
      await provider.init();
      provider.setGroupBy(TimesheetGroupBy.task);
      expect(provider.grouped['Task A']?.length, 2);
      expect(provider.grouped['Task B']?.length, 1);
    });

    test('grouped by day uses YYYY-MM-DD key', () async {
      await provider.init();
      provider.setGroupBy(TimesheetGroupBy.day);
      expect(provider.grouped.keys, containsAll(['2024-06-15', '2024-06-16']));
    });

    test('setGroupBy does not trigger a service call', () async {
      await provider.init();
      provider.setGroupBy(TimesheetGroupBy.month);
      /// Only 1 call from init(), none from setGroupBy
      verify(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).called(1);
    });

    test('setGroupBy notifies listeners', () async {
      await provider.init();
      var notified = false;
      provider.addListener(() => notified = true);
      provider.setGroupBy(TimesheetGroupBy.week);
      expect(notified, isTrue);
    });
  });

  ///  totalHours

  group('TimesheetListProvider.totalHours', () {
    test('sums all entry hours', () async {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => (
                3,
                [
                  makeEntry(hours: 2.5),
                  makeEntry(hours: 1.0),
                  makeEntry(hours: 0.5),
                ],
              ));
      await provider.init();
      expect(provider.totalHours, closeTo(4.0, 0.001));
    });

    test('is 0.0 when entries list is empty', () {
      expect(provider.totalHours, 0.0);
    });
  });

  ///  pagination

  group('TimesheetListProvider pagination', () {
    setUp(() {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async =>
          pagedResult(entries: [makeEntry()], count: 80));
    });

    test('totalPages is ceil(80 / 40) = 2', () async {
      await provider.init();
      expect(provider.totalPages, 2);
    });

    test('canGoNext is true on page 1 of 2', () async {
      await provider.init();
      expect(provider.canGoNext, isTrue);
    });

    test('canGoPrev is false on first page', () async {
      await provider.init();
      expect(provider.canGoPrev, isFalse);
    });

    test('nextPage increments currentPage', () async {
      await provider.init();
      await provider.nextPage();
      expect(provider.currentPage, 2);
    });

    test('prevPage on page 2 returns to 1', () async {
      await provider.init();
      await provider.nextPage();
      await provider.prevPage();
      expect(provider.currentPage, 1);
    });

    test('nextPage is a no-op on last page', () async {
      await provider.init();
      await provider.nextPage(); /// goes to page 2
      await provider.nextPage(); /// already on last page — ignored
      expect(provider.currentPage, 2);
    });

    test('prevPage is a no-op on first page', () async {
      await provider.init();
      await provider.prevPage();
      expect(provider.currentPage, 1);
    });

    test('paginationText shows range on page 1', () async {
      await provider.init();
      /// entries.length = 1 (makeEntry), total = 80
      expect(provider.paginationText, '1–1 / 80');
    });
  });

  ///  clearFilters

  group('TimesheetListProvider.clearFilters', () {
    setUp(() {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => pagedResult());
    });

    test('resets dateFilter to all', () async {
      await provider.setDateFilter(TimesheetDateFilter.today);
      await provider.clearFilters();
      expect(provider.dateFilter, TimesheetDateFilter.all);
    });

    test('resets search to empty', () async {
      await provider.setSearch('pump');
      await provider.clearFilters();
      expect(provider.search, '');
    });

    test('resets groupBy to none', () async {
      provider.setGroupBy(TimesheetGroupBy.month);
      await provider.clearFilters();
      expect(provider.groupBy, TimesheetGroupBy.none);
    });

    test('hasActiveFilter is false after clearFilters', () async {
      await provider.setDateFilter(TimesheetDateFilter.today);
      await provider.clearFilters();
      expect(provider.hasActiveFilter, isFalse);
    });
  });

  ///  reset

  group('TimesheetListProvider.reset', () {
    setUp(() {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => pagedResult());
    });

    test('clears entries', () async {
      await provider.init();
      provider.reset();
      expect(provider.entries, isEmpty);
    });

    test('clears error', () async {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenThrow(Exception('err'));
      await provider.init();
      provider.reset();
      expect(provider.error, isNull);
    });

    test('sets hasFetched to false', () async {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => pagedResult());
      await provider.init();
      provider.reset();
      expect(provider.hasFetched, isFalse);
    });

    test('resets totalCount to 0', () async {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => pagedResult());
      await provider.init();
      provider.reset();
      expect(provider.totalCount, 0);
    });

    test('resets all filter/group fields', () async {
      await provider.setDateFilter(TimesheetDateFilter.today);
      await provider.setSearch('test');
      provider.setGroupBy(TimesheetGroupBy.week);
      provider.reset();

      expect(provider.dateFilter, TimesheetDateFilter.all);
      expect(provider.search, '');
      expect(provider.groupBy, TimesheetGroupBy.none);
      expect(provider.currentPage, 1);
    });

    test('notifies listeners on reset', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.reset();
      expect(notified, isTrue);
    });
  });

  ///  refresh

  group('TimesheetListProvider.refresh', () {
    setUp(() {
      when(() => mockService.fetchPaged(
            page: any(named: 'page'),
            search: any(named: 'search'),
            dateFilter: any(named: 'dateFilter'),
          )).thenAnswer((_) async => pagedResult());
    });

    test('resets page to 1 and reloads', () async {
      await provider.init();
      await provider.nextPage();
      await provider.refresh();
      expect(provider.currentPage, 1);
    });

    test('retains existing dateFilter on refresh', () async {
      await provider.setDateFilter(TimesheetDateFilter.thisWeek);
      await provider.refresh();
      expect(provider.dateFilter, TimesheetDateFilter.thisWeek);
    });
  });
}
