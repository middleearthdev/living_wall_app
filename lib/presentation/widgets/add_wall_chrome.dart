import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Top bar for screens running in add-wall mode. Chevron pops one step
/// back; the ✕ collapses the entire add-wall stack and lands on the
/// configured target — typically the room screen the user came from.
/// The ✕ first shows a confirm dialog ("Batalkan menambah wall?") so a
/// stray tap mid-flow doesn't silently throw away work.
class AddWallTopBar extends StatelessWidget {
  const AddWallTopBar({super.key, required this.onConfirmedClose});

  /// Fires only after the user confirms the cancel dialog.
  final VoidCallback onConfirmedClose;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 28),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Text(
            'Tambah Wall',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            final confirmed = await _confirmCancelAddWall(context);
            if (confirmed && context.mounted) onConfirmedClose();
          },
          icon: Icon(Icons.close, size: 22, color: ext.textDim),
        ),
      ],
    );
  }
}

Future<bool> _confirmCancelAddWall(BuildContext context) async {
  final theme = Theme.of(context);
  final ext = theme.extension<LivingWallTheme>()!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ext.surface2,
      title: const Text('Batalkan menambah wall?'),
      content: Text(
        'Wall belum disimpan. Kamu bisa mulai lagi dari ruangan kapan saja.',
        style: theme.textTheme.bodyMedium?.copyWith(color: ext.textDim),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Lanjutkan', style: TextStyle(color: ext.accentLight)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Batalkan'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Banner that calls out which room a new wall will land in. Used right
/// below [AddWallTopBar] on every add-wall step so the user always sees
/// the destination — particularly important when the flow was entered
/// via the dashboard "+" route, where the room was created moments ago.
class AddWallContextBanner extends StatelessWidget {
  const AddWallContextBanner({super.key, required this.roomName});

  final String roomName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ext.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext.accentLight.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.home_outlined, size: 16, color: ext.accentLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.labelMedium?.copyWith(
                  color: ext.accentLight,
                ),
                children: [
                  const TextSpan(text: 'Wall baru akan masuk ke '),
                  TextSpan(
                    text: roomName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
