import '../../data/models/add_wall_context.dart';
import '../../data/models/discovered_wall.dart';
import '../../data/models/provision_payload.dart';

/// Path constants. Keep them grouped by feature so feature deletion is a
/// single import to remove.
class Routes {
  Routes._();

  static const String root = '/';

  // First-launch onboarding — 5 steps (S01–S04 plus QR scan inserted
  // between discovery and name & place to read the wall's grid dims).
  static const String onboardingEmpty = '/onboarding/empty';
  static const String onboardingWifi = '/onboarding/wifi';
  static const String onboardingDiscovery = '/onboarding/discovery';
  static const String onboardingQrScan = '/onboarding/qr-scan';
  static const String onboardingNamePlace = '/onboarding/name-place';

  // Dashboard
  static const String dashboard = '/dashboard';
  static const String dashboardRoomPath = '/dashboard/room/:roomId';
  static const String dashboardWallPath = '/dashboard/room/:roomId/wall/:wallId';

  static String dashboardRoom(String roomId) => '/dashboard/room/$roomId';
  static String dashboardWall(String roomId, String wallId) =>
      '/dashboard/room/$roomId/wall/$wallId';
  static String dashboardScenes(String roomId, String wallId) =>
      '/dashboard/room/$roomId/wall/$wallId/scenes';

  /// Scene gallery opened from Room screen — applies to the whole room.
  static String dashboardRoomScenes(String roomId) =>
      '/dashboard/room/$roomId/scenes';

  /// Re-scan QR for an existing wall (Wall Settings → "Konfigurasi ulang").
  /// Reuses [QrScanScreen] but the route callback updates the wall record
  /// instead of creating a new one.
  static String reconfigureQr(String roomId, String wallId) =>
      '/dashboard/room/$roomId/wall/$wallId/reconfigure-qr';

  // Add-wall flow — 3 steps (Discovery → QR scan → Name). WiFi guide is
  // skipped because the app is already running on WiFi when add-wall is
  // entered; QR scan provisions the new wall's grid layout.
  static String addWallDiscovery(String roomId) =>
      '/dashboard/room/$roomId/add-wall/discovery';
  static String addWallQrScan(String roomId) =>
      '/dashboard/room/$roomId/add-wall/qr-scan';
  static String addWallName(String roomId) =>
      '/dashboard/room/$roomId/add-wall/name';

  /// Resolvers used by the Discovery / QR / Name screens so each one doesn't
  /// re-implement the "onboarding vs add-wall" branch. Returns the path
  /// the *next* step should navigate to.
  static String discoveryFor(AddWallContext? ctx) =>
      ctx == null ? onboardingDiscovery : addWallDiscovery(ctx.roomId);
  static String qrScanFor(AddWallContext? ctx) =>
      ctx == null ? onboardingQrScan : addWallQrScan(ctx.roomId);
  static String namePlaceFor(AddWallContext? ctx) =>
      ctx == null ? onboardingNamePlace : addWallName(ctx.roomId);

  // App-level Settings (gear icon top-right on Dashboard). About is the
  // EUPL-1.2 attribution path — see CLAUDE.md "WLED attribution" rule.
  static const String settings = '/settings';
  static const String settingsAbout = '/settings/about';
}

/// Bundle passed via go_router `extra` from the QR scan screen forward into
/// Name & Place. Combines the wall picked at Discovery with the validated
/// payload from QR scan so the final step can render dimensions and the
/// submit controller can populate the Wall record + WLED 2D matrix config.
typedef OnboardingPayload = ({
  DiscoveredWall discovered,
  ProvisionPayload provision,
});
