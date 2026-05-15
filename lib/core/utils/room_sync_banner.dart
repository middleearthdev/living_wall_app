/// Drives the room screen's sync banner copy + visual treatment from
/// (wallCount, excludedCount). Extracted so the four-state decision is
/// unit-testable without spinning up the widget tree.
class RoomSyncBannerCopy {
  const RoomSyncBannerCopy(this.kind, this.message);
  final RoomSyncBannerKind kind;
  final String message;
}

enum RoomSyncBannerKind {
  /// Single-wall room — no group, no banner.
  hidden,

  /// Everyone in sync. Accent style.
  synced,

  /// Some walls excluded. Muted/neutral style.
  partiallyExcluded,

  /// Every wall excluded. Warning style — mood grid disabled.
  allExcluded,
}

RoomSyncBannerCopy roomSyncBanner({
  required int wallCount,
  required int excludedCount,
}) {
  if (wallCount < 2) return const RoomSyncBannerCopy(RoomSyncBannerKind.hidden, '');
  if (excludedCount == 0) {
    return RoomSyncBannerCopy(
      RoomSyncBannerKind.synced,
      '$wallCount wall di ruangan ini berubah bersamaan',
    );
  }
  if (excludedCount >= wallCount) {
    return const RoomSyncBannerCopy(
      RoomSyncBannerKind.allExcluded,
      'Semua wall dikecualikan — aktifkan minimal satu',
    );
  }
  return RoomSyncBannerCopy(
    RoomSyncBannerKind.partiallyExcluded,
    '$excludedCount dari $wallCount wall sedang dikecualikan',
  );
}
