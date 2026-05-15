import 'dart:async';

/// Trailing-edge throttler. Coalesces bursts of writes into one call per
/// [cooldown] — while a previous call is in flight or the cooldown is still
/// ticking, the most recent value is held and dispatched when the slot frees.
///
/// We honor the trailing edge so a fast slider drag that releases on "85%"
/// always lands on 85% rather than the last intermediate frame.
class Throttler<T extends Object> {
  Throttler({
    required this.cooldown,
    required Future<void> Function(T value) onFire,
  }) : _onFire = onFire;

  final Duration cooldown;
  final Future<void> Function(T value) _onFire;

  T? _pending;
  bool _busy = false;
  Timer? _cooldownTimer;
  bool _disposed = false;

  void submit(T value) {
    if (_disposed) return;
    _pending = value;
    _maybeFire();
  }

  void _maybeFire() {
    if (_busy || _cooldownTimer != null || _pending == null) return;
    final value = _pending as T;
    _pending = null;
    _busy = true;
    _onFire(value).whenComplete(() {
      _busy = false;
      if (_disposed) return;
      _cooldownTimer = Timer(cooldown, () {
        _cooldownTimer = null;
        _maybeFire();
      });
    });
  }

  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _pending = null;
  }
}
