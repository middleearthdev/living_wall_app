import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/controllers/onboarding_controller.dart';
import '../../../application/providers/app_providers.dart';
import '../../../application/providers/room_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/add_wall_context.dart';
import '../../../data/models/room.dart';
import '../../routing/routes.dart';
import '../../widgets/add_wall_chrome.dart';
import '../../widgets/onboarding_scaffold.dart';

/// S04 — final step. Confirm name, pick or create a room, commit.
///
/// First-launch run hits this with zero rooms: we hide the picker and just
/// show the "new room" field. Once the user has rooms, the same screen is
/// reused from the Add Wall flow with the picker visible.
///
/// The [payload] carries both the wall picked at Discovery and the validated
/// grid dims from QR scan — submit feeds both into the controller so the
/// Wall record + WLED 2D matrix config land in one atomic operation.
class NamePlaceScreen extends ConsumerStatefulWidget {
  const NamePlaceScreen({super.key, required this.payload, this.addContext});

  final OnboardingPayload payload;

  /// When non-null the room is locked — picker is hidden and the wall lands
  /// in the configured room. Success navigation also lands back on that
  /// room instead of bouncing through the dashboard.
  final AddWallContext? addContext;

  @override
  ConsumerState<NamePlaceScreen> createState() => _NamePlaceScreenState();
}

class _NamePlaceScreenState extends ConsumerState<NamePlaceScreen> {
  late final TextEditingController _wallNameCtrl;
  late final TextEditingController _newRoomCtrl;
  String? _selectedRoomId;
  bool _creatingNewRoom = true;

  Future<List<Room>>? _roomsFuture;

  @override
  void initState() {
    super.initState();
    _wallNameCtrl = TextEditingController(text: widget.payload.discovered.name);
    _newRoomCtrl = TextEditingController(text: 'Ruang Tamu');
    _roomsFuture = _loadRooms();
  }

  static String _errorMessage(Object? error) {
    if (error == null) return '';
    final s = error.toString();
    // Exception.toString() prepends "Exception: " — strip it for display.
    if (s.startsWith('Exception: ')) return s.substring('Exception: '.length);
    return s;
  }

  Future<List<Room>> _loadRooms() async {
    final homes = ref.read(homeRepositoryProvider);
    // Don't call ensureDefaultHome here — creating the home before the user
    // commits would leave an orphan if they back out.
    final home = await homes.findDefaultHome();
    if (home == null) return const [];
    return homes.roomsForHome(home.id);
  }

  @override
  void dispose() {
    _wallNameCtrl.dispose();
    _newRoomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final submit = ref.watch(onboardingSubmitControllerProvider);
    final ctx = widget.addContext;
    final lockedRoom = ctx == null ? null : ref.watch(roomByIdProvider(ctx.roomId));

    // After commit: onboarding bounces to dashboard; add-wall lands back on
    // the room the user came from.
    ref.listen(onboardingSubmitControllerProvider, (prev, next) {
      next.whenData((wall) {
        if (wall != null && mounted) {
          context.go(
            ctx == null ? Routes.dashboard : Routes.dashboardRoom(ctx.roomId),
          );
        }
      });
    });

    return OnboardingScaffold(
      stepLabel: ctx == null ? 'LANGKAH 4 / 4' : null,
      topBar: ctx == null
          ? null
          : AddWallTopBar(
              onConfirmedClose: () =>
                  context.go(Routes.dashboardRoom(ctx.roomId)),
            ),
      contextBanner: ctx == null
          ? null
          : AddWallContextBanner(roomName: lockedRoom?.name ?? 'Ruangan'),
      title: 'Beri nama wall',
      subtitle: ctx == null
          ? 'Nama ini muncul di dashboard. Pilih ruangan supaya wall ikut sinkron dengan panel lain di ruangan yang sama.'
          : 'Nama yang mudah kamu kenali. Wall langsung masuk ke ruangan yang sudah dipilih.',
      body: FutureBuilder<List<Room>>(
        future: _roomsFuture,
        builder: (context, snap) {
          final rooms = snap.data ?? const <Room>[];
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(text: 'Nama wall'),
                const SizedBox(height: 8),
                _Field(controller: _wallNameCtrl, hint: 'mis. Wall Sofa'),
                const SizedBox(height: 24),
                _FieldLabel(text: 'Ruangan'),
                const SizedBox(height: 8),
                if (ctx != null) ...[
                  _LockedRoomChip(name: lockedRoom?.name ?? 'Ruangan'),
                  const SizedBox(height: 12),
                ] else if (rooms.isNotEmpty) ...[
                  for (final room in rooms)
                    _RoomTile(
                      room: room,
                      selected: !_creatingNewRoom && _selectedRoomId == room.id,
                      onTap: () => setState(() {
                        _creatingNewRoom = false;
                        _selectedRoomId = room.id;
                      }),
                    ),
                  const SizedBox(height: 8),
                  _NewRoomTile(
                    selected: _creatingNewRoom,
                    onTap: () => setState(() {
                      _creatingNewRoom = true;
                      _selectedRoomId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                if (ctx == null && _creatingNewRoom) ...[
                  _Field(controller: _newRoomCtrl, hint: 'Nama ruangan baru'),
                ],
                if (submit.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage(submit.error),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ext.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ext.surface3),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: ext.textDim),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.payload.discovered.ipAddress} · ${widget.payload.discovered.deviceId}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ext.textDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      primaryAction: PrimaryButton(
        label: 'Selesai',
        loading: submit.isLoading,
        onPressed: () {
          final name = _wallNameCtrl.text.trim();
          if (name.isEmpty) return;
          // Add-wall mode: room is locked by ctx.roomId — skip picker fields.
          if (ctx != null) {
            ref
                .read(onboardingSubmitControllerProvider.notifier)
                .submit(
                  payload: widget.payload,
                  wallName: name,
                  roomId: ctx.roomId,
                );
            return;
          }
          if (_creatingNewRoom && _newRoomCtrl.text.trim().isEmpty) return;
          ref
              .read(onboardingSubmitControllerProvider.notifier)
              .submit(
                payload: widget.payload,
                wallName: name,
                roomId: _creatingNewRoom ? null : _selectedRoomId,
                newRoomName: _creatingNewRoom ? _newRoomCtrl.text : null,
              );
        },
      ),
    );
  }
}

class _LockedRoomChip extends StatelessWidget {
  const _LockedRoomChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ext.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext.accentLight.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.home_outlined, size: 16, color: ext.accentLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: ext.accentLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.lock_outline, size: 14, color: ext.accentLight),
          const SizedBox(width: 4),
          Text(
            'terkunci',
            style: TextStyle(color: ext.accentLight, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(color: ext.textDim),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return TextField(
      controller: controller,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: ext.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.surface3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.surface3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.accent),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.selected,
    required this.onTap,
  });

  final Room room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: ext.surface2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? ext.accent : ext.surface3,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: Text(room.name)),
                if (selected) Icon(Icons.check, color: ext.accent, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewRoomTile extends StatelessWidget {
  const _NewRoomTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return Material(
      color: ext.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? ext.accent : ext.surface3,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add, color: ext.accent, size: 18),
              const SizedBox(width: 8),
              const Text('Buat ruangan baru'),
            ],
          ),
        ),
      ),
    );
  }
}
