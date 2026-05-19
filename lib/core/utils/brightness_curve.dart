import 'dart:math';

/// Maps between user-facing slider position and WLED device brightness.
///
/// Human perception of brightness is logarithmic, not linear. A raw 0-255
/// brightness slider feels squished at the bottom: dragging from 100% to
/// 50% is barely noticeable, while 10% to 0% drops off a cliff. Living
/// Wall is a mood-lighting product where the ambient range (~5-40%
/// perceived) is used heavily, so we apply a gamma curve so each segment
/// of slider travel maps to a comparable perceived change.
///
/// Gamma 2.2 is the standard sRGB display gamma — close enough to the
/// CIE L* lightness curve for our purposes, much simpler to compute, and
/// matches what user eyes are already calibrated to from screens.
///
/// HARDWARE-VALIDATION GATE: some WLED builds also apply gamma correction
/// inside the firmware (config flag `gc_bri`). If both layers apply
/// gamma the wall will be too dim — visible artifact is a hard floor
/// where slider 0-25% all looks the same near-black. Confirm `gc_bri`
/// is OFF on the production firmware build before final tuning, or
/// reduce [_gamma] toward 1.0 to compensate.
class BrightnessCurve {
  BrightnessCurve._();

  static const double _gamma = 2.2;

  /// Slider position (0..255) → device brightness sent to WLED (0..255).
  static int sliderToDevice(double slider) {
    final clamped = slider.clamp(0.0, 255.0);
    if (clamped <= 0) return 0;
    final t = clamped / 255.0;
    return (pow(t, _gamma) * 255).round();
  }

  /// Device brightness (0..255) → slider position (0..255). Used when
  /// seeding the thumb from a WS echo or initial state so the visible
  /// position reflects perceived brightness, not raw device value.
  static double deviceToSlider(int device) {
    final clamped = device.clamp(0, 255);
    if (clamped <= 0) return 0;
    final t = clamped / 255.0;
    return pow(t, 1 / _gamma).toDouble() * 255;
  }
}
