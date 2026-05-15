import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/scene.dart';
import 'app_providers.dart';

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
