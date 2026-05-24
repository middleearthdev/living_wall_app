import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/controllers/room_controller.dart';
import '../../application/providers/scene_providers.dart';
import '../../application/providers/wall_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/scene_palette.dart';
import '../../core/utils/brightness_curve.dart';
import '../../data/models/room.dart';
import '../../data/models/scene.dart';
import '../routing/routes.dart';

/// Dashboard's primary surface. Renders one room with mini-controls that
/// cover the daily 80% — toggle, three quick scenes, brightness — so the
/// user rarely needs to drill into the wall control screen.
class RoomCard extends ConsumerWidget {
  const RoomCard({super.key, required this.room});

  final Room room;

  /// Three curated quick scenes shown on every room card. We pick one from
  /// each of the everyday categories (Tenang/Sosial/Fokus) so the strip
  /// covers the most common moods without needing per-room configuration.
  /// Per-room last-used quick scenes are a Phase 2 nicety.
  static const _quickSceneIds = ['ocean', 'candle', 'focus'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;

    final vitals = ref.watch(roomVitalsProvider(room.id));
    final activeScene = ref.watch(activeSceneForRoomProvider(room.id));
    final catalog = ref.watch(sceneCatalogSyncProvider);

    final controller = ref.read(roomControllerProvider);
    final isOff = !vitals.anyOn || vitals.wallCount == 0;
    final isEmpty = vitals.wallCount == 0;

    final quickScenes = [
      for (final id in _quickSceneIds)
        catalog.firstWhere(
          (s) => s.id == id,
          orElse: () =>
              catalog.isNotEmpty ? catalog.first : _placeholderScene(id),
        ),
    ];

    final metaLine = _metaLine(
      wallCount: vitals.wallCount,
      activeName: activeScene?.name,
      isOff: isOff,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          // Background gradient placeholder for the scene thumbnail (week 8).
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                gradient: ScenePalette.gradient(activeScene?.id),
              ),
              child: ColorFiltered(
                colorFilter: isOff
                    ? const ColorFilter.matrix(_grayscaleMatrix)
                    : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x40000000), Color(0xC7000000)],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openRoom(context, ref, vitals.wallCount),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ext.surface3.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                metaLine,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _RoomToggle(
                          on: vitals.anyOn,
                          enabled: !isEmpty,
                          onChanged: (next) =>
                              controller.setOnOff(room.id, next),
                        ),
                      ],
                    ),
                    if (!isEmpty) ...[
                      const SizedBox(height: 14),
                      _MiniScenesStrip(
                        scenes: quickScenes,
                        activeId: activeScene?.id,
                        onPick: (scene) =>
                            controller.applyScene(room.id, scene),
                        onMore: () => _openScenes(context, ref),
                      ),
                      const SizedBox(height: 12),
                      _RoomBrightnessSlider(
                        roomId: room.id,
                        brightness: vitals.brightness,
                        isOn: vitals.anyOn,
                        enabled: vitals.allKnown,
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _tapHintFor(vitals.wallCount),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada wall · tap untuk tambah',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Per design spec: 1-wall rooms skip the room screen and tap straight
  /// into wall control (jalur A). 2+ walls go through room screen (jalur B)
  /// so the user can drill into a specific wall or apply a mood to all.
  void _openRoom(BuildContext context, WidgetRef ref, int wallCount) {
    if (wallCount == 1) {
      final first = ref.read(firstWallForRoomProvider(room.id)).valueOrNull;
      if (first != null) {
        context.push(Routes.dashboardWall(room.id, first.id));
        return;
      }
    }
    context.push(Routes.dashboardRoom(room.id), extra: room);
  }

  /// "···" on the mini scenes strip opens the scene gallery. Week 5 only
  /// has a per-wall gallery; for 2+-wall rooms we route to the first wall's
  /// gallery as a stop-gap until the room-wide gallery lands in week 6.
  void _openScenes(BuildContext context, WidgetRef ref) {
    final first = ref.read(firstWallForRoomProvider(room.id)).valueOrNull;
    if (first != null) {
      context.push(Routes.dashboardScenes(room.id, first.id));
      return;
    }
    context.push(Routes.dashboardRoom(room.id), extra: room);
  }

  static const _grayscaleMatrix = <double>[
    0.3, 0.59, 0.11, 0, 0,
    0.3, 0.59, 0.11, 0, 0,
    0.3, 0.59, 0.11, 0, 0,
    0, 0, 0, 0.55, 0,
  ];

  static String _metaLine({
    required int wallCount,
    required String? activeName,
    required bool isOff,
  }) {
    if (wallCount == 0) return 'belum ada wall';
    final base = wallCount == 1 ? '1 wall' : '$wallCount wall · tersinkron';
    if (isOff) return '$base · mati';
    if (activeName != null) return '$base · $activeName';
    return base;
  }

  static String _tapHintFor(int wallCount) {
    if (wallCount > 1) return 'Tap kartu untuk lihat $wallCount wall & kontrol grup';
    return 'Tap kartu untuk kontrol penuh';
  }

  Scene _placeholderScene(String id) => Scene(
    id: id,
    name: id,
    category: SceneCategory.tenang,
    compatibility: SceneCompatibility.universal,
    description: '',
    useCase: '',
    thumbnailAsset: '',
    defaultBri: 128,
    fx: 0,
    pal: 0,
  );
}

class _RoomToggle extends StatelessWidget {
  const _RoomToggle({
    required this.on,
    required this.enabled,
    required this.onChanged,
  });

  final bool on;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? () => onChanged(!on) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 24,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: on
                ? ext.accent.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: on
                  ? ext.accentLight.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on
                    ? ext.accentLight
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniScenesStrip extends StatelessWidget {
  const _MiniScenesStrip({
    required this.scenes,
    required this.activeId,
    required this.onPick,
    required this.onMore,
  });

  final List<Scene> scenes;
  final String? activeId;
  final ValueChanged<Scene> onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in scenes) ...[
          _MiniSceneSwatch(
            scene: s,
            selected: s.id == activeId,
            onTap: () => onPick(s),
          ),
          const SizedBox(width: 6),
        ],
        _MiniSceneMore(onTap: onMore),
      ],
    );
  }
}

