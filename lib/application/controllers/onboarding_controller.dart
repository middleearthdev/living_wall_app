import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/aspect_class.dart';
import '../../data/models/room.dart';
import '../../data/models/wall.dart';
import '../../data/services/wled_client.dart';
import '../../presentation/routing/routes.dart';
import '../providers/app_providers.dart';

/// Final step of onboarding / add-wall: persist the wall and provision its
/// WLED 2D matrix + UDP sync. Exposes [AsyncValue] so the UI can show a
/// spinner + error states without raw try/catch inside the widget.
class OnboardingSubmitController extends AutoDisposeAsyncNotifier<Wall?> {
  @override
  Future<Wall?> build() async => null;

  /// Creates (or reuses) the default home, creates the room if it's new,
  /// inserts the wall (with grid dims from the QR payload), and writes the
  /// 2D matrix + UDP sync config to the WLED device in a single batched
  /// `/json/cfg` call.
  ///
  /// [roomId] non-null = adding to existing room. Null + [newRoomName] = new
  /// room. The WLED config write is best-effort: if it fails the wall is
  /// still persisted so the user can retry the provisioning step later from
  /// Wall Settings rather than redoing the whole flow.
  Future<void> submit({
    required OnboardingPayload payload,
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

      final provision = payload.provision;
      final discovered = payload.discovered;
      final wall = await walls.addWall(
        roomId: room.id,
        name: wallName.trim(),
        deviceId: discovered.deviceId,
        ipAddress: discovered.ipAddress,
        serialNumber: provision.serialNumber,
        gridWidth: provision.gridWidth,
        gridHeight: provision.gridHeight,
        lengthMm: provision.lengthMm,
        heightMm: provision.heightMm,
        // Derive from physical mm, not grid LEDs: vertical pitch (5cm) differs
        // from horizontal (1.67cm) so grid ratio != visual aspect ratio.
        aspectClass: aspectClassFor(provision.lengthMm, provision.heightMm),
      );

      // Best-effort: provision the WLED device with its 2D matrix layout and
      // join the room's UDP sync group. Failure here doesn't roll back the
      // DB insert — the user can retry via Wall Settings → "Konfigurasi
      // ulang", whereas losing the wall record would force them to redo the
      // whole onboarding flow.
      try {
        final client = WledClient(baseUrl: 'http://${discovered.ipAddress}');
        await client.configureMatrix(
          gridWidth: provision.gridWidth,
          gridHeight: provision.gridHeight,
        );
      } catch (_) {
        // Swallow — wall is persisted; user can re-issue config from
        // settings once they confirm the device is reachable.
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
