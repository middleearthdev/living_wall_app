import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/aspect_class.dart';
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

  Future<Wall?> findById(String wallId) async {
    final row = await (_db.select(
      _db.walls,
    )..where((t) => t.id.equals(wallId))).getSingleOrNull();
    return row == null ? null : _toWall(row);
  }

  /// Every wall across every room. Used by add-wall discovery to suppress
  /// re-pairing devices we've already registered — the deviceId is the
  /// dedupe key, so a wall that's already in one room can't end up duped
  /// into another.
  Future<List<Wall>> allWalls() async {
    final rows = await _db.select(_db.walls).get();
    return rows.map(_toWall).toList();
  }

  /// Inserts a new wall. Throws on deviceId or serialNumber conflict — the
  /// caller should catch this and surface "wall already added" to the user.
  ///
  /// The grid fields come from the QR payload scanned during add-wall;
  /// [aspectClass] is derived via [aspectClassFor] at the call site so
  /// invalid grid dims (height <= 0) fail loudly before reaching the DB.
  Future<Wall> addWall({
    required String roomId,
    required String name,
    required String deviceId,
    required String ipAddress,
    required String serialNumber,
    required int gridWidth,
    required int gridHeight,
    required int lengthMm,
    required int heightMm,
    required AspectClass aspectClass,
  }) async {
    final wall = Wall(
      id: _generateId('wall'),
      roomId: roomId,
      name: name,
      deviceId: deviceId,
      ipAddress: ipAddress,
      serialNumber: serialNumber,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      lengthMm: lengthMm,
      heightMm: heightMm,
      aspectClass: aspectClass,
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
            serialNumber: wall.serialNumber,
            gridWidth: wall.gridWidth,
            gridHeight: wall.gridHeight,
            lengthMm: wall.lengthMm,
            heightMm: wall.heightMm,
            aspectClass: wall.aspectClass,
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

  Future<void> rename({required String wallId, required String name}) async {
    await (_db.update(_db.walls)..where((t) => t.id.equals(wallId))).write(
      WallsCompanion(name: Value(name)),
    );
  }

  /// Replace the wall's grid / serial / dimension fields. Used by the
  /// "Konfigurasi ulang" flow when the user re-scans a QR (e.g. damaged
  /// label, swapped panel). The WLED `/json/cfg` re-issue is the caller's
  /// responsibility — this method only touches the DB.
  Future<void> updateConfig({
    required String wallId,
    required String serialNumber,
    required int gridWidth,
    required int gridHeight,
    required int lengthMm,
    required int heightMm,
    required AspectClass aspectClass,
  }) async {
    await (_db.update(_db.walls)..where((t) => t.id.equals(wallId))).write(
      WallsCompanion(
        serialNumber: Value(serialNumber),
        gridWidth: Value(gridWidth),
        gridHeight: Value(gridHeight),
        lengthMm: Value(lengthMm),
        heightMm: Value(heightMm),
        aspectClass: Value(aspectClass),
      ),
    );
  }

  Future<void> delete(String wallId) async {
    await (_db.delete(_db.walls)..where((t) => t.id.equals(wallId))).go();
  }

  Wall _toWall(WallRow row) => Wall(
    id: row.id,
    roomId: row.roomId,
    name: row.name,
    deviceId: row.deviceId,
    ipAddress: row.ipAddress,
    serialNumber: row.serialNumber,
    gridWidth: row.gridWidth,
    gridHeight: row.gridHeight,
    lengthMm: row.lengthMm,
    heightMm: row.heightMm,
    aspectClass: row.aspectClass,
    lastSeen: row.lastSeen,
  );
}

String _generateId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
