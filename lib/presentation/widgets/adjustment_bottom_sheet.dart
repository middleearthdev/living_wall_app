import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/controllers/room_controller.dart';
import '../../application/controllers/wall_controller.dart';
import '../../application/providers/room_providers.dart';
import '../../application/providers/wall_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/scene_palette.dart';
import '../../core/utils/speed_label.dart';
import '../../data/models/scene.dart';

/// S09 — modal sheet to fine-tune a scene before applying. Brightness is
/// always present; Speed only when the scene defines a default sx; Intensity
/// only when ix is defined. Dragging dismisses without applying — per spec,
/// "no silent changes" — only the Apply button commits.
///
/// Supply exactly one of [wallId] (single-wall context, e.g. from Wall
/// Control) or [roomId] (room context, e.g. from Room Screen "Lihat semua").
/// Room mode fans out via [RoomController]; wall mode uses [WallController].
class AdjustmentBottomSheet extends ConsumerStatefulWidget {
  const AdjustmentBottomSheet({
    super.key,
    required this.scene,
    this.wallId,
    this.roomId,
  }) : assert(
         wallId != null || roomId != null,
         'Provide wallId (wall mode) or roomId (room mode)',
       );

  final Scene scene;
  final String? wallId;
  final String? roomId;

  @override
  ConsumerState<AdjustmentBottomSheet> createState() =>
      _AdjustmentBottomSheetState();
}

class _AdjustmentBottomSheetState
    extends ConsumerState<AdjustmentBottomSheet> {
  late int _brightness;
  late int? _speed;
  late int? _intensity;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _brightness = widget.scene.defaultBri;
    _speed = widget.scene.defaultSx;
    _intensity = widget.scene.defaultIx;
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    // Capture context-derived values before any await so post-async use
    // doesn't trip the use_build_context_synchronously lint.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      final String targetName;
      if (widget.roomId != null) {
        final roomCtrl = ref.read(roomControllerProvider);
        targetName =
            ref.read(roomByIdProvider(widget.roomId!))?.name ?? 'Ruangan';
        await roomCtrl.applyScene(
          widget.roomId!,
          widget.scene,
          briOverride: _brightness,
          sxOverride: _speed,
          ixOverride: _intensity,
        );
      } else {
        final wallCtrl = ref.read(wallControllerProvider);
        targetName = await wallCtrl.nameOf(widget.wallId!);
        await wallCtrl.applyScene(
          widget.wallId!,
          widget.scene,
          briOverride: _brightness,
          sxOverride: _speed,
          ixOverride: _intensity,
        );
      }
      // S10 — applied toast.
      final percent = (_brightness / 255 * 100).round();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              '${widget.scene.name} diterapkan · $targetName · $percent%',
            ),
          ),
        );
      navigator.pop(true);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: errorColor,
            content: Text('Gagal menerapkan: $e'),
          ),
        );
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final targetName = widget.roomId != null
        ? (ref.watch(roomByIdProvider(widget.roomId!))?.name ?? 'Ruangan')
        : (ref.watch(wallByIdProvider(widget.wallId!)).valueOrNull?.name ??
            'Wall');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ext.surface2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: ext.surface3)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: ext.surface3,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SheetHero(scene: widget.scene),
            const SizedBox(height: 16),
            _BrightnessRow(
              value: _brightness,
              onChanged: (v) => setState(() => _brightness = v),
            ),
            if (widget.scene.defaultSx != null) ...[
              const SizedBox(height: 14),
              _SpeedRow(
                value: _speed ?? widget.scene.defaultSx!,
                onChanged: (v) => setState(() => _speed = v),
              ),
            ],
            if (widget.scene.defaultIx != null) ...[
              const SizedBox(height: 14),
              _IntensityRow(
                value: _intensity ?? widget.scene.defaultIx!,
                onChanged: (v) => setState(() => _intensity = v),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ext.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _applying ? null : _apply,
                child: _applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Terapkan ke $targetName',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHero extends StatelessWidget {
  const _SheetHero({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        gradient: ScenePalette.gradient(scene.id),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x90000000)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scene.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_categoryLabel(scene.category)} · ${scene.description}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(SceneCategory cat) {
    switch (cat) {
      case SceneCategory.tenang:
        return 'Tenang';
      case SceneCategory.fokus:
        return 'Fokus';
      case SceneCategory.sosial:
        return 'Sosial';
      case SceneCategory.dinamis:
        return 'Dinamis';
    }
  }
}

class _BrightnessRow extends StatelessWidget {
  const _BrightnessRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (value / 255 * 100).round();
    return _SliderRow(
      label: 'Brightness',
      trailing: '$percent%',
      value: value.toDouble(),
      onChanged: (v) => onChanged(v.round()),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SliderRow(
      label: 'Speed',
      trailing: speedLabelFor(value),
      value: value.toDouble(),
      onChanged: (v) => onChanged(v.round()),
    );
  }
}

class _IntensityRow extends StatelessWidget {
  const _IntensityRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (value / 255 * 100).round();
    return _SliderRow(
      label: 'Intensity',
      trailing: '$percent%',
      value: value.toDouble(),
      onChanged: (v) => onChanged(v.round()),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.trailing,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String trailing;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: ext.textDim),
            ),
            const Spacer(),
            Text(
              trailing,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            activeTrackColor: ext.accentLight,
            inactiveTrackColor: ext.surface3,
            thumbColor: Colors.white,
            overlayColor: ext.accent.withValues(alpha: 0.18),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(value: value, min: 0, max: 255, onChanged: onChanged),
        ),
      ],
    );
  }
}
