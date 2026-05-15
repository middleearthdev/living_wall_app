import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/home_repository.dart';
import '../../data/repositories/scene_repository.dart';
import '../../data/repositories/wall_repository.dart';
import '../../data/services/discovery_service.dart';
import '../../data/services/wifi_service.dart';

/// App-wide singletons. Database is a real resource — close it on dispose so
/// hot-restart in development doesn't leak connections.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(appDatabaseProvider)),
);

final wallRepositoryProvider = Provider<WallRepository>(
  (ref) => WallRepository(ref.watch(appDatabaseProvider)),
);

/// Single shared catalog cache. Phase 1 catalog is static, so one instance
/// for the whole app lifetime is correct.
final sceneRepositoryProvider = Provider<SceneRepository>(
  (ref) => SceneRepository(),
);

final wifiServiceProvider = Provider<WifiService>((ref) => WifiService());

final discoveryServiceProvider = Provider<DiscoveryService>(
  (ref) => DiscoveryService(),
);

/// First-launch gate. Router watches this to choose onboarding vs dashboard.
final hasAnyWallProvider = FutureProvider<bool>((ref) async {
  return ref.watch(wallRepositoryProvider).hasAnyWall();
});
