import 'dart:developer';
import '../../../core/services/odoo_session_manager.dart';

class AttendanceStatus {
  final bool isCheckedIn;
  final DateTime? checkInTime;
  final int? attendanceId;

  const AttendanceStatus({
    required this.isCheckedIn,
    this.checkInTime,
    this.attendanceId,
  });
}

class CheckInService {
  /// Parses Odoo UTC string → device local DateTime.
  /// Odoo stores all datetimes as UTC ("yyyy-MM-dd HH:mm:ss").
  /// Appending 'Z' tells Dart it's UTC, then .toLocal() converts
  /// to whatever timezone the device (and user) is running in.
  DateTime? _odooUtcToLocal(dynamic raw) {
    if (raw == null || raw == false) return null;
    try {
      final normalized = raw.toString().replaceAll(' ', 'T');
      final utcDt = DateTime.parse('${normalized}Z');
      final local = utcDt.toLocal();
      log('[CheckInService] UTC "$raw" → local "$local"');
      return local;
    } catch (e) {
      log('[CheckInService] ⚠️ Failed to parse date "$raw": $e');
      return null;
    }
  }

  /// Converts device local now → UTC string Odoo expects ("yyyy-MM-dd HH:mm:ss").
  String _nowToOdooUtc() {
    final utc = DateTime.now().toUtc();
    final y  = utc.year.toString().padLeft(4, '0');
    final mo = utc.month.toString().padLeft(2, '0');
    final d  = utc.day.toString().padLeft(2, '0');
    final h  = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final s  = utc.second.toString().padLeft(2, '0');
    final result = '$y-$mo-$d $h:$mi:$s';
    log('[CheckInService] local now → Odoo UTC: $result');
    return result;
  }

  /// Finds the linked employee id for the current user.
  Future<int?> _getEmployeeId(int userId) async {
    log('[CheckInService] Looking up employee for user $userId');
    final res = await OdooSessionManager.safeCallKw({
      'model': 'hr.employee',
      'method': 'search_read',
      'args': [
        [
          ['user_id', '=', userId],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'name'],
        'limit': 1,
      },
    });
    if (res is List && res.isNotEmpty) {
      final id = res.first['id'] as int;
      log('[CheckInService] Found employee id: $id (${res.first['name']})');
      return id;
    }
    log('[CheckInService] ❌ No employee linked to user $userId');
    return null;
  }

  /// Returns the open attendance record (no check_out) for the employee.
  Future<Map<String, dynamic>?> _getOpenAttendance(int employeeId) async {
    log('[CheckInService] Searching open attendance for employee $employeeId');
    final res = await OdooSessionManager.safeCallKw({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [
        [
          ['employee_id', '=', employeeId],
          ['check_out', '=', false],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'check_in', 'check_out'],
        'limit': 1,
        'order': 'check_in desc',
      },
    });
    if (res is List && res.isNotEmpty) {
      log('[CheckInService] Open record: ${res.first}');
      return Map<String, dynamic>.from(res.first);
    }
    return null;
  }

  /// Fetches the current check-in state for the logged-in user.
  Future<AttendanceStatus> fetchCurrentStatus() async {
    log('[CheckInService] ▶ fetchCurrentStatus()');
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) {
      log('[CheckInService] ❌ No session');
      return const AttendanceStatus(isCheckedIn: false);
    }

    final employeeId = await _getEmployeeId(session.userId);
    if (employeeId == null) return const AttendanceStatus(isCheckedIn: false);

    final open = await _getOpenAttendance(employeeId);
    if (open != null) {
      final checkInLocal = _odooUtcToLocal(open['check_in']);
      log('[CheckInService] ✅ Checked in — local checkInTime: $checkInLocal');
      return AttendanceStatus(
        isCheckedIn: true,
        checkInTime: checkInLocal,
        attendanceId: open['id'] as int?,
      );
    }

    log('[CheckInService] ✅ Checked out');
    return const AttendanceStatus(isCheckedIn: false);
  }

  /// Check in: creates a new hr.attendance record with check_in = now UTC.
  Future<AttendanceStatus> checkIn() async {
    log('[CheckInService] ▶ checkIn()');
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) throw Exception('No active session.');

    final employeeId = await _getEmployeeId(session.userId);
    if (employeeId == null) {
      throw Exception(
        'No employee record linked to your account. Contact your administrator.',
      );
    }

    final nowLocal = DateTime.now();
    final nowUtc = _nowToOdooUtc();
    log('[CheckInService] Creating attendance check_in=$nowUtc');

    final result = await OdooSessionManager.safeCallKw({
      'model': 'hr.attendance',
      'method': 'create',
      'args': [
        {'employee_id': employeeId, 'check_in': nowUtc},
      ],
      'kwargs': {},
    });

    log('[CheckInService] ✅ Created id=$result, local time=$nowLocal');
    return AttendanceStatus(
      isCheckedIn: true,
      checkInTime: nowLocal,
      attendanceId: result as int?,
    );
  }

  /// Check out: writes check_out = now UTC on the open attendance record.
  Future<AttendanceStatus> checkOut(int attendanceId) async {
    log('[CheckInService] ▶ checkOut(id=$attendanceId)');
    final nowUtc = _nowToOdooUtc();
    log('[CheckInService] Writing check_out=$nowUtc');

    await OdooSessionManager.safeCallKw({
      'model': 'hr.attendance',
      'method': 'write',
      'args': [
        [attendanceId],
        {'check_out': nowUtc},
      ],
      'kwargs': {},
    });

    log('[CheckInService] ✅ Checked out');
    return const AttendanceStatus(isCheckedIn: false);
  }
}