class _MiniSceneSwatch extends StatelessWidget {
  const _MiniSceneSwatch({
    required this.scene,
    required this.selected,
    required this.onTap,
  });

  final Scene scene;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: ScenePalette.gradient(scene.id),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

class _MiniSceneMore extends StatelessWidget {
  const _MiniSceneMore({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Text(
            '···',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Room-wide brightness slider. Mirrors the wall control screen's slider
/// — perceptual gamma curve, echo suppression, snap-to-off with haptics
/// — but fans out to every wall in the room via [RoomController].
class _RoomBrightnessSlider extends ConsumerStatefulWidget {
  const _RoomBrightnessSlider({
    required this.roomId,
    required this.brightness,
    required this.isOn,
    required this.enabled,
  });

  final String roomId;
  final int brightness;
  final bool isOn;
  final bool enabled;

  @override
  ConsumerState<_RoomBrightnessSlider> createState() =>
      _RoomBrightnessSliderState();
}

class _RoomBrightnessSliderState extends ConsumerState<_RoomBrightnessSlider> {
  double? _draggingValue;
  double? _lastSent;
  Timer? _suppressTimer;

  static const _suppressWindow = Duration(milliseconds: 400);
  static const _offDeadzoneEnter = 8.0;
  static const _offDeadzoneExit = 16.0;
  static const _milestoneStep = 64.0;

  bool _draggingOff = false;
  int _lastMilestone = -1;
  bool? _lastOnOffSent;

  double get _displayValue {
    if (_draggingValue != null) return _draggingValue!;
    if (_lastSent != null) return _lastSent!;
    return BrightnessCurve.deviceToSlider(widget.brightness).clamp(0, 255);
  }

  @override
  void dispose() {
    _suppressTimer?.cancel();
    super.dispose();
  }

  void _maybeSetOnOff(bool desired) {
    if (_lastOnOffSent == desired) return;
    _lastOnOffSent = desired;
    ref.read(roomControllerProvider).setOnOff(widget.roomId, desired);
  }

  void _onChangeStart(double v) {
    HapticFeedback.selectionClick();
    _draggingOff = v < _offDeadzoneEnter || !widget.isOn;
    _lastMilestone = (v / _milestoneStep).floor();
    _lastOnOffSent = null;
  }

  void _onChanged(double v) {
    final inOff = _draggingOff
        ? v < _offDeadzoneExit
        : v < _offDeadzoneEnter;
    final snapped = inOff ? 0.0 : v;

    if (inOff && !_draggingOff) {
      HapticFeedback.mediumImpact();
      _draggingOff = true;
      _maybeSetOnOff(false);
    } else if (!inOff && _draggingOff) {
      HapticFeedback.selectionClick();
      _draggingOff = false;
      _maybeSetOnOff(true);
    } else if (!inOff) {
      final milestone = (snapped / _milestoneStep).floor();
      if (milestone != _lastMilestone) {
        HapticFeedback.selectionClick();
        _lastMilestone = milestone;
      }
    }

    setState(() => _draggingValue = snapped);
    ref
        .read(roomControllerProvider)
        .setBrightness(widget.roomId, BrightnessCurve.sliderToDevice(snapped));
  }

  void _onChangeEnd(double v) {
    final snapped = (_draggingOff || v < _offDeadzoneEnter) ? 0.0 : v;
    HapticFeedback.lightImpact();
    setState(() {
      _draggingValue = null;
      _lastSent = snapped;
    });
    _suppressTimer?.cancel();
    _suppressTimer = Timer(_suppressWindow, () {
      if (mounted) setState(() => _lastSent = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = _displayValue;
    final percent = (value / 255 * 100).round();

    return Opacity(
      opacity: widget.isOn ? 1 : 0.5,
      child: Row(
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            size: 14,
            color: Colors.white.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.08),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: 255,
                onChangeStart: widget.enabled ? _onChangeStart : null,
                onChanged: widget.enabled ? _onChanged : null,
                onChangeEnd: widget.enabled ? _onChangeEnd : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              '$percent%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
