import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// NAUVRA logomark — four rounded panels in a 2×2 grid, one lit with a
/// white spark. Translates the brand-kit SVG directly via [CustomPainter]
/// (no flutter_svg dependency).
///
/// Default is the "filled" treatment from the kit (gradient panels +
/// muted accents). Use [variant] = [NauvraLogomarkVariant.frame] for the
/// in-lockup version with the periwinkle border + soft glow halo.
class NauvraLogomark extends StatelessWidget {
  const NauvraLogomark({
    super.key,
    this.size = 64,
    this.variant = NauvraLogomarkVariant.frame,
  });

  /// Edge length of the rendered box. The mark itself is always 1:1.
  final double size;

  /// Frame = bordered panel with halo (lockup / splash use).
  /// Filled  = solid background tile (app icon / button use).
  final NauvraLogomarkVariant variant;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LogomarkPainter(variant: variant),
    );
  }
}

enum NauvraLogomarkVariant { frame, filled }

class _LogomarkPainter extends CustomPainter {
  _LogomarkPainter({required this.variant});

  final NauvraLogomarkVariant variant;

  // Brand-kit ratios: panel = 84×84 reference, frame radius 16, inner
  // panel size 32 with 6.5 radius, spark radius 3.5 at (23, 23). Scaled
  // by `unit` so the same painter works at any pixel size.
  static const double _refBox = 84;
  static const double _refFrameRadius = 16;
  static const double _refInnerSize = 32;
  static const double _refInnerRadius = 6.5;
  static const double _refInnerInset = 7;
  static const double _refInnerGap = 6; // 45 - (7 + 32) = 6
  static const double _refSparkRadius = 3.5;
  static const double _refSparkCenter = 23;
  static const double _refFrameStroke = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / _refBox;
    final accent = AppColors.accentLight;
    final accentDeep = AppColors.accentDeep;

    // Optional halo behind the mark for the framed variant (used on dark
    // splash + lockup backgrounds). Kept off the filled variant so app
    // icons stay tight inside their corner radius.
    if (variant == NauvraLogomarkVariant.frame) {
      final haloCenter = Offset(size.width / 2, size.height / 2);
      final haloRadius = size.shortestSide * 0.85;
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: haloCenter, radius: haloRadius));
      canvas.drawCircle(haloCenter, haloRadius, haloPaint);
    }

    // Center the 84-unit mark inside the available box.
    final markSide = _refBox * unit;
    final origin = Offset(
      (size.width - markSide) / 2,
      (size.height - markSide) / 2,
    );

    // Outer rounded frame (border only for the framed variant; filled
    // skips the border so the app-icon background carries the color).
    if (variant == NauvraLogomarkVariant.frame) {
      final frame = RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, markSide, markSide),
        Radius.circular(_refFrameRadius * unit),
      );
      final framePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _refFrameStroke * unit
        ..color = accent.withValues(alpha: 0.55);
      canvas.drawRRect(frame, framePaint);
    }

    // 2×2 panel layout. Top-left (lit) and bottom-right carry the
    // gradient; top-right and bottom-left are muted accent fills.
    final innerSize = _refInnerSize * unit;
    final innerRadius = Radius.circular(_refInnerRadius * unit);
    final inset = _refInnerInset * unit;
    final step = inset + innerSize + _refInnerGap * unit;

    final activeRect = Rect.fromLTWH(
      origin.dx + inset,
      origin.dy + inset,
      innerSize,
      innerSize,
    );
    final activeShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [accent, accentDeep],
    ).createShader(activeRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, innerRadius),
      Paint()..shader = activeShader,
    );

    final mutedFill = Paint()..color = accent.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + step, origin.dy + inset, innerSize, innerSize),
        innerRadius,
      ),
      mutedFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + inset, origin.dy + step, innerSize, innerSize),
        innerRadius,
      ),
      mutedFill,
    );

    final bottomRightRect = Rect.fromLTWH(
      origin.dx + step,
      origin.dy + step,
      innerSize,
      innerSize,
    );
    final bottomRightShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [accent, accentDeep],
    ).createShader(bottomRightRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bottomRightRect, innerRadius),
      Paint()
        ..shader = bottomRightShader
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    // White spark in the active (top-left) panel.
    canvas.drawCircle(
      Offset(
        origin.dx + _refSparkCenter * unit,
        origin.dy + _refSparkCenter * unit,
      ),
      _refSparkRadius * unit,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(_LogomarkPainter oldDelegate) =>
      oldDelegate.variant != variant;
}
