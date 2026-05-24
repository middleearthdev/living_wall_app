import 'package:drift/drift.dart';

import '../models/aspect_class.dart';

// Row classes are explicitly named *Row to avoid clashing with the Freezed
// domain models (Home/Room/Wall) in lib/data/models. Repositories translate
// between the two at the boundary.

@DataClassName('HomeRow')
class Homes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RoomRow')
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text().references(Homes, #id)();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WallRow')
class Walls extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get name => text()();
  TextColumn get deviceId => text().unique()();
  TextColumn get ipAddress => text()();

  // 2D matrix spec — populated from the per-unit QR code at provisioning.
  // No defaults: a Wall row without these is meaningless, since scene
  // rendering depends on them. The destructive onUpgrade in AppDatabase
  // wipes pre-v2 walls rather than backfilling fake values.
  TextColumn get serialNumber => text().unique()();
  IntColumn get gridWidth => integer()();
  IntColumn get gridHeight => integer()();
  IntColumn get lengthMm => integer()();
  IntColumn get heightMm => integer()();
  IntColumn get aspectClass => intEnum<AspectClass>()();

  DateTimeColumn get lastSeen => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
