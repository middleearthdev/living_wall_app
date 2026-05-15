import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Typography tokens. Display uses Fraunces (italic for emphasis only).
/// Body uses Hanken Grotesk. Loaded via google_fonts to avoid bundling ~400KB.
class AppTypography {
  AppTypography._();

  static TextTheme build(TextTheme base) {
    final body = GoogleFonts.hankenGroteskTextTheme(base).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return body.copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontWeight: FontWeight.w400,
        fontSize: 60,
        letterSpacing: -1.2,
        color: AppColors.text,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontWeight: FontWeight.w400,
        fontSize: 42,
        letterSpacing: -0.7,
        color: AppColors.text,
      ),
      displaySmall: GoogleFonts.fraunces(
        fontWeight: FontWeight.w400,
        fontSize: 34,
        letterSpacing: -0.4,
        color: AppColors.text,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontWeight: FontWeight.w400,
        fontSize: 30,
        color: AppColors.text,
      ),
      headlineSmall: GoogleFonts.fraunces(
        fontWeight: FontWeight.w500,
        fontSize: 24,
        color: AppColors.text,
      ),
    );
  }
}
