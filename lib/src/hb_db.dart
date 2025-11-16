import 'dart:io';
import 'dart:typed_data';

import 'package:hb_db/src/index.dart';
import 'package:hb_db/src/types/db_config.dart';
import 'package:hb_db/src/core/hb_box.dart';
import 'package:hb_db/src/core/hbdb_listener.dart';
import 'package:hb_db/src/core/hb_adapter.dart';
import 'package:hb_db/src/writer_reader/bf_reader.dart';
import 'package:hb_db/src/writer_reader/binary_rw.dart';
import 'package:hb_db/src/writer_reader/c_writer.dart';
import 'package:hb_db/src/writer_reader/db_reader.dart';
import 'package:hb_db/src/writer_reader/bf_writer.dart';
import 'package:hb_db/src/writer_reader/db_rebuild.dart';
import 'package:hb_db/src/writer_reader/db_writer.dart';
import 'package:hb_db/src/core/db_lock.dart';
import 'package:hb_db/src/types/db_meta_type.dart';
import 'package:hb_db/src/types/dbf_entry.dart';

class HBDB {
  ///
  /// --- Singleton ---
  ///
  static HBDB? _instance;

  ///
  /// ## Singleton Database
  ///
  static HBDB getInstance() {
    _instance ??= HBDB();
    return _instance!;
  }

  late File dbFile;
  late DBLock _dbLock;
  final Map<Type, HBAdapter> _adapter = {};
  final Map<Type, HBBox> _box = {};
  final Map<int, HBBox> _adapterIdBox = {};
  late RandomAccessFile _dbRaf;
  late DBConfig _config;

  ///
  /// ### Open Database
  ///
  Future<void> open(String path, {DBConfig? config}) async {
    if (isDatabaseOpened) return;
    _config = config ?? DBConfig.defaultSetting();

    dbFile = File(path);
    _dbLock = DBLock(
      dbFile: dbFile,
      lockFile: File('$path.lock'),
      localDBLockFile: _config.localDBLockFile,
    );
    // db raf
    _dbRaf = await dbFile.open(mode: FileMode.writeOnlyAppend);
    //db မရှိရင်
    if (_dbRaf.lengthSync() == 0) {
      // write header
      await BinaryRW.writeHeader(
        _dbRaf,
        magic: dbMagic,
        version: _config.version,
        type: _config.type,
      );
      await _dbLock.save();
    }
    // read config
    await _dbLock.load();
  }

  ///
  /// ###  Database Change Path
  ///
  Future<void> changeDBPath(String path) async {
    if (isDatabaseOpened) {
      await close();
    }
    await open(path);
  }

  ///
  /// --- HBAdapter
  ///

  ///
  /// ### Set Adapter`<T>`
  ///
  ///```dart
  ///### Usage
  ///
  /// db.setAdapter<User>(UserAdapter());
  ///
  ///```
  void setAdapter<T>(HBAdapter<T> adapter) {
    _adapter[T] = adapter;
    final box = HBBox<T>(this, adapter);
    _box[T] = box;
    _adapterIdBox[adapter.getUniqueFieldId()] = box;
    _checkAdapterUinqueId<T>(adapter);
  }

  ///
  /// check adapter unique id
  ///
  void _checkAdapterUinqueId<T>(HBAdapter<T> adapter) {
    final ids = <int>{};
    for (var map in _adapter.values) {
      final id = map.getUniqueFieldId();
      if (ids.contains(id)) {
        throw Exception(
          "Duplicate Adapter: `${adapter.runtimeType}` Unique id detected: `$id`",
        );
      }
      ids.add(id);
    }
  }

  ///
  /// ### get adapter
  ///
  HBAdapter<T> _getAdapter<T>() {
    final adapter = _adapter[T];
    if (adapter == null) {
      throw Exception('No Adapter Registerd for type `$T`');
    }
    return adapter as HBAdapter<T>;
  }

  ///
  /// ### HBBox`<T>`
  ///
  HBBox<T> getBox<T>() {
    final box = _box[T];
    if (box == null) {
      throw Exception('Box<$T> not found. Did you setAdapter<$T>()?');
    }
    return box as HBBox<T>;
  }

