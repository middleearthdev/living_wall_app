import 'package:freezed_annotation/freezed_annotation.dart';

part 'discovered_wall.freezed.dart';

/// Transient: produced by DiscoveryService, consumed by the discovery screen.
/// Not persisted — once the user names a discovered wall, it's promoted into
/// the drift-backed [Wall] entity. [deviceId] (MAC) is the dedupe key because
/// the same wall can show up via both mDNS and the subnet sweep.
@freezed
class DiscoveredWall with _$DiscoveredWall {
  const factory DiscoveredWall({
    required String deviceId,
    required String ipAddress,
    required String name,
    required DiscoverySource source,
  }) = _DiscoveredWall;
}

enum DiscoverySource { mdns, subnetPing }
