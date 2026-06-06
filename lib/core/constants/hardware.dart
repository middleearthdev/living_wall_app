/// Fixed hardware constants for the Living Wall LED panel.
///
/// These values are determined by the PCB design and strip spec — they are
/// identical across all units (M, L, custom) and must not be derived from
/// user input or QR data.
class LedHardware {
  LedHardware._();

  /// GPIO data pin on the ESP32-S3 PCB. Confirmed by hardware team.
  static const int dataPin = 16;

  /// WLED LED type code for WS2812B.
  static const int type = 22;

  /// Color order: GRB — WS2812B default.
  static const int colorOrder = 0;
}