  ///
  /// -- Source ---
  ///

  ///
  /// ### Register Unique Field Id List
  ///
  List<int> get getUniqueFieldIdList {
    List<int> fields = [];
    for (var entry in _dbLock.dbEntries) {
      fields.add(entry.uniqueFieldId);
    }

    return fields.toSet().toList();
  }

  ///
  /// ### Read All Source
  ///
  Future<List<Map<String, dynamic>>> readAllSource() async {
    final raf = await dbFile.open();
    final list = await readAllSourceDBBinary(dbLock: _dbLock, raf: raf);
    await raf.close();
    return list;
  }

  ///
  /// ### Read All Source By Field Id
  ///
  Future<List<Map<String, dynamic>>> readSourceByFieldId(int fieldId) async {
    final raf = await dbFile.open();
    final list = await readSourceByFieldIdDBBinary(
      fieldId,
      dbLock: _dbLock,
      raf: raf,
    );
    await raf.close();
    return list;
  }

  ///
  /// ### Read All Source Stream
  ///
  Stream<Map<String, dynamic>> readAllSourceStream() {
    return readAllSourceStreamDBBinary(dbLock: _dbLock, dbFile: dbFile);
  }

  ///
  /// ### Read All Source By Field Id Stream
  ///
  Stream<Map<String, dynamic>> readAllSourceStreamByFieldId(int uniqueFieldId) {
    return readAllSourceByFieldIdStreamDBBinary(
      uniqueFieldId,
      dbLock: _dbLock,
      dbFile: dbFile,
    );
  }

  ///
  /// --- Database ----
  ///

  ///
  /// ## add`<T>`
  ///
  /// Return `[autoId]`
  ///
  Future<int> add<T>(T value) async {
    final adapter = _getAdapter<T>();
    int id = await addDBBinary(
      adapter.toMap(value),
      uniqueFieldId: adapter.getUniqueFieldId(),
      dbLock: _dbLock,
      raf: _dbRaf,
    );
    // save lock
    await _dbLock.save();
    // notify
    notifyListener(
      HBListenerType.addedDB,
      adapterFieldId: adapter.getUniqueFieldId(),
      autoId: id,
    );
    return id;
  }

  ///
  /// ## addAll`<T>`
  /// `Database Add All Or Multi Add`
  ///
  Future<List<int>> addAll<T>(List<T> list) async {
    List<int> idList = [];
    final adapter = _getAdapter<T>();
    for (var value in list) {
      int id = await addDBBinary(
        adapter.toMap(value),
        uniqueFieldId: adapter.getUniqueFieldId(),
        dbLock: _dbLock,
        raf: _dbRaf,
      );
      idList.add(id);
    }

    // save lock
    await _dbLock.save();
    // notify
    notifyListener(
      HBListenerType.addedDB,
      adapterFieldId: adapter.getUniqueFieldId(),
    );
    return idList;
  }

  ///
  /// ## update`<T>`
  ///
  Future<bool> update<T>(int id, T value) async {
    final adapter = _getAdapter<T>();
    final isUpdated = await updateDBBinary(
      id,
      map: adapter.toMap(value),
      uniqueFieldId: adapter.getUniqueFieldId(),
      dbLock: _dbLock,
      raf: _dbRaf,
    );
    // delete count
    _dbLock.deleteOpsCount++;
    // save lock
    await _dbLock.save();
    // auto compack
    await _mabyCompact();
    // notify
    if (isUpdated) {
      notifyListener(
        HBListenerType.updatedDB,
        adapterFieldId: adapter.getUniqueFieldId(),
        autoId: id,
      );
    }
    return isUpdated;
  }

