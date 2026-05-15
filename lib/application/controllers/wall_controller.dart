import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/throttler.dart';
import '../../data/models/scene.dart';
import '../../data/models/wall.dart';
import '../../data/services/wled_client.dart';
import '../providers/app_providers.dart';
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

  Future<void> setOnOff(String wallId, bool on) async {
    final client = await _clientFor(wallId);
    if (client == null) return;
    await client.setOnOff(on);
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

  void dispose() {
    for (final t in _brightnessThrottlers.values) {
      t.dispose();
    }
    _brightnessThrottlers.clear();
  }
}

final wallControllerProvider = Provider<WallController>((ref) {
  final controller = WallController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
