import 'dart:io';

import 'package:hb_db/src/core/internal.dart';

class DBFEntry {
  final String name;
  final String? mime;
  final int size;
  final int compressSize;
  final bool isCompressed;
  final DateTime modified;
  final int offset;
  File? dbFile;
  DBFEntry({
    required this.name,
    this.mime,
    required this.size,
    required this.compressSize,
    required this.isCompressed,
    required this.modified,
    required this.offset,
  });

  String get getSizeLabel => size.getSizeLabel();
  String get getCompressedSizeLabel => compressSize.getSizeLabel();

  @override
  String toString() {
    return 'name: $name';
  }

  DBFEntry copyWith({
    String? name,
    String? mime,
    int? size,
    int? compressSize,
    bool? isCompressed,
    DateTime? modified,
    int? offset,
  }) {
    return DBFEntry(
      name: name ?? this.name,
      mime: mime ?? this.mime,
      size: size ?? this.size,
      compressSize: compressSize ?? this.compressSize,
      isCompressed: isCompressed ?? this.isCompressed,
      modified: modified ?? this.modified,
      offset: offset ?? this.offset,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'mime': mime,
      'size': size,
      'compressSize': compressSize,
      'isCompressed': isCompressed,
      'modified': modified.millisecondsSinceEpoch,
      'offset': offset,
    };
  }

  factory DBFEntry.fromMap(Map<String, dynamic> map) {
    return DBFEntry(
      name: map['name'] as String,
      mime: map['mime'] != null ? map['mime'] as String : null,
      size: map['size'] as int,
      compressSize: map['compressSize'] as int,
      isCompressed: map['isCompressed'] as bool,
      modified: DateTime.fromMillisecondsSinceEpoch(map['modified'] as int),
      offset: map['offset'] as int,
    );
  }
}
