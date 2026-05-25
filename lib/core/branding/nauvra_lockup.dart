import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/colors.dart';
import 'nauvra_logomark.dart';

/// "NAUVRA" wordmark in Unbounded Medium, brand-kit spec:
/// `letter-spacing: 0.16em` for hero lockups, `0.08em` for compact chrome.
class NauvraWordmark extends StatelessWidget {
  const NauvraWordmark({
    super.key,
    this.fontSize = 28,
    this.color,
    this.tight = false,
  });

  final double fontSize;
  final Color? color;

  /// `true` = compact spacing (0.08em) for nav bars / chips.
  /// `false` = full hero spacing (0.16em) for splash / lockups.
  final bool tight;

  @override
  Widget build(BuildContext context) {
    return Text(
      'NAUVRA',
      style: GoogleFonts.unbounded(
        fontWeight: FontWeight.w500,
        fontSize: fontSize,
        color: color ?? AppColors.text,
        letterSpacing: fontSize * (tight ? 0.08 : 0.16),
        height: 1,
      ),
    );
  }
}

/// "LIVING AMBIENT WALLS" tagline. Hanken Grotesk SemiBold all-caps with
/// 0.26em tracking — always paired with the periwinkle separator line
/// above per brand-kit rule.
class NauvraTagline extends StatelessWidget {
  const NauvraTagline({super.key, this.fontSize = 10.5, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'LIVING AMBIENT WALLS',
      style: GoogleFonts.hankenGrotesk(
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        color: color ?? AppColors.accentLight,
        letterSpacing: fontSize * 0.26,
        height: 1,
      ),
    );
  }
}

/// Composed brand lockup: logomark + wordmark + 1.3px periwinkle separator
/// + tagline. Two variants matching the brand kit:
/// - [stacked]: mark on top, wordmark + tagline beneath (splash, hero).
/// - [horizontal]: mark on the left, wordmark + tagline stacked on the
///   right (header bars, signature blocks).
class NauvraLockup extends StatelessWidget {
  const NauvraLockup.stacked({
    super.key,
    this.markSize = 84,
    this.wordmarkSize = 28,
    this.taglineSize = 10.5,
  }) : _orientation = _LockupOrientation.stacked;

  const NauvraLockup.horizontal({
    super.key,
    this.markSize = 56,
    this.wordmarkSize = 22,
    this.taglineSize = 9,
  }) : _orientation = _LockupOrientation.horizontal;

  final _LockupOrientation _orientation;
  final double markSize;
  final double wordmarkSize;
  final double taglineSize;

  @override
  Widget build(BuildContext context) {
    final wordAndTag = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _orientation == _LockupOrientation.stacked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        NauvraWordmark(fontSize: wordmarkSize),
        SizedBox(height: wordmarkSize * 0.4),
        // Brand-kit separator: 1.3px periwinkle, alpha .5. Width scales
        // with the wordmark so the visual proportion holds across sizes.
        Container(
          width: wordmarkSize * 1.6,
          height: 1.3,
          color: AppColors.accentLight.withValues(alpha: 0.5),
        ),
        SizedBox(height: wordmarkSize * 0.55),
        NauvraTagline(fontSize: taglineSize),
      ],
    );

    if (_orientation == _LockupOrientation.stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          NauvraLogomark(size: markSize),
          SizedBox(height: markSize * 0.32),
          wordAndTag,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NauvraLogomark(size: markSize),
        SizedBox(width: markSize * 0.32),
        wordAndTag,
      ],
    );
  }
}

enum _LockupOrientation { stacked, horizontal }
