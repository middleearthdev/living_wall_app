import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/aspect_class.dart';
import '../../data/models/scene.dart';
import 'app_providers.dart';
import 'wall_providers.dart';

/// Full 18-scene catalog. Cached forever because the catalog is bundled
/// data — re-reading the asset on every screen would be wasteful.
final sceneCatalogProvider = FutureProvider<List<Scene>>((ref) {
  return ref.watch(sceneRepositoryProvider).loadAll();
});

/// Synchronous view of the loaded catalog. Returns an empty list while the
/// catalog is still loading, so widgets can render a skeleton without an
/// AsyncValue.when wrapper. Callers that need to wait should watch
/// [sceneCatalogProvider] directly.
final sceneCatalogSyncProvider = Provider<List<Scene>>((ref) {
  return ref.watch(sceneCatalogProvider).valueOrNull ?? const <Scene>[];
});

final sceneByIdProvider = FutureProvider.family<Scene?, String>((ref, id) {
  return ref.watch(sceneRepositoryProvider).findById(id);
});

/// Scene paired with whether it renders optimally at a specific wall.
/// [isOptimal] = false drives the "kurang optimal" badge in the gallery.
class AspectSortedScene {
  const AspectSortedScene({required this.scene, required this.isOptimal});

  final Scene scene;
  final bool isOptimal;
}

/// Curated 6-scene quick-pick lists per aspect class for Wall Control.
/// Each list mixes a couple of orientation-matching scenes with universal
/// staples so the wall's quick strip covers everyday moods (cozy / focus
/// / dim social) without all 6 collapsing into the same category.
const Map<AspectClass, List<String>> _wallQuickSceneIdsByAspect = {
  AspectClass.landscape: [
    'ocean', // landscape — water horizon
    'sunset', // landscape — sky gradient
    'focus', // universal — cool functional
    'candle', // universal — warm cozy
    'forest', // universal — green relaxed
    'golden', // landscape — warm social
  ],
  AspectClass.portrait: [
    'rain', // portrait — vertical drops
    'dawn', // portrait — vertical sunset
    'focus', // universal — cool functional
    'candle', // universal — warm cozy
    'forest', // universal — green relaxed
    'dinner', // portrait — warm vertical glow
  ],
  AspectClass.square: [
    'focus', // universal — cool functional
    'candle', // universal — warm cozy
    'breathe', // universal — soft pulse
    'forest', // universal — green relaxed
    'sakura', // universal — pink mood
    'twinkle', // universal — sparkle
  ],
};

/// Quick scenes for the Wall Control strip — 6 scenes curated for the
/// wall's aspect class. Falls back to the square list (all-universal) when
/// the wall isn't loaded yet, so the UI doesn't flash with the wrong set.
final wallQuickScenesProvider = Provider.family<List<Scene>, String>((
  ref,
  wallId,
) {
  final catalog = ref.watch(sceneCatalogSyncProvider);
  if (catalog.isEmpty) return const <Scene>[];
  final wall = ref.watch(wallByIdProvider(wallId)).valueOrNull;
  final aspect = wall?.aspectClass ?? AspectClass.square;
  final ids = _wallQuickSceneIdsByAspect[aspect]!;
  return [
    for (final id in ids)
      if (catalog.any((s) => s.id == id)) catalog.firstWhere((s) => s.id == id),
  ];
});

/// Catalog re-sorted for a specific wall's aspect class:
/// - matching-orientation scenes first
/// - universal scenes next
/// - mismatched scenes last (with [AspectSortedScene.isOptimal] = false)
///
/// Sort is stable within each priority bucket so the original spec ordering
/// (Tenang → Fokus → Sosial → Dinamis, then catalog order within category)
/// is preserved.
final sortedScenesForWallProvider =
    Provider.family<List<AspectSortedScene>, String>((ref, wallId) {
      final catalog = ref.watch(sceneCatalogSyncProvider);
      final wall = ref.watch(wallByIdProvider(wallId)).valueOrNull;
      if (catalog.isEmpty || wall == null) {
        return [
          for (final s in catalog) AspectSortedScene(scene: s, isOptimal: true),
        ];
      }
      final aspect = wall.aspectClass;
      final indexed = [
        for (var i = 0; i < catalog.length; i++) (catalog[i], i),
      ];
      indexed.sort((a, b) {
        final pa = sceneAspectPriority(a.$1.compatibility, aspect);
        final pb = sceneAspectPriority(b.$1.compatibility, aspect);
        if (pa != pb) return pa.compareTo(pb);
        return a.$2.compareTo(b.$2); // stable by original index
      });
      return [
        for (final (scene, _) in indexed)
          AspectSortedScene(
            scene: scene,
            isOptimal: sceneMatchesAspect(scene.compatibility, aspect),
          ),
      ];
    });
