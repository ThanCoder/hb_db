import 'dart:io';
import 'dart:typed_data';

import 'package:hb_db/src/core/encoder.dart';
import 'package:hb_db/src/core/db_lock.dart';
import 'package:hb_db/src/types/db_meta_type.dart';

Future<void> compactBinary(
  File dbFile, {
  required DBLock dbLock,
  bool createdBackupDB = true,
  OnDBProgressCallback? onProgress,
}) async {
  final raf = await dbFile.open(mode: FileMode.read);
  final tmpFile = File('${dbFile.path}.tmp');
  final outRaf = await tmpFile.open(mode: FileMode.write);

  // magic
  final magicBytes = await raf.read(4);
  // write
  await outRaf.writeFrom(magicBytes);

  while (true) {
    // flag
    final flag = await raf.readByte();
    if (flag == -1) break; // EOF db read တာ ကုန်သွားပြီ။

    // type
    final type = await raf.readByte();

    // json db
    if (type == DBMetaType.jsonTypeInt) {
      // unique field id
      final uniqueFieldId = bytesToInt4(await raf.read(4));
      // db id
      final id = bytesToInt8(await raf.read(8));
      // db length
      final length = bytesToInt4(await raf.read(4));
      if (DBMetaFlag.isActive(flag)) {
        // write
        await outRaf.writeByte(flag);
        await outRaf.writeByte(type);
        await outRaf.writeFrom(intToBytes4(uniqueFieldId));
        await outRaf.writeFrom(intToBytes8(id));
        await outRaf.writeFrom(intToBytes4(length));
        // read data
        final data = await raf.read(length);
        await outRaf.writeFrom(data);
      } else {
        // skip db data
        final currPos = await raf.position();
        await raf.setPosition((currPos + length));
      }
    } else
    // file
    if (type == DBMetaType.fileTypeInt) {
      // compress type
      final compressType = await raf.readByte();
      // file size
      final fileLength = bytesToInt8(await raf.read(8));

      // is active
      if (DBMetaFlag.isActive(flag)) {
        await outRaf.writeByte(flag);
        await outRaf.writeByte(type);
        await outRaf.writeByte(compressType);
        await outRaf.writeFrom(intToBytes8(fileLength));
        // file data
        // --- Stream Copy (1MB per chunk) ---
        int readBytes = 0;
        int remaining = fileLength;
        final buffer = Uint8List(1024 * 1024);

        while (remaining > 0) {
          final toRead = remaining < buffer.length ? remaining : buffer.length;
          final n = await raf.readInto(buffer, 0, toRead);
          if (n == 0) throw Exception("Unexpected EOF while reading file data");

          await outRaf.writeFrom(buffer, 0, n);
          readBytes += n;
          remaining -= n;

          onProgress?.call(readBytes, fileLength, 'Copying...');
        }
        // meta data
        final metaLength = bytesToInt4(await raf.read(4));
        final meta = await raf.read(metaLength);
        await outRaf.writeFrom(intToBytes4(metaLength));
        await outRaf.writeFrom(meta);
      } else {
        // skip file data
        final currPos = await raf.position();
        await raf.setPosition((currPos + fileLength));
        // meta length
        final metaLength = bytesToInt4(await raf.read(4));
        // skip meta
        final metaCurrPos = await raf.position();
        await raf.setPosition((metaCurrPos + metaLength));
      }
    } else
    // cover
    if (type == DBMetaType.coverTypeInt) {
      final coverLength = bytesToInt4(await raf.read(4));
      final currPos = await raf.position();
      // is active
      if (DBMetaFlag.isActive(flag)) {
        await outRaf.writeByte(flag);
        await outRaf.writeByte(type);
        await outRaf.writeFrom(intToBytes4(coverLength));
        await outRaf.writeFrom(await raf.read(coverLength));
      } else {
        // skip
        await raf.setPosition((currPos + coverLength));
      }
    }
  }
  await outRaf.close();
  await raf.close();

  final lockFile = File('${dbFile.path}.lock');
  if (lockFile.existsSync()) {
    await lockFile.delete();
  }

  if (createdBackupDB) {
    await dbFile.rename('${dbFile.path}.bak');
    await tmpFile.rename(dbFile.path);
  } else {
    await dbFile.delete();
    await tmpFile.rename(dbFile.path);
  }
}
