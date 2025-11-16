import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hb_db/hb_db.dart';
import 'package:hb_db/src/core/encoder.dart';

class BinaryRW {
  ///
  /// ### Write Header Binary
  ///
  static Future<void> writeHeader(
    RandomAccessFile raf, {
    required String magic,
    required int version,
    required String type,
  }) async {
    if (type.length != 4) {
      throw Exception(
        'Invalid DB type length: expected 4 bytes, got ${type.length}.',
      );
    }
    await raf.writeFrom(utf8.encode(magic));
    await raf.writeByte(version);
    await raf.writeFrom(utf8.encode(type));
  }

  ///
  /// ### Read Header From Binary
  ///
  /// Return `(magic,version,type)`
  ///
  static Future<(String, int, String)> readHeader(RandomAccessFile raf) async {
    // magic
    final magicBytes = await raf.read(4);
    if (magicBytes.isEmpty) {
      throw Exception('Not `HBDB` Database File!');
    }
    final magic = utf8.decode(magicBytes);
    if (magic != dbMagic) {
      throw Exception('Magic`$magic` Database Not Supported!');
    }
    final version = await raf.readByte();
    final type = utf8.decode(await raf.read(4));
    // tuple
    return (magic, version, type);
  }

  ///
  /// ### Write Cover Binary
  ///
  ///Return `Cover Header Offset`
  ///
  static Future<int> writeCover(
    RandomAccessFile raf, {
    required Uint8List imageData,
  }) async {
    final currPos = await raf.position();
    // write data
    await raf.writeByte(DBMetaFlag.activeFlag);
    await raf.writeByte(DBMetaType.coverTypeInt);
    // length
    await raf.writeFrom(intToBytes4(imageData.length));
    await raf.writeFrom(imageData);

    return currPos;
  }

  ///
  /// ### Read Cover Binary
  ///
  ///Return `Cover Data`
  ///
  static Future<Uint8List?> readCover(
    RandomAccessFile raf, {
    bool isSkipData = false,
  }) async {
    final current = await raf.position();

    final coverLength = bytesToInt4(await raf.read(4));

    if (isSkipData) {
      await raf.setPosition(current + coverLength);
      return null;
    } else {
      final coverData = await raf.read(coverLength);
      return coverData;
    }
  }

  ///
  /// ### Read Json Database
  ///
  /// if `isSkip=true` ? `null` else `Map<String, dynamic>`
  ///
  static Future<DBEntry?> readJsonDatabase(
    RandomAccessFile raf, {
    bool isSkipData = false,
  }) async {
    // unique field id
    final uniqueFieldId = bytesToInt4(await raf.read(4));
    // db id
    final id = bytesToInt8(await raf.read(8));
    // db length
    final length = bytesToInt4(await raf.read(4));
    // skip db data
    final currPos = await raf.position();
    if (isSkipData) {
      await raf.setPosition((currPos + length));
    } else {
      // final data = decodeRecordCompress4(await raf.read(length));
      return DBEntry(
        uniqueFieldId: uniqueFieldId,
        id: id,
        offset: currPos,
        size: length,
      );
    }
    return null;
  }

  ///
  /// ### Read File Entry
  ///
  /// Return file meta `DBFEntry`
  ///
  static Future<DBFEntry?> readFileEntry(
    RandomAccessFile raf, {
    bool isSkipData = false,
  }) async {
    // file size
    final length = bytesToInt8(await raf.read(8));
    // skip file data
    final currPos = await raf.position();
    await raf.setPosition((currPos + length));

    if (isSkipData) {
      // meta
      final metaLength = bytesToInt4(await raf.read(4));
      final metaPos = await raf.position();
      await raf.setPosition(metaPos + metaLength);
    } else {
      // meta
      final metaLength = bytesToInt4(await raf.read(4));
      final map = decodeRecordCompress4(await raf.read(metaLength));
      return DBFEntry.fromMap(map);
    }
    return null;
  }

 
}
