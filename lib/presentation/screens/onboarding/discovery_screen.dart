import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/onboarding_providers.dart';
import '../../../application/providers/room_providers.dart';
import '../../../application/providers/wall_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/add_wall_context.dart';
import '../../../data/models/discovered_wall.dart';
import '../../routing/routes.dart';
import '../../widgets/add_wall_chrome.dart';
import '../../widgets/onboarding_scaffold.dart';

/// S03 — live list of walls as mDNS + subnet sweep find them. Tapping an
/// item promotes the user to S04 with the selection in route extras.
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key, this.addContext});

  /// When non-null the screen renders in add-wall mode, including muted
  /// rows for walls that are already registered ("Sudah ada di {room}")
  /// so users can't accidentally double-pair the same device.
  final AddWallContext? addContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(discoveryScanProvider);
    final registered =
        ref.watch(registeredByDeviceIdProvider).valueOrNull ?? const {};
    final ctx = addContext;
    final targetRoom = ctx == null ? null : ref.watch(roomByIdProvider(ctx.roomId));

    return OnboardingScaffold(
      stepLabel: ctx == null ? 'LANGKAH 2 / 3' : null,
      topBar: ctx == null
          ? null
          : AddWallTopBar(
              onConfirmedClose: () =>
                  context.go(Routes.dashboardRoom(ctx.roomId)),
            ),
      contextBanner: ctx == null
          ? null
          : AddWallContextBanner(roomName: targetRoom?.name ?? 'Ruangan'),
      title: 'Mencari wall di jaringan',
      subtitle:
          'Pastikan HP dan wall berada di WiFi rumah yang sama. Pencarian berlangsung beberapa detik.',
      body: scan.when(
        data: (walls) => _ResultsList(
          walls: walls,
          registered: registered,
          addContext: ctx,
        ),
        loading: () => const _LoadingState(),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(discoveryScanProvider);
          },
        ),
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => ref.invalidate(discoveryScanProvider),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text('Cari ulang'),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.walls,
    required this.registered,
    required this.addContext,
  });

  final List<DiscoveredWall> walls;
  final Map<String, RegisteredWallInfo> registered;
  final AddWallContext? addContext;

  @override
  Widget build(BuildContext context) {
    if (walls.isEmpty) return const _LoadingState();
    return ListView.separated(
      itemCount: walls.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _DiscoveredCard(
        wall: walls[i],
        registered: registered[walls[i].deviceId],
        addContext: addContext,
      ),
    );
  }
}

class _DiscoveredCard extends StatelessWidget {
  const _DiscoveredCard({
    required this.wall,
    required this.registered,
    required this.addContext,
  });

  final DiscoveredWall wall;
  final RegisteredWallInfo? registered;
  final AddWallContext? addContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final isRegistered = registered != null;

    return Opacity(
      opacity: isRegistered ? 0.55 : 1,
      child: Material(
        color: ext.surface2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isRegistered
              ? null
              : () => context.push(
                  Routes.namePlaceFor(addContext),
                  extra: wall,
                ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ext.surface3),
            ),
            child: Row(
              children: [
                Icon(Icons.light_outlined, color: ext.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wall.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        isRegistered
                            ? 'Sudah ada di ${registered!.roomName}'
                            : '${wall.ipAddress} · ${wall.deviceId}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isRegistered ? ext.textDim : ext.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRegistered)
                  Icon(Icons.chevron_right, color: ext.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: ext.accent),
        ),
        const SizedBox(height: 16),
        Text(
          'Menyapu jaringan…',
          style: theme.textTheme.bodyLarge?.copyWith(color: ext.textDim),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: ext.textDim, size: 40),
          const SizedBox(height: 12),
          Text('Pencarian gagal', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: ext.textFaint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
