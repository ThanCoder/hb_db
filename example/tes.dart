import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hb_db/src/core/encoder.dart';

void main() async {
  final db = 'test.t.db';
  // final filePath = '/home/than/Documents/apyar_source.zip';
  // final filePath = 'pubspec.yaml';

  // await write(db, filePath, isCompress: false);
  await read(db);
}

Future<void> write(
  String db,
  String filePath, {
  bool isCompress = false,
}) async {
  final raf = await File(db).open(mode: FileMode.writeOnlyAppend);

  final file = File(filePath);
  await raf.writeByte(isCompress ? 1 : 0);
  int fileLength = await file.length();

  if (isCompress) {
    final encoder = ZLibEncoder();
    // size placeholder
    final sizePos = await raf.position();
    await raf.writeFrom(Uint8List(8));

    final compressedData = encoder.convert(await file.readAsBytes());
    await raf.writeFrom(compressedData);

    // end pos
    final endPos = await raf.position();

    //set size
    await raf.setPosition(sizePos);
    fileLength = (endPos - sizePos) - 8;
    await raf.writeFrom(intToBytes8(fileLength));

    await raf.setPosition(endPos);
  } else {
    await raf.writeFrom(intToBytes8(fileLength));
    await raf.writeFrom(file.readAsBytesSync());
  }
  // write name
  final name = file.uri.pathSegments.last;
  await raf.writeFrom(intToBytes4(name.length));
  await raf.writeFrom(utf8.encode(name));

  await raf.close();
  print('done');
}

Future<void> read(String db) async {
  final raf = await File(db).open(mode: FileMode.read);

  while (true) {
    final isCompressByte = await raf.readByte();
    if (isCompressByte == -1) break; //EOF
    final isCompress = isCompressByte == 1 ? true : false;
    if (isCompress) {
      // final decoder = ZLibDecoder();

      final fileLength = bytesToInt8(await raf.read(8));
      print('compress: $fileLength');
      final currentPos = await raf.position();
      await raf.setPosition(currentPos + fileLength);
    } else {
      final fileLength = bytesToInt8(await raf.read(8));
      print('raw: $fileLength');
      final currentPos = await raf.position();
      await raf.setPosition(currentPos + fileLength);
    }
    // name
    final nameLength = bytesToInt4(await raf.read(4));
    final name = utf8.decode(await raf.read(nameLength));
    print('name: $name');
  }

  await raf.close();
}
