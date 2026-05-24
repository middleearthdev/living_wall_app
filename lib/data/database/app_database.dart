import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/aspect_class.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Homes, Rooms, Walls])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  // Phase 1 is dev-only — no real users, no legacy data to preserve. A schema
  // bump wipes existing rows and recreates from the current schema. When we
  // move toward production (Phase 2+), replace this with per-version
  // migrations that preserve data.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      for (final table in allTables) {
        await m.deleteTable(table.actualTableName);
      }
      await m.createAll();
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'living_wall.db'));
    return NativeDatabase.createInBackground(file);
  });
}
