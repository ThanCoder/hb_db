import 'dart:convert';
import 'dart:io';

import 'package:hb_db/src/core/encoder.dart';
import 'package:hb_db/src/types/db_entry.dart';
import 'package:hb_db/src/types/db_meta_type.dart';
import 'package:hb_db/src/types/dbf_entry.dart';

class DBLock {
  List<DBEntry> dbEntries = [];
  List<DBFEntry> fileEntries = [];
  int coverOffset = -1;
  int deletedSize = 0;
  int lastId = 0;
  int deleteOpsCount = 0;
  final File lockFile;
  final File dbFile;
  final bool isMemoryDBLock;

  DBLock({
    required this.dbFile,
    required this.lockFile,
    this.isMemoryDBLock = false,
  });

  Future<void> load() async {
    if (lockFile.existsSync()) {
      // final source = await lockFile.readAsString();
      // final map = jsonDecode(source);
      final raf = await lockFile.open(mode: FileMode.read);
      final length = bytesToInt8(await raf.read(8));
      final map = decodeRecord(await raf.read(length));
      await _parse(map);
      return;
    }
    // rebuild
    await _rebuild();
  }

  Future<void> _rebuild() async {
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
        // skip db data
        final currPos = await raf.position();
        await raf.setPosition((currPos + length));
        if (DBMetaFlag.isDeleted(flag)) {
          deletedSize += length;
        }
        if (DBMetaFlag.isActive(flag)) {
          // add lock
          dbEntries.add(
            DBEntry(
              uniqueFieldId: uniqueFieldId,
              id: id,
              offset: currPos,
              size: length,
            ),
          );
        }
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
        final meta = decodeRecordCompress4(await raf.read(metaLength));
        if (DBMetaFlag.isDeleted(flag)) {
          deletedSize += length;
        }
        // is active
        if (DBMetaFlag.isActive(flag)) {
          // add lock
          fileEntries.add(DBFEntry.fromMap(meta).copyWith(offset: currPos));
        }
      } else
      // cover
      if (type == DBMetaType.coverTypeInt) {
        final coverLength = bytesToInt4(await raf.read(4));
        final coverPos = await raf.position();
        // set cover
        coverOffset = DBMetaFlag.isActive(flag) ? coverPos : -1;
        await raf.setPosition(coverPos + coverLength);
      }
    }
    await raf.close();
    // colu
    lastId = dbEntries.isEmpty
        ? 0
        : dbEntries
              .map((e) => e.id)
              .reduce((value, element) => value > element ? value : element);

    await save();
  }

  Future<void> save() async {
    if (isMemoryDBLock) return;
    final map = {
      'cover_offset': coverOffset,
      'deleteOpsCount': deleteOpsCount,
      'lastId': lastId,
      'deleted_size': deletedSize,
      'file_entries': fileEntries.map((e) => e.toMap()).toList(),
      'db_entries': dbEntries.map((e) => e.toMap()).toList(),
    };
    // save local
    // await lockFile.writeAsString(JsonEncoder.withIndent(' ').convert(map));
    final json = encodeRecord(map);
    final raf = await lockFile.open(mode: FileMode.write);

    await raf.writeFrom(intToBytes8(json.length));
    await raf.writeFrom(json);
  }

  Future<void> delete() async {
    if (lockFile.existsSync()) {
      await lockFile.delete();
    }
  }

  Future<void> _parse(Map<String, dynamic> map) async {
    try {
      coverOffset = map['cover_offset'] ?? -1;
      deletedSize = map['deleted_size'] ?? 0;
      deleteOpsCount = map['deleteOpsCount'] ?? 0;
      List<dynamic> fileList = map['file_entries'] ?? [];
      List<dynamic> idList = map['db_entries'] ?? [];
      fileEntries = fileList.map((map) => DBFEntry.fromMap(map)).toList();
      dbEntries = idList.map((map) => DBEntry.fromMap(map)).toList();
      lastId = dbEntries.isEmpty
          ? 0
          : dbEntries
                .map((e) => e.id)
                .reduce((value, element) => value > element ? value : element);
    } catch (e) {
      print('[_parse]: ${e.toString()}');
    }
  }
}
