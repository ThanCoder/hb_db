import 'dart:io';

import 'package:hb_db/hb_db.dart';
import 'package:hb_db/src/core/compresser.dart';
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
    this.dbFile,
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
    File? dbFile,
  }) {
    return DBFEntry(
      name: name ?? this.name,
      mime: mime ?? this.mime,
      size: size ?? this.size,
      compressSize: compressSize ?? this.compressSize,
      isCompressed: isCompressed ?? this.isCompressed,
      modified: modified ?? this.modified,
      offset: offset ?? this.offset,
      dbFile: dbFile ?? this.dbFile,
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

  //
  /// Extract File Binary
  ///
  Future<void> extract(
    String outpath, {
    OnDBProgressCallback? onProgress,
  }) async {
    if (dbFile == null) {
      throw Exception('dbFile is null!');
    }
    final raf = await dbFile!.open(mode: FileMode.read);
    // file data offset
    await raf.setPosition(offset);

    // Open output file for writing
    final outFile = File(outpath);

    final outName = outpath.getName();
    if (isCompressed) {
      // DeCompressing
      final outSink = outFile.openWrite();

      final decoder = ZLibDecoder();
      final sink = decoder.startChunkedConversion(
        IOSinkWrapper(outSink, (written) {}),
      );

      const chunkSize = 1024 * 1024; // 1MB
      int read = 0;
      final fileSize = compressSize;

      while (read < fileSize) {
        final remaining = fileSize - read;
        final toRead = remaining > chunkSize ? chunkSize : remaining;
        final chunk = await raf.read(toRead);
        sink.add(chunk);
        read += toRead;
        // Optional: print progress
        onProgress?.call(read, fileSize, "$outName: DeCompressing...");
      }
      await outSink.close();
      await raf.close();
    } else {
      // ---- Raw Copy ----
      final outRaf = await outFile.open(mode: FileMode.write);
      const chunkSize = 1024 * 1024; // 1MB
      int read = 0;
      final fileSize = size;

      while (read < fileSize) {
        final remaining = fileSize - read;
        final toRead = remaining > chunkSize ? chunkSize : remaining;
        final chunk = raf.readSync(toRead);
        await outRaf.writeFrom(chunk); // write to output file
        read += toRead;
        // Optional: print progress
        onProgress?.call(read, fileSize, "$outName: Extracting...");
      }
      await outRaf.close();
      await raf.close();
    }
  }
}
