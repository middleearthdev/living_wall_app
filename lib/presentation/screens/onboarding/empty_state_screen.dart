import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../routing/routes.dart';
import '../../widgets/onboarding_scaffold.dart';

/// S01 — first launch. No walls in DB yet, so this is the only screen the
/// user can see. CTA hops into the wifi guide.
class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;

    return OnboardingScaffold(
      stepLabel: 'MULAI',
      title: 'Belum ada wall di rumahmu',
      subtitle:
          'Tambahkan panel LED pertama untuk mulai mengatur suasana ruangan.',
      body: Center(
        child: Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ext.surface2,
            border: Border.all(color: ext.surface3),
          ),
          child: Icon(Icons.lightbulb_outline, size: 64, color: ext.accent),
        ),
      ),
      primaryAction: PrimaryButton(
        label: 'Tambah wall pertama',
        onPressed: () => context.push(Routes.onboardingWifi),
      ),
    );
  }
}