  ///
  /// ## delete`<T>`
  ///
  Future<bool> delete<T>(int id) async {
    final adapter = _getAdapter<T>();
    final isDeleted = await deleteDBBinary(id, dbLock: _dbLock, raf: _dbRaf);
    // delete count
    _dbLock.deleteOpsCount++;
    // save lock
    await _dbLock.save();
    // auto compack
    await _mabyCompact();
    // notify
    if (isDeleted) {
      notifyListener(
        HBListenerType.deletedDB,
        adapterFieldId: adapter.getUniqueFieldId(),
        autoId: id,
      );
    }
    return isDeleted;
  }

  ///
  /// ## deleteAll`<T>`
  ///
  Future<List<bool>> deleteAll<T>(List<int> list) async {
    final adapter = _getAdapter<T>();
    List<bool> idList = [];
    for (var id in list) {
      final isDeleted = await deleteDBBinary(id, dbLock: _dbLock, raf: _dbRaf);
      idList.add(isDeleted);
    }
    // delete count
    _dbLock.deleteOpsCount++;
    // save lock
    await _dbLock.save();
    // auto compack
    await _mabyCompact();
    // notify
    notifyListener(
      HBListenerType.deletedDB,
      adapterFieldId: adapter.getUniqueFieldId(),
    );
    return idList;
  }

  ///
  /// ## getById`<T>`
  ///
  Future<T?> getById<T>(int id) async {
    final raf = await dbFile.open();
    final adapter = _getAdapter<T>();
    final map = await getByIdDBBinary(
      id,
      uniqueFieldId: adapter.getUniqueFieldId(),
      dbLock: _dbLock,
      raf: raf,
    );
    await raf.close();
    return map == null ? null : adapter.fromMap(map);
  }

  ///
  /// ## getAll`<T>`
  ///
  Future<List<T>> getAll<T>() async {
    final raf = await dbFile.open();
    final adapter = _getAdapter<T>();
    final list = await getAllDBBinary(
      uniqueFieldId: adapter.getUniqueFieldId(),
      dbLock: _dbLock,
      raf: raf,
    );
    await raf.close();
    return list.map((map) => adapter.fromMap(map)).toList();
  }

  ///
  /// ## query`<T>`
  ///
  Future<T?> query<T>(bool Function(T value) test) async {
    final list = await getAll<T>();
    final filterd = list.where(test);
    return filterd.isNotEmpty ? filterd.first : null;
  }

  ///
  /// ## getAllStream`<T>`
  ///
  Stream<T> getAllStream<T>() async* {
    final raf = await dbFile.open();
    final adapter = _getAdapter<T>();

    await for (final map in getAllDBStreamBinary(
      uniqueFieldId: adapter.getUniqueFieldId(),
      dbLock: _dbLock,
      raf: raf,
    )) {
      yield adapter.fromMap(map);
    }
    await raf.close();
  }

  ///
  /// ## queryStream`<T>`
  ///
  Stream<T> queryStream<T>(bool Function(T value) test) async* {
    final raf = await dbFile.open();
    final adapter = _getAdapter<T>();

    await for (final map in getAllDBStreamBinary(
      uniqueFieldId: adapter.getUniqueFieldId(),
      dbLock: _dbLock,
      raf: raf,
    )) {
      final value = adapter.fromMap(map);
      if (test(value)) yield value;
    }
    await raf.close();
  }

  ///
  /// --- Cover Entry ----
  ///

  ///
  /// ### Check Cover Entry
  ///
  bool get isExistsCover => _dbLock.coverOffset != -1 ? true : false;

  ///
  /// ### Set Cover Entry
  ///
  Future<void> setCover(Uint8List imageData) async {
    await setCoverBinary(imageData, raf: _dbRaf, dbLock: _dbLock);

    // delete count
    _dbLock.deleteOpsCount++;
    // save lock
    await _dbLock.save();
    // auto compack
    await _mabyCompact();
    // notify
    notifyListener(HBListenerType.setCover);
  }

  ///
  /// ### Delete Cover Entry
  ///
  Future<void> deleteCover() async {
    await deleteCoverBinary(raf: _dbRaf, dbLock: _dbLock);
    // delete count
    _dbLock.deleteOpsCount++;
    // save lock
    await _dbLock.save();
    // auto compack
    await _mabyCompact();
    // notify
    notifyListener(HBListenerType.deletedCover);
  }

