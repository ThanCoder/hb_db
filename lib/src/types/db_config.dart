// ignore_for_file: public_member_api_docs, sort_constructors_first
class DBConfig {
  ///
  /// Rule 1: Deleted > X MB
  ///
  final int deletedSizeLimit;

  ///
  ///  Rule 2: Deleted ratio > 20%
  ///
  final double deletedRatioLimit;

  ///
  ///  Rule 3: Too many delete ops
  /// ### currenty not working...
  final int deleteOpsLimit;

  ///
  ///  Auto Compact
  ///
  final bool isAutoCompact;

  ///
  ///  ### Not Saving Local `.lock` file
  ///
  final bool localDBLockFile;

  ///
  ///  ### Database Version
  ///
  /// default=`1`
  ///
  final int version;

  ///
  ///  ### Database Type
  ///
  /// default=`GENL` // Genral
  ///
  /// expected `4 bytes` Or text count `4`
  ///
  final String type;

  DBConfig({
    required this.deletedSizeLimit,
    required this.deletedRatioLimit,
    required this.deleteOpsLimit,
    required this.isAutoCompact,
    required this.localDBLockFile,
    required this.version,
    required this.type,
  });

  factory DBConfig.defaultSetting() {
    return DBConfig(
      deletedSizeLimit: 5 * 1024 * 1024, // 5MB,
      deletedRatioLimit: 0.20,
      deleteOpsLimit: 200,
      isAutoCompact: true,
      localDBLockFile: true,
      version: 1,
      type: 'GENL',
    );
  }

  DBConfig copyWith({
    int? deletedSizeLimit,
    double? deletedRatioLimit,
    int? deleteOpsLimit,
    bool? isAutoCompact,
    bool? localDBLockFile,
    int? version,
    String? type,
  }) {
    return DBConfig(
      deletedSizeLimit: deletedSizeLimit ?? this.deletedSizeLimit,
      deletedRatioLimit: deletedRatioLimit ?? this.deletedRatioLimit,
      deleteOpsLimit: deleteOpsLimit ?? this.deleteOpsLimit,
      isAutoCompact: isAutoCompact ?? this.isAutoCompact,
      localDBLockFile: localDBLockFile ?? this.localDBLockFile,
      version: version ?? this.version,
      type: type ?? this.type,
    );
  }
}
