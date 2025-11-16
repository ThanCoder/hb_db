import 'dart:io';
import 'dart:typed_data';

import 'package:hb_db/src/core/db_lock.dart';
import 'package:hb_db/src/types/db_meta_type.dart';
import 'package:hb_db/src/writer_reader/binary_rw.dart';

///
/// ## get Cover Entry Binary Without `.lock`
///
Future<Uint8List?> readCoverFromDBFileBinary({required File dbFile}) async {
  if (!dbFile.existsSync()) {
    print('db: `${dbFile.path}` Not Exists');
    return null;
  }
  final raf = await dbFile.open();
  // header
  await BinaryRW.readHeader(raf);

  Uint8List? coverData;

  while (true) {
    // flag
    final flag = await raf.readByte();
    if (flag == -1) break; // EOF db read တာ ကုန်သွားပြီ။

    // type
    final type = await raf.readByte();

    // json db
    if (type == DBMetaType.jsonTypeInt) {
      await BinaryRW.readJsonDatabase(raf, isSkipData: true);
    } else
    // file
    if (type == DBMetaType.fileTypeInt) {
      await BinaryRW.readFileEntry(raf, isSkipData: true);
    } else
    // cover
    if (type == DBMetaType.coverTypeInt) {
      coverData = await BinaryRW.readCover(raf);
    }
  }
  await raf.close();

  return coverData;
}

///
/// ## get Cover Entry Binary
///
Future<Uint8List?> getCoverBinary({
  required File dbFile,
  required DBLock dbLock,
}) async {
  final coverPos = dbLock.coverOffset;
  final raf = await dbFile.open();
  if (coverPos == -1) return null;

  await raf.setPosition(coverPos);
  // skip flag
  await raf.readByte();
  await raf.readByte();

  final data = await BinaryRW.readCover(raf);

  await raf.close();
  return data;
}

///
/// ## Set Cover Entry Binary
///
/// if Cover Already `Exists` and It Will Deleted Old `Cover Data`
///
Future<void> setCoverBinary(
  Uint8List imageData, {
  required RandomAccessFile raf,
  required DBLock dbLock,
}) async {
  final oldOffset = dbLock.coverOffset;

  final endPos = await raf.position();
  if (oldOffset != -1) {
    // is exists old cover
    await raf.setPosition(oldOffset);
    //wirte flag
    await raf.writeByte(DBMetaFlag.deleteFlag);
    // go end pos
    await raf.setPosition(endPos);
  }

  final coverPos = await BinaryRW.writeCover(raf, imageData: imageData);

  // add memory
  dbLock.coverOffset = coverPos;
  // save
  await dbLock.save();
}

///
/// ## Delete Cover Entry Binary
///
Future<void> deleteCoverBinary({
  required RandomAccessFile raf,
  required DBLock dbLock,
}) async {
  final oldOffset = dbLock.coverOffset;
  if (oldOffset == -1) return;

  final endPos = await raf.position();
  // is exists old cover
  await raf.setPosition(oldOffset);
  //wirte flag
  await raf.writeByte(DBMetaFlag.deleteFlag);
  await raf.setPosition(endPos);

  // add memory
  dbLock.coverOffset = -1;
  // dbLock.deletedSize += length;
  // save
  await dbLock.save();
}
