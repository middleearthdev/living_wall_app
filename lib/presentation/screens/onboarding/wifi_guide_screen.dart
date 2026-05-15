import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/providers/app_providers.dart';
import '../../../application/providers/onboarding_providers.dart';
import '../../../application/providers/room_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/add_wall_context.dart';
import '../../routing/routes.dart';
import '../../widgets/add_wall_chrome.dart';
import '../../widgets/onboarding_scaffold.dart';

/// S02 — guide the user through the WLED captive-portal dance.
///
/// We can't programmatically join a network on iOS, and Android's
/// WifiNetworkSuggestion flow is too brittle across vendors. So the screen
/// just opens system WiFi settings and reads back the SSID once the user
/// returns. Real captive-portal automation is deferred to hardware testing.
class WifiGuideScreen extends ConsumerStatefulWidget {
  const WifiGuideScreen({super.key, this.addContext});

  /// When non-null, the screen renders in add-wall mode: top bar with close,
  /// context banner pointing at the target room, and "next" navigation that
  /// stays inside the add-wall stack.
  final AddWallContext? addContext;

  @override
  ConsumerState<WifiGuideScreen> createState() => _WifiGuideScreenState();
}

class _WifiGuideScreenState extends ConsumerState<WifiGuideScreen> {
  @override
  void initState() {
    super.initState();
    // Permission ask before snapshot — Android needs location for SSID read.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(wifiServiceProvider).ensureSsidPermission();
      ref.invalidate(wifiSnapshotProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final snapshot = ref.watch(wifiSnapshotProvider);
    final ctx = widget.addContext;
    final targetRoom = ctx == null ? null : ref.watch(roomByIdProvider(ctx.roomId));

    return OnboardingScaffold(
      stepLabel: ctx == null ? 'LANGKAH 1 / 3' : null,
      topBar: ctx == null
          ? null
          : AddWallTopBar(
              onConfirmedClose: () =>
                  context.go(Routes.dashboardRoom(ctx.roomId)),
            ),
      contextBanner: ctx == null
          ? null
          : AddWallContextBanner(roomName: targetRoom?.name ?? 'Ruangan'),
      title: 'Sambungkan wall ke WiFi',
      subtitle:
          'Setelah dinyalakan, wall membuat jaringan sementara bernama "WLED-AP". '
          'Sambungkan HP ke jaringan itu untuk memberi tahu password WiFi rumah.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CurrentNetworkCard(snapshot: snapshot),
          const SizedBox(height: 24),
          Text(
            'Langkah singkat:',
            style: theme.textTheme.titleMedium?.copyWith(color: ext.textDim),
          ),
          const SizedBox(height: 12),
          const _Step(
            n: 1,
            text:
                'Buka pengaturan WiFi, pilih jaringan "WLED-AP" (password: wled1234).',
          ),
          const _Step(
            n: 2,
            text:
                'HP otomatis membuka halaman setup. Pilih WiFi rumah, isi password, tap Save.',
          ),
          const _Step(
            n: 3,
            text:
                'Kembali ke pengaturan WiFi, sambungkan HP ke WiFi rumah, lalu lanjut.',
          ),
        ],
      ),
      secondaryAction: OutlinedButton(
        onPressed: () async {
          // App-Prefs:root=WIFI is undocumented on iOS but reliable; on
          // Android, prefs:// fails so we fall back to the package URI.
          final uri = Platform.isIOS
              ? Uri.parse('App-Prefs:root=WIFI')
              : Uri.parse('package:com.android.settings');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            // Last-resort: open generic settings on Android.
            await launchUrl(
              Uri.parse('intent://settings/wifi#Intent;scheme=android-app;end'),
              mode: LaunchMode.externalApplication,
            );
          }
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: ext.surface3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text('Buka pengaturan WiFi'),
      ),
      primaryAction: PrimaryButton(
        label: 'Lanjut ke pencarian',
        onPressed: () => context.push(Routes.discoveryFor(ctx)),
      ),
    );
  }
}

class _CurrentNetworkCard extends StatelessWidget {
  const _CurrentNetworkCard({required this.snapshot});

  final AsyncValue<dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ext.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.surface3),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi, color: ext.accent, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jaringan saat ini',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ext.textDim,
                  ),
                ),
                const SizedBox(height: 4),
                snapshot.when(
                  data: (snap) {
                    final ssid = snap.ssid as String?;
                    if (ssid == null) {
                      return Text(
                        'Tidak terdeteksi',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: ext.textDim,
                        ),
                      );
                    }
                    return Text(
                      ssid,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                  loading: () => Text(
                    'Memeriksa…',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: ext.textDim,
                    ),
                  ),
                  error: (_, __) => Text(
                    'Tidak terdeteksi',
                    style: theme.textTheme.bodyLarge?.copyWith(
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
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ext.surface3,
            ),
            child: Text(
              '$n',
              style: theme.textTheme.labelMedium?.copyWith(color: ext.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
