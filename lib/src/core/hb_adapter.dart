abstract class HBAdapter<T> {
  ///
  /// default map type `id=0`.
  ///
  /// you should start `id=1`,
  ///
  int getUniqueFieldId();
  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T value);
}
