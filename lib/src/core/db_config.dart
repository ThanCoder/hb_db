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
  final bool isMemoryDBLock;

  DBConfig({
    required this.deletedSizeLimit,
    required this.deletedRatioLimit,
    required this.deleteOpsLimit,
    required this.isAutoCompact,
    required this.isMemoryDBLock,
  });

  factory DBConfig.defaultSetting() {
    return DBConfig(
      deletedSizeLimit: 5 * 1024 * 1024, // 5MB,
      deletedRatioLimit: 0.20,
      deleteOpsLimit: 200,
      isAutoCompact: true,
      isMemoryDBLock: false,
    );
  }

  DBConfig copyWith({
    int? deletedSizeLimit,
    double? deletedRatioLimit,
    int? deleteOpsLimit,
    bool? isAutoCompact,
    bool? isMemoryDBLock,
  }) {
    return DBConfig(
      deletedSizeLimit: deletedSizeLimit ?? this.deletedSizeLimit,
      deletedRatioLimit: deletedRatioLimit ?? this.deletedRatioLimit,
      deleteOpsLimit: deleteOpsLimit ?? this.deleteOpsLimit,
      isAutoCompact: isAutoCompact ?? this.isAutoCompact,
      isMemoryDBLock: isMemoryDBLock ?? this.isMemoryDBLock,
    );
  }
}
