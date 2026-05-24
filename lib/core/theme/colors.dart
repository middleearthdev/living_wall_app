import 'package:flutter/material.dart';

/// Single source of truth for brand colors.
/// Inline hex elsewhere in the app is a review-time smell — pull from here.
class AppColors {
  AppColors._();

  // Background and rising surfaces
  static const Color ink = Color(0xFF000000);
  static const Color surface = Color(0xFF0C0D10);
  static const Color surface2 = Color(0xFF141619);
  static const Color surface3 = Color(0xFF1C1F25);

  // Accent — periwinkle. Chrome only; never amber.
  static const Color accent = Color(0xFF7C8EF5);
  static const Color accentLight = Color(0xFF9AA8FF);
  static const Color accentDeep = Color(0xFF5D6FE0);

  // Text. Use textDim/textFaint instead of ad-hoc opacity.
  static const Color text = Color(0xFFEEF0F5);
  static final Color textDim = text.withValues(alpha: 0.56);
  static final Color textFaint = text.withValues(alpha: 0.32);

  // Severity. Reserved for inline error/warning messaging — not chrome.
  // Matches the docs/development-brief.html risk register palette.
  static const Color high = Color(0xFFE8826B);

  // Scene category badges. Not for general chrome.
  static const Color tenang = Color(0xFF8AA6C9);
  static const Color fokus = Color(0xFF9EC5A8);
  static const Color sosial = Color(0xFFD2A07A);
  static const Color dinamis = Color(0xFFC688B8);
}
