class DBMetaType {
  static const int jsonTypeInt = 0;
  static const int fileTypeInt = 1;
  static const int coverTypeInt = 2;
  static const int otherTypeInt = 3;
}

class DBMetaFlag {
  static const int activeFlag = 1;
  static const int deleteFlag = 0;

  static bool isActive(int flag) => flag == activeFlag ? true : false;
  static bool isDeleted(int flag) => flag == deleteFlag ? true : false;
}

class DbMetaCompressType {
  static const int rowFileType = 0;
  static const int compressFileType = 1;

  static int parseBool(bool isCompressed) =>
      isCompressed ? compressFileType : rowFileType;
  static bool isCompressType(int type) =>
      type == compressFileType ? true : false;
}

typedef OnDBProgressCallback =
    void Function(int loaded, int total, String message);

const String dbAutoIdField = 'autoId';
const String dbMagic = 'HBDB';
