import 'dart:typed_data';

///
/// ## Cover Entry
///
class CEntry {
  final int size;
  final DateTime modified;
  final int offset;
  Uint8List data;
  CEntry({
    required this.size,
    required this.modified,
    required this.offset,
    required this.data,
  });
}
