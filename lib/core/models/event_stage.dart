class EventStage {
  final int id;
  final String name;
  final String displayName;
  final String? description;
  final int sequence;
  final bool fold;
  final bool pipeEnd;
  final List<dynamic>? createUid;
  final String? createDate;
  final List<dynamic>? writeUid;
  final String? writeDate;

  EventStage({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    required this.sequence,
    required this.fold,
    required this.pipeEnd,
    this.createUid,
    this.createDate,
    this.writeUid,
    this.writeDate,
  });


  factory EventStage.fromJson(Map<String, dynamic> json) {
    return EventStage(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
      description: json['description'] == false
          ? null
          : json['description'],
      sequence: json['sequence'],
      fold: json['fold'] ?? false,
      pipeEnd: json['pipe_end'] ?? false,
      createUid: json['create_uid'],
      createDate: json['create_date'],
      writeUid: json['write_uid'],
      writeDate: json['write_date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'description': description,
      'sequence': sequence,
      'fold': fold,
      'pipe_end': pipeEnd,
      'create_uid': createUid,
      'create_date': createDate,
      'write_uid': writeUid,
      'write_date': writeDate,
    };
  }
}
