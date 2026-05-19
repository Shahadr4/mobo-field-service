class TaskModel {
  final int id;
  final String name;
  final String projectName;
  final String stageName;
  final String assigneeName;
  final String createDate;
  final String partnerName;
  final String partnerStreet;
  final String partnerCity;
  final String partnerCountry;
  final String partnerPhone;
  final String scheduledStart;
  final String scheduledEnd;
  final String deadline;
  final int priority;
  final String description;
  final double allocatedHours;
  final double effectiveHours;
  final double remainingHours;
  final String tagNames;
  final bool underWarranty;

  const TaskModel({
    required this.id,
    required this.name,
    required this.projectName,
    required this.stageName,
    required this.assigneeName,
    required this.createDate,
    required this.partnerName,
    required this.partnerStreet,
    required this.partnerCity,
    required this.partnerCountry,
    required this.partnerPhone,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.deadline,
    required this.priority,
    required this.description,
    required this.allocatedHours,
    required this.effectiveHours,
      required this.remainingHours,
    required this.tagNames,
    required this.underWarranty,
  });

  String get partnerAddress {
    final parts = [partnerStreet, partnerCity, partnerCountry]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }


  factory TaskModel.fromMap(Map<String, dynamic> map) {
    String rel(dynamic v) {
      if (v == false || v == null) return '';
      if (v is List && v.length >= 2) return v[1].toString();
      return v.toString();
    }


    String parseDate(dynamic v) {
      if (v == false || v == null) return '';
      final s = v.toString();
      return s.length >= 10 ? s.substring(0, 10) : s;
    }

    DateTime? parseOdooDt(dynamic v) {
      if (v == false || v == null) return null;
      final s = v.toString().replaceFirst(' ', 'T');
      return DateTime.tryParse('${s}Z')?.toLocal();
    }

    String fmt12(DateTime dt) {
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      final date   = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
      final h      = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m      = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour < 12 ? 'AM' : 'PM';
      return '$date  $h:$m $period';
    }

    final beginDt = parseOdooDt(map['planned_date_begin']);
    final deadlineDt = parseOdooDt(map['date_deadline']);

    return TaskModel(
      id: (map['id'] as num).toInt(),
      name: map['name']?.toString() ?? '',
      projectName: rel(map['project_id']),
      stageName: rel(map['stage_id']),
      assigneeName: map['user_names']?.toString() ?? '',
      createDate: parseDate(map['create_date']),
      partnerName: rel(map['partner_id']),
      partnerStreet: map['partner_street']?.toString() ?? '',
      partnerCity: map['partner_city']?.toString() ?? '',
      partnerCountry: map['partner_country']?.toString() ?? '',
      partnerPhone: map['partner_phone']?.toString() ?? '',
      scheduledStart: beginDt != null ? fmt12(beginDt) : '',
      scheduledEnd: deadlineDt != null ? fmt12(deadlineDt) : '',
      deadline: parseDate(map['date_deadline']),
      priority: int.tryParse(map['priority']?.toString() ?? '0') ?? 0,
      description: map['description'] is String ? map['description'] : '',
      allocatedHours: (map['allocated_hours'] as num?)?.toDouble() ?? 0.0,
      effectiveHours: (map['effective_hours'] as num?)?.toDouble() ?? 0.0,
        remainingHours: (map['remaining_hours'] as num?)?.toDouble() ?? 0.0,
      tagNames: map['tag_names']?.toString() ?? '',
      underWarranty: map['under_warranty'] == true,
    );
  }
}
