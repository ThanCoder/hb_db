import 'dart:io';

import 'package:hb_db/src/core/encoder.dart';
import 'package:hb_db/src/core/db_lock.dart';
import 'package:hb_db/src/types/db_entry.dart';
import 'package:hb_db/src/types/db_meta_type.dart';

///
/// ## Add DB Binary
///
/// Return `[autoId]`
///
Future<int> addDBBinary(
  Map<String, dynamic> map, {
  required int uniqueFieldId,
  required DBLock dbLock,
  required RandomAccessFile raf,
}) async {
  dbLock.lastId += 1;
  final newId = dbLock.lastId;
  map[dbAutoIdField] = newId;

  final jsonData = encodeRecordCompress4(map);

  // flag
  await raf.writeFrom([DBMetaFlag.activeFlag]); // 1B flag=active 0x00=false
  await raf.writeFrom([DBMetaType.jsonTypeInt]);
  // unique field id
  await raf.writeFrom(intToBytes4(uniqueFieldId));
  // db id
  await raf.writeFrom(intToBytes8(newId));
  // write data length
  await raf.writeFrom(intToBytes4(jsonData.length)); // json length byte
  // db data offset
  final offset = await raf.position();
  // json data
  await raf.writeFrom(jsonData); // N Byte
  // add memory
  dbLock.dbEntries.add(
    DBEntry(
      uniqueFieldId: uniqueFieldId,
      id: newId,
      offset: offset,
      size: jsonData.length,
    ),
  );
  return newId;
}

///
/// ## Delete DB Binary
///
Future<bool> deleteDBBinary(
  int id, {
  required DBLock dbLock,
  required RandomAccessFile raf,
}) async {
  final index = dbLock.dbEntries.indexWhere((e) => e.id == id);
  if (index == -1) return false;

  final db = dbLock.dbEntries[index];

  final endPos = await raf.position();

  await raf.setPosition(db.offset - 4 - 8 - 4 - 1 - 1); //to flag pos
  // delete flag
  await raf.writeFrom([DBMetaFlag.deleteFlag]);
  // go end pos
  await raf.setPosition(endPos);

  // remove
  dbLock.dbEntries.removeAt(index);
  dbLock.deletedSize += db.size;

  return true;
}

///
/// ## Update DB Binary
///
Future<bool> updateDBBinary(
  int id, {
  required Map<String, dynamic> map,
  required int uniqueFieldId,
  required DBLock dbLock,
  required RandomAccessFile raf,
}) async {
  final index = dbLock.dbEntries.indexWhere((e) => e.id == id);
  if (index == -1) return false;

  final db = dbLock.dbEntries[index];

  final jsonData = encodeRecordCompress4(map);

  await raf.setPosition(db.offset - 4 - 8 - 4 - 1 - 1); //to flag pos
  // delete flag
  await raf.writeFrom([DBMetaFlag.deleteFlag]);

  // add deleted size
  dbLock.deletedSize += db.size;

  // go append pos or db end pos
  await raf.setPosition(await raf.length());

  // flag
  await raf.writeFrom([DBMetaFlag.activeFlag]); // 1B flag=active 0x00=false
  await raf.writeFrom([DBMetaType.jsonTypeInt]);
  // unique field id
  await raf.writeFrom(intToBytes4(uniqueFieldId));
  // db id
  await raf.writeFrom(intToBytes8(db.id));
  // write data length
  await raf.writeFrom(intToBytes4(jsonData.length)); // json length byte
  // db data offset
  final offset = await raf.position();
  // json data
  await raf.writeFrom(jsonData); // N Byte
  // update memory
  dbLock.dbEntries[index] = db.copyWith(offset: offset, size: jsonData.length);

  return true;
}
