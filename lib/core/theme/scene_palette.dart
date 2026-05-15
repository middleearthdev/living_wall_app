import 'package:flutter/material.dart';

/// Two-stop gradient swatches per scene id. Used as a placeholder background
/// on dashboard cards and wall hero panels until real photographic thumbnails
/// land in week 8 (after hardware tuning). Each pair is (top, bottom) — the
/// card overlay darkens the bottom further so text stays legible on either.
class ScenePalette {
  ScenePalette._();

  /// Generic dark fallback for unknown scene ids (e.g. wall is off, or scene
  /// was removed from the catalog).
  static const Color _fallbackTop = Color(0xFF1C1F25);
  static const Color _fallbackBottom = Color(0xFF0C0D10);

  static (Color, Color) of(String? sceneId) {
    final pair = sceneId == null ? null : _swatches[sceneId];
    return pair ?? const (_fallbackTop, _fallbackBottom);
  }

  static LinearGradient gradient(String? sceneId) {
    final (top, bottom) = of(sceneId);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [top, bottom],
    );
  }

  static const Map<String, (Color, Color)> _swatches = {
    // Tenang
    'ocean': (Color(0xFF1B4A6E), Color(0xFF0B1F33)),
    'candle': (Color(0xFFE0A04A), Color(0xFF3A1F0A)),
    'dawn': (Color(0xFFB66E7A), Color(0xFF2A1A2E)),
    'aurora': (Color(0xFF3E9C81), Color(0xFF1A1F4A)),
    'rain': (Color(0xFF5A6F88), Color(0xFF1F2530)),
    'breathe': (Color(0xFF78C8DC), Color(0xFF1A2F38)),
    // Fokus
    'focus': (Color(0xFFC8DCFF), Color(0xFF2A3242)),
    'forest': (Color(0xFF4A7A4A), Color(0xFF1B2A1B)),
    'daylight': (Color(0xFFFFFFF0), Color(0xFF6E7080)),
    // Sosial
    'sunset': (Color(0xFFE0833A), Color(0xFF4A1A3E)),
    'dinner': (Color(0xFFC8884A), Color(0xFF3A1F1A)),
    'movie': (Color(0xFF8A4A6E), Color(0xFF1F1A2A)),
    'tokyo': (Color(0xFFD850B0), Color(0xFF1F2A4E)),
    'golden': (Color(0xFFE0B040), Color(0xFF4A2E1A)),
    'sakura': (Color(0xFFE890B8), Color(0xFF3A1F2A)),
    // Dinamis
    'fireplace': (Color(0xFFE0501A), Color(0xFF2A0A0A)),
    'twinkle': (Color(0xFFD8D0F0), Color(0xFF0A0F2E)),
    'party': (Color(0xFFD040D0), Color(0xFF2A0A3E)),
  };
}
