import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/discovered_wall.dart';
import '../../data/models/room.dart';
import '../../data/models/wall.dart';
import '../../data/services/wled_client.dart';
import '../providers/app_providers.dart';

/// Final step of onboarding: persist the wall and wire it into a room's UDP
/// sync group. Exposes [AsyncValue] so the UI can show a spinner + error
/// states without raw try/catch inside the widget.
class OnboardingSubmitController extends AutoDisposeAsyncNotifier<Wall?> {
  @override
  Future<Wall?> build() async => null;

  /// Creates (or reuses) the default home, creates the room if it's new,
  /// inserts the wall, and toggles UDP sync on the device.
  ///
  /// [roomId] non-null = adding to existing room. Null + [newRoomName] = new
  /// room. UDP sync failures don't roll back DB inserts — the user can retry
  /// the sync from the room screen later, but losing the wall record would
  /// force them to redo the whole flow.
  Future<void> submit({
    required DiscoveredWall discovered,
    required String wallName,
    String? roomId,
    String? newRoomName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final homes = ref.read(homeRepositoryProvider);
      final walls = ref.read(wallRepositoryProvider);

      final home = await homes.ensureDefaultHome();

      Room room;
      if (roomId != null) {
        final existing = await homes.roomsForHome(home.id);
        room = existing.firstWhere((r) => r.id == roomId);
      } else {
        final name = (newRoomName ?? '').trim();
        if (name.isEmpty) {
          throw ArgumentError('Room name required when creating a new room');
        }
        room = await homes.createRoom(homeId: home.id, name: name);
      }

      final wall = await walls.addWall(
        roomId: room.id,
        name: wallName.trim(),
        deviceId: discovered.deviceId,
        ipAddress: discovered.ipAddress,
      );

      // Best-effort: enable UDP sync so this wall is part of the room group.
      try {
        final client = WledClient(baseUrl: 'http://${discovered.ipAddress}');
        await client.setSyncEnabled(send: true, recv: true);
      } catch (_) {
        // Swallow — wall is persisted; user can re-enable from room screen.
      }

      // Invalidate the first-launch gate so the router moves to dashboard.
      ref.invalidate(hasAnyWallProvider);

      return wall;
    });
  }
}

final onboardingSubmitControllerProvider =
    AutoDisposeAsyncNotifierProvider<OnboardingSubmitController, Wall?>(
      OnboardingSubmitController.new,
    );
