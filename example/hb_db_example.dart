import 'dart:io';

import 'package:hb_db/hb_db.dart';
import 'package:hb_db/src/core/internal.dart';
import 'package:hb_db/src/types/db_config.dart';

void main() async {
  try {
    final dir = Directory('dist');
    if (!dir.existsSync()) {
      await dir.create();
    }
    // final isSaved = await HBDB.extractCoverToFile(
    //   '/home/than/projects/plugins/hb_db/dist/၂၁ရာစုအင်မော်တယ် ဖေဖေ.db',
    //   savePath: 'cover.png',
    //   override: true,
    // );
    // print('cover: $isSaved');

    // final files = await HBDB.readFileEntriesFromDBFile(
    //   '/home/than/projects/plugins/hb_db/dist/၂၁ရာစုအင်မော်တယ် ဖေဖေ.db',
    // );
    // print(files);

    // final one = files.first;
    // await one.extract(one.name);

    final db = HBDB.getInstance();
    await db.open(
      '/home/than/projects/plugins/hb_db/dist/၂၁ရာစုအင်မော်တယ် ဖေဖေ.db',
      config: DBConfig.defaultSetting()
    );

    // db.setAdapter<User>(UserAdapter());
    // db.setAdapter<Car>(CarAdapter());

    // final box = db.getBox<User>();
    // await box.addAll([User(name: 'ThanCoder'), User(name: 'Aung Aung')]);
    // print(await box.getAll());

    // print(db.getUniqueFieldIdList);
    db.readAllSourceStream().listen((data) {
      print(data);
    });

    print('lastId: ${db.getLastId}');
    print('deletedSize: ${db.getDeletedSize.getSizeLabel()}');

    await db.close();
  } catch (e) {
    print('[error]: ${e.toString()}');
  }
}

class UserBoxListener implements HBBoxListener {
  @override
  void onHBBoxChanged(HBBoxListenerType type, int? autoId) {
    print('[User Box] Type: $type - autoId: $autoId');
  }
}

class CarBoxListener implements HBBoxListener {
  @override
  void onHBBoxChanged(HBBoxListenerType type, int? autoId) {
    print('[Car Box] Type: $type - autoId: $autoId');
  }
}

// listener
class DBListener implements HBListener {
  @override
  void onHBDBChanged(HBListenerType type, int? adapterFieldId, int? autoId) {
    print(
      '[DB] Type: $type - adapterFieldId: $adapterFieldId - autoId: $autoId',
    );
  }
}

///
/// ### [`autoId`] database auto generated
///

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

class Car {
  final int autoId; // database auto create
  final String name;
  Car({this.autoId = 0, required this.name});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'autoId': autoId, 'name': name};
  }

  factory Car.fromMap(Map<String, dynamic> map) {
    return Car(autoId: map['autoId'] as int, name: map['name'] as String);
  }
  @override
  String toString() {
    return name;
  }
}

class CarAdapter extends HBAdapter<Car> {
  @override
  Car fromMap(Map<String, dynamic> map) {
    return Car.fromMap(map);
  }

  @override
  int getUniqueFieldId() {
    return 2;
  }

  @override
  Map<String, dynamic> toMap(Car value) {
    return value.toMap();
  }
}
