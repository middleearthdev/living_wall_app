import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/throttler.dart';
import '../../data/models/aspect_class.dart';
import '../../data/models/provision_payload.dart';
import '../../data/models/scene.dart';
import '../../data/models/wall.dart';
import '../../data/services/wled_client.dart';
import '../providers/app_providers.dart';
import '../providers/room_providers.dart';
import '../providers/wall_providers.dart';

/// Single-wall control. The scene-gallery → adjustment-sheet flow needs
/// per-wall HTTP with brightness/speed/intensity overrides, so this is a
/// distinct service from [RoomController] rather than a shared abstraction
/// — the call shapes diverge enough that one parameter struct would obscure
/// more than it would dedupe.
class WallController {
  WallController(this._ref);

  final Ref _ref;
  final Map<String, Throttler<int>> _brightnessThrottlers = {};

  // Auto-clear timers for the optimistic [wallIntentOnProvider] entries.
  // Window matches what feels like the longest the WebSocket should take
  // to echo back a successful state change on a healthy LAN. If WS is
  // sluggish (e.g. recovering from a power cycle), the timer extends
  // itself up to [_intentMaxExtensions] times so the toggle doesn't
  // bounce back to a stale truth before the device's actual echo lands.
  static const _intentClearWindow = Duration(seconds: 3);
  static const _intentMaxExtensions = 3; // total ~12s before giving up
  final Map<String, Timer> _intentTimers = {};

  Future<WledClient?> _clientFor(String wallId) async {
    final wall = await _ref.read(wallRepositoryProvider).findById(wallId);
    if (wall == null) return null;
    return WledClient(baseUrl: 'http://${wall.ipAddress}');
  }

  Future<Wall?> _wall(String wallId) {
    return _ref.read(wallRepositoryProvider).findById(wallId);
  }

  /// Best-effort apply. User-intent override fires synchronously so the UI
  /// reflects the chosen scene immediately; HTTP runs after. WebSocket echo
  /// then reconciles the truth via the fx/pal lookup if the HTTP failed.
  Future<void> applyScene(
    String wallId,
    Scene scene, {
    int? briOverride,
    int? sxOverride,
    int? ixOverride,
  }) async {
    _ref.read(lastAppliedSceneIdProvider(wallId).notifier).state = scene.id;
    final client = await _clientFor(wallId);
    if (client == null) return;
    await client.applyScene(
      scene,
      briOverride: briOverride,
      sxOverride: sxOverride,
      ixOverride: ixOverride,
    );
  }

  /// Toggle on/off with optimistic UI. Sets [wallIntentOnProvider]
  /// synchronously so the toggle flips before the HTTP round-trip
  /// (otherwise a 1.5s connect timeout — and a 3.4s worst-case retry
  /// chain when the wall is unreachable — would leave the toggle
  /// looking frozen). The intent auto-clears after [_intentClearWindow]
  /// so the WebSocket truth reasserts itself; if the wall is offline
  /// and never echoes back, the toggle correctly snaps to "the wall
  /// didn't respond".
  Future<void> setOnOff(String wallId, bool on) async {
    _ref.read(wallIntentOnProvider(wallId).notifier).state = on;
    _scheduleIntentClear(wallId, on);
    final client = await _clientFor(wallId);
    if (client == null) return;
    try {
      await client.setOnOff(on);
      // If the WebSocket isn't currently online (e.g. still in backoff
      // after a power cycle), nudge the live-state pipeline so the WS
      // truth catches up to the change we just made — otherwise the
      // intent timer would expire to a stale `vitals.anyOn` and the
      // toggle would bounce back.
      final conn = _ref.read(wallConnectivityProvider(wallId)).valueOrNull;
      if (conn != WallConnectivity.online) {
        triggerStateRefresh(_ref, wallId);
      }
    } catch (_) {
      // Swallow — intent auto-clear + WS reconciliation will surface
      // the actual device state. Could snackbar from the caller if the
      // failure needs to be visible.
    }
  }

  void _scheduleIntentClear(String wallId, bool intent) {
    _intentTimers.remove(wallId)?.cancel();
    var extensions = 0;
    late void Function() check;
    check = () {
      final notifier = _ref.read(wallIntentOnProvider(wallId).notifier);
      // A newer tap superseded ours — let it manage its own timer.
      if (notifier.state != intent) {
        _intentTimers.remove(wallId);
        return;
      }
      final state = _ref.read(wallStateProvider(wallId)).valueOrNull;
      final wsAligns = state?.on == intent;
      if (wsAligns || extensions >= _intentMaxExtensions) {
        _intentTimers.remove(wallId);
        notifier.state = null;
      } else {
        // WS hasn't echoed back our intent yet — give it another window
        // before surrendering. Common when WS is recovering from a
        // power cycle and lags behind the HTTP control path.
        extensions++;
        _intentTimers[wallId] = Timer(_intentClearWindow, check);
      }
    };
    _intentTimers[wallId] = Timer(_intentClearWindow, check);
  }

