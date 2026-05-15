import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/data/models/discovered_wall.dart';
import 'package:living_wall_app/data/models/wled_info.dart';
import 'package:living_wall_app/data/services/discovery_service.dart';

void main() {
  group('DiscoveryService', () {
    test('emits mDNS hits as DiscoveredWall', () async {
      final service = DiscoveryService(
        mdns: (_) =>
            Stream<MdnsHit>.fromIterable([const MdnsHit('192.168.1.50', 80)]),
        probe: (ip) async => ip == '192.168.1.50'
            ? const WledInfo(
                brand: 'WLED',
                ver: '0.14',
                mac: 'AA:BB:CC:DD:EE:01',
                name: 'Lounge Wall',
              )
            : null,
        subnetResolver: () async => null, // skip ping fallback
      );

      final results = await service.scan().toList();

      expect(results, hasLength(1));
      expect(results.first.deviceId, 'AA:BB:CC:DD:EE:01');
      expect(results.first.source, DiscoverySource.mdns);
    });

    test('subnet ping finds walls when mDNS is empty', () async {
      final service = DiscoveryService(
        mdns: (_) => const Stream<MdnsHit>.empty(),
        probe: (ip) async => ip == '192.168.1.7'
            ? const WledInfo(
                brand: 'WLED',
                ver: '0.14',
                mac: 'AA:BB:CC:DD:EE:07',
                name: 'Bedroom',
              )
            : null,
        subnetResolver: () async => '192.168.1',
      );

      final results = await service.scan().toList();

      expect(results, hasLength(1));
      expect(results.first.ipAddress, '192.168.1.7');
      expect(results.first.source, DiscoverySource.subnetPing);
    });

    test('dedupes by deviceId across both sources', () async {
      // Same MAC found by mDNS and by ping — should only emit once. The mDNS
      // path runs first and wins by virtue of arriving sooner in this test.
      final service = DiscoveryService(
        mdns: (_) =>
            Stream<MdnsHit>.fromIterable([const MdnsHit('192.168.1.50', 80)]),
        probe: (ip) async {
          if (ip == '192.168.1.50' || ip == '192.168.1.51') {
            return const WledInfo(
              brand: 'WLED',
              ver: '0.14',
              mac: 'AA:BB:CC:DD:EE:01',
              name: 'Lounge Wall',
            );
          }
          return null;
        },
        subnetResolver: () async => '192.168.1',
      );

      final results = await service.scan().toList();

      expect(results, hasLength(1));
      expect(results.first.deviceId, 'AA:BB:CC:DD:EE:01');
    });

    test('completes when both branches finish', () async {
      final service = DiscoveryService(
        mdns: (_) => const Stream<MdnsHit>.empty(),
        probe: (_) async => null,
        subnetResolver: () async => null,
      );

      // toList() only resolves when the stream emits onDone, so awaiting it
      // already proves completion. Test passes by not hanging.
      final results = await service.scan().toList().timeout(
        const Duration(seconds: 2),
      );

      expect(results, isEmpty);
    });

    test('cancellation stops further emission', () async {
      final mdnsController = StreamController<MdnsHit>();
      final service = DiscoveryService(
        mdns: (_) => mdnsController.stream,
        probe: (ip) async => const WledInfo(
          brand: 'WLED',
          ver: '0.14',
          mac: 'AA:BB:CC:DD:EE:01',
          name: 'X',
        ),
        subnetResolver: () async => null,
      );

      final received = <DiscoveredWall>[];
      final sub = service.scan().listen(received.add);

      mdnsController.add(const MdnsHit('192.168.1.10', 80));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await sub.cancel();
      mdnsController.add(const MdnsHit('192.168.1.11', 80));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, hasLength(1));
      await mdnsController.close();
    });
  });
}
