import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// Brand tokens that Material's ThemeData can't express natively.
/// Read via `Theme.of(context).extension<LivingWallTheme>()`.
@immutable
class LivingWallTheme extends ThemeExtension<LivingWallTheme> {
  const LivingWallTheme({
    required this.accent,
    required this.accentLight,
    required this.accentDeep,
    required this.surface2,
    required this.surface3,
    required this.textDim,
    required this.textFaint,
    required this.tenang,
    required this.fokus,
    required this.sosial,
    required this.dinamis,
  });

  final Color accent;
  final Color accentLight;
  final Color accentDeep;
  final Color surface2;
  final Color surface3;
  final Color textDim;
  final Color textFaint;
  final Color tenang;
  final Color fokus;
  final Color sosial;
  final Color dinamis;

  @override
  LivingWallTheme copyWith({
    Color? accent,
    Color? accentLight,
    Color? accentDeep,
    Color? surface2,
    Color? surface3,
    Color? textDim,
    Color? textFaint,
    Color? tenang,
    Color? fokus,
    Color? sosial,
    Color? dinamis,
  }) {
    return LivingWallTheme(
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentDeep: accentDeep ?? this.accentDeep,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      textDim: textDim ?? this.textDim,
      textFaint: textFaint ?? this.textFaint,
      tenang: tenang ?? this.tenang,
      fokus: fokus ?? this.fokus,
      sosial: sosial ?? this.sosial,
      dinamis: dinamis ?? this.dinamis,
    );
  }

  @override
  LivingWallTheme lerp(ThemeExtension<LivingWallTheme>? other, double t) {
    if (other is! LivingWallTheme) return this;
    return LivingWallTheme(
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      tenang: Color.lerp(tenang, other.tenang, t)!,
      fokus: Color.lerp(fokus, other.fokus, t)!,
      sosial: Color.lerp(sosial, other.sosial, t)!,
      dinamis: Color.lerp(dinamis, other.dinamis, t)!,
    );
  }

  static const LivingWallTheme dark = LivingWallTheme(
    accent: AppColors.accent,
    accentLight: AppColors.accentLight,
    accentDeep: AppColors.accentDeep,
    surface2: AppColors.surface2,
    surface3: AppColors.surface3,
    // textDim/textFaint are not const (built from withValues); see initializer in buildAppTheme.
    textDim: Color(0x8FEEF0F5),
    textFaint: Color(0x52EEF0F5),
    tenang: AppColors.tenang,
    fokus: AppColors.fokus,
    sosial: AppColors.sosial,
    dinamis: AppColors.dinamis,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
    surface: AppColors.ink,
  ).copyWith(primary: AppColors.accent);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: colorScheme,
    textTheme: AppTypography.build(base.textTheme),
    extensions: const <ThemeExtension<dynamic>>[LivingWallTheme.dark],
  );
}
