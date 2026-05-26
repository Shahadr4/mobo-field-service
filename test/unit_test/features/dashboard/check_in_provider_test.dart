
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_feild_service/features/dashboard/provider/check_in_provider.dart';
import 'package:mobo_feild_service/features/dashboard/services/check_in_service.dart';

/// Mock service substituted for [CheckInService] in every test.
class MockCheckInService extends Mock implements CheckInService {}

/// Returns a checked-in [AttendanceStatus] with attendance record id = 99.
AttendanceStatus checkedInStatus({DateTime? at}) => AttendanceStatus(
      isCheckedIn: true,
      checkInTime: at ?? DateTime(2024, 6, 15, 9, 0),
      attendanceId: 99,
    );

/// A checked-out [AttendanceStatus] with no time or id.
const checkedOutStatus = AttendanceStatus(isCheckedIn: false);

void main() {
  late MockCheckInService mockService;
  late CheckInProvider provider;

  setUp(() {
    mockService = MockCheckInService();
    provider = CheckInProvider(service: mockService);
  });

  tearDown(() => provider.dispose());

  /// ── Initial state ──────────────────────────────────────────────────────────

  group('CheckInProvider – initial state', () {
    test('isCheckedIn is false', () => expect(provider.isCheckedIn, isFalse));
    test('isInitialized is false', () => expect(provider.isInitialized, isFalse));
    test('isInitializing is false', () => expect(provider.isInitializing, isFalse));
    test('isRefreshing is false', () => expect(provider.isRefreshing, isFalse));
    test('isLoading is false', () => expect(provider.isLoading, isFalse));
    test('error is null', () => expect(provider.error, isNull));
    test('checkInTime is null', () => expect(provider.checkInTime, isNull));
    test('formattedCheckInTime is empty when no check-in', () {
      expect(provider.formattedCheckInTime, '');
    });
  });

  /// ── init – success ─────────────────────────────────────────────────────────

  group('CheckInProvider.init – success', () {
    test('sets isCheckedIn true when service returns checked-in status', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus());
      await provider.init();
      expect(provider.isCheckedIn, isTrue);
    });

    test('stores checkInTime from service', () async {
      final at = DateTime(2024, 6, 15, 9, 30);
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus(at: at));
      await provider.init();
      expect(provider.checkInTime, at);
    });

    test('sets isInitialized true after success', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus());
      await provider.init();
      expect(provider.isInitialized, isTrue);
    });

    test('isInitializing is false after init completes', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus());
      await provider.init();
      expect(provider.isInitializing, isFalse);
    });

    test('notifies with isInitializing=true then false', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedOutStatus);
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isInitializing));
      await provider.init();
      expect(states, containsAllInOrder([true, false]));
    });

    test('formattedCheckInTime formats correctly as 12-hour time', () async {
      final at = DateTime(2024, 6, 15, 14, 5); /// 2:05 PM
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus(at: at));
      await provider.init();
      expect(provider.formattedCheckInTime, '2:05 PM');
    });

    test('formattedCheckInTime handles midnight (12:00 AM)', () async {
      final at = DateTime(2024, 6, 15, 0, 0);
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus(at: at));
      await provider.init();
      expect(provider.formattedCheckInTime, '12:00 AM');
    });

    test('formattedCheckInTime handles noon (12:00 PM)', () async {
      final at = DateTime(2024, 6, 15, 12, 0);
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus(at: at));
      await provider.init();
      expect(provider.formattedCheckInTime, '12:00 PM');
    });
  });

  /// ── init – error ───────────────────────────────────────────────────────────

  group('CheckInProvider.init – error', () {
    setUp(() {
      when(() => mockService.fetchCurrentStatus())
          .thenThrow(Exception('timeout'));
    });

    test('isInitializing is false after error', () async {
      await provider.init();
      expect(provider.isInitializing, isFalse);
    });

    test('isInitialized remains false on error', () async {
      await provider.init();
      expect(provider.isInitialized, isFalse);
    });

    test('isCheckedIn stays false on error', () async {
      await provider.init();
      expect(provider.isCheckedIn, isFalse);
    });
  });

  /// ── init – no-op guard ─────────────────────────────────────────────────────

  group('CheckInProvider.init – no-op guard', () {
    test('second init call is ignored after successful first call', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedOutStatus);
      await provider.init();
      await provider.init();
      verify(() => mockService.fetchCurrentStatus()).called(1);
    });
  });

  /// ── refresh – success ──────────────────────────────────────────────────────

  group('CheckInProvider.refresh – success', () {
    test('updates status on refresh', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus());
      await provider.refresh();
      expect(provider.isCheckedIn, isTrue);
    });

    test('isRefreshing is false after refresh completes', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedOutStatus);
      await provider.refresh();
      expect(provider.isRefreshing, isFalse);
    });

    test('notifies with isRefreshing=true then false', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedOutStatus);
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isRefreshing));
      await provider.refresh();
      expect(states, containsAllInOrder([true, false]));
    });
  });

  /// refresh – error

  group('CheckInProvider.refresh – error', () {
    test('isRefreshing is false after error', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenThrow(Exception('network'));
      await provider.refresh();
      expect(provider.isRefreshing, isFalse);
    });
  });

  /// toggle – check-in

  group('CheckInProvider.toggle – check-in', () {
    test('flips status to checkedIn after successful check-in', () async {
      when(() => mockService.checkIn())
          .thenAnswer((_) async => checkedInStatus());
      await provider.toggle();
      expect(provider.isCheckedIn, isTrue);
    });

    test('stores checkInTime from check-in result', () async {
      final at = DateTime(2024, 6, 15, 8, 0);
      when(() => mockService.checkIn())
          .thenAnswer((_) async => checkedInStatus(at: at));
      await provider.toggle();
      expect(provider.checkInTime, at);
    });

    test('isLoading is false after check-in completes', () async {
      when(() => mockService.checkIn())
          .thenAnswer((_) async => checkedInStatus());
      await provider.toggle();
      expect(provider.isLoading, isFalse);
    });

    test('error is null after successful check-in', () async {
      when(() => mockService.checkIn())
          .thenAnswer((_) async => checkedInStatus());
      await provider.toggle();
      expect(provider.error, isNull);
    });
  });

  ///toggle – check-out

  group('CheckInProvider.toggle – check-out', () {
    /// Seed the provider into a checked-in state first.
    setUp(() async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus());
      await provider.init();
    });

    test('flips status to checkedOut after successful check-out', () async {
      when(() => mockService.checkOut(any()))
          .thenAnswer((_) async => checkedOutStatus);
      await provider.toggle();
      expect(provider.isCheckedIn, isFalse);
    });

    test('clears checkInTime after check-out', () async {
      when(() => mockService.checkOut(any()))
          .thenAnswer((_) async => checkedOutStatus);
      await provider.toggle();
      expect(provider.checkInTime, isNull);
    });

    test('calls checkOut with the stored attendanceId', () async {
      when(() => mockService.checkOut(99))
          .thenAnswer((_) async => checkedOutStatus);
      await provider.toggle();
      verify(() => mockService.checkOut(99)).called(1);
    });
  });

  ///  toggle – error

  group('CheckInProvider.toggle – error', () {
    test('sets friendly error on check-in failure', () async {
      when(() => mockService.checkIn())
          .thenThrow(Exception('SocketException: No internet'));
      await provider.toggle();
      expect(provider.error, contains('No internet'));
    });

    test('isLoading is false after error', () async {
      when(() => mockService.checkIn()).thenThrow(Exception('fail'));
      await provider.toggle();
      expect(provider.isLoading, isFalse);
    });
  });



  group('CheckInProvider.reset', () {
    test('restores all fields to their initial values', () async {
      when(() => mockService.fetchCurrentStatus())
          .thenAnswer((_) async => checkedInStatus());
      await provider.init();
      provider.reset();

      expect(provider.isCheckedIn, isFalse);
      expect(provider.isInitialized, isFalse);
      expect(provider.isInitializing, isFalse);
      expect(provider.isRefreshing, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.checkInTime, isNull);
    });

    test('notifies listeners on reset', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.reset();
      expect(notified, isTrue);
    });
  });
}
