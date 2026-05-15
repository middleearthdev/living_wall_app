import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import '../../core/constants/network.dart';
import '../models/discovered_wall.dart';
import '../models/wled_info.dart';
import 'wled_client.dart';

/// Resolves the /24 subnet base from a wifi IP, e.g. "192.168.1.42" → "192.168.1".
typedef SubnetResolver = Future<String?> Function();

/// Probe a single IP. Returns null if it's not a WLED host. Wraps WledClient.
typedef WledProbe = Future<WledInfo?> Function(String ip);

/// Emits `(ip, deviceId, name)` for each mDNS hit. Stops when [timeout] elapses
/// or the caller cancels the subscription. Implementation seam for tests.
typedef MdnsScanner = Stream<MdnsHit> Function(Duration timeout);

/// Finds WLED panels on the LAN.
///
/// Strategy: run mDNS (`_wled._tcp`) and a /24 subnet ping in parallel, dedupe
/// by deviceId (MAC). Streaming output so the discovery screen shows results
/// as they arrive instead of waiting for the slowest path.
///
/// All three IO seams ([mdns], [probe], [subnetResolver]) are injectable so
/// the service is fully unit-testable without a real LAN.
class DiscoveryService {
  DiscoveryService({
    MdnsScanner? mdns,
    WledProbe? probe,
    SubnetResolver? subnetResolver,
  }) : _mdns = mdns ?? _defaultMdnsScanner,
       _probe = probe ?? _defaultProbe,
       _subnetResolver = subnetResolver ?? _defaultSubnetResolver;

  final MdnsScanner _mdns;
  final WledProbe _probe;
  final SubnetResolver _subnetResolver;

  /// Begins a scan and returns a stream of unique discoveries.
  ///
  /// The stream completes when both mDNS and the subnet sweep finish. Callers
  /// can cancel the subscription early to abort both branches.
  Stream<DiscoveredWall> scan({
    Duration mdnsTimeout = NetworkTiming.discoveryMdnsTimeout,
  }) {
    final controller = StreamController<DiscoveredWall>();
    final seen = <String>{};
    var mdnsDone = false;
    var sweepDone = false;
    StreamSubscription<MdnsHit>? mdnsSub;
    final pingFutures = <Future<void>>[];
    var cancelled = false;

    void maybeClose() {
      if (mdnsDone && sweepDone && !controller.isClosed) {
        controller.close();
      }
    }

    void emit(DiscoveredWall wall) {
      if (cancelled || controller.isClosed) return;
      if (seen.add(wall.deviceId)) {
        controller.add(wall);
      }
    }

    mdnsSub = _mdns(mdnsTimeout).listen(
      (hit) async {
        // Probe to confirm it's actually WLED and grab MAC + name.
        final info = await _probe(hit.ip);
        if (info == null) return;
        emit(
          DiscoveredWall(
            deviceId: info.mac,
            ipAddress: hit.ip,
            name: info.name,
            source: DiscoverySource.mdns,
          ),
        );
      },
      onDone: () {
        mdnsDone = true;
        maybeClose();
      },
      onError: (_) {
        mdnsDone = true;
        maybeClose();
      },
    );

    () async {
      try {
        final base = await _subnetResolver();
        if (base == null) return;
        // Skip .0 (network), .255 (broadcast). Sweep 1..254.
        for (var i = 1; i < 255; i++) {
          if (cancelled) break;
          final ip = '$base.$i';
          pingFutures.add(() async {
            final info = await _probe(ip);
            if (info == null) return;
            emit(
              DiscoveredWall(
                deviceId: info.mac,
                ipAddress: ip,
                name: info.name,
                source: DiscoverySource.subnetPing,
              ),
            );
          }());
        }
        await Future.wait(pingFutures);
      } finally {
        sweepDone = true;
        maybeClose();
      }
    }();

    controller.onCancel = () async {
      cancelled = true;
      await mdnsSub?.cancel();
    };

    return controller.stream;
  }
}

/// Tuple emitted by the mDNS scanner seam. Public so test fakes can construct
/// it; not consumed by production callers outside the service.
class MdnsHit {
  const MdnsHit(this.ip, this.port);
  final String ip;
  final int port;
}

/// Default mDNS implementation. Streams hits until [timeout] elapses or the
/// downstream subscription is cancelled.
Stream<MdnsHit> _defaultMdnsScanner(Duration timeout) async* {
  final client = MDnsClient();
  await client.start();
  final stopAt = DateTime.now().add(timeout);

  try {
    await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('_wled._tcp.local'),
      timeout: timeout,
    )) {
      if (DateTime.now().isAfter(stopAt)) break;
      await for (final SrvResourceRecord srv
          in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
            timeout: timeout,
          )) {
        await for (final IPAddressResourceRecord addr
            in client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
              timeout: timeout,
            )) {
          yield MdnsHit(addr.address.address, srv.port);
        }
      }
    }
  } finally {
    client.stop();
  }
}

/// Default probe — one-shot WledClient per IP. Short timeout so the /24 sweep
/// finishes in seconds, not minutes.
Future<WledInfo?> _defaultProbe(String ip) async {
  final client = WledClient(baseUrl: 'http://$ip');
  return client.getInfo();
}

/// Default subnet resolver: read the device's wifi IP, derive its /24.
/// Returns null if the device isn't on WiFi or the IP isn't IPv4.
Future<String?> _defaultSubnetResolver() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length != 4) continue;
        if (addr.address.startsWith('127.')) continue;
        return '${parts[0]}.${parts[1]}.${parts[2]}';
      }
    }
  } catch (_) {
    // fall through
  }
  return null;
}
