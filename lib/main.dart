import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/controllers/ip_reconciler.dart';
import 'core/theme/app_theme.dart';
import 'presentation/routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerThirdPartyLicenses();
  runApp(const ProviderScope(child: LivingWallApp()));
}

/// EUPL-1.2 attribution for the WLED firmware that runs on every panel.
/// Registered with Flutter's [LicenseRegistry] so the bundled
/// `showLicensePage` lists WLED alongside the pub-package licenses it
/// already aggregates. WLED isn't a pub package, so without this it
/// wouldn't appear — the firmware is on the ESP32, the app just talks
/// to it.
///
/// Per CLAUDE.md, this is the *only* place WLED is attributed in the
/// app. No splash, no chrome, no marketing — just the standard
/// Settings → About → Open Source Licenses flow.
void _registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/licenses/eupl-1.2.txt');
    yield LicenseEntryWithLineBreaks(const ['WLED'], text);
  });
}

class LivingWallApp extends ConsumerStatefulWidget {
  const LivingWallApp({super.key});

  @override
  ConsumerState<LivingWallApp> createState() => _LivingWallAppState();
}

class _LivingWallAppState extends ConsumerState<LivingWallApp> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget DHCP reconciliation. Failure is non-fatal — the live
    // sockets surface offline status if any IPs have actually rotted.
    Future.microtask(() {
      ref.read(ipReconciliationProvider.future).catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Nauvra',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