  /// Toggle whether the wall participates in its room's UDP sync group.
  /// `true` = excluded (drops out of the group), `false` = re-included.
  /// Writes through to the device first; the local flag only flips after
  /// the HTTP succeeds so a failed call doesn't leave UI lying about
  /// device state.
  Future<void> setExcluded(String wallId, bool excluded) async {
    final client = await _clientFor(wallId);
    if (client == null) return;
    await client.setSyncEnabled(send: !excluded, recv: !excluded);
    _ref.read(wallExcludedProvider(wallId).notifier).state = excluded;
  }

  /// Throttled — coalesces slider frames into ~12 calls/sec per wall so a
  /// hard drag doesn't flood the network while keeping <200ms response.
  void setBrightness(String wallId, int brightness) {
    final clamped = brightness.clamp(0, 255);
    final throttler = _brightnessThrottlers.putIfAbsent(
      wallId,
      () => Throttler<int>(
        cooldown: const Duration(milliseconds: 80),
        onFire: (value) async {
          final client = await _clientFor(wallId);
          if (client == null) return;
          await client.setBrightness(value);
        },
      ),
    );
    throttler.submit(clamped);
  }

  /// Resolves the wall's user-facing name. Used by the adjustment sheet's
  /// Apply button label and by snackbar copy.
  Future<String> nameOf(String wallId) async {
    final wall = await _wall(wallId);
    return wall?.name ?? 'Wall';
  }

  /// Persist a new name. Only the wallByIdProvider entry needs explicit
  /// invalidation — the room's wall list watches Wall objects too, but the
  /// list itself doesn't refetch on rename, so we nudge it as well.
  Future<void> rename(String wallId, String name) async {
    final repo = _ref.read(wallRepositoryProvider);
    await repo.rename(wallId: wallId, name: name);
    _ref.invalidate(wallByIdProvider(wallId));
    final wall = await repo.findById(wallId);
    if (wall != null) {
      _ref.invalidate(wallsForRoomProvider(wall.roomId));
    }
  }

  /// Re-provision an existing wall from a fresh QR scan. Used by the
  /// Wall Settings "Konfigurasi ulang" flow when the saved dimensions are
  /// wrong (mis-scan, panel swap, factory bug).
  ///
  /// DB always wins: the new grid/serial fields are persisted even if the
  /// WLED config re-issue fails (offline device). The active scene is
  /// implicitly reset on the device because [WledClient.configureMatrix]
  /// rewrites `hw.led.matrix` — that's expected per the confirmation
  /// dialog copy.
  Future<void> reconfigure(String wallId, ProvisionPayload payload) async {
    final repo = _ref.read(wallRepositoryProvider);
    final wall = await repo.findById(wallId);
    if (wall == null) return;

    await repo.updateConfig(
      wallId: wallId,
      serialNumber: payload.serialNumber,
      gridWidth: payload.gridWidth,
      gridHeight: payload.gridHeight,
      lengthMm: payload.lengthMm,
      heightMm: payload.heightMm,
      // Derive from physical mm, not grid LEDs — see aspectClassFor doc.
      aspectClass: aspectClassFor(payload.lengthMm, payload.heightMm),
    );

    try {
      final client = WledClient(baseUrl: 'http://${wall.ipAddress}');
      await client.configureMatrix(
        gridWidth: payload.gridWidth,
        gridHeight: payload.gridHeight,
      );
    } catch (_) {
      // Swallow — DB is updated. User can re-trigger from settings once
      // the device is reachable. Losing the new dims would force another
      // QR scan and is worse UX than a stale device config.
    }

    invalidateWall(_ref, wallId);
  }

  /// Removes the wall from drift and tears down its socket/state providers.
  /// The caller should navigate away — staying on a wall control screen
  /// for a wall that no longer exists will render as offline + empty.
  Future<void> delete(String wallId) async {
    final repo = _ref.read(wallRepositoryProvider);
    final wall = await repo.findById(wallId);
    if (wall == null) return;
    final roomId = wall.roomId;

    await repo.delete(wallId);
    invalidateWall(_ref, wallId);
    _ref.invalidate(wallsForRoomProvider(roomId));
    _ref.invalidate(firstWallForRoomProvider(roomId));
    _ref.invalidate(registeredByDeviceIdProvider);
    _ref.invalidate(hasAnyWallProvider);
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

final wallControllerProvider = Provider<WallController>((ref) {
  final controller = WallController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
