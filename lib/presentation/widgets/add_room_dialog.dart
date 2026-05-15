import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/app_providers.dart';
import '../../application/providers/room_providers.dart';
import '../../core/theme/app_theme.dart';
import '../routing/routes.dart';

/// Modal entry point for "tambah ruangan" from the dashboard. By design this
/// is a dialog, not a route — the spec calls it out as an intentional
/// non-route because a half-typed room name should never end up in the back
/// stack as a navigable URL.
class AddRoomDialog extends ConsumerStatefulWidget {
  const AddRoomDialog({super.key});

  @override
  ConsumerState<AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends ConsumerState<AddRoomDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama ruangan tidak boleh kosong');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final homes = ref.read(homeRepositoryProvider);
      final home = await homes.ensureDefaultHome();
      final room = await homes.createRoom(homeId: home.id, name: name);
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      final navigator = GoRouter.of(context);
      Navigator.of(context).pop(room);
      // Per spec B.2 — "Buat & tambah wall": after creating the room, hand
      // straight off to the add-wall flow with the new room locked in. If
      // the user cancels mid-add-wall the room is preserved (Dashboard
      // shows it as an empty room with "Tambah wall pertama").
      navigator.push(Routes.addWallWifi(room.id));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Gagal: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;

    return Dialog(
      backgroundColor: ext.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ruangan baru', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Beri nama ruangan. Tambah wall pertamanya setelah ini.',
              style: theme.textTheme.bodySmall?.copyWith(color: ext.textDim),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'mis. Ruang Tamu',
                filled: true,
                fillColor: ext.surface3,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
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
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: ext.textDim),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ext.accent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Buat & tambah wall'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
