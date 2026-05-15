import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/scene_providers.dart';
import '../../../application/providers/wall_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/scene_palette.dart';
import '../../../data/models/scene.dart';
import '../../widgets/adjustment_bottom_sheet.dart';

/// S08 — full scene catalog browsing surface. Category chips filter the
/// per-category sections below; tapping a scene card opens the adjustment
/// sheet (S09) rather than applying immediately — the gallery is for
/// browsing with intent to tune, the quick-scene strip is for instant
/// apply.
class SceneGalleryScreen extends ConsumerStatefulWidget {
  const SceneGalleryScreen({
    super.key,
    required this.roomId,
    required this.wallId,
  });

  final String roomId;
  final String wallId;

  @override
  ConsumerState<SceneGalleryScreen> createState() =>
      _SceneGalleryScreenState();
}

class _SceneGalleryScreenState extends ConsumerState<SceneGalleryScreen> {
  SceneCategory? _filter; // null == "Semua"

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final catalogAsync = ref.watch(sceneCatalogProvider);
    final activeScene = ref.watch(activeSceneForWallProvider(widget.wallId));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(title: 'Pilih Scene', onBack: () => context.pop()),
              const SizedBox(height: 4),
              _CategoryChips(
                selected: _filter,
                onChanged: (cat) => setState(() => _filter = cat),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: catalogAsync.when(
                  data: (catalog) => _SceneSections(
                    catalog: catalog,
                    filter: _filter,
                    activeId: activeScene?.id,
                    onTap: (scene) => _openAdjustmentSheet(scene),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'Gagal memuat scene: $e',
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

  Future<void> _openAdjustmentSheet(Scene scene) async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdjustmentBottomSheet(
        scene: scene,
        wallId: widget.wallId,
      ),
    );
    // If the user applied, bounce back to the wall control screen so they
    // can see the new hero/state without an extra tap.
    if (applied == true && mounted) {
      context.pop();
    }
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
        Text(title, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onChanged});

  final SceneCategory? selected;
  final ValueChanged<SceneCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'Semua',
            isSelected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'Tenang',
            isSelected: selected == SceneCategory.tenang,
            onTap: () => onChanged(SceneCategory.tenang),
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'Fokus',
            isSelected: selected == SceneCategory.fokus,
            onTap: () => onChanged(SceneCategory.fokus),
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'Sosial',
            isSelected: selected == SceneCategory.sosial,
            onTap: () => onChanged(SceneCategory.sosial),
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'Dinamis',
            isSelected: selected == SceneCategory.dinamis,
            onTap: () => onChanged(SceneCategory.dinamis),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? ext.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? ext.accentLight.withValues(alpha: 0.6)
                : ext.surface3,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? ext.accentLight : ext.textDim,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Renders per-category sections in spec order (Tenang → Fokus → Sosial →
/// Dinamis). Filter "Semua" shows all four; specific filter shows just one.
/// Empty sections are silently dropped — per spec, no zero-state headers.
class _SceneSections extends StatelessWidget {
  const _SceneSections({
    required this.catalog,
    required this.filter,
    required this.activeId,
    required this.onTap,
  });

  static const _categoryOrder = [
    (SceneCategory.tenang, 'Tenang'),
    (SceneCategory.fokus, 'Fokus'),
    (SceneCategory.sosial, 'Sosial'),
    (SceneCategory.dinamis, 'Dinamis'),
  ];

  final List<Scene> catalog;
  final SceneCategory? filter;
  final String? activeId;
  final ValueChanged<Scene> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;

    final sections = <Widget>[];
    for (final (cat, label) in _categoryOrder) {
      if (filter != null && filter != cat) continue;
      final scenes = catalog.where((s) => s.category == cat).toList();
      if (scenes.isEmpty) continue;
      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                '${scenes.length} scene',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ext.textFaint,
                ),
              ),
            ],
          ),
        ),
      );
      sections.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.45,
          ),
          itemCount: scenes.length,
          itemBuilder: (_, i) => _SceneCard(
            scene: scenes[i],
            isActive: scenes[i].id == activeId,
            onTap: () => onTap(scenes[i]),
          ),
        ),
      );
      sections.add(const SizedBox(height: 14));
    }

    if (sections.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada scene di kategori ini.',
          style: theme.textTheme.bodyMedium?.copyWith(color: ext.textDim),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: sections,
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.scene,
    required this.isActive,
    required this.onTap,
  });

  final Scene scene;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                gradient: ScenePalette.gradient(scene.id),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isActive
                      ? ext.accentLight
                      : ext.surface3.withValues(alpha: 0.6),
                  width: isActive ? 1.8 : 1,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB0000000)],
                ),
              ),
            ),
          ),
          if (isActive)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: ext.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Aktif',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  scene.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scene.description,
                  maxLines: 2,
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
}
