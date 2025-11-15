# HBDB – Hybrid Binary Database

---

## 📌 Introduction

HBDB is a **Hybrid Binary Database** for Dart/Flutter that allows you to store three main types of data inside a single ".db" file:

- **Map/JSON structured data** using Adapters
- **Binary files** (PDF, images, audio, any file)
- **Cover image (thumbnail)**

It uses a **custom binary format** with a **DB lock file**, supports **auto compact (clean-up)**, **stream reading**, **typed boxes**, and **listeners** for DB changes.

---

## 🚀 Features

- Type-safe data storage using **HBAdapter<T>**
- `add`, `update`, `delete`, `query`, `getAll`, `getAllStream`
- File entry support with compression
- Cover image support (set, get, delete)
- Auto compaction of database
- Built-in listeners for database and box-level events
- Single-file database design

---

## 🔧 How to Use

### 1. Initialize Database

```dart
final db = HBDB.getInstance();
await db.open('mydata.db');
```

### 2. Create Adapter for Your Model

```dart
class User {
  final String name;
  final int autoId; // [`autoId`] database auto generated

  User({required this.name, this.autoId = 0});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'name': name, 'autoId': autoId};
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(name: map['name'] as String, autoId: map['autoId'] as int);
  }
  @override
  String toString() {
    return name;
  }
}
class UserAdapter extends HBAdapter<User> {
  @override
  int getUniqueFieldId() {
    return 1;
  }

  @override
  User fromMap(Map<String, dynamic> map) {
    return User.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(User value) {
    return value.toMap();
  }
}
```

### 3. Register Adapter

```dart
db.setAdapter<User>(UserAdapter());
```

### 4. Add Data

```dart
final id = await db.add<User>(User(name: 'Than'));
```

### 5. Read All

```dart
final users = await db.getAll<User>();
```

### 6. Update

```dart
await db.update<User>(id, User(name: 'New Name'));
```

### 7. Delete

```dart
await db.delete<User>(id);
```

---

## Box

### Create Box

```dart
final userBox = db.getBox<User>();
```

### Add Data

```dart
final id = await userBox.add(User(name: 'Than'));
```

### Read All

```dart
final users = await userBox.getAll();
```

### Update

```dart
await userBox.update(id, User(name: 'New Name'));
```

### Delete

```dart
await userBox.delete(id);
```

---

## 📁 File Handling

### Add File

```dart
await db.addFile(File('test.pdf'));
```

### Extract File

```dart
await db.extractFile('output/', entry);
```

### Delete File

```dart
await db.deleteFile(entry);
```

---

## 🖼 Cover Image

```dart
await db.setCover(imageBytes);
final data = await db.getCoverData();
await db.deleteCover();
```

---

## 🧹 Auto Compact

Database automatically rebuilds when deleted size or delete count exceeds limits.
You can also manually compact:

```dart
await db.compact();
```

---

## 🔔 Database Stream

### Stream

```dart
// DB Cast
db.getAllStream<User>().listen((user) {
  print('user: $user');
});

// Box
userBox.getAllStream().listen((user) {
  print('user: $user');
});

```

---

### Query

```dart
// db
User? user1 = await db.query<User>((value) => value.name == 'name');
// box
User? user = await userBox.query((value) => value.name == 'name');

// Stream
/// db
db.queryStream<User>((value) => value.name == 'name').listen((user) {
  print('user: $user');
});
/// user
userBox.queryStream((value) => value.name == 'name').listen((user) {
  print('user: $user');
});
```

---

## 🔔 Listeners

```dart
class DBListener implements HBListener {
  @override
  void onHBDBChanged(HBListenerType type, int? adapterFieldId, int? autoId) {
    print(
      '[DB] Type: $type - adapterFieldId: $adapterFieldId - autoId: $autoId',
    );
  }
}
db.addListener(DBListener());

```

Type-specific box listeners:

```dart
final box = db.getBox<User>();

class UserBoxListener implements HBBoxListener {
  @override
  void onHBBoxChanged(HBBoxListenerType type, int? autoId) {
    print('[User Box] Type: $type - autoId: $autoId');
  }
}

userBox.addListener(UserBoxListener());

```

---

## 🇲🇲 မြန်မာဘာသာ Documentation

HBDB ကို Dart/Flutter အတွက်ရေးထားတဲ့ **Hybrid Binary Database** ဖြစ်ပြီး database file တစ်ခုအတွင်း

- **JSON/Map data**
- **Binary File (PDF, Image, video, zip)**
- **Cover image**

တွေကို အကုန်ပေါင်းသိမ်းလို့ရပါတယ်။

DB lock, compact, stream reading, adapter system, listeners တွေနဲ့ဆိုတော့ lightweight Hive + File system mix လိုအသုံးပြုလို့ရပါတယ်။

---

## 🚀 Feature အကျဉ်းချုပ်

- Adapter ဖြင့် type-safe data
- add/update/delete/query/getAll/getAllStream
- File တွေထည့်/ဖတ်/ဖြင့်နိုင်
- Cover image ထည့်/ဖယ်ရှားနိုင်
- Auto compact database clean-up
- Listener system included
- Database file တစ်ခုတည်း

---

## 📘 Conclusion

HBDB is simple, fast, compact, and flexible for apps that need mixed JSON + File storage in one database.

---
