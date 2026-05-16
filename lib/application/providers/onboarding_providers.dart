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

/// Progress snapshot for the discovery screen: cumulative walls found plus
/// a terminal flag so the UI can distinguish "still scanning, nothing yet"
/// from "scan finished, found nothing" — the second case needs a diagnostic
/// empty state, the first just shows a spinner.
class DiscoveryProgress {
  const DiscoveryProgress({required this.walls, required this.isDone});
  final List<DiscoveredWall> walls;
  final bool isDone;
}

/// Live discovery stream. Auto-dispose so leaving the discovery screen tears
/// down mDNS + the subnet sweep instead of leaking sockets.
final discoveryScanProvider = StreamProvider.autoDispose<DiscoveryProgress>((
  ref,
) async* {
  final service = ref.watch(discoveryServiceProvider);
  final found = <DiscoveredWall>[];
  yield const DiscoveryProgress(walls: [], isDone: false);
  await for (final wall in service.scan()) {
    found.add(wall);
    yield DiscoveryProgress(
      walls: List<DiscoveredWall>.unmodifiable(found),
      isDone: false,
    );
  }
  yield DiscoveryProgress(
    walls: List<DiscoveredWall>.unmodifiable(found),
    isDone: true,
  );
});
