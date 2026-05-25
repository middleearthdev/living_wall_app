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

/// Compact info about an already-registered wall keyed by its `deviceId`
/// (MAC). The add-wall discovery screen looks each scan hit up here to
/// decide whether to disable the row with a "Sudah ada di {room}" label
/// instead of letting the user re-pair it.
class RegisteredWallInfo {
  const RegisteredWallInfo({required this.wallId, required this.roomName});
  final String wallId;
  final String roomName;
}

final registeredByDeviceIdProvider =
    FutureProvider<Map<String, RegisteredWallInfo>>((ref) async {
      final walls = await ref.watch(wallRepositoryProvider).allWalls();
      if (walls.isEmpty) return const <String, RegisteredWallInfo>{};
      final rooms = await ref.watch(roomsProvider.future);
      final roomById = {for (final r in rooms) r.id: r};
      return {
        for (final w in walls)
          w.deviceId: RegisteredWallInfo(
            wallId: w.id,
            roomName: roomById[w.roomId]?.name ?? 'Ruangan',
          ),
      };
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

/// Single shared WebSocket per wall. Both [wallStateProvider] and
/// [wallConnectivityProvider] subscribe to the same socket so we don't
/// open two TCP connections per wall — broadcast streams from one
/// instance fan out to all watchers.
final _wallSocketProvider = FutureProvider.family<WledSocket?, String>((
  ref,
  wallId,
) async {
  final wall = await ref.watch(wallRepositoryProvider).findById(wallId);
  if (wall == null) return null;
  final ip = wall.ipAddress;
  final socket = WledSocket(
    ip,
    // HTTP probe ensures we only mark the socket "connected" once the
    // wall has actually answered something — the WS channel object
    // creation is optimistic. Without this the toggle bounces on/off
    // each reconnect cycle for a powered-off wall.
    probe: () async {
      try {
        final info = await WledClient(baseUrl: 'http://$ip').getInfo();
        return info?.brand == 'WLED';
      } catch (_) {
        return false;
      }
    },
  );
  ref.onDispose(socket.dispose);
  socket.connect();
  return socket;
});

/// Live wall state via WebSocket. Seeds with a one-shot HTTP `/json/state`
/// read so the UI doesn't sit in `AsyncLoading` waiting for the first
/// device-side change. Socket lifetime is the app session.
final wallStateProvider = StreamProvider.family<WallState, String>((
  ref,
  wallId,
) async* {
  final wall = await ref.watch(wallRepositoryProvider).findById(wallId);
  if (wall == null) return;

  final client = WledClient(baseUrl: 'http://${wall.ipAddress}');
  final seed = await client.getState();
  if (seed != null) yield seed;

  final socket = await ref.watch(_wallSocketProvider(wallId).future);
  if (socket == null) return;
  yield* socket.stream;
});

/// Coarse reachability for a wall. Drives the "Tidak terjangkau" labels
/// and lets controllers/UI distinguish "wall is genuinely offline" from
/// "we just haven't talked to it yet".
enum WallConnectivity {
  /// Socket is still trying to connect or has never connected. UI should
  /// show a neutral state — neither online nor a hard offline warning.
  connecting,

  /// Latest socket activity is a successful connect.
  online,

  /// Socket lost its connection or failed initial connect after retries.
  /// UI surfaces "Tidak terjangkau".
  offline,
}

WallConnectivity _connectivityFor(WledSocketStatus status) {
  switch (status) {
    case WledSocketStatus.connecting:
      return WallConnectivity.connecting;
    case WledSocketStatus.connected:
      return WallConnectivity.online;
    case WledSocketStatus.disconnected:
      return WallConnectivity.offline;
  }
}

/// Reactive connectivity. Seeds with the socket's [currentStatus] so a late
/// subscriber doesn't sit at "connecting" forever just because it missed
/// the initial "connected" event on the broadcast stream.
final wallConnectivityProvider =
    StreamProvider.family<WallConnectivity, String>((ref, wallId) async* {
      final socket = await ref.watch(_wallSocketProvider(wallId).future);
      if (socket == null) {
        yield WallConnectivity.offline;
        return;
      }
      yield _connectivityFor(socket.currentStatus);
      await for (final status in socket.status) {
        yield _connectivityFor(status);
      }
    });

/// Tear down every per-wall provider that owns runtime state for a given
/// wall. The socket and stream providers dispose on invalidate; the simple
/// state providers reset to their defaults. Used after rename/delete so
/// stale entries don't linger in the family cache.
void invalidateWall(Ref ref, String wallId) {
  ref.invalidate(_wallSocketProvider(wallId));
  ref.invalidate(wallStateProvider(wallId));
  ref.invalidate(wallConnectivityProvider(wallId));
  ref.invalidate(wallByIdProvider(wallId));
  ref.invalidate(lastAppliedSceneIdProvider(wallId));
  ref.invalidate(wallExcludedProvider(wallId));
  ref.invalidate(wallIntentOnProvider(wallId));
}

/// Forces a wall's live-state pipeline to rebuild without touching user
/// intent / exclusion / scene state. Use this after a successful HTTP
/// command (toggle, brightness, scene) when the WebSocket appears to be
/// stuck in a backoff loop — a fresh subscription re-seeds via
/// [WledClient.getState] and reconnects immediately, so the UI converges
/// before the optimistic-intent window closes.
void triggerStateRefresh(Ref ref, String wallId) {
  ref.invalidate(_wallSocketProvider(wallId));
  ref.invalidate(wallStateProvider(wallId));
  ref.invalidate(wallConnectivityProvider(wallId));
}

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

/// Optimistic on/off intent for a single wall. The controller sets this
/// the instant the user taps a toggle so the UI flips before the HTTP
/// round-trip; the controller's auto-clear timer drops it back to null
/// after a few seconds so the WebSocket truth ([WallState.on]) takes
/// over again. `null` = no pending intent, fall back to WS state.
///
/// Mirrors the [lastAppliedSceneIdProvider] pattern (user intent wins
/// briefly, then truth reconciles).
final wallIntentOnProvider = StateProvider.family<bool?, String>(
  (ref, wallId) => null,
);

/// Optimistic on/off intent for a whole room (RoomCard toggle). Same
/// semantics as [wallIntentOnProvider] but room-scoped — set by
/// [RoomController.setOnOff], cleared by the room's auto-clear timer.
final roomIntentOnProvider = StateProvider.family<bool?, String>(
  (ref, roomId) => null,
);

/// True if at least one wall in the room is currently reachable
/// (WebSocket online). Drives the RoomCard toggle's enabled state —
/// when every wall is offline, tapping the toggle would just stall on
/// HTTP timeouts, so we disable it and surface a snackbar instead.
final roomReachableProvider = Provider.family<bool, String>((ref, roomId) {
  final walls =
      ref.watch(wallsForRoomProvider(roomId)).valueOrNull ?? const <Wall>[];
  if (walls.isEmpty) return false;
  return walls.any((w) {
    final c = ref.watch(wallConnectivityProvider(w.id)).valueOrNull;
    return c == WallConnectivity.online;
  });
});

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
