import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/wall_providers.dart';

/// One-shot reconciliation between stored wall IPs and what's actually on
/// the network. WLED devices on consumer routers usually live behind DHCP
/// — leases roll over, IPs shift. We match the freshly-discovered devices
/// by deviceId (MAC) and update the cached IP for any wall whose address
/// has moved, then invalidate the socket so it reconnects to the new IP.
///
/// Fire-and-forget at app boot. If discovery returns nothing (user is on a
/// different network, airplane mode, etc.) we silently no-op — the
/// existing IPs may still work, and the live socket will surface offline
/// status if they don't.
final ipReconciliationProvider = FutureProvider<void>((ref) async {
  final walls = await ref.read(wallRepositoryProvider).allWalls();
  if (walls.isEmpty) return;

  final byDeviceId = {for (final w in walls) w.deviceId: w};
  final discovery = ref.read(discoveryServiceProvider);
  final repo = ref.read(wallRepositoryProvider);

  await for (final hit in discovery.scan()) {
    final wall = byDeviceId[hit.deviceId];
    if (wall == null) continue; // not one of ours
    if (wall.ipAddress == hit.ipAddress) continue;

    await repo.updateIp(deviceId: hit.deviceId, ip: hit.ipAddress);
    invalidateWall(ref, wall.id);
  }
});
