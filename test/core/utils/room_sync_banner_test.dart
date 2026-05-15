import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/core/utils/room_sync_banner.dart';

void main() {
  group('roomSyncBanner', () {
    test('hides for single-wall room — no group concept', () {
      final copy = roomSyncBanner(wallCount: 1, excludedCount: 0);
      expect(copy.kind, RoomSyncBannerKind.hidden);
    });

    test('hides for empty room', () {
      final copy = roomSyncBanner(wallCount: 0, excludedCount: 0);
      expect(copy.kind, RoomSyncBannerKind.hidden);
    });

    test('synced when nobody is excluded', () {
      final copy = roomSyncBanner(wallCount: 3, excludedCount: 0);
      expect(copy.kind, RoomSyncBannerKind.synced);
      expect(copy.message, contains('3 wall'));
      expect(copy.message, contains('berubah bersamaan'));
    });

    test('partial exclusion shows N of M', () {
      final copy = roomSyncBanner(wallCount: 4, excludedCount: 1);
      expect(copy.kind, RoomSyncBannerKind.partiallyExcluded);
      expect(copy.message, contains('1 dari 4'));
      expect(copy.message, contains('dikecualikan'));
    });

    test('all-excluded warns the user to re-include at least one', () {
      final copy = roomSyncBanner(wallCount: 2, excludedCount: 2);
      expect(copy.kind, RoomSyncBannerKind.allExcluded);
      expect(copy.message, contains('aktifkan minimal satu'));
    });

    test('excludedCount over wallCount still classifies as all-excluded', () {
      // Defensive — shouldn't normally happen but the function must not crash
      // or fall into the partial bucket if state gets inconsistent.
      final copy = roomSyncBanner(wallCount: 2, excludedCount: 5);
      expect(copy.kind, RoomSyncBannerKind.allExcluded);
    });
  });
}
