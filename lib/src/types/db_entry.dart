class DBEntry {
  final int uniqueFieldId;
  final int id;
  final int offset;
  final int size;
  DBEntry({
    required this.uniqueFieldId,
    required this.id,
    required this.offset,
    required this.size,
  });

  DBEntry copyWith({int? uniqueFieldId, int? id, int? offset, int? size}) {
    return DBEntry(
      uniqueFieldId: uniqueFieldId ?? this.uniqueFieldId,
      id: id ?? this.id,
      offset: offset ?? this.offset,
      size: size ?? this.size,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uniqueFieldId': uniqueFieldId,
      'id': id,
      'offset': offset,
      'size': size,
    };
  }

  factory DBEntry.fromMap(Map<String, dynamic> map) {
    return DBEntry(
      uniqueFieldId: map['uniqueFieldId'] as int,
      id: map['id'] as int,
      offset: map['offset'] as int,
      size: map['size'] as int,
    );
  }
}
