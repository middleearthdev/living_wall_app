import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/wall_providers.dart';
import '../../../core/theme/app_theme.dart';

/// S06 placeholder. Wired into the router so the wall-row tap from
/// [RoomScreen] has somewhere to land during week 4. Full implementation
/// (hero, quick scenes, brightness, scene gallery entry) ships in week 5.
class WallControlPlaceholderScreen extends ConsumerWidget {
  const WallControlPlaceholderScreen({super.key, required this.wallId});

  final String wallId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final wall = ref.watch(wallByIdProvider(wallId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(wall?.name ?? 'Wall'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kontrol wall',
                style: theme.textTheme.displaySmall?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 12),
              Text(
                'Layar kontrol satuan datang di sprint week 5. Untuk sekarang, atur dari kartu ruangan di dashboard.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: ext.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
