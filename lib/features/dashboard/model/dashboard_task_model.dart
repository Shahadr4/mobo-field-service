class DashboardTask {
  final int id;
  final String name;
  final String projectName;
  final String stageName;
  final String assigneeName;
  final String partnerName;
  final String partnerAddress;
  final String deadline;
  final String scheduledStart;
  final String scheduledEnd;
  final int priority; // 0 = normal, 1/2/3 = star levels
  final double partnerLat;
  final double partnerLng;

  const DashboardTask({
    required this.id,
    required this.name,
    required this.projectName,
    required this.stageName,
    required this.assigneeName,
    required this.partnerName,
    required this.partnerAddress,
    required this.deadline,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.priority,
    required this.partnerLat,
    required this.partnerLng,
  });

  factory DashboardTask.fromMap(Map<String, dynamic> map) {
    String rel(dynamic v) {
      if (v == false || v == null) return '';
      if (v is List && v.length >= 2) return v[1].toString();
      return v.toString();
    }

    String assignees(dynamic v) {
      if (v == false || v == null) return '';
      if (v is List) {
        return v
            .whereType<List>()
            .map((e) => e.length >= 2 ? e[1].toString() : '')
            .where((s) => s.isNotEmpty)
            .join(', ');
      }
      return '';
    }

    DateTime? parseOdooDt(dynamic v) {
      if (v == false || v == null) return null;
      final s = v.toString().replaceFirst(' ', 'T');
      return DateTime.tryParse('${s}Z')?.toLocal();
    }

    String fmt12(DateTime dt) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour < 12 ? 'AM' : 'PM';
      return '$h:$m $period';
    }

    String parseDate(dynamic v) {
      if (v == false || v == null) return '';
      final s = v.toString();
      return s.length >= 10 ? s.substring(0, 10) : s;
    }

    final beginDt = parseOdooDt(map['planned_date_begin']);
    final endDt   = parseOdooDt(map['date_deadline']);

    final street  = map['partner_street']?.toString() ?? '';
    final city    = map['partner_city']?.toString() ?? '';
    final country = map['partner_country']?.toString() ?? '';
    final parts   = [street, city, country].where((s) => s.isNotEmpty).toList();

    return DashboardTask(
      id: (map['id'] as num).toInt(),
      name: map['name']?.toString() ?? '',
      projectName: rel(map['project_id']),
      stageName: rel(map['stage_id']),
      assigneeName: assignees(map['user_ids']),
      partnerName: rel(map['partner_id']),
      partnerAddress: parts.join(', '),
      deadline: parseDate(map['date_deadline']),
      scheduledStart: beginDt != null ? fmt12(beginDt) : '',
      scheduledEnd:   endDt   != null ? fmt12(endDt)   : '',
      priority: int.tryParse(map['priority']?.toString() ?? '0') ?? 0,
      partnerLat: (map['partner_lat'] as num?)?.toDouble() ?? 0.0,
      partnerLng: (map['partner_lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  int? get daysRemaining {
    if (deadline.isEmpty) return null;
    final d = DateTime.tryParse(deadline);
    if (d == null) return null;
    return d.difference(DateTime.now()).inDays;
  }
}
