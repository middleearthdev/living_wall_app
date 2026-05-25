import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/network.dart';
import '../models/wall_state.dart';

enum WledSocketStatus { disconnected, connecting, connected }

/// One socket per wall. Exposes a broadcast stream of [WallState] and
/// transparently reconnects with exponential backoff when the socket drops.
///
/// Callers do not need to handle reconnect themselves — they just listen.
/// `dispose()` permanently stops the reconnect loop.
///
/// [probe] is an optional async health check called before each
/// "connected" transition. Without it, the socket optimistically reports
/// connected as soon as the channel object is created — but the
/// underlying TCP handshake hasn't necessarily succeeded yet. On a
/// powered-off wall this creates a ~10s false-connected window each
/// reconnect cycle (until ping/pong eventually times out), which bounces
/// the toggle on/off in the UI. With a probe, we only mark connected
/// once the wall has confirmed it's actually responsive.
class WledSocket {
  WledSocket(this._ip, {Future<bool> Function()? probe}) : _probe = probe;

  final String _ip;
  final Future<bool> Function()? _probe;
  final StreamController<WallState> _states =
      StreamController<WallState>.broadcast();
  final StreamController<WledSocketStatus> _statuses =
      StreamController<WledSocketStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Duration _nextDelay = NetworkTiming.wsReconnectInitial;
  bool _disposed = false;
  WledSocketStatus _currentStatus = WledSocketStatus.disconnected;

  Stream<WallState> get stream => _states.stream;
  Stream<WledSocketStatus> get status => _statuses.stream;

  /// Latest-known status. Useful for late subscribers since [_statuses] is a
  /// broadcast controller without replay — a fresh listener won't see the
  /// "connected" event fired before it attached. Pair with the stream:
  /// seed with this, then yield from the stream.
  WledSocketStatus get currentStatus => _currentStatus;

  Future<void> connect() async {
    if (_disposed) return;
    _setStatus(WledSocketStatus.connecting);

    // Probe before opening WS so a powered-off wall doesn't transition
    // through a false "connected" state. The WS handshake is async and
    // we don't get a clean success callback — without this we'd flip
    // to connected the instant the channel object is created, then
    // bounce back to disconnected ~10s later when ping/pong times out.
    if (_probe != null) {
      final alive = await _probe();
      if (_disposed) return;
      if (!alive) {
        _scheduleReconnect();
        return;
      }
    }

    try {
      // IOWebSocketChannel (vs. the platform-agnostic WebSocketChannel)
      // gives us [pingInterval], which catches a wall whose power is
      // cut after the connection was already established: OS TCP
      // keepalive is hours by default, but a 5s app-level ping that
      // doesn't pong tears the socket down in ~10s and triggers
      // reconnect.
      _channel = IOWebSocketChannel.connect(
        Uri.parse('ws://$_ip/ws'),
        pingInterval: NetworkTiming.wsPingInterval,
      );
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    _subscription = _channel!.stream.listen(
      _onMessage,
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
    _setStatus(WledSocketStatus.connected);
    _nextDelay = NetworkTiming.wsReconnectInitial;
  }

  void _setStatus(WledSocketStatus next) {
    _currentStatus = next;
    _statuses.add(next);
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return;
    final state = json['state'];
    if (state is Map<String, dynamic>) {
      _states.add(WallState.fromWledJson(state));
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _setStatus(WledSocketStatus.disconnected);
    _teardownChannel();

    _reconnectTimer?.cancel();
    final delay = _nextDelay;
    _reconnectTimer = Timer(delay, connect);
    _nextDelay = _expBackoff(delay);
  }

  Duration _expBackoff(Duration current) {
    final doubled = current * 2;
    return doubled > NetworkTiming.wsReconnectMax
        ? NetworkTiming.wsReconnectMax
        : doubled;
  }

  void _teardownChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _teardownChannel();
    await _states.close();
    await _statuses.close();
  }
}
