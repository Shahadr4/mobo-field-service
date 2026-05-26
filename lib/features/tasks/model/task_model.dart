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
  final String partnerEmail;
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
  final int? worksheetTemplateId;
  final String worksheetTemplateName;
  final bool displayTimesheetTimer;
  final bool displaySendReport;
  final bool displaySignReport;
  final bool displayMarkAsDone;
  final bool hasTemplateAncestor;
  final bool hasProjectTemplate;
  final bool allowMaterial;
  final bool isFsm;
  final bool allowWorksheets;
  final int worksheetCount;
  final int? projectId;
  final int? stageId;
  final int? partnerId;
  final List<int> assigneeIds;
  final List<int> tagIds;
  final DateTime? plannedDateBegin;
  final DateTime? plannedDateEnd;

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
    this.partnerEmail = '',
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
    this.worksheetTemplateId,
    this.worksheetTemplateName = '',
    this.displayTimesheetTimer = true,
    this.displaySendReport = false,
    this.displaySignReport = false,
    this.displayMarkAsDone = false,
    this.hasTemplateAncestor = false,
    this.hasProjectTemplate = false,
    this.allowMaterial = false,
    this.isFsm = false,
    this.allowWorksheets = false,
    this.worksheetCount = 0,
    this.projectId,
    this.stageId,
    this.partnerId,
    this.assigneeIds = const [],
    this.tagIds = const [],
    this.plannedDateBegin,
    this.plannedDateEnd,
  });

  TaskModel copyWith({
    int? id,
    String? name,
    String? projectName,
    String? stageName,
    String? assigneeName,
    String? createDate,
    String? partnerName,
    String? partnerStreet,
    String? partnerCity,
    String? partnerCountry,
    String? partnerPhone,
    String? partnerEmail,
    String? scheduledStart,
    String? scheduledEnd,
    String? deadline,
    int? priority,
    String? description,
    double? allocatedHours,
    double? effectiveHours,
    double? remainingHours,
    String? tagNames,
    bool? underWarranty,
    int? worksheetTemplateId,
    String? worksheetTemplateName,
    bool? displayTimesheetTimer,
    bool? displaySendReport,
    bool? displaySignReport,
    bool? displayMarkAsDone,
    bool? hasTemplateAncestor,
    bool? hasProjectTemplate,
    bool? allowMaterial,
    bool? isFsm,
    bool? allowWorksheets,
    int? worksheetCount,
    int? projectId,
    int? stageId,
    int? partnerId,
    List<int>? assigneeIds,
    List<int>? tagIds,
    DateTime? plannedDateBegin,
    DateTime? plannedDateEnd,
  }) {
    return TaskModel(
      id: id ?? this.id,
      name: name ?? this.name,
      projectName: projectName ?? this.projectName,
      stageName: stageName ?? this.stageName,
      assigneeName: assigneeName ?? this.assigneeName,
      createDate: createDate ?? this.createDate,
      partnerName: partnerName ?? this.partnerName,
      partnerStreet: partnerStreet ?? this.partnerStreet,
      partnerCity: partnerCity ?? this.partnerCity,
      partnerCountry: partnerCountry ?? this.partnerCountry,
      partnerPhone: partnerPhone ?? this.partnerPhone,
      partnerEmail: partnerEmail ?? this.partnerEmail,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      allocatedHours: allocatedHours ?? this.allocatedHours,
      effectiveHours: effectiveHours ?? this.effectiveHours,
      remainingHours: remainingHours ?? this.remainingHours,
      tagNames: tagNames ?? this.tagNames,
      underWarranty: underWarranty ?? this.underWarranty,
      worksheetTemplateId: worksheetTemplateId ?? this.worksheetTemplateId,
      worksheetTemplateName: worksheetTemplateName ?? this.worksheetTemplateName,
      displayTimesheetTimer: displayTimesheetTimer ?? this.displayTimesheetTimer,
      displaySendReport: displaySendReport ?? this.displaySendReport,
      displaySignReport: displaySignReport ?? this.displaySignReport,
      displayMarkAsDone: displayMarkAsDone ?? this.displayMarkAsDone,
      hasTemplateAncestor: hasTemplateAncestor ?? this.hasTemplateAncestor,
      hasProjectTemplate: hasProjectTemplate ?? this.hasProjectTemplate,
      allowMaterial: allowMaterial ?? this.allowMaterial,
      isFsm: isFsm ?? this.isFsm,
      allowWorksheets: allowWorksheets ?? this.allowWorksheets,
      worksheetCount: worksheetCount ?? this.worksheetCount,
      projectId: projectId ?? this.projectId,
      stageId: stageId ?? this.stageId,
      partnerId: partnerId ?? this.partnerId,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      tagIds: tagIds ?? this.tagIds,
      plannedDateBegin: plannedDateBegin ?? this.plannedDateBegin,
      plannedDateEnd: plannedDateEnd ?? this.plannedDateEnd,
    );
  }

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

    int? rawId(dynamic v) {
      if (v is List && v.isNotEmpty) return (v[0] as num).toInt();
      if (v is num) return v.toInt();
      return null;
    }

    List<int> rawList(dynamic v) {
      if (v is List) {
        return v.whereType<num>().map((e) => e.toInt()).toList();
      }
      return [];
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
      partnerEmail: map['partner_email']?.toString() ?? '',
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
      worksheetTemplateId: rawId(map['worksheet_template_id']),
      worksheetTemplateName: rel(map['worksheet_template_id']),
      displayTimesheetTimer: map['display_timesheet_timer'] != false,
      displaySendReport: map['display_send_report_secondary'] == true,
      displaySignReport: map['display_sign_report_secondary'] == true,
      displayMarkAsDone: map['display_mark_as_done_secondary'] == true,
      hasTemplateAncestor: map['has_template_ancestor'] == true,
      hasProjectTemplate: map['has_project_template'] == true,
      allowMaterial: map['allow_material'] == true,
      isFsm: map['is_fsm'] == true,
      allowWorksheets: map['allow_worksheets'] == true,
      worksheetCount: (map['worksheet_count'] as num?)?.toInt() ?? 0,
      projectId: rawId(map['project_id']),
      stageId: rawId(map['stage_id']),
      partnerId: rawId(map['partner_id']),
      assigneeIds: rawList(map['user_ids']),
      tagIds: rawList(map['tag_ids']),
      plannedDateBegin: beginDt,
      plannedDateEnd: deadlineDt,
    );
  }
}
