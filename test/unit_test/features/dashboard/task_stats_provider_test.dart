
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_feild_service/features/dashboard/model/task_stats_model.dart';
import 'package:mobo_feild_service/features/dashboard/provider/task_stats_provider.dart';
import 'package:mobo_feild_service/features/dashboard/services/task_stats_service.dart';

/// Mock service substituted for [TaskStatsService] in every test.
class MockTaskStatsService extends Mock implements TaskStatsService {}

/// Sample stats returned by the mock on success paths.
const _sampleStats = TaskStats(
  activeTasks: 3,
  assignedTasks: 5,
  completedTasks: 2,
  totalTasks: 10,
);

void main() {
  late MockTaskStatsService mockService;
  late TaskStatsProvider provider;

  setUp(() {
    mockService = MockTaskStatsService();
    provider = TaskStatsProvider(service: mockService);
  });

  tearDown(() => provider.dispose());

  /// ── Initial state ──────────────────────────────────────────────────────────

  group('TaskStatsProvider – initial state', () {
    test('isLoading is false', () => expect(provider.isLoading, isFalse));
    test('isInitialized is false', () => expect(provider.isInitialized, isFalse));
    test('isRefreshing is false', () => expect(provider.isRefreshing, isFalse));
    test('error is null', () => expect(provider.error, isNull));
    test('stats are all zero', () {
      expect(provider.stats.activeTasks, 0);
      expect(provider.stats.totalTasks, 0);
    });
  });

  /// ── fetch – happy path ─────────────────────────────────────────────────────

  group('TaskStatsProvider.fetch – success', () {
    setUp(() {
      when(() => mockService.fetchTaskStats())
          .thenAnswer((_) async => _sampleStats);
    });

    test('sets isInitialized to true after successful fetch', () async {
      await provider.fetch();
      expect(provider.isInitialized, isTrue);
    });

    test('applies returned stats', () async {
      await provider.fetch();
      expect(provider.stats.activeTasks, 3);
      expect(provider.stats.assignedTasks, 5);
      expect(provider.stats.completedTasks, 2);
      expect(provider.stats.totalTasks, 10);
    });

    test('isLoading is false after fetch completes', () async {
      await provider.fetch();
      expect(provider.isLoading, isFalse);
    });

    test('error remains null on success', () async {
      await provider.fetch();
      expect(provider.error, isNull);
    });

    test('notifies listeners during loading and after completion', () async {
      final notifications = <bool>[];
      provider.addListener(() => notifications.add(provider.isLoading));
      await provider.fetch();
      /// First notification: isLoading=true; second: isLoading=false
      expect(notifications, containsAllInOrder([true, false]));
    });

    test('calls fetchTaskStats exactly once', () async {
      await provider.fetch();
      verify(() => mockService.fetchTaskStats()).called(1);
    });
  });

  /// ── fetch – error path ─────────────────────────────────────────────────────

  group('TaskStatsProvider.fetch – error', () {
    setUp(() {
      when(() => mockService.fetchTaskStats())
          .thenThrow(Exception('network error'));
    });

    test('sets error message on failure', () async {
      await provider.fetch();
      expect(provider.error, isNotNull);
      expect(provider.error, contains('Failed to load'));
    });

    test('isLoading is false after error', () async {
      await provider.fetch();
      expect(provider.isLoading, isFalse);
    });

    test('isInitialized remains false on error', () async {
      await provider.fetch();
      expect(provider.isInitialized, isFalse);
    });

    test('stats remain at zero on error', () async {
      await provider.fetch();
      expect(provider.stats.totalTasks, 0);
    });
  });

  /// ── fetch – no-op guard ────────────────────────────────────────────────────

  group('TaskStatsProvider.fetch – no-op guards', () {
    test('second fetch call is ignored when already initialized', () async {
      when(() => mockService.fetchTaskStats())
          .thenAnswer((_) async => _sampleStats);
      await provider.fetch();
      await provider.fetch(); /// should be skipped
      verify(() => mockService.fetchTaskStats()).called(1);
    });
  });

  /// ── refresh – happy path ───────────────────────────────────────────────────

  group('TaskStatsProvider.refresh – success', () {
    setUp(() {
      when(() => mockService.fetchTaskStats())
          .thenAnswer((_) async => _sampleStats);
    });

    test('updates stats on refresh', () async {
      await provider.refresh();
      expect(provider.stats.activeTasks, 3);
    });

    test('sets isInitialized to true after refresh', () async {
      await provider.refresh();
      expect(provider.isInitialized, isTrue);
    });

    test('isRefreshing is false after refresh completes', () async {
      await provider.refresh();
      expect(provider.isRefreshing, isFalse);
    });

    test('notifies with isRefreshing=true then false', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isRefreshing));
      await provider.refresh();
      expect(states, containsAllInOrder([true, false]));
    });
  });

  /// ── refresh – error path ───────────────────────────────────────────────────

  group('TaskStatsProvider.refresh – error', () {
    setUp(() {
      when(() => mockService.fetchTaskStats())
          .thenThrow(Exception('timeout'));
    });

    test('sets error on refresh failure', () async {
      await provider.refresh();
      expect(provider.error, contains('Failed to refresh'));
    });

    test('isRefreshing is false after error', () async {
      await provider.refresh();
      expect(provider.isRefreshing, isFalse);
    });
  });

  /// ── reset ──────────────────────────────────────────────────────────────────

  group('TaskStatsProvider.reset', () {
    test('resets all fields to their initial values', () async {
      when(() => mockService.fetchTaskStats())
          .thenAnswer((_) async => _sampleStats);
      await provider.fetch();
      provider.reset();

      expect(provider.isInitialized, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.isRefreshing, isFalse);
      expect(provider.error, isNull);
      expect(provider.stats.totalTasks, 0);
    });

    test('notifies listeners on reset', () async {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.reset();
      expect(notified, isTrue);
    });

    test('fetch works again after reset', () async {
      when(() => mockService.fetchTaskStats())
          .thenAnswer((_) async => _sampleStats);
      await provider.fetch();
      provider.reset();
      await provider.fetch();
      expect(provider.isInitialized, isTrue);
    });
  });
}
