import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/settings_providers.dart';
import '../../../core/branding/nauvra_lockup.dart';
import '../../../core/theme/app_theme.dart';

/// "Tentang Nauvra" — second hop from Dashboard → Settings.
///
/// Shows the brand lockup, app + firmware versions, and the entry into
/// Flutter's bundled license aggregator (`showLicensePage`). That's
/// where WLED attribution surfaces: registered in `main.dart` via
/// [LicenseRegistry.addLicense] so it sits alongside the pub-package
/// licenses without any special wiring here.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  /// Hardcoded floor for the firmware-version label when no wall is
  /// reachable to probe. Bump this whenever the factory baseline moves.
  static const _firmwareFallback = '0.15.x';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final appInfo = ref.watch(appInfoProvider);
    final firmwareVersions = ref.watch(firmwareVersionsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text('Tentang Nauvra', style: theme.textTheme.titleMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const SizedBox(height: 12),
            const Center(
              child: NauvraLockup.stacked(
                markSize: 96,
                wordmarkSize: 24,
                taglineSize: 9,
              ),
            ),
            const SizedBox(height: 32),
            _InfoRow(
              label: 'Versi aplikasi',
              value: appInfo.when(
                data: (i) => '${i.version}+${i.buildNumber}',
                loading: () => '…',
                error: (_, __) => 'tidak tersedia',
              ),
            ),
            _InfoRow(
              label: 'Versi firmware wall',
              value: firmwareVersions.when(
                data: (vs) => vs.isEmpty
                    ? _firmwareFallback
                    : (vs.length == 1 ? vs.single : '${vs.first} – ${vs.last}'),
                loading: () => '…',
                error: (_, __) => _firmwareFallback,
              ),
            ),
            const SizedBox(height: 32),
            _SectionLabel(text: 'Legal'),
            const SizedBox(height: 8),
            Material(
              color: ext.surface2,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openLicensePage(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ext.surface3),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: ext.accentLight,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lisensi sumber terbuka',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'WLED firmware + pustaka pendukung aplikasi',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: ext.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: ext.textDim,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '© 2026 Nauvra. Dibangun di atas WLED open-source firmware.',
                textAlign: TextAlign.center,
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

  Future<void> _openLicensePage(BuildContext context, WidgetRef ref) async {
    final info = await ref.read(appInfoProvider.future);
    if (!context.mounted) return;
    showLicensePage(
      context: context,
      applicationName: 'Nauvra',
      applicationVersion: '${info.version}+${info.buildNumber}',
      applicationLegalese:
          '© 2026 Nauvra · Living Ambient Walls.\n'
          'Dibangun di atas WLED open-source firmware.',
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: ext.textDim),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: ext.textFaint,
        letterSpacing: 1.4,
      ),
    );
  }
}
