import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../routing/routes.dart';

/// Top-level Settings screen. Phase 1 is minimal — just the "Tentang
/// Nauvra" entry that gates the EUPL-1.2 attribution flow. Additional
/// settings (notifications, appearance) land here in later phases.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text('Pengaturan', style: theme.textTheme.titleMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SettingsRow(
              icon: Icons.info_outline,
              label: 'Tentang Nauvra',
              hint: 'Versi, tagline, lisensi sumber terbuka',
              onTap: () => context.push(Routes.settingsAbout),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Pengaturan lain menyusul di rilis berikutnya.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ext.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Material(
      color: ext.surface2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ext.surface3),
          ),
          child: Row(
            children: [
              Icon(icon, color: ext.accentLight, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: ext.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: ext.textDim, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
