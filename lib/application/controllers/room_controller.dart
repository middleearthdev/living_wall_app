import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/throttler.dart';
import '../../data/models/scene.dart';
import '../../data/models/wall.dart';
import '../../data/repositories/wall_repository.dart';
import '../../data/services/wled_client.dart';
import '../providers/app_providers.dart';
import '../providers/wall_providers.dart';
import 'wall_controller.dart';

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

  // Mirrors WallController's optimistic-intent pattern — see comments
  // there for the timer-extension rationale.
  static const _intentClearWindow = Duration(seconds: 3);
  static const _intentMaxExtensions = 3;
  final Map<String, Timer> _intentTimers = {};

  WledClient _clientFor(Wall wall) =>
      WledClient(baseUrl: 'http://${wall.ipAddress}');

  WallRepository get _wallRepo => _ref.read(wallRepositoryProvider);

  /// Walls in the room that are still part of the sync group. Excluded walls
  /// and offline walls are both skipped — offline walls can't receive HTTP
  /// commands, and sending to them just wastes the connect-timeout budget.
  Future<List<Wall>> _targets(String roomId) async {
    final all = await _wallRepo.wallsInRoom(roomId);
    return all.where((w) {
      if (_ref.read(wallExcludedProvider(w.id))) return false;
      final conn = _ref.read(wallConnectivityProvider(w.id)).valueOrNull;
      return conn == WallConnectivity.online;
    }).toList(growable: false);
  }

  Future<void> _forEach(
    String roomId,
    Future<void> Function(WledClient client) action,
  ) async {
    final walls = await _targets(roomId);
    if (walls.isEmpty) return;
    await Future.wait(walls.map((w) => action(_clientFor(w))));
  }

  /// Best-effort scene apply. The user-intent override fires synchronously so
  /// the UI flips to the new scene immediately; the HTTP fan-out runs after.
  /// If the request fails the override stays — the next WebSocket frame from
  /// the wall will re-derive the truth via the fx/pal lookup. Excluded walls
  /// and offline walls are skipped entirely.
  Future<void> applyScene(
    String roomId,
    Scene scene, {
    int? briOverride,
    int? sxOverride,
    int? ixOverride,
  }) async {
    final walls = await _targets(roomId);
    for (final w in walls) {
      _ref.read(lastAppliedSceneIdProvider(w.id).notifier).state = scene.id;
    }
    await Future.wait(
      walls.map(
        (w) => _clientFor(w).applyScene(
          scene,
          briOverride: briOverride,
          sxOverride: sxOverride,
          ixOverride: ixOverride,
        ),
      ),
    );
  }

  /// Optimistic room-level on/off. Sets [roomIntentOnProvider] before
  /// fanning out HTTP so the RoomCard toggle flips immediately even when
  /// one or more walls are unreachable (HTTP would otherwise stall the
  /// toggle until the 3.4s retry chain finishes). Auto-clears so WS
  /// truth wins after the dust settles.
  Future<void> setOnOff(String roomId, bool on) async {
    _ref.read(roomIntentOnProvider(roomId).notifier).state = on;
    _scheduleIntentClear(roomId, on);
    try {
      await _forEach(roomId, (c) => c.setOnOff(on));
    } catch (_) {
      // Per-wall failures are tolerated — intent + WS reconciliation
      // surface whatever actually happened on each device.
    }
    // Nudge any wall whose WebSocket is still in backoff so the state
    // pipeline picks up the change quickly. Without this the intent
    // window would expire to a stale `vitals.anyOn` after a power
    // cycle, snapping the toggle back.
    final walls = await _targets(roomId);
    for (final w in walls) {
      final conn = _ref.read(wallConnectivityProvider(w.id)).valueOrNull;
      if (conn != WallConnectivity.online) {
        triggerStateRefresh(_ref, w.id);
      }
    }
  }

  void _scheduleIntentClear(String roomId, bool intent) {
    _intentTimers.remove(roomId)?.cancel();
    var extensions = 0;
    late void Function() check;
    check = () {
      final notifier = _ref.read(roomIntentOnProvider(roomId).notifier);
      if (notifier.state != intent) {
        _intentTimers.remove(roomId);
        return;
      }
      final vitals = _ref.read(roomVitalsProvider(roomId));
      final wsAligns = vitals.anyOn == intent;
      if (wsAligns || extensions >= _intentMaxExtensions) {
        _intentTimers.remove(roomId);
        notifier.state = null;
      } else {
        extensions++;
        _intentTimers[roomId] = Timer(_intentClearWindow, check);
      }
    };
    _intentTimers[roomId] = Timer(_intentClearWindow, check);
  }

  /// Throttled — coalesces slider frames into ~12 calls/sec per room. That
  /// keeps the wall feeling instant (<200ms response) without flooding the
  /// network when the slider is dragged hard. The targets list is
  /// re-resolved on every fire, so toggling exclusion mid-drag takes effect
  /// on the next frame rather than at the next gesture.
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

  /// Re-include every wall in the room. Used by the "Sertakan semua wall"
  /// CTA when the user wants to undo all temporary exclusions at once
  /// instead of toggling each row.
  Future<void> includeAllWalls(String roomId) async {
    final walls = await _wallRepo.wallsInRoom(roomId);
    final wallCtrl = _ref.read(wallControllerProvider);
    await Future.wait(
      walls.map((w) => wallCtrl.setExcluded(w.id, false)),
    );
  }

  void dispose() {
    for (final t in _brightnessThrottlers.values) {
      t.dispose();
    }
    _brightnessThrottlers.clear();
    for (final t in _intentTimers.values) {
      t.cancel();
    }
    _intentTimers.clear();
  }
}

final roomControllerProvider = Provider<RoomController>((ref) {
  final controller = RoomController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
