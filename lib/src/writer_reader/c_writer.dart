import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hb_db/src/core/encoder.dart';
import 'package:hb_db/src/core/db_lock.dart';
import 'package:hb_db/src/types/db_meta_type.dart';

///
/// ## get Cover Entry Binary Without `.lock`
///
Future<Uint8List?> readCoverFromDBFileBinary({required File dbFile}) async {
  if (!dbFile.existsSync()) {
    print('db: `${dbFile.path}` Not Exists');
    return null;
  }
  final raf = await dbFile.open();

  // magic
  final magicBytes = await raf.read(4);
  if (magicBytes.isEmpty) {
    throw Exception('Not `HBDB` Database File!');
  }
  final magic = utf8.decode(magicBytes);
  if (magic != dbMagic) {
    throw Exception('Magic`$magic` Database Not Supported!');
  }

  Uint8List? coverData;

  while (true) {
    // flag
    final flag = await raf.readByte();
    if (flag == -1) break; // EOF db read တာ ကုန်သွားပြီ။

    // type
    final type = await raf.readByte();

    // json db
    if (type == DBMetaType.jsonTypeInt) {
      // unique field id
      await raf.read(4);
      // db id
      await raf.read(8);
      // db length
      final length = bytesToInt4(await raf.read(4));
      // skip db data
      final currPos = await raf.position();
      await raf.setPosition((currPos + length));
    } else
    // file
    if (type == DBMetaType.fileTypeInt) {
      // compress type
      await raf.readByte();
      // file size
      final length = bytesToInt8(await raf.read(8));
      // skip file data
      final currPos = await raf.position();
      await raf.setPosition((currPos + length));
      // meta data
      final metaLength = bytesToInt4(await raf.read(4));
      await raf.read(metaLength);
    } else
    // cover
    if (type == DBMetaType.coverTypeInt) {
      final coverLength = bytesToInt4(await raf.read(4));
      // final coverPos = await raf.position();
      // set cover
      coverData = await raf.read(coverLength);
      // await raf.setPosition(coverPos + coverLength);
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

  final coverLength = bytesToInt4(await raf.read(4));
  final data = await raf.read(coverLength);

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

  // write data
  await raf.writeByte(DBMetaFlag.activeFlag);
  await raf.writeByte(DBMetaType.coverTypeInt);
  // length
  await raf.writeFrom(intToBytes4(imageData.length));
  await raf.writeFrom(imageData);

  // add memory
  dbLock.coverOffset = endPos;
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
