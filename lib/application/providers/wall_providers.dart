import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/scene.dart';
import '../../data/models/wall.dart';
import '../../data/models/wall_state.dart';
import '../../data/services/wled_client.dart';
import '../../data/services/wled_socket.dart';
import 'app_providers.dart';
import 'room_providers.dart';
import 'scene_providers.dart';

final wallByIdProvider = FutureProvider.family<Wall?, String>((ref, wallId) {
  return ref.watch(wallRepositoryProvider).findById(wallId);
});

/// First wall in a room. Used as the canonical signal for "the room's
/// scene" — UDP sync keeps the rest aligned.
final firstWallForRoomProvider = FutureProvider.family<Wall?, String>((
  ref,
  roomId,
) async {
  final walls = await ref.watch(wallsForRoomProvider(roomId).future);
  return walls.isEmpty ? null : walls.first;
});

/// Live wall state via WebSocket. Seeds with a one-shot HTTP `/json/state`
/// read so the UI doesn't sit in `AsyncLoading` waiting for the first
/// device-side change. Socket lifetime is the app session — the family arg
/// caches one socket per wall.
final wallStateProvider = StreamProvider.family<WallState, String>((
  ref,
  wallId,
) async* {
  final wall = await ref.watch(wallRepositoryProvider).findById(wallId);
  if (wall == null) return;

  final client = WledClient(baseUrl: 'http://${wall.ipAddress}');
  final seed = await client.getState();
  if (seed != null) yield seed;

  final socket = WledSocket(wall.ipAddress);
  ref.onDispose(socket.dispose);
  socket.connect();
  yield* socket.stream;
});

/// User-intent override: which scene id the controller most recently applied
/// to this wall. UI prefers this over the fx/pal reverse-lookup because it
/// updates instantly on tap; the lookup is the source of truth after a
/// restart or external (web UI) change.
final lastAppliedSceneIdProvider = StateProvider.family<String?, String>(
  (ref, wallId) => null,
);

/// In-memory exclusion flag. `true` means the wall is temporarily out of
/// its room's sync group — room-level commands skip it, and the device's
/// udpn.send/recv is toggled to false. Resets on app launch, matching the
/// spec's "sementara" wording. Device-side udpn config persists; a future
/// week-8 startup pass can reconcile.
final wallExcludedProvider = StateProvider.family<bool, String>(
  (ref, wallId) => false,
);

/// What scene to surface as "active" on cards/headers. Falls back through:
/// explicit user intent → fx+pal lookup against catalog → null (Custom).
final activeSceneForWallProvider = Provider.family<Scene?, String>((
  ref,
  wallId,
) {
  final explicitId = ref.watch(lastAppliedSceneIdProvider(wallId));
  final catalog = ref.watch(sceneCatalogSyncProvider);

  if (explicitId != null) {
    for (final s in catalog) {
      if (s.id == explicitId) return s;
    }
  }

  final state = ref.watch(wallStateProvider(wallId)).valueOrNull;
  if (state == null || state.fx == null) return null;
  for (final s in catalog) {
    if (s.fx == state.fx && s.pal == state.pal) return s;
  }
  return null;
});

/// Room-level convenience: surface whatever scene the room's first wall is
/// playing. UDP sync keeps the rest aligned, so wall #0 is canonical.
final activeSceneForRoomProvider = Provider.family<Scene?, String>((
  ref,
  roomId,
) {
  final first = ref.watch(firstWallForRoomProvider(roomId)).valueOrNull;
  if (first == null) return null;
  return ref.watch(activeSceneForWallProvider(first.id));
});

/// Aggregated live signals across every wall in a room. Used by RoomCard and
/// RoomScreen so each widget doesn't re-watch every wall individually.
///
/// - [anyOn]: true if any wall reports `on=true`. "Any" matches the design's
///   intent — the card reflects "the room is lit" even when one wall is
///   excluded from a group action.
/// - [brightness]: max brightness across walls (0–255). With UDP sync these
///   align; max is safer than "first" if one wall hasn't streamed yet.
/// - [allKnown]: every wall has emitted at least one state. Controls are
///   disabled until this flips true so the slider doesn't snap from 0.
class RoomVitals {
  const RoomVitals({
    required this.wallCount,
    required this.anyOn,
    required this.brightness,
    required this.allKnown,
    required this.excludedCount,
  });

  const RoomVitals.empty()
    : wallCount = 0,
      anyOn = false,
      brightness = 0,
      allKnown = false,
      excludedCount = 0;

  final int wallCount;
  final bool anyOn;
  final int brightness;
  final bool allKnown;
  final int excludedCount;

  int get inSyncCount => wallCount - excludedCount;
  bool get hasExclusions => excludedCount > 0;
  bool get allExcluded => wallCount > 0 && excludedCount >= wallCount;
}

final roomVitalsProvider = Provider.family<RoomVitals, String>((ref, roomId) {
  final walls =
      ref.watch(wallsForRoomProvider(roomId)).valueOrNull ?? const <Wall>[];
  if (walls.isEmpty) return const RoomVitals.empty();

  var anyOn = false;
  var maxBri = 0;
  var known = 0;
  var excluded = 0;
  for (final w in walls) {
    if (ref.watch(wallExcludedProvider(w.id))) excluded += 1;
    final state = ref.watch(wallStateProvider(w.id)).valueOrNull;
    if (state == null) continue;
    known += 1;
    if (state.on) anyOn = true;
    if (state.brightness > maxBri) maxBri = state.brightness;
  }
  return RoomVitals(
    wallCount: walls.length,
    anyOn: anyOn,
    brightness: maxBri,
    allKnown: known == walls.length,
    excludedCount: excluded,
  );
});
