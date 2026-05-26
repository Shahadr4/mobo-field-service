
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_feild_service/features/dashboard/model/dashboard_task_model.dart';
import 'package:mobo_feild_service/features/dashboard/provider/dashboard_task_provider.dart';
import 'package:mobo_feild_service/features/dashboard/services/dashboard_task_service.dart';
import 'package:mobo_feild_service/features/tasks/services/task_service.dart';

/// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockDashboardTaskService extends Mock implements DashboardTaskService {}
class MockTaskService extends Mock implements TaskService {}

/// ── Fixtures ──────────────────────────────────────────────────────────────────

DashboardTask makeDashboardTask({int id = 1, String name = 'Task A'}) =>
    DashboardTask(
      id: id,
      name: name,
      projectName: 'Project',
      stageName: 'New',
      assigneeName: 'Alice',
      partnerName: 'Client',
      partnerAddress: '1 Main St',
      deadline: '2030-12-31',
      scheduledStart: '',
      scheduledEnd: '',
      priority: 0,
      partnerLat: 0,
      partnerLng: 0,
    );

const _fsmSettings = (warrantyEnabled: false, worksheetEnabled: false);
const _fsmSettingsWithWarranty = (warrantyEnabled: true, worksheetEnabled: true);

void main() {
  late MockDashboardTaskService mockService;
  late MockTaskService mockTaskService;
  late DashboardTaskProvider provider;

  setUp(() {
    mockService = MockDashboardTaskService();
    mockTaskService = MockTaskService();
    provider = DashboardTaskProvider(
      service: mockService,
      taskService: mockTaskService,
    );
  });

  tearDown(() => provider.dispose());

  /// ── Initial state ──────────────────────────────────────────────────────────

  group('DashboardTaskProvider – initial state', () {
    test('tabIndex is 0', () => expect(provider.tabIndex, 0));
    test('currentTab is "New"', () => expect(provider.currentTab, 'New'));
    test('tasks list is empty', () => expect(provider.tasks, isEmpty));
    test('isLoading is false', () => expect(provider.isLoading, isFalse));
    test('error is null', () => expect(provider.error, isNull));
    test('warrantyEnabled is false', () => expect(provider.warrantyEnabled, isFalse));
    test('worksheetEnabled is false', () => expect(provider.worksheetEnabled, isFalse));
    test('getVisibleCount defaults to 5 for any tab', () {
      expect(provider.getVisibleCount(0), 5);
      expect(provider.getVisibleCount(3), 5);
    });
  });

  /// ── init – success ─────────────────────────────────────────────────────────

  group('DashboardTaskProvider.init – success', () {
    final sampleTasks = [makeDashboardTask(id: 1), makeDashboardTask(id: 2)];

    setUp(() {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettings);
      when(() => mockService.fetchByTab('New'))
          .thenAnswer((_) async => sampleTasks);
    });

    test('loads tasks for tab 0 (New)', () async {
      await provider.init();
      expect(provider.tasks.length, 2);
    });

    test('isLoading is false after init completes', () async {
      await provider.init();
      expect(provider.isLoading, isFalse);
    });

    test('error is null after successful init', () async {
      await provider.init();
      expect(provider.error, isNull);
    });

    test('applies fsm settings from TaskService', () async {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettingsWithWarranty);
      await provider.init();
      expect(provider.warrantyEnabled, isTrue);
      expect(provider.worksheetEnabled, isTrue);
    });

    test('notifies listeners during loading sequence', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));
      await provider.init();
      expect(states, containsAllInOrder([true, false]));
    });
  });

  /// ── init – error ───────────────────────────────────────────────────────────

  group('DashboardTaskProvider.init – error', () {
    setUp(() {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettings);
      when(() => mockService.fetchByTab(any()))
          .thenThrow(Exception('network failure'));
    });

    test('sets error message', () async {
      await provider.init();
      expect(provider.error, isNotNull);
    });

    test('isLoading is false after error', () async {
      await provider.init();
      expect(provider.isLoading, isFalse);
    });

    test('tasks remain empty after error', () async {
      await provider.init();
      expect(provider.tasks, isEmpty);
    });
  });

  /// ── init – no-op guard ─────────────────────────────────────────────────────

  group('DashboardTaskProvider.init – no-op guard', () {
    test('second init call is ignored when cache for tab 0 already exists',
        () async {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettings);
      when(() => mockService.fetchByTab('New'))
          .thenAnswer((_) async => [makeDashboardTask()]);
      await provider.init();
      await provider.init();
      verify(() => mockService.fetchByTab('New')).called(1);
    });
  });

  /// ── selectTab ──────────────────────────────────────────────────────────────

  group('DashboardTaskProvider.selectTab', () {
    setUp(() {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettings);
      when(() => mockService.fetchByTab(any()))
          .thenAnswer((_) async => [makeDashboardTask()]);
    });

    test('switches tabIndex to selected index', () async {
      await provider.selectTab(2);
      expect(provider.tabIndex, 2);
    });

    test('currentTab reflects the selected tab name', () async {
      await provider.selectTab(1);
      expect(provider.currentTab, DashboardTaskProvider.tabs[1]);
    });

    test('loads tasks when tab not cached', () async {
      await provider.selectTab(2);
      expect(provider.tasks, isNotEmpty);
    });

    test('does not reload when same tab is selected again', () async {
      await provider.init();
      await provider.selectTab(0); // already on tab 0 and cached
      verify(() => mockService.fetchByTab('New')).called(1);
    });

    test('uses cache on second visit to same tab', () async {
      await provider.selectTab(1);
      await provider.selectTab(0);
      await provider.selectTab(1); // should use cache
      verify(() => mockService.fetchByTab(DashboardTaskProvider.tabs[1]))
          .called(1);
    });
  });

  /// ── loadMore ───────────────────────────────────────────────────────────────

  group('DashboardTaskProvider.loadMore', () {
    test('increments visible count by 5', () {
      provider.loadMore(0);
      expect(provider.getVisibleCount(0), 10);
    });

    test('multiple loadMore calls accumulate', () {
      provider.loadMore(0);
      provider.loadMore(0);
      expect(provider.getVisibleCount(0), 15);
    });

    test('loadMore for different tab indices are independent', () {
      provider.loadMore(0);
      expect(provider.getVisibleCount(1), 5);
    });

    test('notifies listeners after loadMore', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.loadMore(0);
      expect(notified, isTrue);
    });
  });

  /// ── refresh ────────────────────────────────────────────────────────────────

  group('DashboardTaskProvider.refresh', () {
    setUp(() {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettings);
      when(() => mockService.fetchByTab(any()))
          .thenAnswer((_) async => [makeDashboardTask()]);
    });

    test('reloads current tab after cache clear', () async {
      await provider.init();
      await provider.refresh();
      verify(() => mockService.fetchByTab('New')).called(2);
    });

    test('tasks are still populated after refresh', () async {
      await provider.init();
      await provider.refresh();
      expect(provider.tasks, isNotEmpty);
    });
  });

  /// ── reset ──────────────────────────────────────────────────────────────────

  group('DashboardTaskProvider.reset', () {
    test('restores tabIndex to 0', () async {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettings);
      when(() => mockService.fetchByTab(any()))
          .thenAnswer((_) async => [makeDashboardTask()]);
      await provider.selectTab(3);
      provider.reset();
      expect(provider.tabIndex, 0);
    });

    test('clears tasks list', () async {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettings);
      when(() => mockService.fetchByTab(any()))
          .thenAnswer((_) async => [makeDashboardTask()]);
      await provider.init();
      provider.reset();
      expect(provider.tasks, isEmpty);
    });

    test('clears error state', () async {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettings);
      when(() => mockService.fetchByTab(any()))
          .thenThrow(Exception('oops'));
      await provider.init();
      provider.reset();
      expect(provider.error, isNull);
    });

    test('resets warrantyEnabled and worksheetEnabled to false', () async {
      when(() => mockTaskService.fetchFsmSettings())
          .thenAnswer((_) async => _fsmSettingsWithWarranty);
      when(() => mockService.fetchByTab(any()))
          .thenAnswer((_) async => []);
      await provider.init();
      provider.reset();
      expect(provider.warrantyEnabled, isFalse);
      expect(provider.worksheetEnabled, isFalse);
    });

    test('notifies listeners on reset', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.reset();
      expect(notified, isTrue);
    });
  });
}
