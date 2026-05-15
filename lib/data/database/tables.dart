import 'package:drift/drift.dart';

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
  DateTimeColumn get lastSeen => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
