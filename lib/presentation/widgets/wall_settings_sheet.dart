import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/controllers/wall_controller.dart';
import '../../application/providers/wall_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/aspect_class.dart';
import '../../data/models/wall.dart';
import '../routing/routes.dart';

/// "···" menu on the wall control screen. Phase 1 actions are Rename and
/// Delete. Move-to-another-room is parked for Phase 2 — it needs UDP sync
/// reconfig that isn't worth the complexity until people ask for it.
///
/// Returns `true` from the sheet when the wall was deleted so the caller
/// can pop the wall control screen out of the back stack.
class WallSettingsSheet extends ConsumerStatefulWidget {
  const WallSettingsSheet({super.key, required this.wallId});

  final String wallId;

  @override
  ConsumerState<WallSettingsSheet> createState() => _WallSettingsSheetState();
}

class _WallSettingsSheetState extends ConsumerState<WallSettingsSheet> {
  bool _busy = false;

  Future<void> _rename(Wall wall) async {
    final controller = TextEditingController(text: wall.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ext = Theme.of(ctx).extension<LivingWallTheme>()!;
        return AlertDialog(
          backgroundColor: ext.surface2,
          title: const Text('Ganti nama wall'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            decoration: InputDecoration(
              filled: true,
              fillColor: ext.surface3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ext.surface3),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text('Batal', style: TextStyle(color: ext.textDim)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ext.accent,
                foregroundColor: Colors.black,
              ),
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (newName == null || newName.isEmpty || newName == wall.name) return;
    if (!mounted) return;
    setState(() => _busy = true);
    await ref.read(wallControllerProvider).rename(wall.id, newName);
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _reconfigure(Wall wall) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final ext = theme.extension<LivingWallTheme>()!;
        return AlertDialog(
          backgroundColor: ext.surface2,
          title: const Text('Konfigurasi ulang wall?'),
          content: Text(
            'Mengganti konfigurasi akan menulis ulang setup 2D matrix di '
            'wall — scene yang aktif akan reset ke default. Scan QR di '
            'label wall pada langkah berikutnya.',
            style: theme.textTheme.bodyMedium?.copyWith(color: ext.textDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Batal', style: TextStyle(color: ext.textDim)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ext.accent,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Lanjut scan QR'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!mounted) return;
    // Close the sheet first so the QR scan route renders as a clean
    // full-screen flow rather than stacking on top of a dismissed sheet.
    final router = GoRouter.of(context);
    Navigator.of(context).pop(false);
    router.push(Routes.reconfigureQr(wall.roomId, wall.id));
  }

  void _addAnotherWall(Wall wall) {
    // Closes the gap where a single-wall room can't be expanded: tapping
    // a 1-wall RoomCard on the Dashboard skips Room Screen and lands
    // straight on Wall Control (per design spec, daily-use shortcut),
    // which means _AddWallRow inside Room Screen is unreachable from
    // here. Surfacing the add-wall trigger inside Wall Settings keeps the
    // shortcut intact while still giving 1-wall rooms a path to grow.
    final router = GoRouter.of(context);
    Navigator.of(context).pop(false);
    router.push(Routes.addWallDiscovery(wall.roomId));
  }

  Future<void> _delete(Wall wall) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final ext = theme.extension<LivingWallTheme>()!;
        return AlertDialog(
          backgroundColor: ext.surface2,
          title: Text('Hapus ${wall.name}?'),
          content: Text(
            'Wall akan dilepas dari aplikasi. Perangkat WLED tetap menyala — kamu bisa menambahkannya kembali nanti.',
            style: theme.textTheme.bodyMedium?.copyWith(color: ext.textDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Batal', style: TextStyle(color: ext.textDim)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    await ref.read(wallControllerProvider).delete(wall.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    final wallAsync = ref.watch(wallByIdProvider(widget.wallId));

    return Container(
      decoration: BoxDecoration(
        color: ext.surface2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: ext.surface3)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: ext.surface3,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          wallAsync.when(
            data: (wall) {
              if (wall == null) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Wall tidak ditemukan.'),
                );
              }
              return Column(
                children: [
                  _SpecCard(wall: wall),
                  const SizedBox(height: 6),
                  _SettingsAction(
                    icon: Icons.edit_outlined,
                    label: 'Ganti nama',
                    onTap: _busy ? null : () => _rename(wall),
                  ),
                  _SettingsAction(
                    icon: Icons.qr_code_scanner_outlined,
                    label: 'Konfigurasi ulang',
                    onTap: _busy ? null : () => _reconfigure(wall),
                  ),
                  _SettingsAction(
                    icon: Icons.add_box_outlined,
                    label: 'Tambah wall di ruangan yang sama',
                    onTap: _busy ? null : () => _addAnotherWall(wall),
                  ),
                  _SettingsAction(
                    icon: Icons.delete_outline,
                    label: 'Hapus wall',
                    destructive: true,
                    onTap: _busy ? null : () => _delete(wall),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Gagal memuat wall: $e'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.wall});

  final Wall wall;

  String _aspectLabel(AspectClass c) => switch (c) {
    AspectClass.landscape => 'Landscape',
    AspectClass.portrait => 'Portrait',
    AspectClass.square => 'Square',
  };

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ext.surface3,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _SpecRow(label: 'Serial', value: wall.serialNumber),
          const SizedBox(height: 8),
          _SpecRow(
            label: 'Dimensi',
            value: '${wall.lengthMm} × ${wall.heightMm} mm',
          ),
          const SizedBox(height: 8),
          _SpecRow(
            label: 'Grid',
            value: '${wall.gridWidth} × ${wall.gridHeight} LED',
          ),
          const SizedBox(height: 8),
          _SpecRow(label: 'Aspect', value: _aspectLabel(wall.aspectClass)),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              color: ext.textDim,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final color = destructive ? theme.colorScheme.error : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color ?? ext.accentLight, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
