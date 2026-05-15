import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/network.dart';
import '../models/wall_state.dart';

enum WledSocketStatus { disconnected, connecting, connected }

/// One socket per wall. Exposes a broadcast stream of [WallState] and
/// transparently reconnects with exponential backoff when the socket drops.
///
/// Callers do not need to handle reconnect themselves — they just listen.
/// `dispose()` permanently stops the reconnect loop.
class WledSocket {
  WledSocket(this._ip);

  final String _ip;
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

  void connect() {
    if (_disposed) return;
    _setStatus(WledSocketStatus.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$_ip/ws'));
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
