import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Snapshot of the device's current WiFi context. All fields can be null on
/// permission denial or when the device is on cellular or in airplane mode.
class WifiSnapshot {
  const WifiSnapshot({this.ssid, this.gatewayIp, this.deviceIp});

  final String? ssid;
  final String? gatewayIp;
  final String? deviceIp;

  /// True when the user is connected to a WLED panel's setup AP. We detect by
  /// SSID prefix because every WLED AP advertises as `WLED-AP` or `WLED-<id>`.
  bool get isOnWledSetupAp {
    final s = ssid;
    return s != null && s.toUpperCase().startsWith('WLED-');
  }
}

/// Thin wrapper over network_info_plus + permission_handler. Lives in `data/`
/// because it's IO; controllers consume it via providers and surface the
/// permission-denied state to the UI.
class WifiService {
  WifiService({NetworkInfo? info}) : _info = info ?? NetworkInfo();

  final NetworkInfo _info;

  /// Reading SSID on Android 8.1+ requires `ACCESS_FINE_LOCATION` granted at
  /// runtime. Call this before [snapshot] on first run; safe to call again.
  /// On iOS the system handles the local-network prompt automatically once the
  /// app tries to talk to a LAN host.
  Future<bool> ensureSsidPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<WifiSnapshot> snapshot() async {
    // Each lookup is best-effort: one failing field shouldn't blank the rest.
    final results = await Future.wait([
      _safe(() => _info.getWifiName()),
      _safe(() => _info.getWifiGatewayIP()),
      _safe(() => _info.getWifiIP()),
    ]);
    return WifiSnapshot(
      ssid: _cleanSsid(results[0]),
      gatewayIp: results[1],
      deviceIp: results[2],
    );
  }

  Future<String?> _safe(Future<String?> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }

  /// network_info_plus wraps the SSID in quotes on some Android versions.
  String? _cleanSsid(String? raw) {
    if (raw == null) return null;
    var s = raw;
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      s = s.substring(1, s.length - 1);
    }
    if (s.isEmpty || s == '<unknown ssid>') return null;
    return s;
  }
}
