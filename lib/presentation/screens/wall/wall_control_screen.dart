import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/controllers/wall_controller.dart';
import '../../../application/providers/scene_providers.dart';
import '../../../application/providers/wall_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/scene_palette.dart';
import '../../../data/models/scene.dart';
import '../../routing/routes.dart';
import '../../widgets/wall_settings_sheet.dart';

/// S06 — single-wall control. Hero shows what's playing, the quick-scene
/// strip handles the 80% case (tap = apply defaults), and "Lihat semua →"
/// opens the full gallery for browsing with parameter overrides.
class WallControlScreen extends ConsumerWidget {
  const WallControlScreen({
    super.key,
    required this.roomId,
    required this.wallId,
  });

  final String roomId;
  final String wallId;

  /// Six fixed quick-scene favorites, two rows of three. Mix of categories
  /// so the strip covers everyday moods without per-wall configuration.
  /// Per-wall last-used quick scenes are a Phase 2 nicety.
  static const _quickSceneIds = [
    'ocean',
    'focus',
    'candle',
    'sunset',
    'forest',
    'rain',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;

    final wallAsync = ref.watch(wallByIdProvider(wallId));
    final state = ref.watch(wallStateProvider(wallId)).valueOrNull;
    final activeScene = ref.watch(activeSceneForWallProvider(wallId));
    final catalog = ref.watch(sceneCatalogSyncProvider);
    final controller = ref.read(wallControllerProvider);
    final connectivity =
        ref.watch(wallConnectivityProvider(wallId)).valueOrNull ??
        WallConnectivity.connecting;

    final wallName = wallAsync.valueOrNull?.name ?? 'Wall';

    final quickScenes = [
      for (final id in _quickSceneIds)
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
              _TopBar(
                title: wallName,
                onBack: () => context.pop(),
                onMore: () => _openSettings(context, ref, wallId),
              ),
              const SizedBox(height: 8),
              _Hero(
                activeScene: activeScene,
                isOn: state?.on ?? false,
                brightness: state?.brightness ?? 0,
                connectivity: connectivity,
                hasSeenState: state != null,
              ),
              const SizedBox(height: 14),
              _SectionHeader(
                title: 'Quick Scenes',
                trailing: 'Lihat semua →',
                trailingColor: ext.accentLight,
                onTrailingTap: () => context.push(
                  Routes.dashboardScenes(roomId, wallId),
                ),
              ),
              const SizedBox(height: 10),
              _QuickScenesGrid(
                scenes: quickScenes,
                activeId: activeScene?.id,
                onPick: (scene) => controller.applyScene(wallId, scene),
              ),
              const Spacer(),
              _BrightnessSlider(
                wallId: wallId,
                brightness: state?.brightness ?? 0,
                enabled: (state?.on ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onMore,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
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
        IconButton(
          onPressed: onMore,
          padding: EdgeInsets.zero,
          icon: Icon(Icons.more_horiz, size: 22, color: ext.textDim),
        ),
      ],
    );
  }
}

Future<void> _openSettings(
  BuildContext context,
  WidgetRef ref,
  String wallId,
) async {
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WallSettingsSheet(wallId: wallId),
  );
  // Wall was deleted from inside the sheet — bail out of this screen too.
  if (deleted == true && context.mounted) {
    context.pop();
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.activeScene,
    required this.isOn,
    required this.brightness,
    required this.connectivity,
    required this.hasSeenState,
  });

  final Scene? activeScene;
  final bool isOn;
  final int brightness;
  final WallConnectivity connectivity;

  /// True if we've received at least one state frame. Distinguishes the
  /// "first connect, no data yet" case from "wall went offline after we
  /// had data" — the latter should keep showing the last-known scene
  /// rather than reverting to the connecting copy.
  final bool hasSeenState;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    final percent = (brightness / 255 * 100).round();

    final String status;
    if (connectivity == WallConnectivity.offline) {
      status = 'Tidak terjangkau';
    } else if (!hasSeenState && connectivity == WallConnectivity.connecting) {
      status = 'Menyambungkan…';
    } else if (!isOn) {
      status = 'Mati';
    } else {
      status = 'Aktif sekarang · $percent%';
    }

    return Container(
      height: 112,
      decoration: BoxDecoration(
        gradient: ScenePalette.gradient(activeScene?.id),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.surface3.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x30000000), Color(0xA0000000)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeScene?.name ?? 'Custom',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.trailingColor,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final Color? trailingColor;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
        ),
        const Spacer(),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: trailingColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickScenesGrid extends StatelessWidget {
  const _QuickScenesGrid({
    required this.scenes,
    required this.activeId,
    required this.onPick,
  });

  final List<Scene> scenes;
  final String? activeId;
  final ValueChanged<Scene> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 10,
        childAspectRatio: 0.86,
      ),
      itemCount: scenes.length,
      itemBuilder: (_, i) => _QuickSceneTile(
        scene: scenes[i],
        selected: scenes[i].id == activeId,
        onTap: () => onPick(scenes[i]),
      ),
    );
  }
}

class _QuickSceneTile extends StatelessWidget {
  const _QuickSceneTile({
    required this.scene,
    required this.selected,
    required this.onTap,
  });

  final Scene scene;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                gradient: ScenePalette.gradient(scene.id),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selected
                      ? ext.accentLight
                      : ext.surface3.withValues(alpha: 0.6),
                  width: selected ? 1.8 : 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scene.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: selected ? null : ext.textDim,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Brightness slider with optimistic local state while dragging. Mirrors
/// the dashboard mini-slider but full width and labeled.
class _BrightnessSlider extends ConsumerStatefulWidget {
  const _BrightnessSlider({
    required this.wallId,
    required this.brightness,
    required this.enabled,
  });

  final String wallId;
  final int brightness;
  final bool enabled;

  @override
  ConsumerState<_BrightnessSlider> createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends ConsumerState<_BrightnessSlider> {
  double? _draggingValue;

  double get _displayValue =>
      _draggingValue ?? widget.brightness.toDouble().clamp(0, 255);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final percent = (_displayValue / 255 * 100).round();

    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Brightness',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: ext.textDim,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: ext.accentLight,
              inactiveTrackColor: ext.surface3,
              thumbColor: Colors.white,
              overlayColor: ext.accent.withValues(alpha: 0.18),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _displayValue,
              min: 0,
              max: 255,
              onChanged: widget.enabled
                  ? (v) {
                      setState(() => _draggingValue = v);
                      ref
                          .read(wallControllerProvider)
                          .setBrightness(widget.wallId, v.round());
                    }
                  : null,
              onChangeEnd: (_) => setState(() => _draggingValue = null),
            ),
          ),
        ],
      ),
    );
  }
}
