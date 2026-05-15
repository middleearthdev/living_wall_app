/// Network timing constants tuned for LAN-local WLED.
/// LEDs respond in <50ms on a healthy WiFi; 3s timeout is generous and
/// catches the "device offline" case fast enough to feel snappy.
class NetworkTiming {
  NetworkTiming._();

  static const Duration httpConnectTimeout = Duration(seconds: 3);
  static const Duration httpReceiveTimeout = Duration(seconds: 3);

  /// One retry on transient errors. Local WLED rarely fails twice in a row;
  /// more retries just delay the inevitable "offline" UI.
  static const int httpMaxRetries = 1;
  static const Duration httpRetryDelay = Duration(milliseconds: 400);

  /// Discovery probe — kept short so a /24 sweep finishes in a few seconds.
  static const Duration discoveryProbeTimeout = Duration(milliseconds: 600);

  /// WebSocket reconnect — exponential backoff capped at 30s so a
  /// long-offline wall doesn't hammer the network.
  static const Duration wsReconnectInitial = Duration(seconds: 2);
  static const Duration wsReconnectMax = Duration(seconds: 30);
}
