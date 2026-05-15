import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/controllers/room_controller.dart';
import '../../../application/providers/room_providers.dart';
import '../../../application/providers/scene_providers.dart';
import '../../../application/providers/wall_providers.dart';
import '../../../application/controllers/wall_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/scene_palette.dart';
import '../../../core/utils/room_sync_banner.dart';
import '../../../data/models/scene.dart';
import '../../../data/models/wall.dart';
import '../../routing/routes.dart';

/// S07 — room-level control. Two affordances stacked: the wall list (drill
/// down to a single wall) and the mood grid (apply a scene to the whole
/// room). Sync banner appears when more than one wall belongs here, since
/// that's the case where group control is non-obvious.
class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key, required this.roomId});

  final String roomId;

  /// Curated "mood ruangan" set. Mirrors the design spec sample (Ocean,
  /// Sunset, Dinner, Movie). Full gallery (S08) lives behind "Lihat semua →"
  /// — wired in week 5.
  static const _moodIds = ['ocean', 'sunset', 'dinner', 'movie'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;

    final roomsAsync = ref.watch(roomsProvider);
    final wallsAsync = ref.watch(wallsForRoomProvider(roomId));
    final activeScene = ref.watch(activeSceneForRoomProvider(roomId));
    final catalog = ref.watch(sceneCatalogSyncProvider);
    final vitals = ref.watch(roomVitalsProvider(roomId));

    final rooms = roomsAsync.valueOrNull;
    final room = rooms?.where((r) => r.id == roomId).firstOrNull;
    final roomName = room?.name ?? 'Ruangan';

    final moods = [
      for (final id in _moodIds)
        if (catalog.any((s) => s.id == id))
          catalog.firstWhere((s) => s.id == id),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(title: roomName, onBack: () => context.pop()),
              const SizedBox(height: 8),
              Text(
                'Atur seluruh ruangan',
                style: theme.textTheme.displaySmall?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 12),
              _SyncBanner(
                copy: roomSyncBanner(
                  wallCount: vitals.wallCount,
                  excludedCount: vitals.excludedCount,
                ),
              ),
              Expanded(
                child: wallsAsync.when(
                  data: (walls) => walls.isEmpty
                      ? _EmptyRoom(roomId: roomId)
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            _SectionLabel(
                              text: 'Wall di ruangan ini',
                              hint: vitals.wallCount >= 2
                                  ? 'toggle untuk kecualikan'
                                  : 'tap untuk kontrol satuan',
                            ),
                            const SizedBox(height: 8),
                            for (final w in walls) ...[
                              _WallRow(
                                wall: w,
                                showToggle: vitals.wallCount >= 2,
                                onTap: () => context.push(
                                  Routes.dashboardWall(roomId, w.id),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            const SizedBox(height: 16),
                            _SectionLabel(
                              text: 'Mood ruangan',
                              hint: 'Lihat semua →',
                              hintColor: ext.accentLight,
                            ),
                            const SizedBox(height: 8),
                            _MoodGrid(
                              moods: moods,
                              activeId: activeScene?.id,
                              disabled: vitals.allExcluded,
                              onPick: (s) {
                                ref
                                    .read(roomControllerProvider)
                                    .applyScene(roomId, s);
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text('Terapkan ${s.name}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                              },
                            ),
                          ],
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'Gagal memuat wall: $e',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: ext.textDim,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.chevron_left, size: 28),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Three-state sync banner. Hidden state collapses to a zero-height widget
/// rather than being omitted from the tree so layout doesn't shift when the
/// state flips at runtime.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.copy});

  final RoomSyncBannerCopy copy;

  @override
  Widget build(BuildContext context) {
    if (copy.kind == RoomSyncBannerKind.hidden) {
      return const SizedBox.shrink();
    }
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    final (bg, border, fg, dot) = switch (copy.kind) {
      RoomSyncBannerKind.synced => (
        ext.accent.withValues(alpha: 0.14),
        ext.accentLight.withValues(alpha: 0.4),
        ext.accentLight,
        ext.accent,
      ),
      RoomSyncBannerKind.partiallyExcluded => (
        ext.surface3.withValues(alpha: 0.45),
        ext.surface3,
        ext.textDim,
        ext.textFaint,
      ),
      RoomSyncBannerKind.allExcluded => (
        Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
        Theme.of(context).colorScheme.error.withValues(alpha: 0.45),
        Theme.of(context).colorScheme.error,
        Theme.of(context).colorScheme.error,
      ),
      RoomSyncBannerKind.hidden => (
        Colors.transparent,
        Colors.transparent,
        Colors.transparent,
        Colors.transparent,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                copy.message,
                style: TextStyle(color: fg, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.hint, this.hintColor});

  final String text;
  final String? hint;
  final Color? hintColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
        ),
        const Spacer(),
        if (hint != null)
          Text(
            hint!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: hintColor ?? ext.textDim,
            ),
          ),
      ],
    );
  }
}

class _WallRow extends ConsumerWidget {
  const _WallRow({
    required this.wall,
    required this.showToggle,
    required this.onTap,
  });

  final Wall wall;

  /// Renders the sync-include toggle when true (multi-wall room) and a
  /// navigation chevron when false (single-wall room — no group concept).
  final bool showToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final state = ref.watch(wallStateProvider(wall.id)).valueOrNull;
    final scene = ref.watch(activeSceneForWallProvider(wall.id));
    final excluded = ref.watch(wallExcludedProvider(wall.id));

    final isOff = state == null || !state.on;
    final sceneLabel = scene?.name ?? (isOff ? 'mati' : 'Custom');

    return Opacity(
      opacity: excluded ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: ext.surface2.withValues(alpha: 0.5),
              border: Border.all(
                color: excluded
                    ? ext.surface3
                    : ext.accentLight.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                ColorFiltered(
                  colorFilter: excluded
                      ? const ColorFilter.matrix(_grayscaleMatrix)
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: ScenePalette.gradient(scene?.id),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: ext.surface3),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wall.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ext.textDim,
                          ),
                          children: excluded
                              ? const [
                                  TextSpan(
                                    text: 'Dikecualikan · kontrol sendiri',
                                  ),
                                ]
                              : [
                                  if (!isOff) ...[
                                    TextSpan(
                                      text: 'Tersinkron',
                                      style: TextStyle(color: ext.accentLight),
                                    ),
                                    const TextSpan(text: ' · '),
                                  ],
                                  TextSpan(text: sceneLabel),
                                ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (showToggle)
                  _SyncToggle(
                    included: !excluded,
                    onChanged: (include) => ref
                        .read(wallControllerProvider)
                        .setExcluded(wall.id, !include),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: ext.accentLight,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _grayscaleMatrix = <double>[
    0.3, 0.59, 0.11, 0, 0,
    0.3, 0.59, 0.11, 0, 0,
    0.3, 0.59, 0.11, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Smaller sibling of the dashboard room toggle — used per-wall to flip
/// sync membership. Its own GestureDetector means taps don't bubble up to
/// the row's InkWell, so toggling exclusion never accidentally navigates
/// into the wall control screen.
class _SyncToggle extends StatelessWidget {
  const _SyncToggle({required this.included, required this.onChanged});

  final bool included;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return GestureDetector(
      onTap: () => onChanged(!included),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: included
              ? ext.accent.withValues(alpha: 0.32)
              : ext.surface3.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: included
                ? ext.accentLight.withValues(alpha: 0.6)
                : ext.surface3,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: included ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: included ? ext.accentLight : ext.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodGrid extends StatelessWidget {
  const _MoodGrid({
    required this.moods,
    required this.activeId,
    required this.onPick,
    this.disabled = false,
  });

  final List<Scene> moods;
  final String? activeId;
  final ValueChanged<Scene> onPick;

  /// When true the grid renders dim and ignores taps. Used when every wall
  /// in the room is excluded — there's no one to apply a mood to until the
  /// user re-includes at least one wall.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.1,
      ),
      itemCount: moods.length,
      itemBuilder: (_, i) => _MoodTile(
        scene: moods[i],
        selected: moods[i].id == activeId,
        onTap: disabled ? null : () => onPick(moods[i]),
      ),
    );

    if (!disabled) return grid;

    return Opacity(
      opacity: 0.5,
      child: IgnorePointer(ignoring: true, child: grid),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.scene,
    required this.selected,
    required this.onTap,
  });

  final Scene scene;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          gradient: ScenePalette.gradient(scene.id),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? ext.accentLight
                : Colors.white.withValues(alpha: 0.1),
            width: selected ? 1.8 : 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        alignment: Alignment.bottomLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            scene.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Belum ada wall di ruangan ini',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tambah wall pertama untuk mengaktifkan kontrol grup di sini.',
              style: theme.textTheme.bodyMedium?.copyWith(color: ext.textDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ext.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              // Week 7 will route to a room-aware add-wall flow; until then
              // the onboarding wifi screen is the available entry point.
              onPressed: () => GoRouter.of(context).push(Routes.onboardingWifi),
              child: const Text('Tambah wall pertama'),
            ),
          ],
        ),
      ),
    );
  }
}
