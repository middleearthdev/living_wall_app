/// Network timing constants tuned for LAN-local WLED.
/// LEDs respond in <50ms on a healthy WiFi; we keep the connect window
/// short so a powered-off wall surfaces as "tidak terjangkau" within a
/// couple of seconds instead of stalling the UI for 6+ seconds across
/// the retry path.
class NetworkTiming {
  NetworkTiming._();

  /// 1.5s connect — generous for any LAN, fast-fail when a wall is
  /// genuinely off. Worst case across the retry: 1.5s + 400ms + 1.5s
  /// ≈ 3.4s before the controller swallows the error.
  static const Duration httpConnectTimeout = Duration(milliseconds: 1500);
  static const Duration httpReceiveTimeout = Duration(seconds: 3);

  /// One retry on transient errors. Local WLED rarely fails twice in a row;
  /// more retries just delay the inevitable "offline" UI.
  static const int httpMaxRetries = 1;
  static const Duration httpRetryDelay = Duration(milliseconds: 400);

  /// Discovery probe — kept short so a /24 sweep finishes in a few seconds.
  static const Duration discoveryProbeTimeout = Duration(milliseconds: 600);

  /// mDNS query window. WLED advertises within ~1s on a clean network; 8s
  /// covers noisy WiFi and devices that just woke up.
  static const Duration discoveryMdnsTimeout = Duration(seconds: 8);

  /// WebSocket reconnect — exponential backoff capped at 30s so a
  /// long-offline wall doesn't hammer the network.
  static const Duration wsReconnectInitial = Duration(seconds: 2);
  static const Duration wsReconnectMax = Duration(seconds: 30);

  /// Application-level WebSocket keepalive. A power-cut wall doesn't
  /// emit a TCP FIN, and the OS keepalive timer is hours by default —
  /// so without this app-level ping the socket would hang in
  /// "connected" state indefinitely, hiding the offline transition
  /// from the toggle / brightness UI. 5s ping + ~5s pong timeout
  /// means a dead wall surfaces within ~10s.
  static const Duration wsPingInterval = Duration(seconds: 5);
}
