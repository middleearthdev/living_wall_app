import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/wall.dart';

class WallRepository {
  WallRepository(this._db);

  final AppDatabase _db;

  /// First-launch check: do we have any wall persisted? Drives the router's
  /// onboarding-vs-dashboard branch.
  Future<bool> hasAnyWall() async {
    final count =
        await (_db.selectOnly(_db.walls)..addColumns([_db.walls.id.count()]))
            .map((row) => row.read(_db.walls.id.count()) ?? 0)
            .getSingle();
    return count > 0;
  }

  Future<List<Wall>> wallsInRoom(String roomId) async {
    final rows = await (_db.select(
      _db.walls,
    )..where((t) => t.roomId.equals(roomId))).get();
    return rows.map(_toWall).toList();
  }

  /// Inserts a new wall. Throws on deviceId conflict — the caller should
  /// catch this and surface "wall already added" to the user.
  Future<Wall> addWall({
    required String roomId,
    required String name,
    required String deviceId,
    required String ipAddress,
  }) async {
    final wall = Wall(
      id: _generateId('wall'),
      roomId: roomId,
      name: name,
      deviceId: deviceId,
      ipAddress: ipAddress,
      lastSeen: DateTime.now(),
      online: true,
    );
    await _db
        .into(_db.walls)
        .insert(
          WallsCompanion.insert(
            id: wall.id,
            roomId: wall.roomId,
            name: wall.name,
            deviceId: wall.deviceId,
            ipAddress: wall.ipAddress,
            lastSeen: Value(wall.lastSeen),
          ),
        );
    return wall;
  }

  /// IPs are caches, not truth. Re-discovery on app launch matches by
  /// deviceId (MAC) and updates the IP here.
  Future<void> updateIp({required String deviceId, required String ip}) async {
    await (_db.update(
      _db.walls,
    )..where((t) => t.deviceId.equals(deviceId))).write(
      WallsCompanion(ipAddress: Value(ip), lastSeen: Value(DateTime.now())),
    );
  }

  Wall _toWall(WallRow row) => Wall(
    id: row.id,
    roomId: row.roomId,
    name: row.name,
    deviceId: row.deviceId,
    ipAddress: row.ipAddress,
    lastSeen: row.lastSeen,
  );
}

String _generateId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
