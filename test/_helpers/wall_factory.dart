import 'package:living_wall_app/data/models/aspect_class.dart';
import 'package:living_wall_app/data/models/wall.dart';

/// Test-time [Wall] factory with M-tier landscape defaults.
///
/// Production code requires every grid/serial field at construction so
/// invalid walls fail loudly; that's the right discipline for runtime but
/// noisy for tests that only care about one field at a time. This helper
/// fills the boilerplate and lets each test override exactly what it needs:
///
/// ```dart
/// final wall = makeTestWall();                           // M-tier landscape
/// final tall = makeTestWall(gridWidth: 48, gridHeight: 72,
///                           aspectClass: AspectClass.portrait);
/// ```
Wall makeTestWall({
  String id = 'wall_test_1',
  String roomId = 'room_test_1',
  String name = 'Test Wall',
  String deviceId = 'AA:BB:CC:DD:EE:01',
  String ipAddress = '192.168.1.50',
  String serialNumber = 'LW-TEST-001',
  int gridWidth = 72,
  int gridHeight = 48,
  int lengthMm = 1200,
  int heightMm = 800,
  AspectClass aspectClass = AspectClass.landscape,
  DateTime? lastSeen,
  bool online = true,
}) => Wall(
  id: id,
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
  lastSeen: lastSeen,
  online: online,
);
