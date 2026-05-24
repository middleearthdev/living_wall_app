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

    // Surface "Cari ulang" only when a re-scan makes sense: scan finished
    // (empty terminal) or at least one wall has shown up. During the initial
    // sweep the button is noise — the user is already waiting on it.
    // Errors render their own inline retry, so no scaffold button there.
    final showRetry = scan.maybeWhen(
      data: (p) => p.walls.isNotEmpty || p.isDone,
      orElse: () => false,
    );

    void rescan() {
      ref.invalidate(resolvedSubnetProvider);
      ref.invalidate(discoveryScanProvider);
    }

    return OnboardingScaffold(
      stepLabel: ctx == null ? 'LANGKAH 2 / 4' : null,
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
        data: (progress) => _Body(
          progress: progress,
          registered: registered,
          addContext: ctx,
        ),
        loading: () => const _LoadingState(),
        error: (e, _) => _ErrorState(message: e.toString(), onRetry: rescan),
      ),
      secondaryAction: showRetry
          ? OutlinedButton(
              onPressed: rescan,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Cari ulang'),
            )
          : null,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.progress,
    required this.registered,
    required this.addContext,
  });

  final DiscoveryProgress progress;
  final Map<String, RegisteredWallInfo> registered;
  final AddWallContext? addContext;

  @override
  Widget build(BuildContext context) {
    final walls = progress.walls;
    if (walls.isEmpty) {
      return progress.isDone ? const _EmptyState() : const _LoadingState();
    }
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
                  Routes.qrScanFor(addContext),
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

class _LoadingState extends ConsumerWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final subnet = ref.watch(resolvedSubnetProvider).valueOrNull;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ext.surface2,
              border: Border.all(color: ext.surface3),
            ),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: ext.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Menyapu jaringan…',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subnet == null
                ? 'Biasanya selesai dalam 5–10 detik.'
                : 'Menyapu $subnet.x · biasanya 5–10 detik.',
            style: theme.textTheme.bodySmall?.copyWith(color: ext.textFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final subnet = ref.watch(resolvedSubnetProvider).valueOrNull;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.search_off_outlined, color: ext.textDim, size: 40),
          const SizedBox(height: 12),
          Text(
            'Belum ada wall ditemukan',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Periksa hal-hal berikut, lalu tap "Cari ulang" di bawah.',
            style: theme.textTheme.bodySmall?.copyWith(color: ext.textFaint),
            textAlign: TextAlign.center,
          ),
          if (subnet != null) ...[
            const SizedBox(height: 12),
            Text(
              'Pencarian dijalankan di $subnet.x',
              style: theme.textTheme.labelSmall?.copyWith(color: ext.textFaint),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          const _DiagnosticItem(
            text: 'Wall sudah dinyalakan dan LED-nya menyala.',
          ),
          const _DiagnosticItem(
            text:
                'Wall sudah disambungkan ke WiFi rumah lewat captive portal "WLED-AP".',
          ),
          _DiagnosticItem(
            text: subnet == null
                ? 'HP kamu di WiFi rumah yang sama — bukan jaringan tamu atau ekstender berbeda.'
                : 'IP wall di aplikasi WLED diawali $subnet — kalau bukan, HP dan wall di jaringan berbeda.',
          ),
          const _DiagnosticItem(
            text:
                'Tunggu sekitar 30 detik setelah wall menyala — wall butuh waktu untuk join jaringan.',
          ),
        ],
      ),
    );
  }
}

class _DiagnosticItem extends StatelessWidget {
  const _DiagnosticItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: ext.textDim, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: ext.textDim),
            ),
          ),
        ],
      ),
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
