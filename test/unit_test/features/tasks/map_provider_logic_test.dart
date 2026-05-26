
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobo_feild_service/features/dashboard/model/dashboard_task_model.dart';
import 'package:mobo_feild_service/features/map/provider/map_provider.dart';

/// Helpers

/// Builds a [DashboardTask] with the given values; all other fields use safe
/// defaults so tests remain focused on what they actually exercise.
DashboardTask makeTask({
  int id = 1,
  String name = 'Task',
  String partnerName = '',
  String partnerAddress = '',
  String projectName = '',
  String stageName = '',
  double lat = 25.0,
  double lng = 55.0,
}) =>
    DashboardTask(
      id: id,
      name: name,
      projectName: projectName,
      stageName: stageName,
      assigneeName: '',
      partnerName: partnerName,
      partnerAddress: partnerAddress,
      deadline: '',
      scheduledStart: '',
      scheduledEnd: '',
      priority: 0,
      partnerLat: lat,
      partnerLng: lng,
    );

/// Tests

void main() {
  ///  Group: TaskCluster

  group('TaskCluster', () {
    test('isSingle is true when cluster contains exactly one task', () {
      final cluster = TaskCluster(
        position: const LatLng(25.0, 55.0),
        tasks: [makeTask()],
      );
      expect(cluster.isSingle, isTrue);
    });

    test('isSingle is false when cluster contains more than one task', () {
      final cluster = TaskCluster(
        position: const LatLng(25.0, 55.0),
        tasks: [makeTask(id: 1), makeTask(id: 2)],
      );
      expect(cluster.isSingle, isFalse);
    });

    test('stores position correctly', () {
      const pos = LatLng(12.34, 56.78);
      final cluster = TaskCluster(position: pos, tasks: [makeTask()]);
      expect(cluster.position.latitude, closeTo(12.34, 0.001));
      expect(cluster.position.longitude, closeTo(56.78, 0.001));
    });

    test('stores all provided tasks', () {
      final tasks = List.generate(5, (i) => makeTask(id: i));
      final cluster = TaskCluster(
        position: const LatLng(0, 0),
        tasks: tasks,
      );
      expect(cluster.tasks.length, 5);
    });
  });

  /// Group: MapViewMode enum

  group('MapViewMode enum', () {
    test('has map and list values', () {
      expect(MapViewMode.values, containsAll([MapViewMode.map, MapViewMode.list]));
    });

    test('has exactly 2 values', () {
      expect(MapViewMode.values.length, 2);
    });
  });

  ///  Group: MapLoadState enum

  group('MapLoadState enum', () {
    test('contains all expected states', () {
      expect(
        MapLoadState.values,
        containsAll([
          MapLoadState.idle,
          MapLoadState.loading,
          MapLoadState.loaded,
          MapLoadState.error,
          MapLoadState.permissionDenied,
        ]),
      );
    });

    test('has exactly 5 states', () {
      expect(MapLoadState.values.length, 5);
    });
  });

  ///  Group: NavStartResult enum

  group('NavStartResult enum', () {
    test('contains ok, noCoords, noUserLocation, routeUnavailable', () {
      expect(
        NavStartResult.values,
        containsAll([
          NavStartResult.ok,
          NavStartResult.noCoords,
          NavStartResult.noUserLocation,
          NavStartResult.routeUnavailable,
        ]),
      );
    });

    test('has exactly 4 result values', () {
      expect(NavStartResult.values.length, 4);
    });
  });

  /// Group: MapProvider initial state

  group('MapProvider – initial state', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('state is idle on creation', () {
      expect(provider.state, MapLoadState.idle);
    });

    test('tasks list is empty on creation', () {
      expect(provider.tasks, isEmpty);
    });

    test('searchQuery is empty on creation', () {
      expect(provider.searchQuery, '');
    });

    test('currentPage is 1 on creation', () {
      expect(provider.currentPage, 1);
    });

    test('userPosition is null on creation', () {
      expect(provider.userPosition, isNull);
    });

    test('userLatLng is null when userPosition is null', () {
      expect(provider.userLatLng, isNull);
    });

    test('isListMode is false on creation (default is map mode)', () {
      expect(provider.isListMode, isFalse);
    });

    test('isNavigating is false on creation', () {
      expect(provider.isNavigating, isFalse);
    });

    test('arrived is false on creation', () {
      expect(provider.arrived, isFalse);
    });

    test('routePoints is empty on creation', () {
      expect(provider.routePoints, isEmpty);
    });

    test('selectedCluster is null on creation', () {
      expect(provider.selectedCluster, isNull);
    });

    test('error is null on creation', () {
      expect(provider.error, isNull);
    });
  });

  ///  Group: MapProvider.setSearchQuery

  group('MapProvider.setSearchQuery', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('updates searchQuery', () {
      provider.setSearchQuery('pump');
      expect(provider.searchQuery, 'pump');
    });

    test('resets currentPage to 1 when query changes', () {
      provider.setPage(2);
      provider.setSearchQuery('pump');
      expect(provider.currentPage, 1);
    });

    test('clears search when empty string is set', () {
      provider.setSearchQuery('pump');
      provider.setSearchQuery('');
      expect(provider.searchQuery, '');
    });
  });

  ///  Group: MapProvider.filteredTasks

  group('MapProvider.filteredTasks', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('returns all tasks when search is empty', () {
      /// Tasks list is empty by default — filtered should also be empty.
      expect(provider.filteredTasks, isEmpty);
    });

    test('filters nothing for empty query after reset', () {
      provider.setSearchQuery('');
      expect(provider.filteredTasks.length, provider.tasks.length);
    });
  });

  /// Group: MapProvider.setPage

  group('MapProvider.setPage', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('setPage(1) keeps page at 1 when already there', () {
      provider.setPage(1);
      expect(provider.currentPage, 1);
    });

    test('setPage(0) is ignored — page stays at 1', () {
      provider.setPage(0);
      expect(provider.currentPage, 1);
    });

    test('setPage(99) is ignored when totalPages is 1', () {
      provider.setPage(99);
      expect(provider.currentPage, 1);
    });
  });

  /// ── Group: MapProvider.paginationText ────────────────────────────────────
  group('MapProvider.paginationText', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('returns "0 / 0" when no tasks exist', () {
      expect(provider.paginationText, '0 / 0');
    });
  });

  /// Group: MapProvider.totalPages

  group('MapProvider.totalPages', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('is 1 when no tasks exist', () {
      expect(provider.totalPages, 1);
    });
  });

  /// ── Group: MapProvider.setViewMode ────────────────────────────────────────

  group('MapProvider.setViewMode', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('switches to list mode', () {
      provider.setViewMode(MapViewMode.list);
      expect(provider.isListMode, isTrue);
      expect(provider.viewMode, MapViewMode.list);
    });

    test('switches back to map mode', () {
      provider.setViewMode(MapViewMode.list);
      provider.setViewMode(MapViewMode.map);
      expect(provider.isListMode, isFalse);
      expect(provider.viewMode, MapViewMode.map);
    });

    test('setViewMode with same mode does not change state', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.setViewMode(MapViewMode.map); // already map
      expect(notified, isFalse);
    });
  });

  /// ── Group: MapProvider.stopNavigation ─────────────────────────────────────

  group('MapProvider.stopNavigation', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('resets navigation state to defaults', () {
      provider.stopNavigation();
      expect(provider.isNavigating, isFalse);
      expect(provider.navTask, isNull);
      expect(provider.navDestination, isNull);
      expect(provider.routePoints, isEmpty);
      expect(provider.routeDistanceMeters, 0);
      expect(provider.routeDurationSeconds, 0);
      expect(provider.arrived, isFalse);
    });
  });

  /// ── Group: MapProvider.setActiveHomeTab ───────────────────────────────────

  group('MapProvider.setActiveHomeTab', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('activeHomeTab defaults to 0', () {
      expect(provider.activeHomeTab, 0);
    });

    test('setActiveHomeTab updates the index', () {
      provider.setActiveHomeTab(2);
      expect(provider.activeHomeTab, 2);
    });

    test('setActiveHomeTab with same value does not notify', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.setActiveHomeTab(0); // same as default
      expect(notified, isFalse);
    });
  });

  /// ── Group: MapProvider.setPendingJumpTaskId ───────────────────────────────

  group('MapProvider.setPendingJumpTaskId', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('pendingJumpTaskId defaults to null', () {
      expect(provider.pendingJumpTaskId, isNull);
    });

    test('can set a pending jump task id', () {
      provider.setPendingJumpTaskId(42);
      expect(provider.pendingJumpTaskId, 42);
    });

    test('can clear pending jump task id back to null', () {
      provider.setPendingJumpTaskId(42);
      provider.setPendingJumpTaskId(null);
      expect(provider.pendingJumpTaskId, isNull);
    });
  });

  /// ── Group: MapProvider.reset ──────────────────────────────────────────────

  group('MapProvider.reset', () {
    late MapProvider provider;

    setUp(() => provider = MapProvider());
    tearDown(() => provider.dispose());

    test('resets all state to defaults without triggering load', () {
      provider.setSearchQuery('test');
      provider.setViewMode(MapViewMode.list);
      provider.setActiveHomeTab(2);

      provider.reset();

      expect(provider.state, MapLoadState.idle);
      expect(provider.tasks, isEmpty);
      expect(provider.searchQuery, '');
      expect(provider.currentPage, 1);
      expect(provider.viewMode, MapViewMode.map);
      expect(provider.activeHomeTab, 0);
      expect(provider.isNavigating, isFalse);
      expect(provider.routePoints, isEmpty);
    });
  });
}
