import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/onboarding_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/discovered_wall.dart';
import '../../routing/routes.dart';
import '../../widgets/onboarding_scaffold.dart';

/// S03 — live list of walls as mDNS + subnet sweep find them. Tapping an
/// item promotes the user to S04 with the selection in route extras.
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(discoveryScanProvider);

    return OnboardingScaffold(
      stepLabel: 'LANGKAH 2 / 3',
      title: 'Mencari wall di jaringan',
      subtitle:
          'Pastikan HP dan wall berada di WiFi rumah yang sama. Pencarian berlangsung beberapa detik.',
      body: scan.when(
        data: (walls) => _ResultsList(walls: walls),
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
  const _ResultsList({required this.walls});

  final List<DiscoveredWall> walls;

  @override
  Widget build(BuildContext context) {
    if (walls.isEmpty) return const _LoadingState();
    return ListView.separated(
      itemCount: walls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _DiscoveredCard(wall: walls[i]),
    );
  }
}

class _DiscoveredCard extends StatelessWidget {
  const _DiscoveredCard({required this.wall});

  final DiscoveredWall wall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Material(
      color: ext.surface2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.onboardingNamePlace, extra: wall),
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
                      '${wall.ipAddress} · ${wall.deviceId}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: ext.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: ext.textDim),
            ],
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
