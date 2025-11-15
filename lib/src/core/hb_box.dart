import 'package:hb_db/hb_db.dart';

class HBBox<T> {
  final HBDB db;
  final HBAdapter<T> adapter;
  HBBox(this.db, this.adapter);

  Future<int> add(T value) async {
    return await db.add<T>(value);
  }

  Future<bool> delete(int id) async {
    return await db.delete<T>(id);
  }

  Future<List<bool>> deleteAll(List<int> list) async {
    return await db.deleteAll<T>(list);
  }

  Future<List<int>> addAll(List<T> list) async {
    return await db.addAll<T>(list);
  }

  Future<T?> getByid(int id) async {
    return await db.getById<T>(id);
  }

  Future<List<T>> getAll() async {
    return await db.getAll<T>();
  }

  Future<T?> query(bool Function(T value) test) async {
    return await db.query<T>(test);
  }

  Stream<T> getAllStream() {
    return db.getAllStream<T>();
  }

  Stream<T> queryStream(bool Function(T value) test) {
    return db.queryStream<T>(test);
  }

  Future<bool> update(int id, T value) async {
    return await db.update<T>(id, value);
  }

  ///
  /// --- Listener ---
  ///
  final List<HBBoxListener> _listener = [];

  ///
  /// ## addListener
  ///
  ///```dart
  ///  box.addListener(UserBoxListener());
  ///
  /// class UserBoxListener implements HBBoxListener {
  ///   @override
  ///   void onHBBoxChanged(HBBoxListenerType type, int? autoId) {
  ///     print('[User Box] Type: $type - autoId: $autoId');
  ///   }
  /// }
  ///```
  void addListener(HBBoxListener listener) {
    _listener.add(listener);
  }

  ///
  /// ## removeListener
  ///
  void removeListener(HBBoxListener listener) {
    _listener.remove(listener);
  }

  ///
  /// ## notify
  ///
  void notify(HBBoxListenerType type, {int? autoId}) {
    for (var listener in _listener) {
      listener.onHBBoxChanged(type, autoId);
    }
  }
}
