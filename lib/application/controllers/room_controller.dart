import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/throttler.dart';
import '../../data/models/scene.dart';
import '../../data/models/wall.dart';
import '../../data/services/wled_client.dart';
import '../providers/app_providers.dart';
import '../providers/wall_providers.dart';

/// Room-scoped control: applies commands to every wall in the room.
///
/// Week 6 will introduce UDP-sync-driven "send to leader, mirror on the rest"
/// for instant fan-out at LED speed. Until that lands and is verified on
/// hardware, the app issues one HTTP call per wall in parallel — slightly
/// more network traffic, but deterministic regardless of sync state.
class RoomController {
  RoomController(this._ref);

  final Ref _ref;
  final Map<String, Throttler<int>> _brightnessThrottlers = {};

  WledClient _clientFor(Wall wall) =>
      WledClient(baseUrl: 'http://${wall.ipAddress}');

  Future<List<Wall>> _walls(String roomId) =>
      _ref.read(wallRepositoryProvider).wallsInRoom(roomId);

  Future<void> _forEach(
    String roomId,
    Future<void> Function(WledClient client) action,
  ) async {
    final walls = await _walls(roomId);
    if (walls.isEmpty) return;
    await Future.wait(walls.map((w) => action(_clientFor(w))));
  }

  /// Best-effort scene apply. The user-intent override fires synchronously so
  /// the UI flips to the new scene immediately; the HTTP fan-out runs after.
  /// If the request fails the override stays — the next WebSocket frame from
  /// the wall will re-derive the truth via the fx/pal lookup.
  Future<void> applyScene(String roomId, Scene scene) async {
    final walls = await _walls(roomId);
    for (final w in walls) {
      _ref.read(lastAppliedSceneIdProvider(w.id).notifier).state = scene.id;
    }
    await Future.wait(walls.map((w) => _clientFor(w).applyScene(scene)));
  }

  Future<void> setOnOff(String roomId, bool on) {
    return _forEach(roomId, (c) => c.setOnOff(on));
  }

  /// Throttled — coalesces slider frames into ~12 calls/sec per room. That
  /// keeps the wall feeling instant (<200ms response) without flooding the
  /// network when the slider is dragged hard.
  void setBrightness(String roomId, int brightness) {
    final clamped = brightness.clamp(0, 255);
    final throttler = _brightnessThrottlers.putIfAbsent(
      roomId,
      () => Throttler<int>(
        cooldown: const Duration(milliseconds: 80),
        onFire: (value) => _forEach(roomId, (c) => c.setBrightness(value)),
      ),
    );
    throttler.submit(clamped);
  }

  void dispose() {
    for (final t in _brightnessThrottlers.values) {
      t.dispose();
    }
    _brightnessThrottlers.clear();
  }
}

final roomControllerProvider = Provider<RoomController>((ref) {
  final controller = RoomController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
