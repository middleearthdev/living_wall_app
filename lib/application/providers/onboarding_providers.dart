import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/discovered_wall.dart';
import '../../data/services/wifi_service.dart';
import 'app_providers.dart';

/// One-shot snapshot of the current WiFi context. Auto-refreshes when the
/// screen rebuilds — onboarding only needs a fresh read on entry, not live
/// updates (changing WiFi mid-flow drops the app anyway).
final wifiSnapshotProvider = FutureProvider.autoDispose<WifiSnapshot>((ref) {
  return ref.watch(wifiServiceProvider).snapshot();
});

/// Live discovery stream. Auto-dispose so leaving the discovery screen tears
/// down mDNS + the subnet sweep instead of leaking sockets.
final discoveryScanProvider = StreamProvider.autoDispose<List<DiscoveredWall>>((
  ref,
) {
  final service = ref.watch(discoveryServiceProvider);
  final found = <DiscoveredWall>[];
  final controller = service.scan();
  return controller.map((wall) {
    found.add(wall);
    return List<DiscoveredWall>.unmodifiable(found);
  });
});
