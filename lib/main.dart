import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/controllers/ip_reconciler.dart';
import 'core/theme/app_theme.dart';
import 'presentation/routing/app_router.dart';

void main() {
  runApp(const ProviderScope(child: LivingWallApp()));
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
      title: 'Living Wall',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
