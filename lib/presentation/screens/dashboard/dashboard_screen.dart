import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/room_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/greeting.dart';
import '../../../data/models/room.dart';
import '../../widgets/add_room_dialog.dart';
import '../../widgets/room_card.dart';

/// S05 — daily entry point. Greeting header, one card per room with
/// mini-controls embedded, and a single "+" affordance to add a room. The
/// design intentionally pushes 80% of daily actions onto each RoomCard so
/// users rarely need to drill deeper.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;

    final homeAsync = ref.watch(defaultHomeProvider);
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(
                greeting: greetingFor(DateTime.now()),
                homeName: homeAsync.valueOrNull?.name ?? 'Rumah',
                onAddRoom: () => _openAddRoom(context, ref),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: roomsAsync.when(
                  data: (rooms) => _RoomList(rooms: rooms),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'Gagal memuat ruangan: $e',
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

  Future<void> _openAddRoom(BuildContext context, WidgetRef ref) async {
    await showDialog<Room>(
      context: context,
      builder: (_) => const AddRoomDialog(),
    );
    // AddRoomDialog handles persistence + invalidation + navigation itself.
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.greeting,
    required this.homeName,
    required this.onAddRoom,
  });

  final String greeting;
  final String homeName;
  final VoidCallback onAddRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: ext.textDim,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                homeName,
                style: theme.textTheme.displaySmall?.copyWith(fontSize: 28),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _AddRoomButton(onTap: onAddRoom),
      ],
    );
  }
}

class _AddRoomButton extends StatelessWidget {
  const _AddRoomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return Material(
      color: ext.accent.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ext.accentLight.withValues(alpha: 0.5)),
          ),
          child: Icon(Icons.add, color: ext.accentLight, size: 20),
        ),
      ),
    );
  }
}

class _RoomList extends StatelessWidget {
  const _RoomList({required this.rooms});

  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) return const _EmptyRoomsHint();
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: rooms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => RoomCard(room: rooms[i]),
    );
  }
}

class _EmptyRoomsHint extends StatelessWidget {
  const _EmptyRoomsHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Belum ada ruangan',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap tombol + di atas untuk membuat ruangan dan menambahkan wall pertamanya.',
              style: theme.textTheme.bodyMedium?.copyWith(color: ext.textDim),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
