import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/app_providers.dart';
import '../../data/models/discovered_wall.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/onboarding/discovery_screen.dart';
import '../screens/onboarding/empty_state_screen.dart';
import '../screens/onboarding/name_place_screen.dart';
import '../screens/onboarding/wifi_guide_screen.dart';
import '../screens/room/room_screen.dart';
import '../screens/scenes/scene_gallery_screen.dart';
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
      GoRoute(path: Routes.root, builder: (_, __) => const _SplashScreen()),
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
        path: Routes.onboardingNamePlace,
        builder: (context, state) {
          final discovered = state.extra as DiscoveredWall?;
          if (discovered == null) {
            // Defensive: someone navigated here without a selection.
            return const _MissingExtraScreen();
          }
          return NamePlaceScreen(discovered: discovered);
        },
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
                ],
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
