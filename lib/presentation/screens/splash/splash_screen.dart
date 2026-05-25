import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/branding/nauvra_lockup.dart';
import '../../../core/theme/colors.dart';

/// First-frame splash shown while the router resolves `hasAnyWallProvider`
/// from drift. Matches the NAUVRA brand-kit splash spec:
/// - centered stacked lockup (logomark + wordmark + tagline)
/// - radial periwinkle glow on a black field
/// - "Powered by WLED" attribution at the bottom in tracked grotesk
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          // Two soft periwinkle glows — top-center halo behind the
          // lockup, faint bottom glow to lift the attribution line.
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 0.9,
            colors: [Color(0x47124281), Color(0x00000000)],
            stops: [0, 1],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Center(child: NauvraLockup.stacked()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: Text(
                    'POWERED BY WLED',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text.withValues(alpha: 0.4),
                      letterSpacing: 8.5 * 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
