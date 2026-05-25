import 'package:flutter/material.dart';

import '../../../core/branding/nauvra_lockup.dart';
import '../../../core/theme/colors.dart';

/// First-frame splash shown while the router resolves `hasAnyWallProvider`
/// from drift. Matches the NAUVRA brand-kit splash spec:
/// - centered stacked lockup (logomark + wordmark + tagline)
/// - radial periwinkle glow on a black field
///
/// WLED attribution is intentionally not on this screen — per CLAUDE.md
/// it lives only in Settings → About → Open Source Licenses, matching
/// the standard EUPL-1.2 compliance pattern (accessibility, not
/// prominence).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.ink,
      body: DecoratedBox(
        decoration: BoxDecoration(
          // Soft periwinkle glow halo behind the lockup.
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 0.9,
            colors: [Color(0x47124281), Color(0x00000000)],
            stops: [0, 1],
          ),
        ),
        child: SafeArea(child: Center(child: NauvraLockup.stacked())),
      ),
    );
  }
}
