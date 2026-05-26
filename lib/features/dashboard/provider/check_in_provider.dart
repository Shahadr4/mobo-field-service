import 'package:flutter/material.dart';

import '../services/check_in_service.dart';

enum CheckInStatus { checkedIn, checkedOut }

class CheckInProvider extends ChangeNotifier {
  final CheckInService _service;

  CheckInProvider({CheckInService? service})
      : _service = service ?? CheckInService();

  CheckInStatus _status = CheckInStatus.checkedOut;
  DateTime? _checkInTime;
  int? _attendanceId;

  bool _isInitialized = false; /// true after first successful fetch
  bool _isInitializing = false; /// true only during the very first load
  bool _isRefreshing = false;  /// true during pull-to-refresh reload
  bool _isLoading = false;     /// true during check-in / check-out action
  String? _error;

  bool get isCheckedIn => _status == CheckInStatus.checkedIn;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isRefreshing => _isRefreshing;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get checkInTime => _checkInTime;

  String get formattedCheckInTime {
    if (_checkInTime == null) return '';
    final h = _checkInTime!.hour;
    final m = _checkInTime!.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display:$m $period';
  }

  /// Resets state so the next init() triggers a fresh load with shimmer.
  void reset() {
    _isInitialized = false;
    _isInitializing = false;
    _isRefreshing = false;
    _isLoading = false;
    _status = CheckInStatus.checkedOut;
    _checkInTime = null;
    _attendanceId = null;
    _error = null;
    notifyListeners();
  }

  /// First load — shows full shimmer skeleton. No-op if already loaded.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitializing = true;
    _error = null;
    notifyListeners();

    try {
      final status = await _service.fetchCurrentStatus();
      _applyStatus(status);
      _isInitialized = true;
    } catch (e, st) {
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh — shows shimmer, replaces data when done.
  Future<void> refresh() async {
    if (_isRefreshing || _isLoading) return;
    _isRefreshing = true;
    _error = null;
    notifyListeners();

    try {
      final status = await _service.fetchCurrentStatus();
      _applyStatus(status);
    } catch (e, st) {
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
  void _applyStatus(AttendanceStatus status) {
    _status = status.isCheckedIn
        ? CheckInStatus.checkedIn
        : CheckInStatus.checkedOut;
    _checkInTime = status.checkInTime;
    _attendanceId = status.attendanceId;
  }

  /// Toggle check-in / check-out.
  Future<void> toggle() async {
    if (_isLoading || _isInitializing || _isRefreshing) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_status == CheckInStatus.checkedOut) {
        final result = await _service.checkIn();
        _status = CheckInStatus.checkedIn;
        _checkInTime = result.checkInTime;
        _attendanceId = result.attendanceId;
      } else {
        if (_attendanceId == null) {
          final current = await _service.fetchCurrentStatus();
          _attendanceId = current.attendanceId;
        }
        if (_attendanceId == null) {
          throw Exception('Could not find open attendance record to check out.');
        }
        await _service.checkOut(_attendanceId!);
        _status = CheckInStatus.checkedOut;
        _checkInTime = null;
        _attendanceId = null;
      }
    } catch (e, st) {
      _error = _friendlyError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('No internet') || raw.contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    if (raw.contains('Session') || raw.contains('401') || raw.contains('403')) {
      return 'Session expired. Please log in again.';
    }
    if (raw.contains('employee record')) return raw;
    if (raw.contains('hr_attendance') || raw.contains('not installed')) {
      return 'HR Attendance module is not installed on the server.';
    }
    return 'Something went wrong. Please try again.';
  }
}
