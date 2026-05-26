
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_feild_service/features/employee/model/employee_filter.dart';
import 'package:mobo_feild_service/features/employee/model/employee_model.dart';
import 'package:mobo_feild_service/features/employee/provider/employee_provider.dart';
import 'package:mobo_feild_service/features/employee/service/employee_service.dart';

/// ── Mock ──────────────────────────────────────────────────────────────────────

class MockAssigneeService extends Mock implements AssigneeService {}

/// ── Fixtures ──────────────────────────────────────────────────────────────────

AssigneeModel makeEmployee({
  int id = 1,
  String name = 'Alice',
  String department = 'Engineering',
  String jobTitle = 'Engineer',
  String manager = 'Bob',
}) =>
    AssigneeModel(
      id: id,
      name: name,
      email: '$name@example.com',
      phone: '',
      jobTitle: jobTitle,
      department: department,
      manager: manager,
      avatar: [],
    );

AssigneePageResult pageResult({
  List<AssigneeModel>? assignees,
  int total = 5,
}) =>
    AssigneePageResult(
      assignees: assignees ?? [makeEmployee()],
      total: total,
    );

void main() {
  late MockAssigneeService mockService;
  late AssigneeProvider provider;

  setUp(() {
    mockService = MockAssigneeService();
    provider = AssigneeProvider(service: mockService);
  });

  tearDown(() => provider.dispose());

  /// ── Initial state ──────────────────────────────────────────────────────────

  group('AssigneeProvider – initial state', () {
    test('assignees is empty', () => expect(provider.assignees, isEmpty));
    test('isLoading is false', () => expect(provider.isLoading, isFalse));
    test('error is null', () => expect(provider.error, isNull));
    test('hasFetched is false', () => expect(provider.hasFetched, isFalse));
    test('search is empty', () => expect(provider.search, ''));
    test('filters is empty', () => expect(provider.filters, isEmpty));
    test('groupBy is none', () => expect(provider.groupBy, AssigneeGroupBy.none));
    test('currentPage is 1', () => expect(provider.currentPage, 1));
    test('totalCount is 0', () => expect(provider.totalCount, 0));
    test('canGoNext is false', () => expect(provider.canGoNext, isFalse));
    test('canGoPrev is false', () => expect(provider.canGoPrev, isFalse));
    test('hasActiveFilter is false', () => expect(provider.hasActiveFilter, isFalse));
    test('paginationText is "0 / 0"', () => expect(provider.paginationText, '0 / 0'));
  });

  /// ── fetchAssignees – success ───────────────────────────────────────────────

  group('AssigneeProvider.fetchAssignees – success', () {
    setUp(() {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => pageResult(
            assignees: [makeEmployee(id: 1), makeEmployee(id: 2)],
            total: 2,
          ));
    });

    test('populates assignees list', () async {
      await provider.fetchAssignees();
      expect(provider.assignees.length, 2);
    });

    test('sets totalCount correctly', () async {
      await provider.fetchAssignees();
      expect(provider.totalCount, 2);
    });

    test('sets hasFetched to true', () async {
      await provider.fetchAssignees();
      expect(provider.hasFetched, isTrue);
    });

    test('isLoading is false after fetch', () async {
      await provider.fetchAssignees();
      expect(provider.isLoading, isFalse);
    });

    test('error is null after success', () async {
      await provider.fetchAssignees();
      expect(provider.error, isNull);
    });

    test('notifies with isLoading=true then false', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));
      await provider.fetchAssignees();
      expect(states, containsAllInOrder([true, false]));
    });
  });

  /// ── fetchAssignees – error ─────────────────────────────────────────────────

  group('AssigneeProvider.fetchAssignees – error', () {
    setUp(() {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenThrow(Exception('server error'));
    });

    test('sets error message', () async {
      await provider.fetchAssignees();
      expect(provider.error, isNotNull);
    });

    test('isLoading is false after error', () async {
      await provider.fetchAssignees();
      expect(provider.isLoading, isFalse);
    });

    test('assignees remain empty after error', () async {
      await provider.fetchAssignees();
      expect(provider.assignees, isEmpty);
    });
  });

  /// ── fetchAssignees – no-op while loading ──────────────────────────────────

  group('AssigneeProvider.fetchAssignees – no-op guard', () {
    test('concurrent call is ignored while loading', () async {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return pageResult();
      });

      final f1 = provider.fetchAssignees();
      final f2 = provider.fetchAssignees();
      await Future.wait([f1, f2]);
      verify(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).called(1);
    });
  });

  /// ── setSearch ──────────────────────────────────────────────────────────────

  group('AssigneeProvider.setSearch', () {
    setUp(() {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => pageResult());
    });

    test('updates search field', () async {
      await provider.setSearch('Alice');
      expect(provider.search, 'Alice');
    });

    test('resets currentPage to 1', () async {
      /// advance to page 2 first
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => pageResult(total: 80));
      await provider.goToPage(2);
      await provider.setSearch('Alice');
      expect(provider.currentPage, 1);
    });

    test('triggers a fetch', () async {
      await provider.setSearch('Bob');
      verify(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).called(1);
    });
  });

  /// ── setFilters ─────────────────────────────────────────────────────────────

  group('AssigneeProvider.setFilters', () {
    setUp(() {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => pageResult());
    });

    test('replaces filter set', () async {
      await provider.setFilters({AssigneeFilterBy.archived});
      expect(provider.filters, {AssigneeFilterBy.archived});
    });

    test('resets currentPage to 1', () async {
      await provider.setFilters({AssigneeFilterBy.archived});
      expect(provider.currentPage, 1);
    });

    test('hasActiveFilter is true when filters are set', () async {
      await provider.setFilters({AssigneeFilterBy.myDepartment});
      expect(provider.hasActiveFilter, isTrue);
    });
  });

  /// ── clearFilters ───────────────────────────────────────────────────────────

  group('AssigneeProvider.clearFilters', () {
    setUp(() {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => pageResult());
    });

    test('empties filter set', () async {
      await provider.setFilters({AssigneeFilterBy.archived});
      await provider.clearFilters();
      expect(provider.filters, isEmpty);
    });

    test('resets groupBy to none', () async {
      provider.setGroupBy(AssigneeGroupBy.department);
      await provider.clearFilters();
      expect(provider.groupBy, AssigneeGroupBy.none);
    });

    test('hasActiveFilter is false after clearFilters', () async {
      await provider.setFilters({AssigneeFilterBy.archived});
      await provider.clearFilters();
      expect(provider.hasActiveFilter, isFalse);
    });
  });

  /// ── setGroupBy / grouped ───────────────────────────────────────────────────

  group('AssigneeProvider.setGroupBy / grouped', () {
    setUp(() {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => AssigneePageResult(
            assignees: [
              makeEmployee(id: 1, department: 'Engineering'),
              makeEmployee(id: 2, department: 'Sales'),
              makeEmployee(id: 3, department: 'Engineering'),
            ],
            total: 3,
          ));
    });

    test('grouped by none returns single empty-key entry', () async {
      await provider.fetchAssignees();
      expect(provider.grouped.keys.single, '');
    });

    test('grouped by department produces correct keys', () async {
      await provider.fetchAssignees();
      provider.setGroupBy(AssigneeGroupBy.department);
      expect(provider.grouped.keys, containsAll(['Engineering', 'Sales']));
    });

    test('grouped by department puts employees in correct buckets', () async {
      await provider.fetchAssignees();
      provider.setGroupBy(AssigneeGroupBy.department);
      expect(provider.grouped['Engineering']?.length, 2);
      expect(provider.grouped['Sales']?.length, 1);
    });

    test('grouped by jobTitle uses correct key', () async {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => AssigneePageResult(
            assignees: [
              makeEmployee(id: 1, jobTitle: 'Engineer'),
              makeEmployee(id: 2, jobTitle: ''),
            ],
            total: 2,
          ));
      await provider.fetchAssignees();
      provider.setGroupBy(AssigneeGroupBy.jobTitle);
      expect(provider.grouped.keys, containsAll(['Engineer', 'No Job Title']));
    });

    test('setGroupBy notifies listeners', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.setGroupBy(AssigneeGroupBy.manager);
      expect(notified, isTrue);
    });

    test('hasActiveFilter is true when groupBy is non-none', () {
      provider.setGroupBy(AssigneeGroupBy.department);
      expect(provider.hasActiveFilter, isTrue);
    });
  });

  /// ── pagination ─────────────────────────────────────────────────────────────

  group('AssigneeProvider pagination', () {
    setUp(() {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async =>
          pageResult(assignees: [makeEmployee()], total: 80));
    });

    test('totalPages is ceil(80 / 40) = 2', () async {
      await provider.fetchAssignees();
      expect(provider.totalPages, 2);
    });

    test('canGoNext is true when not on last page', () async {
      await provider.fetchAssignees();
      expect(provider.canGoNext, isTrue);
    });

    test('canGoPrev is false on first page', () async {
      await provider.fetchAssignees();
      expect(provider.canGoPrev, isFalse);
    });

    test('nextPage increments currentPage', () async {
      await provider.fetchAssignees();
      await provider.nextPage();
      expect(provider.currentPage, 2);
    });

    test('prevPage on page 2 returns to 1', () async {
      await provider.fetchAssignees();
      await provider.goToPage(2);
      await provider.prevPage();
      expect(provider.currentPage, 1);
    });

    test('goToPage out of range is ignored', () async {
      await provider.fetchAssignees();
      await provider.goToPage(99);
      expect(provider.currentPage, 1);
    });

    test('paginationText shows 1–40 / 80 on page 1', () async {
      await provider.fetchAssignees();
      expect(provider.paginationText, '1–40 / 80');
    });
  });

  /// ── reset ──────────────────────────────────────────────────────────────────

  group('AssigneeProvider.reset', () {
    setUp(() {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => pageResult());
    });

    test('clears assignees list', () async {
      await provider.fetchAssignees();
      provider.reset();
      expect(provider.assignees, isEmpty);
    });

    test('clears search', () async {
      await provider.setSearch('Alice');
      provider.reset();
      expect(provider.search, '');
    });

    test('clears filters', () async {
      await provider.setFilters({AssigneeFilterBy.archived});
      provider.reset();
      expect(provider.filters, isEmpty);
    });

    test('resets groupBy to none', () {
      provider.setGroupBy(AssigneeGroupBy.department);
      provider.reset();
      expect(provider.groupBy, AssigneeGroupBy.none);
    });

    test('resets currentPage to 1', () async {
      await provider.fetchAssignees();
      provider.reset();
      expect(provider.currentPage, 1);
    });

    test('resets totalCount to 0', () async {
      await provider.fetchAssignees();
      provider.reset();
      expect(provider.totalCount, 0);
    });

    test('sets hasFetched to false', () async {
      await provider.fetchAssignees();
      provider.reset();
      expect(provider.hasFetched, isFalse);
    });

    test('notifies listeners on reset', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.reset();
      expect(notified, isTrue);
    });
  });

  /// ── refresh ────────────────────────────────────────────────────────────────

  group('AssigneeProvider.refresh', () {
    setUp(() {
      when(() => mockService.fetchAssigneesPaged(
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => pageResult());
    });

    test('resets search and page then reloads', () async {
      await provider.setSearch('Alice');
      await provider.refresh();
      expect(provider.search, '');
      expect(provider.currentPage, 1);
    });
  });
}
