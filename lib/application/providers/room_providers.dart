import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/home.dart';
import '../../data/models/room.dart';
import '../../data/models/wall.dart';
import 'app_providers.dart';

/// Phase 1 only ever has one home, but expose this through a provider so
/// downstream code doesn't bake in the single-home assumption — when
/// multi-home arrives in Phase 2, this provider becomes a family by homeId.
final defaultHomeProvider = FutureProvider<Home?>((ref) {
  return ref.watch(homeRepositoryProvider).findDefaultHome();
});

/// Rooms in the default home. Empty list when onboarding hasn't completed.
final roomsProvider = FutureProvider<List<Room>>((ref) async {
  final home = await ref.watch(defaultHomeProvider.future);
  if (home == null) return const <Room>[];
  return ref.watch(homeRepositoryProvider).roomsForHome(home.id);
});

final wallsForRoomProvider = FutureProvider.family<List<Wall>, String>((
  ref,
  roomId,
) {
  return ref.watch(wallRepositoryProvider).wallsInRoom(roomId);
});