  ///
  /// ### Cover Image Data
  ///
  Future<Uint8List?> getCoverData() async {
    return await getCoverBinary(dbFile: dbFile, dbLock: _dbLock);
  }

  ///
  /// ### save Image Data
  ///
  /// if `imageData` exists ? `save` : `not save`
  ///
  Future<bool> saveCoverData(String path) async {
    final imageData = await getCoverBinary(dbFile: dbFile, dbLock: _dbLock);
    if (imageData == null) return false;
    await File(path).writeAsBytes(imageData);

    return true;
  }

  ///
  /// Reads the cover image directly from the database file.
  ///
  /// * Does NOT require calling `open()`
  /// * Works purely on the provided database file
  ///
  /// Returns:
  ///   - `Uint8List` (cover image bytes) if exists
  ///   - `null` if no cover entry is found
  ///
  static Future<Uint8List?> readCoverFromDBFile(String dbFile) async {
    return await readCoverFromDBFileBinary(dbFile: File(dbFile));
  }

  /// ### Save Image Data Without Opening the Database
  ///
  /// Saves the provided `imageData` directly to `savePath` without opening the DB.
  ///
  /// - If `imageData` is not null → the image file is saved.
  /// - If `imageData` is null → no file will be saved.
  ///
  /// Returns `true` if the image was saved, otherwise `false`.
  static Future<bool> extractCoverToFile(
    String dbFile, {
    required String savePath,
    bool override = false,
  }) async {
    final file = File(savePath);
    if (file.existsSync() && !override) return true;
    final imageData = await readCoverFromDBFileBinary(dbFile: File(dbFile));
    if (imageData == null) return false;
    await file.writeAsBytes(imageData);

    return true;
  }

  ///
  /// --- File Entry ----
  ///

  ///
  /// ### Add File Entry
  ///
  Future<void> addFile(
    File file, {
    bool isCompressed = true,
    OnDBProgressCallback? onProgress,
  }) async {
    await addFileBinary(
      file,
      raf: _dbRaf,
      dbLock: _dbLock,
      onProgress: onProgress,
    );
    // save lock
    await _dbLock.save();
    // notify
    notifyListener(HBListenerType.addedFile);
  }

  ///
  /// ### Add Multi File Entry
  ///
  Future<void> addMultiFile(
    List<File> files, {
    bool isCompressed = true,
    OnDBProgressCallback? onProgress,
  }) async {
    for (var file in files) {
      await addFileBinary(
        file,
        isCompressed: isCompressed,
        raf: _dbRaf,
        dbLock: _dbLock,
        onProgress: onProgress,
      );
    }
    // save lock
    await _dbLock.save();
    // notify
    notifyListener(HBListenerType.addedFile);
  }

  ///
  /// ### Extract File Entry
  ///
  Future<void> extractFile(
    String outpath,
    DBFEntry entry, {
    OnDBProgressCallback? onProgress,
  }) async {
    await extractFileBinary(
      outpath,
      db: this,
      entry: entry,
      onProgress: onProgress,
    );
  }

  ///
  /// ### Delete File Entry
  ///
  Future<bool> deleteFile(DBFEntry entry) async {
    final isDeleted = await deleteFileBinary(
      entry,
      raf: _dbRaf,
      dbLock: _dbLock,
    );
    // delete count
    _dbLock.deleteOpsCount++;
    // save lock
    await _dbLock.save();
    // auto compack
    await _mabyCompact();
    // notify
    notifyListener(HBListenerType.deletedFile);
    return isDeleted;
  }

  ///
  /// ### Delete Multi File Entry
  ///
  Future<void> deleteMultiFile(List<DBFEntry> entries) async {
    for (var entry in entries) {
      await deleteFileBinary(entry, raf: _dbRaf, dbLock: _dbLock);
    }
    _dbLock.deleteOpsCount++;

    // save lock
    await _dbLock.save();
    // auto compack
    await _mabyCompact();
    // notify
    notifyListener(HBListenerType.deletedFile);
  }

