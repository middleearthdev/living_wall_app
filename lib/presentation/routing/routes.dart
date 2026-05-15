import '../../data/models/add_wall_context.dart';

/// Path constants. Keep them grouped by feature so feature deletion is a
/// single import to remove.
class Routes {
  Routes._();

  static const String root = '/';

  // Onboarding (S01–S04)
  static const String onboardingEmpty = '/onboarding/empty';
  static const String onboardingWifi = '/onboarding/wifi';
  static const String onboardingDiscovery = '/onboarding/discovery';
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

  // Add-wall flow (Sub-A + Sub-B). Same three screens as onboarding but
  // nested under a known room so the success path lands back in context.
  static String addWallWifi(String roomId) =>
      '/dashboard/room/$roomId/add-wall/wifi';
  static String addWallDiscovery(String roomId) =>
      '/dashboard/room/$roomId/add-wall/discovery';
  static String addWallName(String roomId) =>
      '/dashboard/room/$roomId/add-wall/name';

  /// Resolver used by the WiFi/Discovery/Name screens so each one doesn't
  /// re-implement the "onboarding vs add-wall" branch. Returns the path
  /// the *next* step should navigate to.
  static String wifiFor(AddWallContext? ctx) =>
      ctx == null ? onboardingWifi : addWallWifi(ctx.roomId);
  static String discoveryFor(AddWallContext? ctx) =>
      ctx == null ? onboardingDiscovery : addWallDiscovery(ctx.roomId);
  static String namePlaceFor(AddWallContext? ctx) =>
      ctx == null ? onboardingNamePlace : addWallName(ctx.roomId);
}
