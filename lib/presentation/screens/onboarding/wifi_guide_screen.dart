import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
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
    // SSID readout is Android-only. iOS would need the paid
    // wifi-info entitlement we deliberately do not ship, so we skip
    // the permission ask and the snapshot fetch entirely.
    if (!Platform.isAndroid) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(wifiServiceProvider).ensureSsidPermission();
      ref.invalidate(wifiSnapshotProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    final ctx = widget.addContext;
    final targetRoom = ctx == null
        ? null
        : ref.watch(roomByIdProvider(ctx.roomId));

    // iOS gets a static informational card — we can't read SSID, so
    // pretending to "detect" it leaves the user staring at a permanent
    // "Tidak terdeteksi" diagnostic that reads as broken. The
    // wifiSnapshotProvider is intentionally not watched on iOS so its
    // autoDispose lifecycle doesn't churn for a value we ignore.
    final wifiCard = Platform.isAndroid
        ? _CurrentNetworkCard(snapshot: ref.watch(wifiSnapshotProvider))
        : const _IosWifiReminderCard();

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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            wifiCard,
            const SizedBox(height: 24),
            Text(
              'Langkah singkat:',
              style: theme.textTheme.titleMedium?.copyWith(color: ext.textDim),
            ),
            const SizedBox(height: 12),
            // Step 1 wording follows the button behavior: Android lands at
            // the WiFi panel directly, iOS lands at the app's settings page
            // and the user has to navigate up.
            _Step(
              n: 1,
              text: Platform.isAndroid
                  ? 'Tap "Buka pengaturan WiFi" di bawah, lalu pilih jaringan "WLED-AP" (password: wled1234).'
                  : 'Tap "Buka pengaturan" di bawah, tap "< Settings" di pojok kiri atas, pilih "Wi-Fi", lalu pilih jaringan "WLED-AP" (password: wled1234).',
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
      ),
      secondaryAction: OutlinedButton(
        // Platform asymmetry: Android exposes a public, documented intent
        // action for the WiFi panel; iOS does not allow third-party apps
        // to deep-link there at all. Fall back to the app's own settings
        // page when the intent is unhandled (rare, mainly heavily-skinned
        // Android ROMs).
        onPressed: () async {
          if (Platform.isAndroid) {
            final uri = Uri.parse(
              'intent:#Intent;action=android.settings.WIFI_SETTINGS;end',
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return;
            }
          }
          await openAppSettings();
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: ext.surface3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          Platform.isAndroid ? 'Buka pengaturan WiFi' : 'Buka pengaturan',
        ),
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

    final String? ssid = snapshot.maybeWhen(
      data: (snap) => snap.ssid as String?,
      orElse: () => null,
    );
    final isLoading = snapshot.isLoading;
    final showDiagnostic = !isLoading && ssid == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ext.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.surface3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                    if (isLoading)
                      Text(
                        'Memeriksa…',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: ext.textDim,
                        ),
                      )
                    else if (ssid == null)
                      Text(
                        'Tidak terdeteksi',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: ext.textDim,
                        ),
                      )
                    else
                      Text(
                        ssid,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (showDiagnostic) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: ext.surface3),
            const SizedBox(height: 12),
            Text(
              'Aktifkan WiFi dan berikan izin lokasi supaya nama jaringan bisa terbaca.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ext.textFaint,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openAppSettings(),
                icon: Icon(
                  Icons.settings_outlined,
                  size: 16,
                  color: ext.accent,
                ),
                label: Text(
                  'Buka pengaturan permission',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: ext.accent,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// iOS variant of the WiFi card. Static informational reminder rather
/// than a "detection" pattern — we can't read the SSID, so the Android
/// "Jaringan saat ini" framing would always degrade to a permanent
/// "Tidak terdeteksi" that reads as broken.
class _IosWifiReminderCard extends StatelessWidget {
  const _IosWifiReminderCard();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi, color: ext.accent, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WiFi rumah',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ext.textDim,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pastikan HP sudah terhubung ke jaringan tempat wall akan dipakai.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
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