  /// --- Static ---
  ///

  ///
  /// ### Read File Entries File From DB File
  ///
  /// Without DB Opening
  ///
  static Future<List<DBFEntry>> readFileEntriesFromDBFile(String dbPath) async {
    return await readFileEntriesFormDBFileBinary(File(dbPath));
  }

  ///
  /// ### Maby Compact
  ///
  Future<void> _mabyCompact() async {
    // auto compack close
    if (!_config.isAutoCompact) return;

    final total = _dbLock.fileEntries.length;
    final deleted = _dbLock.deletedSize;

    if (deleted > _config.deletedSizeLimit ||
        deleted / total > _config.deletedRatioLimit ||
        _dbLock.deleteOpsCount > _config.deleteOpsLimit) {
      await compact();
      _dbLock.deleteOpsCount = 0;
    }
  }

  ///
  /// ### Compact
  ///
  /// `Database Clean Up` Or `Clean Rebuild Database`
  ///
  Future<void> compact({
    bool createdBackupDB = true,
    OnDBProgressCallback? onProgress,
  }) async {
    final configSize = (1024 * 1024) * 5; // 5MB
    //
    if (_dbLock.deletedSize > configSize) {
      await close();
      await compactBinary(
        dbFile,
        dbLock: _dbLock,
        createdBackupDB: createdBackupDB,
        onProgress: onProgress,
      );
      // deleted lock
      await _dbLock.delete();
      await open(dbFile.path);
    }
  }

  ///
  /// ### Database Config
  ///
  DBConfig get getConfig => _config;

  ///
  /// get last id
  ///
  int get getLastId => _dbLock.lastId;

  ///
  /// get last id
  ///
  int get getDeletedSize => _dbLock.deletedSize;

  ///
  /// get All Files
  ///
  List<DBFEntry> get getAllFilesEntries => _dbLock.fileEntries;

  ///
  /// get All Database Entries
  ///
  List<DBEntry> get getDBEntries => _dbLock.dbEntries;

  ///
  /// ### Database is Opened
  ///
  bool get isDatabaseOpened {
    try {
      _dbRaf;
      return true;
    } catch (e) {
      return false;
    }
  }

  ///
  /// ### Close Database
  ///
  Future<void> close() async => await _dbRaf.close();

  ///
  /// --- Database Listener ---
  ///
  final List<HBListener> _listener = [];

  ///
  /// ### addListener
  ///
  ///```dart
  /// db.addListener(DBListener());
  ///
  /// class DBListener implements HBListener {
  ///   @override
  ///   void onHBDBChanged(HBListenerType type, int? adapterFieldId, int? autoId) {
  ///     print(
  ///       '[DB] Type: $type - adapterFieldId: $adapterFieldId - autoId: $autoId',
  ///     );
  ///   }
  /// }
  ///```
  void addListener(HBListener listener) {
    _listener.add(listener);
  }

  ///
  /// ### removeListener
  ///
  void removeListener(HBListener listener) {
    _listener.remove(listener);
  }

  ///
  /// ### notifyListener
  ///
  void notifyListener(HBListenerType type, {int? adapterFieldId, int? autoId}) {
    for (var listener in _listener) {
      // all listener
      listener.onHBDBChanged(type, adapterFieldId, autoId);
    }
    // သီးသန့်
    if (adapterFieldId == null) return;
    final box = _adapterIdBox[adapterFieldId];
    if (box == null) return;

    if (type == HBListenerType.addedDB) {
      box.notify(HBBoxListenerType.addedDB, autoId: autoId);
    }
    if (type == HBListenerType.updatedDB) {
      box.notify(HBBoxListenerType.updatedDB, autoId: autoId);
    }
    if (type == HBListenerType.deletedDB) {
      box.notify(HBBoxListenerType.deletedDB, autoId: autoId);
    }
  }

  ///
  /// --- Static ---
  ///
  // Future<DBMeta?> getMetaFromDBFile(String dbPath) async {
  //   return null;
  // }
}
