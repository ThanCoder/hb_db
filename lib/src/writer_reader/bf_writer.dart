import 'dart:io';
import 'dart:typed_data';

import 'package:hb_db/src/core/encoder.dart';
import 'package:hb_db/src/core/db_lock.dart';
import 'package:hb_db/src/types/db_meta_type.dart';
import 'package:hb_db/src/types/dbf_entry.dart';
import 'package:hb_db/src/core/internal.dart';

///
/// ## Add File Binary
///
Future<void> addFileBinary(
  File file, {
  bool isCompressed = true,
  required RandomAccessFile raf,
  required DBLock dbLock,
  OnDBProgressCallback? onProgress,
}) async {
  if (!file.existsSync()) {
    throw PathNotFoundException(file.path, OSError('file not found!'));
  }
  final name = file.path.getName();
  final index = dbLock.fileEntries.indexWhere((e) => e.name == name);
  if (index != -1) {
    throw Exception('`$name` Already Exists in `$dbMagic`!.');
  }

  final source = await file.open();

  //wirte flag
  await raf.writeByte(DBMetaFlag.activeFlag);
  await raf.writeByte(DBMetaType.fileTypeInt);

  // write files
  const chunkSize = 1024 * 1024; // 1MB
  final buffer = Uint8List(chunkSize);
  // --- Metadata ---
  var entry = DBFEntry(
    name: name,
    size: await file.length(),
    compressSize: 0,
    isCompressed: isCompressed,
    modified: file.statSync().modified,
    offset: 0, //file data position
  );
  // compress
  if (isCompressed) {
    // ---- Compress Writing ----

    // placehoder compress size
    final sizePos = await raf.position();
    await raf.writeFrom(Uint8List(8));
    // data position
    final fileDataPos = await raf.position();
    // compress
    int compressedSize = 0;
    final inputStream = file.openRead();
    final outputRaf = raf; // RandomAccessFile open for write

    await for (final chunk in inputStream.transform(ZLibEncoder())) {
      await outputRaf.writeFrom(chunk); // async write safely
      compressedSize += chunk.length;
      onProgress?.call(
        compressedSize,
        file.lengthSync(),
        "[$name]: Compressing...",
      );
    }
    // end of pos
    final endPos = await raf.position();
    // set size pos
    await raf.setPosition(sizePos);
    // final fileLength = (endPos - sizePos) - 8;
    // write length
    await raf.writeFrom(intToBytes8(compressedSize));
    // to end pos
    await raf.setPosition(endPos);
    // add entry
    entry = entry.copyWith(compressSize: compressedSize, offset: fileDataPos);
  } else {
    /// --- Raw writing ---

    // write length
    await raf.writeFrom(intToBytes8(file.lengthSync()));

    // data position
    final fileDataPos = await raf.position();

    // --- Stream Copy (1MB per chunk) ---
    int readBytes = 0;
    while (true) {
      final n = await source.readInto(buffer);
      if (n == 0) break;
      await raf.writeFrom(buffer, 0, n);
      readBytes += n;
      // progress
      onProgress?.call(readBytes, source.lengthSync(), 'Writting: `$name`');
    }
    entry = entry.copyWith(offset: fileDataPos, size: file.lengthSync());
  }

  // meta json
  final entryData = encodeRecordCompress4(entry.toMap());
  //write entry length
  await raf.writeFrom(intToBytes4(entryData.length));
  await raf.writeFrom(entryData);

  await source.close();

  // add meta memory
  dbLock.fileEntries.add(entry);
}

///
/// ## Delete File Binary
///
Future<bool> deleteFileBinary(
  DBFEntry entry, {
  required RandomAccessFile raf,
  required DBLock dbLock,
}) async {
  final index = dbLock.fileEntries.indexWhere((e) => e.name == entry.name);
  if (index == -1) return false;
  final flagPos = entry.offset - 8 - 3; // fileLength=8,flag,type,compress=3

  final endPos = await raf.position();
  // go flag pos
  await raf.setPosition(flagPos);
  // set deleted mark
  await raf.writeFrom([DBMetaFlag.deleteFlag]);

  // go end pos
  await raf.setPosition(endPos);

  // update memory
  dbLock.fileEntries.removeAt(index);
  dbLock.deletedSize += entry.isCompressed ? entry.compressSize : entry.size;

  return true;
}
