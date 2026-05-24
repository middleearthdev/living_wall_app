import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/data/models/add_wall_context.dart';
import 'package:living_wall_app/presentation/routing/routes.dart';

void main() {
  group('Routes.*For helpers', () {
    test('null context returns onboarding paths', () {
      expect(Routes.discoveryFor(null), Routes.onboardingDiscovery);
      expect(Routes.qrScanFor(null), Routes.onboardingQrScan);
      expect(Routes.namePlaceFor(null), Routes.onboardingNamePlace);
    });

    test('add-wall context returns room-scoped paths', () {
      const ctx = AddWallContext(roomId: 'room_42');
      expect(
        Routes.discoveryFor(ctx),
        '/dashboard/room/room_42/add-wall/discovery',
      );
      expect(
        Routes.qrScanFor(ctx),
        '/dashboard/room/room_42/add-wall/qr-scan',
      );
      expect(
        Routes.namePlaceFor(ctx),
        '/dashboard/room/room_42/add-wall/name',
      );
    });

    test('different room ids produce distinct paths', () {
      const a = AddWallContext(roomId: 'room_a');
      const b = AddWallContext(roomId: 'room_b');
      expect(Routes.qrScanFor(a), isNot(equals(Routes.qrScanFor(b))));
    });
  });

  group('Routes builders', () {
    test('dashboardWall interpolates both segments', () {
      expect(
        Routes.dashboardWall('r1', 'w1'),
        '/dashboard/room/r1/wall/w1',
      );
    });

    test('dashboardScenes nests under wall', () {
      expect(
        Routes.dashboardScenes('r1', 'w1'),
        '/dashboard/room/r1/wall/w1/scenes',
      );
    });

    test('reconfigureQr nests under the specific wall', () {
      expect(
        Routes.reconfigureQr('r1', 'w1'),
        '/dashboard/room/r1/wall/w1/reconfigure-qr',
      );
    });

    test('reconfigureQr keeps room + wall ids distinct', () {
      expect(
        Routes.reconfigureQr('r_a', 'w_x'),
        isNot(equals(Routes.reconfigureQr('r_a', 'w_y'))),
      );
      expect(
        Routes.reconfigureQr('r_a', 'w_x'),
        isNot(equals(Routes.reconfigureQr('r_b', 'w_x'))),
      );
    });
  });
}
