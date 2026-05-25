import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/nauvra_logomark.dart';
import '../../routing/routes.dart';
import '../../widgets/onboarding_scaffold.dart';

/// S01 — first launch. No walls in DB yet, so this is the only screen the
/// user can see. CTA hops into the wifi guide.
///
/// The body slot carries the NAUVRA logomark (frame variant — its built-in
/// periwinkle halo doubles as the visual focal point that the old generic
/// lightbulb icon used to provide).
class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      stepLabel: 'MULAI',
      title: 'Belum ada wall di rumahmu',
      subtitle:
          'Tambahkan panel LED pertama untuk mulai mengatur suasana ruangan.',
      body: const Center(child: NauvraLogomark(size: 168)),
      primaryAction: PrimaryButton(
        label: 'Tambah wall pertama',
        onPressed: () => context.push(Routes.onboardingWifi),
      ),
    );
  }
}
