enum HBListenerType {
  addedDB,
  updatedDB,
  deletedDB,
  setCover,
  deletedCover,
  addedFile,
  deletedFile,
}

mixin HBListener {
  void onHBDBChanged(HBListenerType type, int? adapterFieldId, int? autoId);
}

enum HBBoxListenerType { addedDB, updatedDB, deletedDB }

mixin HBBoxListener {
  void onHBBoxChanged(HBBoxListenerType type, int? autoId);
}
