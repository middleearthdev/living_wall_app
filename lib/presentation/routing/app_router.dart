import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/controllers/wall_controller.dart';
import '../../application/providers/app_providers.dart';
import '../../data/models/add_wall_context.dart';
import '../../data/models/discovered_wall.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/onboarding/discovery_screen.dart';
import '../screens/onboarding/empty_state_screen.dart';
import '../screens/onboarding/name_place_screen.dart';
import '../screens/onboarding/qr_scan_screen.dart';
import '../screens/onboarding/wifi_guide_screen.dart';
import '../screens/room/room_screen.dart';
import '../screens/scenes/scene_gallery_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/wall/wall_control_screen.dart';
import 'routes.dart';

/// Router lives behind a provider so it can read `hasAnyWallProvider` for the
/// first-launch redirect. Re-evaluated when that provider invalidates, so the
/// final onboarding step naturally bounces the user into the dashboard.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.root,
    refreshListenable: _ProviderRefreshListenable(ref, hasAnyWallProvider),
    redirect: (context, state) {
      final hasWall = ref.read(hasAnyWallProvider).valueOrNull;
      // Still loading the gate — let the splash render briefly.
      if (hasWall == null) return null;

      final isAtRoot = state.matchedLocation == Routes.root;
      if (isAtRoot) {
        return hasWall ? Routes.dashboard : Routes.onboardingEmpty;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.root, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: Routes.onboardingEmpty,
        builder: (_, __) => const EmptyStateScreen(),
      ),
      GoRoute(
        path: Routes.onboardingWifi,
        builder: (_, __) => const WifiGuideScreen(),
      ),
      GoRoute(
        path: Routes.onboardingDiscovery,
        builder: (_, __) => const DiscoveryScreen(),
      ),
      GoRoute(
        path: Routes.onboardingQrScan,
        builder: (context, state) {
          final discovered = state.extra as DiscoveredWall?;
          if (discovered == null) return const _MissingExtraScreen();
          return QrScanScreen(
            discovered: discovered,
            onScanned: (payload) => context.push(
              Routes.onboardingNamePlace,
              extra: (discovered: discovered, provision: payload),
            ),
          );
        },
      ),
      GoRoute(
        path: Routes.onboardingNamePlace,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! OnboardingPayload) return const _MissingExtraScreen();
          return NamePlaceScreen(payload: extra);
        },
      ),
      // Settings is app-level (not nested under dashboard) so the gear
      // icon push stays distinct from any per-room/per-wall navigation.
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'about',
            builder: (_, __) => const AboutScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.dashboard,
        builder: (_, __) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'room/:roomId',
            builder: (_, state) =>
                RoomScreen(roomId: state.pathParameters['roomId']!),
            routes: [
              GoRoute(
                path: 'wall/:wallId',
                builder: (_, state) => WallControlScreen(
                  roomId: state.pathParameters['roomId']!,
                  wallId: state.pathParameters['wallId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'scenes',
                    builder: (_, state) => SceneGalleryScreen(
                      roomId: state.pathParameters['roomId']!,
                      wallId: state.pathParameters['wallId']!,
                    ),
                  ),
                  // Wall Settings → "Konfigurasi ulang": re-scan QR for an
                  // existing wall. The screen is the same as onboarding's
                  // QR step; only the onScanned callback differs.
                  GoRoute(
                    path: 'reconfigure-qr',
                    builder: (context, state) {
                      final wallId = state.pathParameters['wallId']!;
                      return _ReconfigureQrRoute(wallId: wallId);
                    },
                  ),
                ],
              ),
              // Add-wall flow — 3 steps reusing onboarding screens with an
              // AddWallContext that locks the target room. WiFi guide is
              // skipped (app is already on WiFi); QR scan is mandatory for
              // every new wall to populate grid dimensions.
              GoRoute(
                path: 'add-wall/discovery',
                builder: (_, state) => DiscoveryScreen(
                  addContext: AddWallContext(
                    roomId: state.pathParameters['roomId']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'add-wall/qr-scan',
                builder: (context, state) {
                  final roomId = state.pathParameters['roomId']!;
                  final addCtx = AddWallContext(roomId: roomId);
                  final discovered = state.extra as DiscoveredWall?;
                  if (discovered == null) return const _MissingExtraScreen();
                  return QrScanScreen(
                    discovered: discovered,
                    addContext: addCtx,
                    onScanned: (payload) => context.push(
                      Routes.addWallName(roomId),
                      extra: (discovered: discovered, provision: payload),
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'add-wall/name',
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is! OnboardingPayload) {
                    return const _MissingExtraScreen();
                  }
                  return NamePlaceScreen(
                    payload: extra,
                    addContext: AddWallContext(
                      roomId: state.pathParameters['roomId']!,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges a Riverpod provider to go_router's [Listenable] refresh contract so
/// the router re-evaluates `redirect` whenever the watched provider changes.
class _ProviderRefreshListenable extends ChangeNotifier {
  _ProviderRefreshListenable(Ref ref, ProviderListenable<Object?> provider) {
    _sub = ref.listen<Object?>(provider, (_, __) => notifyListeners());
  }

  late final ProviderSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

class _MissingExtraScreen extends StatelessWidget {
  const _MissingExtraScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih wall dari hasil discovery dulu.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    GoRouter.of(context).go(Routes.onboardingDiscovery),
                child: const Text('Kembali ke discovery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin wrapper around [QrScanScreen] that wires the scanned payload into
/// [WallController.reconfigure] for an existing wall, then pops back to the
/// wall control screen with a confirmation snackbar.
///
/// Lives in the router file (not screens/) because the only reason it
/// exists is to bridge route params to the controller call — the actual
/// scanning UI is the shared [QrScanScreen].
class _ReconfigureQrRoute extends ConsumerWidget {
  const _ReconfigureQrRoute({required this.wallId});

  final String wallId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return QrScanScreen(
      onScanned: (payload) async {
        await ref.read(wallControllerProvider).reconfigure(wallId, payload);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfigurasi wall diperbarui.')),
        );
        context.pop();
      },
    );
  }
}
