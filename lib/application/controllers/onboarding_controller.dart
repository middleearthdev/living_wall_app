import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/aspect_class.dart';
import '../../data/models/room.dart';
import '../../data/models/wall.dart';
import '../../data/services/wled_client.dart';
import '../../presentation/routing/routes.dart';
import '../providers/app_providers.dart';
import '../providers/room_providers.dart';
import '../providers/wall_providers.dart';

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
      final Wall wall;
      try {
        wall = await walls.addWall(
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
      } catch (e) {
        throw _friendlyInsertError(e);
      }

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

      // Invalidate providers that depend on the wall list for this room so
      // the dashboard card and room screen reflect the new wall immediately.
      ref.invalidate(hasAnyWallProvider);
      ref.invalidate(wallsForRoomProvider(room.id));
      ref.invalidate(registeredByDeviceIdProvider);

      return wall;
    });
  }
}

final onboardingSubmitControllerProvider =
    AutoDisposeAsyncNotifierProvider<OnboardingSubmitController, Wall?>(
      OnboardingSubmitController.new,
    );

/// Converts a raw DB unique-constraint exception into a user-facing message.
/// SQLite surfaces these as "UNIQUE constraint failed: walls.column_name".
Exception _friendlyInsertError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('unique constraint failed')) {
    if (s.contains('device_id')) {
      return Exception(
        'Perangkat WLED ini sudah terdaftar. Setiap panel hanya bisa '
        'dipasangkan satu kali.',
      );
    }
    if (s.contains('serial_number')) {
      return Exception(
        'Nomor seri panel ini sudah terdaftar. Gunakan '
        '"Konfigurasi ulang" di Wall Settings jika panel diganti.',
      );
    }
    return Exception('Wall ini sudah terdaftar sebelumnya.');
  }
  return Exception('Gagal menyimpan wall. Coba lagi.');
}
