import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/home.dart';
import '../models/room.dart';

/// Owns Home + Room persistence. Phase 1 only ever has one Home, but the
/// schema supports many — keep the API future-friendly so we don't rewrite
/// when multi-home lands in Phase 2.
class HomeRepository {
  HomeRepository(this._db);

  final AppDatabase _db;

  /// Returns the default home if it exists, otherwise null. Useful for
  /// pre-onboarding queries that shouldn't side-effect a home into existence.
  Future<Home?> findDefaultHome() async {
    final existing = await (_db.select(_db.homes)..limit(1)).getSingleOrNull();
    return existing == null ? null : _toHome(existing);
  }

  /// Returns the default home, creating it on first call. Phase 1 invariant:
  /// the user always has exactly one Home after onboarding completes.
  Future<Home> ensureDefaultHome() async {
    final existing = await (_db.select(_db.homes)..limit(1)).getSingleOrNull();
    if (existing != null) return _toHome(existing);

    final home = Home(id: _generateId('home'), name: 'Rumah');
    await _db
        .into(_db.homes)
        .insert(HomesCompanion.insert(id: home.id, name: home.name));
    return home;
  }

  Future<List<Room>> roomsForHome(String homeId) async {
    final rows =
        await (_db.select(_db.rooms)
              ..where((t) => t.homeId.equals(homeId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map(_toRoom).toList();
  }

  Future<Room> createRoom({
    required String homeId,
    required String name,
  }) async {
    final existing = await roomsForHome(homeId);
    final room = Room(
      id: _generateId('room'),
      homeId: homeId,
      name: name,
      sortOrder: existing.length,
    );
    await _db
        .into(_db.rooms)
        .insert(
          RoomsCompanion.insert(
            id: room.id,
            homeId: room.homeId,
            name: room.name,
            sortOrder: Value(room.sortOrder),
          ),
        );
    return room;
  }

  Home _toHome(HomeRow row) => Home(id: row.id, name: row.name);

  Room _toRoom(RoomRow row) => Room(
    id: row.id,
    homeId: row.homeId,
    name: row.name,
    sortOrder: row.sortOrder,
  );
}

/// Tiny ID helper. Not cryptographic — just needs to be locally unique.
String _generateId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
