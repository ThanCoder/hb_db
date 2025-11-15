import 'dart:io';

import 'package:hb_db/src/core/encoder.dart';
import 'package:hb_db/src/core/db_lock.dart';

///
/// -- Stream ---
///
///
/// ### Read All Source DB Binary
///
Stream<Map<String, dynamic>> readAllSourceStreamDBBinary({
  required DBLock dbLock,
  required File dbFile,
}) async* {
  final raf = await dbFile.open(mode: FileMode.read);

  for (var db in dbLock.dbEntries) {
    await raf.setPosition(db.offset);
    final data = decodeRecordCompress4(await raf.read(db.size));

    await Future.delayed(Duration.zero);

    yield data;
  }
  await raf.close();
}

///
/// ### Read All Source By Field Id Stream DB Binary
///
Stream<Map<String, dynamic>> readAllSourceByFieldIdStreamDBBinary(
  int uniqueFieldId, {
  required DBLock dbLock,
  required File dbFile,
}) async* {
  final raf = await dbFile.open();

  for (var db in dbLock.dbEntries) {
    // check id
    if (db.uniqueFieldId == uniqueFieldId) {
      await raf.setPosition(db.offset);
      final data = decodeRecordCompress4(await raf.read(db.size));
      yield data;
    }
  }
  await raf.close();
}

///
/// ### Read All Source DB Binary
///
Future<List<Map<String, dynamic>>> readAllSourceDBBinary({
  required DBLock dbLock,
  required RandomAccessFile raf,
}) async {
  List<Map<String, dynamic>> list = [];

  for (var db in dbLock.dbEntries) {
    await raf.setPosition(db.offset);
    final data = decodeRecordCompress4(await raf.read(db.size));
    list.add(data);
  }
  return list;
}

///
/// ### Read Soure By FieldId DB Binary
///
Future<List<Map<String, dynamic>>> readSourceByFieldIdDBBinary(
  int uniqueFieldId, {
  required DBLock dbLock,
  required RandomAccessFile raf,
}) async {
  List<Map<String, dynamic>> list = [];

  for (var db in dbLock.dbEntries) {
    // check id
    if (uniqueFieldId == db.uniqueFieldId) {
      await raf.setPosition(db.offset);
      final data = decodeRecordCompress4(await raf.read(db.size));
      list.add(data);
    }
  }
  return list;
}

///
/// getAll DB Binary
///
Future<List<Map<String, dynamic>>> getAllDBBinary({
  required int uniqueFieldId,
  required DBLock dbLock,
  required RandomAccessFile raf,
}) async {
  List<Map<String, dynamic>> list = [];

  for (var db in dbLock.dbEntries) {
    if (uniqueFieldId == -1) {
      await raf.setPosition(db.offset);
      final data = decodeRecordCompress4(await raf.read(db.size));
      list.add(data);
    } else {
      // check id
      if (uniqueFieldId == db.uniqueFieldId) {
        await raf.setPosition(db.offset);
        final data = decodeRecordCompress4(await raf.read(db.size));
        list.add(data);
      }
    }
  }
  return list;
}

///
/// getById DB Binary
///
Future<Map<String, dynamic>?> getByIdDBBinary(
  int id, {
  required int uniqueFieldId,
  required DBLock dbLock,
  required RandomAccessFile raf,
}) async {
  final index = dbLock.dbEntries.indexWhere((e) => e.id == id);
  if (index == -1) return null;
  final entry = dbLock.dbEntries[index];
  // set position
  await raf.setPosition(entry.offset);

  final map = decodeRecordCompress4(await raf.read(entry.size));
  return map;
}

/// --- Stream ---

///
/// getAllStream DB Binary
///
Stream<Map<String, dynamic>> getAllDBStreamBinary({
  required int uniqueFieldId,
  required DBLock dbLock,
  required RandomAccessFile raf,
}) async* {
  for (var db in dbLock.dbEntries) {
    if (uniqueFieldId == -1) {
      await raf.setPosition(db.offset);
      final data = decodeRecordCompress4(await raf.read(db.size));
      yield data;
    } else {
      // check id
      if (uniqueFieldId == db.uniqueFieldId) {
        await raf.setPosition(db.offset);
        final data = decodeRecordCompress4(await raf.read(db.size));
        yield data;
      }
    }
  }
}
