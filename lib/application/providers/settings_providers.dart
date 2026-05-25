import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/services/wled_client.dart';
import 'app_providers.dart';

/// App version / build info sourced from the native bundle (so it can't
/// drift from pubspec). Used by the About screen.
final appInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Distinct WLED firmware versions across every registered wall, sorted
/// ascending. Each wall is probed in parallel via `/json/info`; unreachable
/// walls are skipped (the About screen falls back to a hardcoded "0.15.x"
/// label if no wall responds).
///
/// Kept in settings_providers.dart rather than wall_providers.dart because
/// the only consumer is the About screen — bundling it next to room/wall
/// state would imply runtime hot-path usage.
final firmwareVersionsProvider = FutureProvider<List<String>>((ref) async {
  final walls = await ref.read(wallRepositoryProvider).allWalls();
  if (walls.isEmpty) return const [];

  final probes = walls.map((w) async {
    try {
      final info = await WledClient(
        baseUrl: 'http://${w.ipAddress}',
      ).getInfo();
      return info?.ver;
    } catch (_) {
      return null;
    }
  });
  final results = await Future.wait(probes);
  final versions = results.whereType<String>().toSet().toList()..sort();
  return versions;
});
