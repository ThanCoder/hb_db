import 'dart:io';

import 'package:hb_db/src/core/compresser.dart';
import 'package:hb_db/src/hb_db.dart';
import 'package:hb_db/src/core/internal.dart';
import 'package:hb_db/src/types/db_meta_type.dart';
import 'package:hb_db/src/types/dbf_entry.dart';

///
/// Extract File Binary
///
Future<void> extractFileBinary(
  String outpath, {
  required HBDB db,
  required DBFEntry entry,
  OnDBProgressCallback? onProgress,
}) async {
  final raf = await db.dbFile.open(mode: FileMode.read);
  // file data offset
  await raf.setPosition(entry.offset);

  // Open output file for writing
  final outFile = File(outpath);

  final outName = outpath.getName();
  if (entry.isCompressed) {
    // DeCompressing
    final outSink = outFile.openWrite();

    final decoder = ZLibDecoder();
    final sink = decoder.startChunkedConversion(
      IOSinkWrapper(outSink, (written) {}),
    );

    const chunkSize = 1024 * 1024; // 1MB
    int read = 0;
    final fileSize = entry.compressSize;

    while (read < fileSize) {
      final remaining = fileSize - read;
      final toRead = remaining > chunkSize ? chunkSize : remaining;
      // final chunk = raf.readSync(toRead);
      final chunk = await raf.read(toRead);
      // await outRaf.writeFrom(chunk); // write to output file
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
    final fileSize = entry.size;

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
